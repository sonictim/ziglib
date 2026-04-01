const std = @import("std");

// ── Fast JSON helpers ─────────────────────────────────────────────────────────
//
// Minimal JSON field extraction for hot paths that skip full parseFromSlice.
// These scan raw JSON bytes and return slices into the source buffer (zero-copy).
// Use `stringify` to convert request structs to JSON at comptime.

/// Convert a struct to a JSON string at comptime. Supports structs with
/// optional fields, enums, bools, integers, strings, and nested structs.
/// Null optional fields are omitted.
///
/// Usage:
///   const req = comptime stringify(GetTrackListRequestBody{});
///   const resp = try ptsl.send(a, .GetTrackList, req);
pub fn stringify(comptime value: anytype) []const u8 {
    comptime return stringifyValue(value);
}

fn stringifyValue(comptime value: anytype) []const u8 {
    const T = @TypeOf(value);
    const info = @typeInfo(T);

    if (T == []const u8) return "\"" ++ value ++ "\"";
    if (info == .null) return "null";

    if (info == .@"enum") return "\"" ++ @tagName(value) ++ "\"";

    if (info == .bool) return if (value) "true" else "false";

    if (info == .int or info == .comptime_int) return std.fmt.comptimePrint("{d}", .{value});

    if (info == .optional) {
        if (value) |v| return stringifyValue(v);
        return "null";
    }

    if (info == .@"struct") {
        comptime {
            var result: []const u8 = "{";
            var first = true;
            for (@typeInfo(T).@"struct".fields) |field| {
                const field_value = @field(value, field.name);
                // Skip null optionals
                if (@typeInfo(field.type) == .optional) {
                    if (field_value == null) continue;
                }
                if (!first) result = result ++ ",";
                result = result ++ "\"" ++ field.name ++ "\":" ++ stringifyValue(field_value);
                first = false;
            }
            return result ++ "}";
        }
    }

    if (info == .pointer and info.pointer.size == .slice) {
        comptime {
            var result: []const u8 = "[";
            for (value, 0..) |item, i| {
                if (i > 0) result = result ++ ",";
                result = result ++ stringifyValue(item);
            }
            return result ++ "]";
        }
    }

    @compileError("json.stringify: unsupported type " ++ @typeName(T));
}

/// Find the next string value for a given key starting at `pos`.
/// Returns the value slice and updates `pos` past the closing quote.
/// E.g. for key "name" matching `"name":"hello"`, returns "hello".
/// Skip whitespace (space, tab, newline, carriage return).
fn skipWs(buf: []const u8, start: usize) usize {
    var i = start;
    while (i < buf.len and (buf[i] == ' ' or buf[i] == '\t' or buf[i] == '\n' or buf[i] == '\r')) : (i += 1) {}
    return i;
}

pub fn getInt(buf: []const u8, key: []const u8) ?i64 {
    return findInt(buf, 0, key);
}
fn findInt(buf: []const u8, start: usize, key: []const u8) ?i64 {
    var needle_buf: [128]u8 = undefined;
    if (key.len + 3 > needle_buf.len) return null;
    needle_buf[0] = '"';
    @memcpy(needle_buf[1..][0..key.len], key);
    @memcpy(needle_buf[1 + key.len ..][0..2], "\":");
    const needle = needle_buf[0 .. key.len + 3];

    const needle_start = std.mem.indexOfPos(u8, buf, start, needle) orelse return null;
    const i = skipWs(buf, needle_start + needle.len);
    if (i >= buf.len) return null;
    // Parse digits (with optional leading minus)
    const val_start = i;
    var val_end = val_start;
    if (val_end < buf.len and buf[val_end] == '-') val_end += 1;
    while (val_end < buf.len and buf[val_end] >= '0' and buf[val_end] <= '9') : (val_end += 1) {}
    if (val_end == val_start) return null;
    return std.fmt.parseInt(i64, buf[val_start..val_end], 10) catch null;
}
pub fn getString(buf: []const u8, key: []const u8) ?[]const u8 {
    // Build search needle: "key":
    var needle_buf: [128]u8 = undefined;
    if (key.len + 3 > needle_buf.len) return null;
    needle_buf[0] = '"';
    @memcpy(needle_buf[1..][0..key.len], key);
    @memcpy(needle_buf[1 + key.len ..][0..2], "\":");
    const needle = needle_buf[0 .. key.len + 3];

    const start = std.mem.indexOfPos(u8, buf, 0, needle) orelse return null;
    // Skip optional whitespace after ':', then expect opening '"'
    const i = skipWs(buf, start + needle.len);
    if (i >= buf.len or buf[i] != '"') return null;
    const val_start = i + 1;
    const val_end = std.mem.indexOfScalarPos(u8, buf, val_start, '"') orelse return null;
    return buf[val_start..val_end];
}
pub fn findString(buf: []const u8, pos: *usize, key: []const u8) ?[]const u8 {
    // Build search needle: "key":
    var needle_buf: [128]u8 = undefined;
    if (key.len + 3 > needle_buf.len) return null;
    needle_buf[0] = '"';
    @memcpy(needle_buf[1..][0..key.len], key);
    @memcpy(needle_buf[1 + key.len ..][0..2], "\":");
    const needle = needle_buf[0 .. key.len + 3];

    const start = std.mem.indexOfPos(u8, buf, pos.*, needle) orelse return null;
    // Skip optional whitespace after ':', then expect opening '"'
    const i = skipWs(buf, start + needle.len);
    if (i >= buf.len or buf[i] != '"') return null;
    const val_start = i + 1;
    const val_end = std.mem.indexOfScalarPos(u8, buf, val_start, '"') orelse return null;
    pos.* = val_end + 1;
    return buf[val_start..val_end];
}

