const parity = @import("parity.zig");
const testing = @import("std").testing;

fn parityti2Naive(a: i128) i32 {
    var x = @bitCast(u128, a);
    var has_parity: bool = false;
    while (x > 0) {
        has_parity = !has_parity;
        x = x & (x - 1);
    }
    return @intCast(i32, @boolToInt(has_parity));
}

fn test__parityti2(a: i128) !void {
    var x = parity.__parityti2(a);
    var expected: i128 = parityti2Naive(a);
    try testing.expectEqual(expected, x);
}

test "parityti2" {
    try test__parityti2(0);
    try test__parityti2(1);
    try test__parityti2(2);
    try test__parityti2(@bitCast(i128, @as(u128, 0xffffffff_ffffffff_ffffffff_fffffffd)));
    try test__parityti2(@bitCast(i128, @as(u128, 0xffffffff_ffffffff_ffffffff_fffffffe)));
    try test__parityti2(@bitCast(i128, @as(u128, 0xffffffff_ffffffff_ffffffff_ffffffff)));

    const RndGen = @import("std").rand.DefaultPrng;
    var rnd = RndGen.init(42);
    var i: u32 = 0;
    while (i < 10_000) : (i += 1) {
        var rand_num = rnd.random().int(i128);
        try test__parityti2(rand_num);
    }
}
