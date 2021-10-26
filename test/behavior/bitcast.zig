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

test "@bitCast enum to its integer type" {
    const SOCK = enum(c_int) {
        A,
        B,

        fn testBitCastExternEnum() !void {
            var SOCK_DGRAM = @This().B;
            var sock_dgram = @bitCast(c_int, SOCK_DGRAM);
            try expect(sock_dgram == 1);
        }
    };

    try SOCK.testBitCastExternEnum();
    comptime try SOCK.testBitCastExternEnum();
}

// issue #3010: compiler segfault
test "bitcast literal [4]u8 param to u32" {
    const ip = @bitCast(u32, [_]u8{ 255, 255, 255, 255 });
    try expect(ip == maxInt(u32));
}

test "bitcast generates a temporary value" {
    var y = @as(u16, 0x55AA);
    const x = @bitCast(u16, @bitCast([2]u8, y));
    try expect(y == x);
}
