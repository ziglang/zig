const std = @import("std");

const readInt = std.mem.readInt;
const assert = std.debug.assert;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

const RAPID_SEED: u64 = 0xbdd89aa982704029;
const RAPID_SECRET: [3]u64 = .{ 0x2d358dccaa6c78a5, 0x8bb84b93962eacc9, 0x4b33a62ed433d4a3 };

pub fn hash(seed: u64, input: []const u8) u64 {
    const sc = RAPID_SECRET;
    const len = input.len;
    var a: u64 = 0;
    var b: u64 = 0;
    var k = input;
    var is: [3]u64 = .{ seed, 0, 0 };

    is[0] ^= mix(seed ^ sc[0], sc[1]) ^ len;

    if (len <= 16) {
        if (len >= 4) {
            const d: u64 = ((len & 24) >> @intCast(len >> 3));
            const e = len - 4;
            a = (r32(k) << 32) | r32(k[e..]);
            b = ((r32(k[d..]) << 32) | r32(k[(e - d)..]));
        } else if (len > 0)
            a = (@as(u64, k[0]) << 56) | (@as(u64, k[len >> 1]) << 32) | @as(u64, k[len - 1]);
    } else {
        var remain = len;
        if (len > 48) {
            is[1] = is[0];
            is[2] = is[0];
            while (remain >= 96) {
                inline for (0..6) |i| {
                    const m1 = r64(k[8 * i * 2 ..]);
                    const m2 = r64(k[8 * (i * 2 + 1) ..]);
                    is[i % 3] = mix(m1 ^ sc[i % 3], m2 ^ is[i % 3]);
                }
                k = k[96..];
                remain -= 96;
            }
            if (remain >= 48) {
                inline for (0..3) |i| {
                    const m1 = r64(k[8 * i * 2 ..]);
                    const m2 = r64(k[8 * (i * 2 + 1) ..]);
                    is[i] = mix(m1 ^ sc[i], m2 ^ is[i]);
                }
                k = k[48..];
                remain -= 48;
            }

            is[0] ^= is[1] ^ is[2];
        }

        if (remain > 16) {
            is[0] = mix(r64(k) ^ sc[2], r64(k[8..]) ^ is[0] ^ sc[1]);
            if (remain > 32) {
                is[0] = mix(r64(k[16..]) ^ sc[2], r64(k[24..]) ^ is[0]);
            }
        }

        a = r64(input[len - 16 ..]);
        b = r64(input[len - 8 ..]);
    }

    a ^= sc[1];
    b ^= is[0];
    mum(&a, &b);
    return mix(a ^ sc[0] ^ len, b ^ sc[1]);
}

test "RapidHash.hash" {
    const bytes: []const u8 = "abcdefgh" ** 128;

    const sizes: [13]u64 = .{ 0, 1, 2, 3, 4, 8, 16, 32, 64, 128, 256, 512, 1024 };

    const outcomes: [13]u64 = .{
        0x5a6ef77074ebc84b,
        0xc11328477bc0f5d1,
        0x5644ac035e40d569,
        0x347080fbf5fcd81,
        0x56b66b8dc802bcc,
        0xb6bf9055973aac7c,
        0xed56d62eead1e402,
        0xc19072d767da8ffb,
        0x89bb40a9928a4f0d,
        0xe0af7c5e7b6e29fd,
        0x9a3ed35fbedfa11a,
        0x4c684b2119ca19fb,
        0x4b575f5bf25600d6,
    };

    var success: bool = true;
    for (sizes, outcomes) |s, e| {
        const r = hash(RAPID_SEED, bytes[0..s]);

        expectEqual(e, r) catch |err| {
            std.debug.print("Failed on {d}: {!}\n", .{ s, err });
            success = false;
        };
    }
    try expect(success);
}

inline fn mum(a: *u64, b: *u64) void {
    const r = @as(u128, a.*) * b.*;
    a.* = @truncate(r);
    b.* = @truncate(r >> 64);
}

inline fn mix(a: u64, b: u64) u64 {
    var copy_a = a;
    var copy_b = b;
    mum(&copy_a, &copy_b);
    return copy_a ^ copy_b;
}

inline fn r64(p: []const u8) u64 {
    return readInt(u64, p[0..8], .little);
}

inline fn r32(p: []const u8) u64 {
    return readInt(u32, p[0..4], .little);
}
