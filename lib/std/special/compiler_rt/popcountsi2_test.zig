const popcount = @import("popcount.zig");
const testing = @import("std").testing;

fn popcountsi2Naive(a: i32) i32 {
    var x = a;
    var r: i32 = 0;
    while (x != 0) : (x = @bitCast(i32, @bitCast(u32, x) >> 1)) {
        r += @intCast(i32, x & 1);
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
    try test__popcountsi2(@bitCast(i32, @as(u32, 0xfffffffd)));
    try test__popcountsi2(@bitCast(i32, @as(u32, 0xfffffffe)));
    try test__popcountsi2(@bitCast(i32, @as(u32, 0xffffffff)));

    const RndGen = @import("std").rand.DefaultPrng;
    var rnd = RndGen.init(42);
    var i: u32 = 0;
    while (i < 10_000) : (i += 1) {
        var rand_num = rnd.random().int(i32);
        try test__popcountsi2(rand_num);
    }
}
