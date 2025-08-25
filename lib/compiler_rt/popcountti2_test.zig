const std = @import("std");
const popcount = @import("popcount.zig");
const testing = std.testing;

fn popcountti2Naive(a: i128) i32 {
    var x = a;
    var r: i32 = 0;
    while (x != 0) : (x = @as(i128, @bitCast(@as(u128, @bitCast(x)) >> 1))) {
        r += @as(i32, @intCast(x & 1));
    }
    return r;
}

fn test__popcountti2(a: i128) !void {
    const x = popcount.__popcountti2(a);
    const expected = popcountti2Naive(a);
    try testing.expectEqual(expected, x);
}

test "popcountti2" {
    try test__popcountti2(0);
    try test__popcountti2(1);
    try test__popcountti2(2);
    try test__popcountti2(@as(i128, @bitCast(@as(u128, 0xffffffff_ffffffff_ffffffff_fffffffd))));
    try test__popcountti2(@as(i128, @bitCast(@as(u128, 0xffffffff_ffffffff_ffffffff_fffffffe))));
    try test__popcountti2(@as(i128, @bitCast(@as(u128, 0xffffffff_ffffffff_ffffffff_ffffffff))));

    const RndGen = std.Random.DefaultPrng;
    var rnd = RndGen.init(42);
    var i: u32 = 0;
    while (i < 10_000) : (i += 1) {
        const rand_num = rnd.random().int(i128);
        try test__popcountti2(rand_num);
    }
}
