const __modti3 = @import("modti3.zig").__modti3;
const testing = @import("std").testing;

fn test__modti3(a: i128, b: i128, expected: i128) !void {
    const x = __modti3(a, b);
    try testing.expect(x == expected);
}

test "modti3" {
    try test__modti3(0, 1, 0);
    try test__modti3(0, -1, 0);
    try test__modti3(5, 3, 2);
    try test__modti3(5, -3, 2);
    try test__modti3(-5, 3, -2);
    try test__modti3(-5, -3, -2);

    try test__modti3(0x8000000000000000, 1, 0x0);
    try test__modti3(0x8000000000000000, -1, 0x0);
    try test__modti3(0x8000000000000000, 2, 0x0);
    try test__modti3(0x8000000000000000, -2, 0x0);
    try test__modti3(0x8000000000000000, 3, 2);
    try test__modti3(0x8000000000000000, -3, 2);

    try test__modti3(make_ti(0x8000000000000000, 0), 1, 0x0);
    try test__modti3(make_ti(0x8000000000000000, 0), -1, 0x0);
    try test__modti3(make_ti(0x8000000000000000, 0), 2, 0x0);
    try test__modti3(make_ti(0x8000000000000000, 0), -2, 0x0);
    try test__modti3(make_ti(0x8000000000000000, 0), 3, -2);
    try test__modti3(make_ti(0x8000000000000000, 0), -3, -2);
}

fn make_ti(high: u64, low: u64) i128 {
    var result: u128 = high;
    result <<= 64;
    result |= low;
    return @bitCast(result);
}
