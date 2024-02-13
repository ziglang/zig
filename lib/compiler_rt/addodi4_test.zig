const addv = @import("addo.zig");
const std = @import("std");
const testing = std.testing;
const math = std.math;

fn test__addodi4(a: i64, b: i64) !void {
    var result_ov: c_int = undefined;
    var expected_ov: c_int = undefined;
    const result = addv.__addodi4(a, b, &result_ov);
    const expected: i64 = simple_addodi4(a, b, &expected_ov);
    try testing.expectEqual(expected, result);
    try testing.expectEqual(expected_ov, result_ov);
}

fn simple_addodi4(a: i64, b: i64, overflow: *c_int) i64 {
    overflow.* = 0;
    const min: i64 = math.minInt(i64);
    const max: i64 = math.maxInt(i64);
    if (((a > 0) and (b > max - a)) or
        ((a < 0) and (b < min - a)))
        overflow.* = 1;
    return a +% b;
}

test "addodi4" {
    const min: i64 = math.minInt(i64);
    const max: i64 = math.maxInt(i64);
    var i: i64 = 1;
    while (i < max) : (i *|= 2) {
        try test__addodi4(i, i);
        try test__addodi4(-i, -i);
        try test__addodi4(i, -i);
        try test__addodi4(-i, i);
    }

    // edge cases
    // 0   + 0     = 0
    // MIN + MIN   overflow
    // MAX + MAX   overflow
    // 0   + MIN   MIN
    // 0   + MAX   MAX
    // MIN + 0     MIN
    // MAX + 0     MAX
    // MIN + MAX   -1
    // MAX + MIN   -1
    try test__addodi4(0, 0);
    try test__addodi4(min, min);
    try test__addodi4(max, max);
    try test__addodi4(0, min);
    try test__addodi4(0, max);
    try test__addodi4(min, 0);
    try test__addodi4(max, 0);
    try test__addodi4(min, max);
    try test__addodi4(max, min);

    // derived edge cases
    // MIN+1 + MIN   overflow
    // MAX-1 + MAX   overflow
    // 1     + MIN = MIN+1
    // -1    + MIN   overflow
    // -1    + MAX = MAX-1
    // +1    + MAX   overflow
    // MIN   + 1   = MIN+1
    // MIN   + -1    overflow
    // MAX   + 1     overflow
    // MAX   + -1  = MAX-1
    try test__addodi4(min + 1, min);
    try test__addodi4(max - 1, max);
    try test__addodi4(1, min);
    try test__addodi4(-1, min);
    try test__addodi4(-1, max);
    try test__addodi4(1, max);
    try test__addodi4(min, 1);
    try test__addodi4(min, -1);
    try test__addodi4(max, -1);
    try test__addodi4(max, 1);
}
