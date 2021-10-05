const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const maxInt = std.math.maxInt;
const native_endian = builtin.target.cpu.arch.endian();

test "@bitCast i32 -> u32" {
    try testBitCast_i32_u32();
    comptime try testBitCast_i32_u32();
}

fn testBitCast_i32_u32() !void {
    try expect(conv(-1) == maxInt(u32));
    try expect(conv2(maxInt(u32)) == -1);
}

fn conv(x: i32) u32 {
    return @bitCast(u32, x);
}
fn conv2(x: u32) i32 {
    return @bitCast(i32, x);
}

test "bitcast result to _" {
    _ = @bitCast(u8, @as(i8, 1));
}

test "nested bitcast" {
    const S = struct {
        fn moo(x: isize) !void {
            try expect(@intCast(isize, 42) == x);
        }

        fn foo(x: isize) !void {
            try @This().moo(
                @bitCast(isize, if (x != 0) @bitCast(usize, x) else @bitCast(usize, x)),
            );
        }
    };

    try S.foo(42);
    comptime try S.foo(42);
}
