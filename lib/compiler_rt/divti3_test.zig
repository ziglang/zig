const __divti3 = @import("divti3.zig").__divti3;
const testing = @import("std").testing;

fn test__divti3(a: i128, b: i128, expected: i128) !void {
    const x = __divti3(a, b);
    try testing.expect(x == expected);
}

test "divti3" {
    try test__divti3(0, 1, 0);
    try test__divti3(0, -1, 0);
    try test__divti3(2, 1, 2);
    try test__divti3(2, -1, -2);
    try test__divti3(-2, 1, -2);
    try test__divti3(-2, -1, 2);

    try test__divti3(@as(i128, @bitCast(@as(u128, 0x8 << 124))), 1, @as(i128, @bitCast(@as(u128, 0x8 << 124))));
    try test__divti3(@as(i128, @bitCast(@as(u128, 0x8 << 124))), -1, @as(i128, @bitCast(@as(u128, 0x8 << 124))));
    try test__divti3(@as(i128, @bitCast(@as(u128, 0x8 << 124))), -2, @as(i128, @bitCast(@as(u128, 0x4 << 124))));
    try test__divti3(@as(i128, @bitCast(@as(u128, 0x8 << 124))), 2, @as(i128, @bitCast(@as(u128, 0xc << 124))));
}
