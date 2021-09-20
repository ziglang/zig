const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const builtin = @import("builtin");

test "atomicrmw with ints" {
    try testAtomicRmwInt();
    comptime try testAtomicRmwInt();
}

fn testAtomicRmwInt() !void {
    var x: u8 = 1;
    var res = @atomicRmw(u8, &x, .Xchg, 3, .SeqCst);
    try expect(x == 3 and res == 1);
    _ = @atomicRmw(u8, &x, .Add, 3, .SeqCst);
    try expect(x == 6);
    _ = @atomicRmw(u8, &x, .Sub, 1, .SeqCst);
    try expect(x == 5);
    _ = @atomicRmw(u8, &x, .And, 4, .SeqCst);
    try expect(x == 4);
    _ = @atomicRmw(u8, &x, .Nand, 4, .SeqCst);
    try expect(x == 0xfb);
    _ = @atomicRmw(u8, &x, .Or, 6, .SeqCst);
    try expect(x == 0xff);
    _ = @atomicRmw(u8, &x, .Xor, 2, .SeqCst);
    try expect(x == 0xfd);

    _ = @atomicRmw(u8, &x, .Max, 1, .SeqCst);
    try expect(x == 0xfd);
    _ = @atomicRmw(u8, &x, .Min, 1, .SeqCst);
    try expect(x == 1);
}

test "atomics with different types" {
    try testAtomicsWithType(bool, true, false);
    inline for (.{ u1, i4, u5, i15, u24 }) |T| {
        try testAtomicsWithType(T, 0, 1);
    }
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
