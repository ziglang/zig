const expect = @import("std").testing.expect;

test "Non-exhaustive enum backed by comptime_int" {
    const E = enum(comptime_int) { a, b, c, _ };
    comptime var e: E = .a;
    e = @as(E, @enumFromInt(378089457309184723749));
    try expect(@intFromEnum(e) == 378089457309184723749);
}
