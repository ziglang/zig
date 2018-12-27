const std = @import("std");
const assertOrPanic = std.debug.assertOrPanic;
const maxInt = std.math.maxInt;

test "@bitCast extern enum to its integer type" {
    const SOCK = extern enum {
        A,
        B,

        fn testBitCastExternEnum() void {
            var SOCK_DGRAM = @This().B;
            var sock_dgram = @bitCast(c_int, SOCK_DGRAM);
            assertOrPanic(sock_dgram == 1);
        }
    };

    SOCK.testBitCastExternEnum();
    comptime SOCK.testBitCastExternEnum();
}

