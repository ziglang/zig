const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "@depositBits" {
    switch (builtin.zig_backend) {
        .stage2_llvm, .stage2_x86_64 => {},
        else => return error.SkipZigTest, // TODO
    }

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
    if (builtin.zig_backend != .stage2_llvm) return error.SkipZigTest;

    const S = struct {
        pub fn doTheTest() !void {
            const a: u64 = 0x1234_5678_9012_3456;
            const b: u128 = 0x00F0_FF00_F00F_00FF << 64;

            _ = &a;
            _ = &b;

            try expect(@depositBits(a, b) == 0x0000_1200_3004_0056 << 64);
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}

test "@extractBits" {
    switch (builtin.zig_backend) {
        .stage2_llvm, .stage2_x86_64 => {},
        else => return error.SkipZigTest, // TODO
    }

    const S = struct {
        pub fn doTheTest() !void {
            const a: u64 = 0;
            const b: u64 = 0xFFFF_FFFF_FFFF_FFFF;
            const c: u64 = 0x1234_5678_9012_3456;
            const d: u64 = 0x00F0_FF00_F00F_00FF;

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
    if (builtin.zig_backend != .stage2_llvm) return error.SkipZigTest; // TODO

    const S = struct {
        pub fn doTheTest() !void {
            const a: u128 = 0x1234_5678_9012_3456 << 64;
            const b: u128 = 0x00F0_FF00_F00F_00FF << 64;

            _ = &a;
            _ = &b;

            try expect(@extractBits(a, b) == 0x0356_9256);
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}
