const std = @import("std");
const popcount = @import("popcount.zig");
const testing = std.testing;

fn popcountsi2Naive(a: i32) i32 {
    var x = a;
    var r: i32 = 0;
    while (x != 0) : (x = @as(i32, @bitCast(@as(u32, @bitCast(x)) >> 1))) {
        r += @as(i32, @intCast(x & 1));
    }
    return r;
}

fn test__popcountsi2(a: i32) !void {
    const x = popcount.__popcountsi2(a);
    const expected = popcountsi2Naive(a);
    try testing.expectEqual(expected, x);
}

test "popcountsi2" {
    try test__popcountsi2(0);
    try test__popcountsi2(1);
    try test__popcountsi2(2);
    try test__popcountsi2(@as(i32, @bitCast(@as(u32, 0xfffffffd))));
    try test__popcountsi2(@as(i32, @bitCast(@as(u32, 0xfffffffe))));
    try test__popcountsi2(@as(i32, @bitCast(@as(u32, 0xffffffff))));

    const RndGen = std.Random.DefaultPrng;
    var rnd = RndGen.init(42);
    var i: u32 = 0;
    while (i < 10_000) : (i += 1) {
        const rand_num = rnd.random().int(i32);
        try test__popcountsi2(rand_num);
    }
}
