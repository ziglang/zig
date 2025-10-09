const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

const supports_pext_pdep = switch (builtin.zig_backend) {
    .stage2_llvm => true,
    .stage2_x86_64 => true,
    else => false,
};

test "@depositBits" {
    if (!supports_pext_pdep) return error.SkipZigTest; // TODO

    const S = struct {
        pub fn doTheTest() !void {
            var a: u64 = 0;
            var b: u64 = 0xFFFF_FFFF_FFFF_FFFF;
            var c: u64 = 0x1234_5678_9012_3456;
            var d: u64 = 0x00F0_FF00_F00F_00FF;

            _ = &a;
            _ = &b;
            _ = &c;
            _ = &d;

            try expect(@depositBits(b, a) == 0);
            try expect(@depositBits(a, b) == 0);

            try expect(@depositBits(b, c) == c);
            try expect(@depositBits(b, d) == d);

            try expect(@depositBits(c, d) == 0x0000_1200_3004_0056);
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}

test "@depositBits u128" {
    if (!supports_pext_pdep) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.os.tag == .windows) return error.SkipZigTest; // TODO #19498

    const S = struct {
        pub fn doTheTest() !void {
            var a: u64 = 0x1234_5678_9012_3456;
            var b: u128 = 0x00F0_FF00_F00F_00FF << 64;

            _ = &a;
            _ = &b;

            try expect(@depositBits(a, b) == 0x0000_1200_3004_0056 << 64);
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}

test "@depositBits u256" {
    if (!supports_pext_pdep) return error.SkipZigTest; // TODO

    const S = struct {
        pub fn doTheTest() !void {
            var a: u64 = 0x1234_5678_9ABC_DEF0;
            var b: u256 = 0x0F00_0FF0_0F0F_FF00 << 174;

            _ = &a;
            _ = &b;

            try expect(@depositBits(a, b) == 0x0A00_0BC0_0D0E_F000 << 174);
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}

test "@extractBits" {
    if (!supports_pext_pdep) return error.SkipZigTest; // TODO

    const S = struct {
        pub fn doTheTest() !void {
            var a: u64 = 0;
            var b: u64 = 0xFFFF_FFFF_FFFF_FFFF;
            var c: u64 = 0x1234_5678_9012_3456;
            var d: u64 = 0x00F0_FF00_F00F_00FF;

            _ = &a;
            _ = &b;
            _ = &c;
            _ = &d;

            try expect(@extractBits(b, a) == 0);
            try expect(@extractBits(a, b) == 0);

            try expect(@extractBits(c, b) == c);
            try expect(@extractBits(d, b) == d);

            try expect(@extractBits(c, d) == 0x0356_9256);
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}

test "@extractBits u128" {
    if (!supports_pext_pdep) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.os.tag == .windows) return error.SkipZigTest; // TODO #19498

    const S = struct {
        pub fn doTheTest() !void {
            var a: u128 = 0x1234_5678_9012_3456 << 64;
            var b: u128 = 0x00F0_FF00_F00F_00FF << 64;

            _ = &a;
            _ = &b;

            try expect(@extractBits(a, b) == 0x0356_9256);
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}

test "@extractBits u256" {
    if (!supports_pext_pdep) return error.SkipZigTest; // TODO

    const S = struct {
        pub fn doTheTest() !void {
            var a: u256 = 0x1234_5678_9ABC_DEF0 << 96;
            var b: u256 = 0x0F00_0FF0_0F0F_FF00 << 96;

            _ = &a;
            _ = &b;

            try expect(@extractBits(a, b) == 0x0267_ACDE);
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}