/// Find the next boolean value for a given key starting at `pos`.
/// Returns true/false based on whether the value starts with 't'.
pub fn findBool(buf: []const u8, pos: *usize, key: []const u8) ?bool {
    var needle_buf: [128]u8 = undefined;
    if (key.len + 3 > needle_buf.len) return null;
    needle_buf[0] = '"';
    @memcpy(needle_buf[1..][0..key.len], key);
    @memcpy(needle_buf[1 + key.len ..][0..2], "\":");
    const needle = needle_buf[0 .. key.len + 3];

    const start = std.mem.indexOfPos(u8, buf, pos.*, needle) orelse return null;
    const val_start = skipWs(buf, start + needle.len);
    pos.* = val_start + 1;
    return val_start < buf.len and buf[val_start] == 't';
}

pub fn getBool(buf: []const u8, key: []const u8) ?bool {
    var needle_buf: [128]u8 = undefined;
    if (key.len + 3 > needle_buf.len) return null;
    needle_buf[0] = '"';
    @memcpy(needle_buf[1..][0..key.len], key);
    @memcpy(needle_buf[1 + key.len ..][0..2], "\":");
    const needle = needle_buf[0 .. key.len + 3];

    const start = std.mem.indexOfPos(u8, buf, 0, needle) orelse return null;
    const val_start = skipWs(buf, start + needle.len);
    return val_start < buf.len and buf[val_start] == 't';
}

/// Iterator over JSON objects in an array value for a given key.
/// Given `"track_list":[{...},{...}]`, iterating with key "track_list"
/// yields slices `{...}` for each object, handling nested braces.
pub const ObjectIterator = struct {
    buf: []const u8,
    pos: usize,
    end: usize,

    /// Find a string value within this object slice.
    pub fn getString(self: *const ObjectIterator, key: []const u8) ?[]const u8 {
        const obj = self.buf[self.pos..self.end];
        var p: usize = 0;
        return findString(obj, &p, key);
    }

    /// Find an integer value within this object slice.
    pub fn getInt(self: *const ObjectIterator, key: []const u8) ?i64 {
        const obj = self.buf[self.pos..self.end];
        return findInt(obj, 0, key);
    }

    /// Find a boolean value within this object slice.
    pub fn getBool(self: *const ObjectIterator, key: []const u8) ?bool {
        const obj = self.buf[self.pos..self.end];
        var p: usize = 0;
        return findBool(obj, &p, key);
    }

    /// Get the raw object slice.
    pub fn slice(self: *const ObjectIterator) []const u8 {
        return self.buf[self.pos..self.end];
    }

    /// Advance to the next object in the array.
    pub fn next(self: *ObjectIterator) ?*const ObjectIterator {
        // Skip whitespace and commas to find next '{'
        var i = self.end;
        while (i < self.buf.len) : (i += 1) {
            switch (self.buf[i]) {
                ' ', '\t', '\n', '\r', ',' => continue,
                '{' => break,
                ']' => return null,
                else => return null,
            }
        }
        if (i >= self.buf.len) return null;

        // Find matching '}' respecting nesting
        const obj_start = i;
        var depth: usize = 0;
        while (i < self.buf.len) : (i += 1) {
            switch (self.buf[i]) {
                '{' => depth += 1,
                '}' => {
                    depth -= 1;
                    if (depth == 0) {
                        self.pos = obj_start;
                        self.end = i + 1;
                        return self;
                    }
                },
                '"' => {
                    // Skip string contents (handle escaped quotes)
                    i += 1;
                    while (i < self.buf.len) : (i += 1) {
                        if (self.buf[i] == '\\') {
                            i += 1;
                        } else if (self.buf[i] == '"') break;
                    }
                },
                else => {},
            }
        }
        return null;
    }
};

/// Get an iterator over objects in a JSON array for a given key.
/// E.g. `objects(buf, "track_list")` for `{"track_list":[{...},{...}]}`
pub fn objects(buf: []const u8, key: []const u8) ObjectIterator {
    const empty = ObjectIterator{ .buf = buf, .pos = 0, .end = 0 };
    // Find "key":
    var needle_buf: [128]u8 = undefined;
    const needle_len = key.len + 3;
    if (needle_len > needle_buf.len) return empty;
    needle_buf[0] = '"';
    @memcpy(needle_buf[1..][0..key.len], key);
    @memcpy(needle_buf[1 + key.len ..][0..2], "\":");
    const needle = needle_buf[0..needle_len];

    const start = std.mem.indexOf(u8, buf, needle) orelse return empty;
    // Skip optional whitespace after ':' to find '['
    var i = start + needle.len;
    while (i < buf.len and (buf[i] == ' ' or buf[i] == '\t' or buf[i] == '\n' or buf[i] == '\r')) : (i += 1) {}
    if (i >= buf.len or buf[i] != '[') return empty;
    // Position just after the '[' so first next() finds the first '{'
    return .{ .buf = buf, .pos = 0, .end = i + 1 };
}
