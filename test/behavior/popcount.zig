const expect = @import("std").testing.expect;

test "@popCount" {
    comptime try testPopCount();
    try testPopCount();
}

fn testPopCount() !void {
    {
        var x: u32 = 0xffffffff;
        try expect(@popCount(u32, x) == 32);
    }
    {
        var x: u5 = 0x1f;
        try expect(@popCount(u5, x) == 5);
    }
    {
        var x: u32 = 0xaa;
        try expect(@popCount(u32, x) == 4);
    }
    {
        var x: u32 = 0xaaaaaaaa;
        try expect(@popCount(u32, x) == 16);
    }
    {
        var x: u32 = 0xaaaaaaaa;
        try expect(@popCount(u32, x) == 16);
    }
    {
        var x: i16 = -1;
        try expect(@popCount(i16, x) == 16);
    }
    {
        var x: i8 = -120;
        try expect(@popCount(i8, x) == 2);
    }
    comptime {
        try expect(@popCount(u8, @bitCast(u8, @as(i8, -120))) == 2);
    }
    comptime {
        try expect(@popCount(i128, 0b11111111000110001100010000100001000011000011100101010001) == 24);
    }
}
