const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "@sizeOf and @TypeOf" {
    const y: @TypeOf(x) = 120;
    try expect(@sizeOf(@TypeOf(y)) == 2);
}
const x: u16 = 13;
const z: @TypeOf(x) = 19;

test "@sizeOf on compile-time types" {
    try expect(@sizeOf(comptime_int) == 0);
    try expect(@sizeOf(comptime_float) == 0);
    try expect(@sizeOf(@TypeOf(.hi)) == 0);
    try expect(@sizeOf(@TypeOf(type)) == 0);
}

test "@TypeOf() with multiple arguments" {
    {
        var var_1: u32 = undefined;
        var var_2: u8 = undefined;
        var var_3: u64 = undefined;
        comptime try expect(@TypeOf(var_1, var_2, var_3) == u64);
    }
    {
        var var_1: f16 = undefined;
        var var_2: f32 = undefined;
        var var_3: f64 = undefined;
        comptime try expect(@TypeOf(var_1, var_2, var_3) == f64);
    }
    {
        var var_1: u16 = undefined;
        comptime try expect(@TypeOf(var_1, 0xffff) == u16);
    }
    {
        var var_1: f32 = undefined;
        comptime try expect(@TypeOf(var_1, 3.1415) == f32);
    }
}

fn fn1(alpha: bool) void {
    const n: usize = 7;
    _ = if (alpha) n else @sizeOf(usize);
}

test "lazy @sizeOf result is checked for definedness" {
    _ = fn1;
}
