const addv = @import("addv.zig");
const std = @import("std");
const testing = std.testing;
const math = std.math;

fn test__addvti3(a: i128, b: i128) !void {
    var result_ov: c_int = 0;
    var expected_ov: c_int = undefined;
    var expected: i128 = simple_addoti4(a, b, &expected_ov);
    // TODO add panic runner check
    var result = addv.__addvti3(a, b);
    try testing.expectEqual(expected_ov, result_ov);
    try testing.expectEqual(expected, result);
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

test "addvti3" {
    const min: i128 = math.minInt(i128);
    const max: i128 = math.maxInt(i128);
    var i: i128 = 1;
    while (i < max / 4) : (i *|= 2) {
        try test__addvti3(i, i);
        try test__addvti3(-i, -i);
        try test__addvti3(i, -i);
        try test__addvti3(-i, i);
    }

    // TODO: test outcommented overflow test cases once test runner
    // for panics works
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
    try test__addvti3(0, 0);
    // try test__addvti3(min, min);
    // try test__addvti3(max, max);
    try test__addvti3(0, min);
    try test__addvti3(0, max);
    try test__addvti3(min, 0);
    try test__addvti3(max, 0);
    try test__addvti3(min, max);
    try test__addvti3(max, min);

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
    // try test__addvti3(min + 1, min);
    // try test__addvti3(max - 1, max);
    try test__addvti3(1, min);
    // try test__addvti3(-1, min);
    try test__addvti3(-1, max);
    // try test__addvti3(1, max);
    try test__addvti3(min, 1);
    // try test__addvti3(min, -1);
    try test__addvti3(max, -1);
    // try test__addvti3(max, 1);
}
