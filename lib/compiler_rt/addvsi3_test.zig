const addv = @import("addv.zig");
const testing = @import("std").testing;

fn test__addvsi3(a: i32, b: i32) !void {
    var result_ov: c_int = 0;
    var expected_ov: c_int = undefined;
    var expected: i32 = simple_addosi4(a, b, &expected_ov);
    // TODO add panic runner check
    var result = addv.__addvsi3(a, b);
    try testing.expectEqual(expected_ov, result_ov);
    try testing.expectEqual(expected, result);
}

// use to retrieve, if panic is expected
fn simple_addosi4(a: i32, b: i32, overflow: *c_int) i32 {
    overflow.* = 0;
    const min: i32 = -2147483648;
    const max: i32 = 2147483647;
    if (((a > 0) and (b > max - a)) or
        ((a < 0) and (b < min - a)))
        overflow.* = 1;
    return a +% b;
}

test "addvsi3" {
    // -2^31 <= i32 <= 2^31-1
    // 2^31 = 2147483648
    // 2^31-1 = 2147483647
    const min: i32 = -2147483648;
    const max: i32 = 2147483647;
    var i: i32 = 1;
    while (i < max / 4) : (i *|= 2) {
        try test__addvsi3(i, i);
        try test__addvsi3(-i, -i);
        try test__addvsi3(i, -i);
        try test__addvsi3(-i, i);
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
    try test__addvsi3(0, 0);
    //try test__addvsi3(min, min);
    //try test__addvsi3(max, max);
    try test__addvsi3(0, min);
    try test__addvsi3(0, max);
    try test__addvsi3(min, 0);
    try test__addvsi3(max, 0);
    try test__addvsi3(min, max);
    try test__addvsi3(max, min);

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
    // try test__addvsi3(min + 1, min);
    // try test__addvsi3(max - 1, max);
    // try test__addvsi3(1, min);
    // try test__addvsi3(-1, min);
    try test__addvsi3(-1, max);
    // try test__addvsi3(1, max);
    try test__addvsi3(min, 1);
    // try test__addvsi3(min, -1);
    // try test__addvsi3(max, 1);
    try test__addvsi3(max, -1);
}
