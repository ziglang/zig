const std = @import("std");
const parity = @import("parity.zig");
const testing = std.testing;

fn paritysi2Naive(a: i32) i32 {
    var x = @bitCast(u32, a);
    var has_parity: bool = false;
    while (x > 0) {
        has_parity = !has_parity;
        x = x & (x - 1);
    }
    return @intCast(i32, @boolToInt(has_parity));
}

fn test__paritysi2(a: i32) !void {
    var x = parity.__paritysi2(a);
    var expected: i32 = paritysi2Naive(a);
    try testing.expectEqual(expected, x);
}

test "paritysi2" {
    try test__paritysi2(0);
    try test__paritysi2(1);
    try test__paritysi2(2);
    try test__paritysi2(@bitCast(i32, @as(u32, 0xfffffffd)));
    try test__paritysi2(@bitCast(i32, @as(u32, 0xfffffffe)));
    try test__paritysi2(@bitCast(i32, @as(u32, 0xffffffff)));

    const RndGen = std.rand.DefaultPrng;
    var rnd = RndGen.init(42);
    var i: u32 = 0;
    while (i < 10_000) : (i += 1) {
        var rand_num = rnd.random().int(i32);
        try test__paritysi2(rand_num);
    }
}
