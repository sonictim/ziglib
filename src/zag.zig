pub const std = @import("std");
pub const s = @import("string.zig");
pub const str = s.str;
pub const String = s.String;
pub const json = @import("json.zig");
pub const Io = std.Io;
pub const a = std.mem.Allocator;
pub const eql = std.mem.eql;

pub fn print(comptime txt: str) void {
    std.debug.print(txt ++ "\n", .{});
}
pub fn log(comptime txt: str, args: anytype) void {
    std.log.err(txt ++ "\n", args);
}
pub fn err(comptime txt: str, er: anyerror) void {
    std.log.err(txt ++ " {} ({s})", .{ er, @errorName(er) });
}
pub fn warn(comptime txt: str, args: anytype) void {
    std.log.warn(txt ++ "\n", args);
}
pub fn debug(comptime txt: str, args: anytype) void {
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
