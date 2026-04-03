const std = @import("std");
pub const s = @import("string.zig");
pub const str = s.str;
pub const String = s.String;
pub const json = @import("json.zig");
pub const io = std.Io;
pub const a = std.mem.Allocator;

pub fn print(comptime txt: []const u8) void {
    std.debug.print(txt ++ "\n", .{});
}
pub fn log(comptime txt: []const u8, args: anytype) void {
    std.log.err(txt ++ "\n", args);
}
pub fn err(comptime txt: []const u8, er: anyerror) void {
    std.log.err(txt ++ " {} ({s})", .{ er, @errorName(er) });
}
pub fn warn(comptime txt: []const u8, args: anytype) void {
    std.log.warn(txt ++ "\n", args);
}
pub fn debug(comptime txt: []const u8, args: anytype) void {
    std.log.debug(txt ++ "\n", args);
}

pub fn list(comptime T: type) std.ArrayList(T) {
    return std.ArrayList(T).empty;
    // don't forget to deinit with an allocator after returcning
}

pub fn map(comptime K: type, comptime V: type) std.AutoHashMap(K, V) {
    return std.AutoHashMap(K, V).empty;
    // don't forget to deinit with an allocator after returcning
}
