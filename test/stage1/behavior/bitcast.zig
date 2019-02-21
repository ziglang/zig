const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;
const maxInt = std.math.maxInt;

test "@bitCast i32 -> u32" {
    testBitCast_i32_u32();
    comptime testBitCast_i32_u32();
}

fn testBitCast_i32_u32() void {
    expect(conv(-1) == maxInt(u32));
    expect(conv2(maxInt(u32)) == -1);
}

fn conv(x: i32) u32 {
    return @bitCast(u32, x);
}
fn conv2(x: u32) i32 {
    return @bitCast(i32, x);
}

test "@bitCast extern enum to its integer type" {
    const SOCK = extern enum {
        A,
        B,

        fn testBitCastExternEnum() void {
            var SOCK_DGRAM = @This().B;
            var sock_dgram = @bitCast(c_int, SOCK_DGRAM);
            expect(sock_dgram == 1);
        }
    };

    SOCK.testBitCastExternEnum();
    comptime SOCK.testBitCastExternEnum();
}

test "@bitCast packed structs at runtime and comptime" {
    const Full = packed struct {
        number: u16,
    };
    const Divided = packed struct {
        half1: u8,
        quarter3: u4,
        quarter4: u4,
    };
    const S = struct {
        fn doTheTest() void {
            var full = Full{ .number = 0x1234 };
            var two_halves = @bitCast(Divided, full);
            switch (builtin.endian) {
                builtin.Endian.Big => {
                    expect(two_halves.half1 == 0x12);
                    expect(two_halves.quarter3 == 0x3);
                    expect(two_halves.quarter4 == 0x4);
                },
                builtin.Endian.Little => {
                    expect(two_halves.half1 == 0x34);
                    expect(two_halves.quarter3 == 0x2);
                    expect(two_halves.quarter4 == 0x1);
                },
            }
        }
    };
    S.doTheTest();
    comptime S.doTheTest();
}
