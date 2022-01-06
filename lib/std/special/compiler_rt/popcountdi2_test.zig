const std = @import("std");
const popcount = @import("popcount.zig");
const testing = std.testing;

fn popcountdi2Naive(a: i64) i32 {
    var x = a;
    var r: i32 = 0;
    while (x != 0) : (x = @bitCast(i64, @bitCast(u64, x) >> 1)) {
        r += @intCast(i32, x & 1);
    }
    return r;
}

fn test__popcountdi2(a: i64) !void {
    const x = popcount.__popcountdi2(a);
    const expected = popcountdi2Naive(a);
    try testing.expectEqual(expected, x);
}

test "popcountdi2" {
    try test__popcountdi2(0);
    try test__popcountdi2(1);
    try test__popcountdi2(2);
    try test__popcountdi2(@bitCast(i64, @as(u64, 0xffffffff_fffffffd)));
    try test__popcountdi2(@bitCast(i64, @as(u64, 0xffffffff_fffffffe)));
    try test__popcountdi2(@bitCast(i64, @as(u64, 0xffffffff_ffffffff)));

    const RndGen = std.rand.DefaultPrng;
    var rnd = RndGen.init(42);
    var i: u32 = 0;
    while (i < 10_000) : (i += 1) {
        var rand_num = rnd.random().int(i64);
        try test__popcountdi2(rand_num);
    }
}
