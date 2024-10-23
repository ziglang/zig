const std = @import("std");
const builtin = @import("builtin");
const common = @import("common.zig");
const shr = std.math.shr;
const shl = std.math.shl;

const max_limbs = std.math.divCeil(usize, 65535, 32) catch unreachable; // max supported type is u65535

comptime {
    @export(&__udivei4, .{ .name = "__udivei4", .linkage = common.linkage, .visibility = common.visibility });
    @export(&__umodei4, .{ .name = "__umodei4", .linkage = common.linkage, .visibility = common.visibility });
}

const endian = builtin.cpu.arch.endian();

/// Get the value of a limb.
inline fn limb(x: []const u32, i: usize) u32 {
    return if (endian == .little) x[i] else x[x.len - 1 - i];
}

/// Change the value of a limb.
inline fn limb_set(x: []u32, i: usize, v: u32) void {
    if (endian == .little) {
        x[i] = v;
    } else {
        x[x.len - 1 - i] = v;
    }
}

// Uses Knuth's Algorithm D, 4.3.1, p. 272.
fn divmod(q: ?[]u32, r: ?[]u32, u: []const u32, v: []const u32) !void {
    if (q) |q_| @memset(q_[0..], 0);
    if (r) |r_| @memset(r_[0..], 0);

    if (u.len == 0 or v.len == 0) return error.DivisionByZero;

    var m = u.len - 1;
    var n = v.len - 1;
    while (limb(u, m) == 0) : (m -= 1) {
        if (m == 0) return;
    }
    while (limb(v, n) == 0) : (n -= 1) {
        if (n == 0) return error.DivisionByZero;
    }

    if (n > m) {
        if (r) |r_| @memcpy(r_[0..u.len], u);
        return;
    }

    const s = @clz(limb(v, n));

    var vn: [max_limbs]u32 = undefined;
    var i = n;
    while (i > 0) : (i -= 1) {
        limb_set(&vn, i, shl(u32, limb(v, i), s) | shr(u32, limb(v, i - 1), 32 - s));
    }
    limb_set(&vn, 0, shl(u32, limb(v, 0), s));

    var un: [max_limbs + 1]u32 = undefined;
    limb_set(&un, m + 1, shr(u32, limb(u, m), 32 - s));
    i = m;
    while (i > 0) : (i -= 1) {
        limb_set(&un, i, shl(u32, limb(u, i), s) | shr(u32, limb(u, i - 1), 32 - s));
    }
    limb_set(&un, 0, shl(u32, limb(u, 0), s));

    var j = m - n;
    while (true) : (j -= 1) {
        const uu = (@as(u64, limb(&un, j + n + 1)) << 32) + limb(&un, j + n);
        var qhat = uu / limb(&vn, n);
        var rhat = uu % limb(&vn, n);

        while (true) {
            if (qhat >= (1 << 32) or (n > 0 and qhat * limb(&vn, n - 1) > (rhat << 32) + limb(&un, j + n - 1))) {
                qhat -= 1;
                rhat += limb(&vn, n);
                if (rhat < (1 << 32)) continue;
            }
            break;
        }
        var carry: i64 = 0;
        i = 0;
        while (i <= n) : (i += 1) {
            const p = qhat * limb(&vn, i);
            const t = limb(&un, i + j) - carry - @as(u32, @truncate(p));
            limb_set(&un, i + j, @as(u32, @truncate(@as(u64, @bitCast(t)))));
            carry = @as(i64, @intCast(p >> 32)) - @as(i64, @intCast(t >> 32));
        }
        const t = limb(&un, j + n + 1) -% carry;
        limb_set(&un, j + n + 1, @as(u32, @truncate(@as(u64, @bitCast(t)))));
        if (q) |q_| limb_set(q_, j, @as(u32, @truncate(qhat)));
        if (t < 0) {
            if (q) |q_| limb_set(q_, j, limb(q_, j) - 1);
            var carry2: u64 = 0;
            i = 0;
            while (i <= n) : (i += 1) {
                const t2 = @as(u64, limb(&un, i + j)) + @as(u64, limb(&vn, i)) + carry2;
                limb_set(&un, i + j, @as(u32, @truncate(t2)));
                carry2 = t2 >> 32;
            }
            limb_set(&un, j + n + 1, @as(u32, @truncate(limb(&un, j + n + 1) + carry2)));
        }
        if (j == 0) break;
    }
    if (r) |r_| {
        i = 0;
        while (i <= n) : (i += 1) {
            limb_set(r_, i, shr(u32, limb(&un, i), s) | shl(u32, limb(&un, i + 1), 32 - s));
        }
        limb_set(r_, n, shr(u32, limb(&un, n), s));
    }
}

pub fn __udivei4(r_q: [*]u32, u_p: [*]const u32, v_p: [*]const u32, bits: usize) callconv(.C) void {
    @setRuntimeSafety(builtin.is_test);
    const u = u_p[0 .. std.math.divCeil(usize, bits, 32) catch unreachable];
    const v = v_p[0 .. std.math.divCeil(usize, bits, 32) catch unreachable];
    const q = r_q[0 .. std.math.divCeil(usize, bits, 32) catch unreachable];
    @call(.always_inline, divmod, .{ q, null, u, v }) catch unreachable;
}

pub fn __umodei4(r_p: [*]u32, u_p: [*]const u32, v_p: [*]const u32, bits: usize) callconv(.C) void {
    @setRuntimeSafety(builtin.is_test);
    const u = u_p[0 .. std.math.divCeil(usize, bits, 32) catch unreachable];
    const v = v_p[0 .. std.math.divCeil(usize, bits, 32) catch unreachable];
    const r = r_p[0 .. std.math.divCeil(usize, bits, 32) catch unreachable];
    @call(.always_inline, divmod, .{ null, r, u, v }) catch unreachable;
}

test "__udivei4/__umodei4" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;

    const RndGen = std.Random.DefaultPrng;
    var rnd = RndGen.init(42);
    var i: usize = 10000;
    while (i > 0) : (i -= 1) {
        const u = rnd.random().int(u1000);
        const v = 1 + rnd.random().int(u1200);
        const q = u / v;
        const r = u % v;
        const z = q * v + r;
        try std.testing.expect(z == u);
    }
}
