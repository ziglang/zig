const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const builtin = @import("builtin");

test "cmpxchg" {
    try testCmpxchg();
    comptime try testCmpxchg();
}

fn testCmpxchg() !void {
    var x: i32 = 1234;
    if (@cmpxchgWeak(i32, &x, 99, 5678, .SeqCst, .SeqCst)) |x1| {
        try expect(x1 == 1234);
    } else {
        @panic("cmpxchg should have failed");
    }

    while (@cmpxchgWeak(i32, &x, 1234, 5678, .SeqCst, .SeqCst)) |x1| {
        try expect(x1 == 1234);
    }
    try expect(x == 5678);

    try expect(@cmpxchgStrong(i32, &x, 5678, 42, .SeqCst, .SeqCst) == null);
    try expect(x == 42);
}
