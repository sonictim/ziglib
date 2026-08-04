const std = @import("std");
const Allocator = std.mem.Allocator;

const Text = union(enum) {
    str: []const u8,
    cstr: [*:0]const u8,
    string: std.ArrayList(u8),

    pub fn slice(self: @This()) []const u8 {
        return switch (self) {
            .str => |s| s,
            .cstr => |s| std.mem.span(s),
            .string => |s| s.items,
        };
    }

    pub fn len(self: @This()) usize {
        return switch (self) {
            .str => |s| s.len,
            .cstr => |s| s.len,
            .string => |s| s.items.len,
        };
    }
    pub fn clone(self: @This(), allocator: Allocator) !std.ArrayList(u8) {
        var result: std.ArrayList(u8) = .empty;
        result.appendSlice(allocator, self.slice());
        return result;
    }

    pub fn toCstr(self: @This(), allocator: Allocator) ![:0]const u8 {
        return allocator.dupeZ(u8, self.slice());
    }

    pub fn eq(self: @This(), other: []const u8) bool {
        return std.mem.eql(u8, self.slice(), other);
    }
    pub fn startsWith(self: @This(), prefix: []const u8) bool {
        return std.mem.startsWith(u8, self.slice(), prefix);
    }

    pub fn endsWith(self: @This(), suffix: []const u8) bool {
        return std.mem.endsWith(u8, self.slice(), suffix);
    }
    pub fn indexOf(self: @This(), needle: []const u8) ?usize {
        return std.mem.indexOf(u8, self.slice(), needle);
    }

    pub fn contains(self: @This(), needle: []const u8) bool {
        return std.mem.indexOf(u8, self.slice(), needle) != null;
    }

    pub fn count(self: @This(), needle: []const u8) usize {
        return std.mem.count(u8, self.slice(), needle);
    }
    pub fn trim(self: @This()) @This() {
        return .{ .str = std.mem.trim(u8, self.slice(), " \t\n\r") };
    }

    pub fn trimLeft(self: @This()) @This() {
        return .{ .str = std.mem.trimLeft(u8, self.slice(), " \t\n\r") };
    }

    pub fn trimRight(self: @This()) @This() {
        return .{ .str = std.mem.trimRight(u8, self.slice(), " \t\n\r") };
    }

    pub fn splitScalar(self: @This(), delim: u8) std.mem.SplitIterator(u8, .scalar) {
        return std.mem.splitScalar(u8, self.slice(), delim);
    }

    pub fn splitSeq(self: @This(), delim: []const u8) std.mem.SplitIterator(u8, .sequence) {
        return std.mem.splitSequence(u8, self.slice(), delim);
    }

    pub fn lines(self: @This()) std.mem.SplitIterator(u8, .scalar) {
        return self.splitScalar('\n');
    }

    pub fn join(allocator: Allocator, parts: []const []const u8, separator: []const u8) !@This() {
        var result: std.ArrayList(u8) = .empty;
        for (parts, 0..) |part, i| {
            try result.appendSlice(allocator, part);
            if (i < parts.len - 1) try result.append(allocator, separator);
        }
        return .{ .string = result };
    }
    pub fn toUpper(self: @This()) void {
        for (self.slice()) |*c| {
            c.* = std.ascii.toUpper(c.*);
        }
    }
    pub fn toLower(self: @This()) void {
        for (self.slice()) |*c| {
            c.* = std.ascii.toLower(c.*);
        }
    }

    // Replace (allocating)

    pub fn replace(self: @This(), allocator: Allocator, needle: []const u8, replacement: []const u8) !@This() {
        var result: std.ArrayList(u8) = .empty;
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
        return .{ .string = result };
    }

    // Parsing

    pub fn parseInt(self: @This(), comptime T: type) !T {
        return std.fmt.parseInt(T, self.slice(), 10);
    }

    pub fn parseFloat(self: @This(), comptime T: type) !T {
        return std.fmt.parseFloat(T, self.slice());
    }

    pub fn from(allocator: Allocator, s: []const u8) !@This() {
        var result: std.ArrayList(u8) = .empty;
        try result.appendSlice(allocator, s);
        return .{ .string = result };
    }

    pub fn fmt(allocator: Allocator, comptime format: []const u8, args: anytype) !@This() {
        const formatted = try std.fmt.allocPrint(allocator, format, args);
        defer allocator.free(formatted);
        var result: std.ArrayList(u8) = .empty;
        try result.appendSlice(allocator, formatted);
        return .{ .string = result };
    }

    pub fn append(self: @This(), allocator: Allocator, s: []const u8) !void {
        if (self == .string) try self.appendSlice(allocator, s) else {
            var result = try Text.from(allocator, self.slice());
            try result.appendSlice(allocator, s);
            self = result;
        }
    }
    pub fn clear(self: @This()) void {
        switch (self) {
            .string => |s| s.clearRetainingCapacity(),
            else => {},
        }
    }
};
