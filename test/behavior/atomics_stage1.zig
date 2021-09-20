const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const builtin = @import("builtin");

test "atomics with different types" {
    try testAtomicsWithType(bool, true, false);

    try testAtomicsWithType(u1, 0, 1);
    try testAtomicsWithType(i4, 0, 1);
    try testAtomicsWithType(u5, 0, 1);
    try testAtomicsWithType(i15, 0, 1);
    try testAtomicsWithType(u24, 0, 1);

    try testAtomicsWithType(u0, 0, 0);
    try testAtomicsWithType(i0, 0, 0);
}

fn testAtomicsWithType(comptime T: type, a: T, b: T) !void {
    var x: T = b;
    @atomicStore(T, &x, a, .SeqCst);
    try expect(x == a);
    try expect(@atomicLoad(T, &x, .SeqCst) == a);
    try expect(@atomicRmw(T, &x, .Xchg, b, .SeqCst) == a);
    try expect(@cmpxchgStrong(T, &x, b, a, .SeqCst, .SeqCst) == null);
    if (@sizeOf(T) != 0)
        try expect(@cmpxchgStrong(T, &x, b, a, .SeqCst, .SeqCst).? == a);
}
