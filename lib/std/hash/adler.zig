// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
// Adler32 checksum.
//
// https://tools.ietf.org/html/rfc1950#section-9
// https://github.com/madler/zlib/blob/master/adler32.c

const std = @import("../std.zig");
const testing = std.testing;

pub const Adler32 = struct {
    const base = 65521;
    const nmax = 5552;

    adler: u32,

    pub fn init() Adler32 {
        return Adler32{ .adler = 1 };
    }

    // This fast variant is taken from zlib. It reduces the required modulos and unrolls longer
    // buffer inputs and should be much quicker.
    pub fn update(self: *Adler32, input: []const u8) void {
        var s1 = self.adler & 0xffff;
        var s2 = (self.adler >> 16) & 0xffff;

        if (input.len == 1) {
            s1 +%= input[0];
            if (s1 >= base) {
                s1 -= base;
            }
            s2 +%= s1;
            if (s2 >= base) {
                s2 -= base;
            }
        } else if (input.len < 16) {
            for (input) |b| {
                s1 +%= b;
                s2 +%= s1;
            }
            if (s1 >= base) {
                s1 -= base;
            }

            s2 %= base;
        } else {
            const n = nmax / 16; // note: 16 | nmax

            var i: usize = 0;

            while (i + nmax <= input.len) {
                var rounds: usize = 0;
                while (rounds < n) : (rounds += 1) {
                    comptime var j: usize = 0;
                    inline while (j < 16) : (j += 1) {
                        s1 +%= input[i + j];
                        s2 +%= s1;
                    }
                    i += 16;
                }

                s1 %= base;
                s2 %= base;
            }

            if (i < input.len) {
                while (i + 16 <= input.len) : (i += 16) {
                    comptime var j: usize = 0;
                    inline while (j < 16) : (j += 1) {
                        s1 +%= input[i + j];
                        s2 +%= s1;
                    }
                }
                while (i < input.len) : (i += 1) {
                    s1 +%= input[i];
                    s2 +%= s1;
                }

                s1 %= base;
                s2 %= base;
            }
        }

        self.adler = s1 | (s2 << 16);
    }

    pub fn final(self: *Adler32) u32 {
        return self.adler;
    }

    pub fn hash(input: []const u8) u32 {
        var c = Adler32.init();
        c.update(input);
        return c.final();
    }
};

test "adler32 sanity" {
    testing.expectEqual(@as(u32, 0x620062), Adler32.hash("a"));
    testing.expectEqual(@as(u32, 0xbc002ed), Adler32.hash("example"));
}

test "adler32 long" {
    const long1 = [_]u8{1} ** 1024;
    testing.expectEqual(@as(u32, 0x06780401), Adler32.hash(long1[0..]));

    const long2 = [_]u8{1} ** 1025;
    testing.expectEqual(@as(u32, 0x0a7a0402), Adler32.hash(long2[0..]));
}

test "adler32 very long" {
    const long = [_]u8{1} ** 5553;
    testing.expectEqual(@as(u32, 0x707f15b2), Adler32.hash(long[0..]));
}

test "adler32 very long with variation" {
    const long = comptime blk: {
        @setEvalBranchQuota(7000);
        var result: [6000]u8 = undefined;

        var i: usize = 0;
        while (i < result.len) : (i += 1) {
            result[i] = @truncate(u8, i);
        }

        break :blk result;
    };

    testing.expectEqual(@as(u32, 0x5af38d6e), std.hash.Adler32.hash(long[0..]));
}
