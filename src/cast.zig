const std = @import("std");

pub fn F32(i: i64) f32 {
    return @as(f32, @floatFromInt(i));
}

pub fn I32(f: f64) i32 {
    return @as(i32, @intFromFloat(f));
}
