const addv = @import("addo.zig");
const std = @import("std");
const testing = std.testing;
const math = std.math;

fn test__addoti4(a: i128, b: i128) !void {
    var result_ov: c_int = undefined;
    var expected_ov: c_int = undefined;
    const result = addv.__addoti4(a, b, &result_ov);
    const expected: i128 = simple_addoti4(a, b, &expected_ov);
    try testing.expectEqual(expected, result);
    try testing.expectEqual(expected_ov, result_ov);
}

fn simple_addoti4(a: i128, b: i128, overflow: *c_int) i128 {
    overflow.* = 0;
    const min: i128 = math.minInt(i128);
    const max: i128 = math.maxInt(i128);
    if (((a > 0) and (b > max - a)) or
        ((a < 0) and (b < min - a)))
        overflow.* = 1;
    return a +% b;
}

test "addoti4" {
    const min: i128 = math.minInt(i128);
    const max: i128 = math.maxInt(i128);
    var i: i128 = 1;
    while (i < max) : (i *|= 2) {
        try test__addoti4(i, i);
        try test__addoti4(-i, -i);
        try test__addoti4(i, -i);
        try test__addoti4(-i, i);
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
    try test__addoti4(0, 0);
    try test__addoti4(min, min);
    try test__addoti4(max, max);
    try test__addoti4(0, min);
    try test__addoti4(0, max);
    try test__addoti4(min, 0);
    try test__addoti4(max, 0);
    try test__addoti4(min, max);
    try test__addoti4(max, min);

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
    try test__addoti4(min + 1, min);
    try test__addoti4(max - 1, max);
    try test__addoti4(1, min);
    try test__addoti4(-1, min);
    try test__addoti4(-1, max);
    try test__addoti4(1, max);
    try test__addoti4(min, 1);
    try test__addoti4(min, -1);
    try test__addoti4(max, -1);
    try test__addoti4(max, 1);
}
