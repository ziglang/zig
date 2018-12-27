const std = @import("std");
const assertOrPanic = std.debug.assertOrPanic;
const maxInt = std.math.maxInt;

test "@bitCast i32 -> u32" {
    testBitCast_i32_u32();
    comptime testBitCast_i32_u32();
}

fn testBitCast_i32_u32() void {
    assertOrPanic(conv(-1) == maxInt(u32));
    assertOrPanic(conv2(maxInt(u32)) == -1);
}

fn conv(x: i32) u32 {
    return @bitCast(u32, x);
}
fn conv2(x: u32) i32 {
    return @bitCast(i32, x);
}

