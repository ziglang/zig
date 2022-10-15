const expect = @import("std").testing.expect;

// This test causes a compile error on stage1 regardless of whether
// the body of the test is comptime-gated or not. To workaround this,
// we gate the inclusion of the test file.
test "Non-exhaustive enum backed by comptime_int" {
    const E = enum(comptime_int) { a, b, c, _ };
    comptime var e: E = .a;
    e = @intToEnum(E, 378089457309184723749);
    try expect(@enumToInt(e) == 378089457309184723749);
}
