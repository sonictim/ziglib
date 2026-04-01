const std = @import("std");
const Allocator = std.mem.Allocator;

// ──────────────────────────────────────────────
// str — immutable, non-allocating slice wrapper
// ──────────────────────────────────────────────

pub const str = []const u8;

// Construction

pub fn fromCstr(s: [*:0]const u8) str {
    return std.mem.span(s);
}

// Comparison

pub fn eql(self: str, other: []const u8) bool {
    return std.mem.eql(u8, self, other);
}

pub fn startsWith(self: str, prefix: []const u8) bool {
    return std.mem.startsWith(u8, self, prefix);
}

pub fn endsWith(self: str, suffix: []const u8) bool {
    return std.mem.endsWith(u8, self, suffix);
}

// Searching

pub fn indexOf(self: str, needle: []const u8) ?usize {
    return std.mem.indexOf(u8, self, needle);
}

pub fn contains(self: str, needle: []const u8) bool {
    return std.mem.indexOf(u8, self, needle) != null;
}

pub fn count(self: str, needle: []const u8) usize {
    return std.mem.count(u8, self, needle);
}

// Slicing / splitting

pub fn trim(self: str) str {
    return std.mem.trim(u8, self, " \t\n\r");
}

pub fn trimLeft(self: str) str {
    return std.mem.trimLeft(u8, self, " \t\n\r");
}

pub fn trimRight(self: str) str {
    return std.mem.trimRight(u8, self, " \t\n\r");
}

pub fn splitScalar(self: str, delim: u8) std.mem.SplitIterator(u8, .scalar) {
    return std.mem.splitScalar(u8, self, delim);
}

pub fn splitSeq(self: str, delim: []const u8) std.mem.SplitIterator(u8, .sequence) {
    return std.mem.splitSequence(u8, self, delim);
}

// Joining (static)

pub fn join(allocator: Allocator, parts: []const []const u8, separator: []const u8) !String {
    var result = String.init(allocator);
    for (parts, 0..) |part, i| {
        try result.append(part);
        if (i < parts.len - 1) try result.append(separator);
    }
    return result;
}

// Case conversion (allocating)

pub fn toUpper(self: str, allocator: Allocator) !String {
    const result = try String.from(allocator, self);
    for (result.buf.items) |*c| {
        c.* = std.ascii.toUpper(c.*);
    }
    return result;
}

pub fn toLower(self: str, allocator: Allocator) !String {
    const result = try String.from(allocator, self);
    for (result.buf.items) |*c| {
        c.* = std.ascii.toLower(c.*);
    }
    return result;
}

// Replace (allocating)

pub fn replace(self: str, allocator: Allocator, needle: []const u8, replacement: []const u8) !String {
    var result = String.init(allocator);
    var i: usize = 0;
    while (i < self.len) {
        if (i + needle.len <= self.len and std.mem.eql(u8, self[i..][0..needle.len], needle)) {
            try result.append(replacement);
            i += needle.len;
        } else {
            try result.buf.append(allocator, self[i]);
            i += 1;
        }
    }
    return result;
}

// Parsing

pub fn parseInt(self: str, comptime T: type) !T {
    return std.fmt.parseInt(T, self, 10);
}

pub fn parseFloat(self: str, comptime T: type) !T {
    return std.fmt.parseFloat(T, self);
}

// Conversion

pub fn toString(self: str, allocator: Allocator) !String {
    return String.from(allocator, self);
}

pub fn cstr(self: str, allocator: Allocator) ![:0]const u8 {
    return allocator.dupeZ(u8, self);
}

// pub fn slice(self: str) []const u8 {
//     return self;
// }
//
// pub fn len(self: str) usize {
//     return self.len;
// }

// ──────────────────────────────────────────────
// String — heap-allocated, owned, mutable
// ──────────────────────────────────────────────

pub const String = struct {
    buf: std.ArrayList(u8),
    allocator: Allocator,

    pub fn init(allocator: Allocator) String {
        return .{
            .buf = .empty,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *String) void {
        self.buf.deinit(self.allocator);
    }

    // Creation

    pub fn from(allocator: Allocator, s: []const u8) !String {
        var result = String.init(allocator);
        try result.buf.appendSlice(allocator, s);
        return result;
    }

    pub fn fmt(allocator: Allocator, comptime format: []const u8, args: anytype) !String {
        const formatted = try std.fmt.allocPrint(allocator, format, args);
        defer allocator.free(formatted);
        var result = String.init(allocator);
        try result.buf.appendSlice(allocator, formatted);
        return result;
    }

    // Mutation

    pub fn append(self: *String, s: []const u8) !void {
        try self.buf.appendSlice(self.allocator, s);
    }

    pub fn appendFmt(self: *String, comptime format: []const u8, args: anytype) !void {
        const formatted = try std.fmt.allocPrint(self.allocator, format, args);
        defer self.allocator.free(formatted);
        try self.buf.appendSlice(self.allocator, formatted);
    }

    pub fn clear(self: *String) void {
        self.buf.clearRetainingCapacity();
    }

    // Case conversion (in-place)

    pub fn toUpper(self: *String) void {
        for (self.buf.items) |*c| {
            c.* = std.ascii.toUpper(c.*);
        }
    }

    pub fn toLower(self: *String) void {
        for (self.buf.items) |*c| {
            c.* = std.ascii.toLower(c.*);
        }
    }

    // Trimming (in-place)

    pub fn trim(self: *String) void {
        const trimmed = std.mem.trim(u8, self.buf.items, " \t\n\r");
        if (trimmed.len == 0) {
            self.buf.clearRetainingCapacity();
            return;
        }
        const offset = @intFromPtr(trimmed.ptr) - @intFromPtr(self.buf.items.ptr);
        if (offset > 0) {
            std.mem.copyForwards(u8, self.buf.items[0..trimmed.len], trimmed);
        }
        self.buf.shrinkRetainingCapacity(trimmed.len);
    }

    pub fn trimLeft(self: *String) void {
        const trimmed = std.mem.trimLeft(u8, self.buf.items, " \t\n\r");
        const offset = @intFromPtr(trimmed.ptr) - @intFromPtr(self.buf.items.ptr);
        if (offset > 0) {
            std.mem.copyForwards(u8, self.buf.items[0..trimmed.len], trimmed);
        }
        self.buf.shrinkRetainingCapacity(trimmed.len);
    }

    pub fn trimRight(self: *String) void {
        const trimmed = std.mem.trimRight(u8, self.buf.items, " \t\n\r");
        self.buf.shrinkRetainingCapacity(trimmed.len);
    }

    // Utilities

    pub fn repeat(allocator: Allocator, s: []const u8, n: usize) !String {
        var result = String.init(allocator);
        try result.buf.ensureTotalCapacity(allocator, s.len * n);
        for (0..n) |_| {
            result.buf.appendSliceAssumeCapacity(s);
        }
        return result;
    }

    // Parsing

    pub fn parseInt(self: String, comptime T: type) !T {
        return std.fmt.parseInt(T, self.buf.items, 10);
    }

    pub fn parseFloat(self: String, comptime T: type) !T {
        return std.fmt.parseFloat(T, self.buf.items);
    }

    // Access

    pub fn view(self: String) str {
        return self.buf.items;
    }

    pub fn cstr(self: *String) ![:0]const u8 {
        return self.allocator.dupeZ(u8, self.buf.items);
    }

    pub fn slice(self: String) []const u8 {
        return self.buf.items;
    }

    pub fn len(self: String) usize {
        return self.buf.items.len;
    }
};
