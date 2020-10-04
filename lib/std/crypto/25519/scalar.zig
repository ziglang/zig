// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std");
const mem = std.mem;

const field_size = [32]u8{
    0xed, 0xd3, 0xf5, 0x5c, 0x1a, 0x63, 0x12, 0x58, 0xd6, 0x9c, 0xf7, 0xa2, 0xde, 0xf9, 0xde, 0x14, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x10, // 2^252+27742317777372353535851937790883648493
};

const ScalarExpanded = struct {
    limbs: [64]i64 = [_]i64{0} ** 64,

    fn fromBytes(s: [32]u8) ScalarExpanded {
        var limbs: [64]i64 = undefined;
        for (s) |x, idx| {
            limbs[idx] = @as(i64, x);
        }
        mem.set(i64, limbs[32..], 0);
        return .{ .limbs = limbs };
    }

    fn fromBytes64(s: [64]u8) ScalarExpanded {
        var limbs: [64]i64 = undefined;
        for (s) |x, idx| {
            limbs[idx] = @as(i64, x);
        }
        return .{ .limbs = limbs };
    }

    fn reduce(e: *ScalarExpanded) void {
        const limbs = &e.limbs;
        var carry: i64 = undefined;
        var i: usize = 63;
        while (i >= 32) : (i -= 1) {
            carry = 0;
            const k = i - 12;
            const xi = limbs[i];
            var j = i - 32;
            while (j < k) : (j += 1) {
                const xj = limbs[j] + carry - 16 * xi * @as(i64, field_size[j - (i - 32)]);
                carry = (xj + 128) >> 8;
                limbs[j] = xj - carry * 256;
            }
            limbs[k] += carry;
            limbs[i] = 0;
        }
        carry = 0;
        comptime var j: usize = 0;
        inline while (j < 32) : (j += 1) {
            const xi = limbs[j] + carry - (limbs[31] >> 4) * @as(i64, field_size[j]);
            carry = xi >> 8;
            limbs[j] = xi & 255;
        }
        j = 0;
        inline while (j < 32) : (j += 1) {
            limbs[j] -= carry * @as(i64, field_size[j]);
        }
        j = 0;
        inline while (j < 32) : (j += 1) {
            limbs[j + 1] += limbs[j] >> 8;
        }
    }

    fn toBytes(e: *ScalarExpanded) [32]u8 {
        e.reduce();
        var r: [32]u8 = undefined;
        var i: usize = 0;
        while (i < 32) : (i += 1) {
            r[i] = @intCast(u8, e.limbs[i]);
        }
        return r;
    }

    fn add(a: ScalarExpanded, b: ScalarExpanded) ScalarExpanded {
        var r = ScalarExpanded{};
        comptime var i = 0;
        inline while (i < 64) : (i += 1) {
            r.limbs[i] = a.limbs[i] + b.limbs[i];
        }
        return r;
    }

    fn mul(a: ScalarExpanded, b: ScalarExpanded) ScalarExpanded {
        var r = ScalarExpanded{};
        var i: usize = 0;
        while (i < 32) : (i += 1) {
            const ai = a.limbs[i];
            comptime var j = 0;
            inline while (j < 32) : (j += 1) {
                r.limbs[i + j] += ai * b.limbs[j];
            }
        }
        r.reduce();
        return r;
    }

    fn sq(a: ScalarExpanded) ScalarExpanded {
        return a.mul(a);
    }

    fn mulAdd(a: ScalarExpanded, b: ScalarExpanded, c: ScalarExpanded) ScalarExpanded {
        var r: ScalarExpanded = .{ .limbs = c.limbs };
        var i: usize = 0;
        while (i < 32) : (i += 1) {
            const ai = a.limbs[i];
            comptime var j = 0;
            inline while (j < 32) : (j += 1) {
                r.limbs[i + j] += ai * b.limbs[j];
            }
        }
        r.reduce();
        return r;
    }
};

/// Reject a scalar whose encoding is not canonical.
pub fn rejectNonCanonical(s: [32]u8) !void {
    var c: u8 = 0;
    var n: u8 = 1;
    var i: usize = 31;
    while (true) : (i -= 1) {
        const xs = @as(u16, s[i]);
        const xfield_size = @as(u16, field_size[i]);
        c |= @intCast(u8, ((xs -% xfield_size) >> 8) & n);
        n &= @intCast(u8, ((xs ^ xfield_size) -% 1) >> 8);
        if (i == 0) break;
    }
    if (c == 0) {
        return error.NonCanonical;
    }
}

/// Reduce a scalar to the field size.
pub fn reduce(s: [32]u8) [32]u8 {
    return ScalarExpanded.fromBytes(s).toBytes();
}

/// Reduce a 64-bytes scalar to the field size.
pub fn reduce64(s: [64]u8) [32]u8 {
    return ScalarExpanded.fromBytes64(s).toBytes();
}

/// Perform the X25519 "clamping" operation.
/// The scalar is then guaranteed to be a multiple of the cofactor.
pub inline fn clamp(s: *[32]u8) void {
    s[0] &= 248;
    s[31] = (s[31] & 127) | 64;
}

/// Return a*b+c (mod L)
pub fn mulAdd(a: [32]u8, b: [32]u8, c: [32]u8) [32]u8 {
    return ScalarExpanded.fromBytes(a).mulAdd(ScalarExpanded.fromBytes(b), ScalarExpanded.fromBytes(c)).toBytes();
}

test "scalar25519" {
    const bytes: [32]u8 = .{ 1, 2, 3, 4, 5, 6, 7, 8, 1, 2, 3, 4, 5, 6, 7, 8, 1, 2, 3, 4, 5, 6, 7, 8, 1, 2, 3, 4, 5, 6, 7, 255 };
    var x = ScalarExpanded.fromBytes(bytes);
    var y = x.toBytes();
    try rejectNonCanonical(y);
    var buf: [128]u8 = undefined;
    std.testing.expectEqualStrings(try std.fmt.bufPrint(&buf, "{X}", .{y}), "1E979B917937F3DE71D18077F961F6CEFF01030405060708010203040506070F");

    const reduced = reduce(field_size);
    std.testing.expectEqualStrings(try std.fmt.bufPrint(&buf, "{X}", .{reduced}), "0000000000000000000000000000000000000000000000000000000000000000");
}

test "non-canonical scalar25519" {
    const too_targe: [32]u8 = .{ 0xed, 0xd3, 0xf5, 0x5c, 0x1a, 0x63, 0x12, 0x58, 0xd6, 0x9c, 0xf7, 0xa2, 0xde, 0xf9, 0xde, 0x14, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x10 };
    std.testing.expectError(error.NonCanonical, rejectNonCanonical(too_targe));
}

test "mulAdd overflow check" {
    const a: [32]u8 = [_]u8{0xff} ** 32;
    const b: [32]u8 = [_]u8{0xff} ** 32;
    const c: [32]u8 = [_]u8{0xff} ** 32;
    const x = mulAdd(a, b, c);
    var buf: [128]u8 = undefined;
    std.testing.expectEqualStrings(try std.fmt.bufPrint(&buf, "{X}", .{x}), "D14DF91389432C25AD60FF9791B9FD1D67BEF517D273ECCE3D9A307C1B419903");
}
