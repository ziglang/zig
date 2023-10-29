const std = @import("std");

fn EmptyStruct() type {
    return struct {};
}

test "comptimeness of optional and error union payload is analyzed properly" {
    // This is primarily a semantic analysis integrity test.
    // The original failure mode for this was a crash.
    // A struct or union payload is needed to trip this because
    // their comptimeness is lazily evaluated.
    // Original bug, regressed in #17471
    const a = @sizeOf(?*EmptyStruct());
    _ = a;
    // Error union version, fails assertion in debug versions of release 0.11.0
    const S = struct {};
    _ = @sizeOf(anyerror!*S);
    _ = @sizeOf(anyerror!?S);
    // Evaluation case, crashes the actual release 0.11.0
    const C = struct { x: comptime_int };
    const c: anyerror!?C = .{ .x = 3 };
    const x = (try c).?.x;
    try std.testing.expectEqual(3, x);
}
