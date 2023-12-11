const subo = @import("subo.zig");
const std = @import("std");
const testing = std.testing;
const math = std.math;

fn test__suboti4(a: i128, b: i128) !void {
    var result_ov: c_int = undefined;
    var expected_ov: c_int = undefined;
    const result = subo.__suboti4(a, b, &result_ov);
    const expected: i128 = simple_suboti4(a, b, &expected_ov);
    try testing.expectEqual(expected, result);
    try testing.expectEqual(expected_ov, result_ov);
}

// 2 cases on evaluating `a-b`:
// 1. `a-b` may underflow, iff b>0 && a<0 and a-b < min <=> a<min+b
// 2. `a-b` may overflow,  iff b<0 && a>0 and a-b > max <=> a>max+b
// `-b` evaluation may overflow, iff b==min, but this is handled by the hardware
pub fn simple_suboti4(a: i128, b: i128, overflow: *c_int) i128 {
    overflow.* = 0;
    const min: i128 = math.minInt(i128);
    const max: i128 = math.maxInt(i128);
    if (((b > 0) and (a < min + b)) or
        ((b < 0) and (a > max + b)))
        overflow.* = 1;
    return a -% b;
}

test "suboti3" {
    const min: i128 = math.minInt(i128);
    const max: i128 = math.maxInt(i128);
    var i: i128 = 1;
    while (i < max) : (i *|= 2) {
        try test__suboti4(i, i);
        try test__suboti4(-i, -i);
        try test__suboti4(i, -i);
        try test__suboti4(-i, i);
    }

    // edge cases
    // 0 - 0       = 0
    // MIN - MIN   = 0
    // MAX - MAX   = 0
    // 0   - MIN     overflow
    // 0   - MAX   = MIN+1
    // MIN - 0     = MIN
    // MAX - 0     = MAX
    // MIN - MAX     overflow
    // MAX - MIN     overflow
    try test__suboti4(0, 0);
    try test__suboti4(min, min);
    try test__suboti4(max, max);
    try test__suboti4(0, min);
    try test__suboti4(0, max);
    try test__suboti4(min, 0);
    try test__suboti4(max, 0);
    try test__suboti4(min, max);
    try test__suboti4(max, min);

    // derived edge cases
    // MIN+1 - MIN = 1
    // MAX-1 - MAX = -1
    // 1     - MIN   overflow
    // -1    - MIN = MAX
    // -1    - MAX = MIN
    // +1    - MAX = MIN+2
    // MIN   - 1     overflow
    // MIN   - -1  = MIN+1
    // MAX   - 1   = MAX-1
    // MAX   - -1    overflow
    try test__suboti4(min + 1, min);
    try test__suboti4(max - 1, max);
    try test__suboti4(1, min);
    try test__suboti4(-1, min);
    try test__suboti4(-1, max);
    try test__suboti4(1, max);
    try test__suboti4(min, 1);
    try test__suboti4(min, -1);
    try test__suboti4(max, -1);
    try test__suboti4(max, 1);
}
