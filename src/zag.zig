pub const std = @import("std");
// pub const s = @import("string.zig");
// pub const str = s.str;
// pub const String = s.String;
pub const json = @import("json.zig");
pub const as = @import("cast.zig");
pub const io = std.Io;
pub const alloc = std.mem.Allocator;
pub const eql = std.mem.eql;
// pub const text = @import("text.zig").Text;

pub const str = []const u8;
pub const cstr = [:0]const u8;
pub const String = std.ArrayList(u8);

pub fn print(comptime txt: str) void {
    std.debug.print(txt ++ "\n", .{});
}
pub fn log(comptime txt: str, args: anytype) void {
    std.log.err(txt, args);
}
pub fn err(comptime txt: str, er: anyerror) void {
    std.log.err(txt ++ " {} ({s})", .{ er, @errorName(er) });
}
pub fn warn(comptime txt: str, args: anytype) void {
    std.log.warn(txt, args);
}
pub fn debug(comptime txt: str, args: anytype) void {
    std.log.debug(txt, args);
}

pub fn list(comptime T: type) std.ArrayList(T) {
    return std.ArrayList(T).empty;
}

pub fn map(comptime K: type, comptime V: type) std.AutoHashMapUnmanaged(K, V) {
    return std.AutoHashMap(K, V).empty;
}

pub fn eq(s1: []const u8, s2: []const u8) bool {
    return eql(u8, s1, s2);
}
