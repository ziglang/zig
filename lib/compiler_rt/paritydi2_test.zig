const std = @import("std");
const parity = @import("parity.zig");
const testing = std.testing;

fn paritydi2Naive(a: i64) i32 {
    var x: u64 = @bitCast(a);
    var has_parity: bool = false;
    while (x > 0) {
        has_parity = !has_parity;
        x = x & (x - 1);
    }
    return @intCast(@intFromBool(has_parity));
}

fn test__paritydi2(a: i64) !void {
    const x = parity.__paritydi2(a);
    const expected: i64 = paritydi2Naive(a);
    try testing.expectEqual(expected, x);
}

test "paritydi2" {
    try test__paritydi2(0);
    try test__paritydi2(1);
    try test__paritydi2(2);
    try test__paritydi2(@bitCast(@as(u64, 0xffffffff_fffffffd)));
    try test__paritydi2(@bitCast(@as(u64, 0xffffffff_fffffffe)));
    try test__paritydi2(@bitCast(@as(u64, 0xffffffff_ffffffff)));

    const RndGen = std.Random.DefaultPrng;
    var rnd = RndGen.init(42);
    var i: u32 = 0;
    while (i < 10_000) : (i += 1) {
        const rand_num = rnd.random().int(i64);
        try test__paritydi2(rand_num);
    }
}
