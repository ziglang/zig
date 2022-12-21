const std = @import("std");
const builtin = @import("builtin");
const common = @import("common.zig");
const shr = std.math.shr;
const shl = std.math.shl;

const max_limbs = std.math.divCeil(usize, 65535, 32) catch unreachable; // max supported type is u65535

comptime {
    @export(__udivei4, .{ .name = "__udivei4", .linkage = common.linkage });
    @export(__umodei4, .{ .name = "__umodei4", .linkage = common.linkage });
}

// Uses Knuth's Algorithm D, 4.3.1, p. 272.
fn divmod(q: ?[]u32, r: ?[]u32, u: []const u32, v: []const u32) !void {
    @setRuntimeSafety(builtin.is_test);

    if (q) |q_| std.mem.set(u32, q_[0..], 0);
    if (r) |r_| std.mem.set(u32, r_[0..], 0);

    if (u.len == 0 or v.len == 0) return error.DivisionByZero;

    var m = u.len - 1;
    var n = v.len - 1;
    while (u[m] == 0) : (m -= 1) {
        if (m == 0) return;
    }
    while (v[n] == 0) : (n -= 1) {
        if (n == 0) return error.DivisionByZero;
    }

    if (n > m) {
        if (r) |r_| std.mem.copy(u32, r_[0..], u[0..]);
        return;
    }

    const s = @clz(v[n]);

    var vn: [max_limbs]u32 = undefined;
    var i = n;
    while (i > 0) : (i -= 1) {
        vn[i] = shl(u32, v[i], s) | shr(u32, v[i - 1], 32 - s);
    }
    vn[0] = shl(u32, v[0], s);

    var un: [max_limbs + 1]u32 = undefined;
    un[m + 1] = shr(u32, u[m], 32 - s);
    i = m;
    while (i > 0) : (i -= 1) {
        un[i] = shl(u32, u[i], s) | shr(u32, u[i - 1], 32 - s);
    }
    un[0] = shl(u32, u[0], s);

    var j = m - n;
    while (true) : (j -= 1) {
        const uu = (@as(u64, un[j + n + 1]) << 32) + un[j + n];
        var qhat = uu / vn[n];
        var rhat = uu % vn[n];

        while (true) {
            if (qhat >= (1 << 32) or (n > 0 and qhat * vn[n - 1] > (rhat << 32) + un[j + n - 1])) {
                qhat -= 1;
                rhat += vn[n];
                if (rhat < (1 << 32)) continue;
            }
            break;
        }
        var carry: u64 = 0;
        i = 0;
        while (i <= n) : (i += 1) {
            const p = qhat * vn[i];
            const t = un[i + j] - carry - @truncate(u32, p);
            un[i + j] = @truncate(u32, @bitCast(u64, t));
            carry = @intCast(u64, p >> 32) - @intCast(u64, t >> 32);
        }
        const t = un[j + n + 1] - carry;
        un[j + n + 1] = @truncate(u32, @bitCast(u64, t));
        if (q) |q_| q_[j] = @truncate(u32, qhat);
        if (t < 0) {
            if (q) |q_| q_[j] -= 1;
            var carry2: u64 = 0;
            i = 0;
            while (i <= n) : (i += 1) {
                const t2 = @as(u64, un[i + j]) + @as(u64, vn[i]) + carry2;
                un[i + j] = @truncate(u32, t2);
                carry2 = t2 >> 32;
            }
            un[j + n + 1] = @truncate(u32, un[j + n + 1] + carry2);
        }
        if (j == 0) break;
    }
    if (r) |r_| {
        i = 0;
        while (i <= n) : (i += 1) {
            r_[i] = shr(u32, un[i], s) | shl(u32, un[i + 1], 32 - s);
        }
        r_[n] = shr(u32, un[n], s);
    }
}

pub fn __udivei4(r_q: [*c]u32, u_p: [*c]const u32, v_p: [*c]const u32, bits: usize) callconv(.C) void {
    const u = u_p[0 .. bits / 32];
    const v = v_p[0 .. bits / 32];
    var q = r_q[0 .. bits / 32];
    @call(.always_inline, divmod, .{q, null, u, v}) catch unreachable;
}

pub fn __umodei4(r_p: [*c]u32, u_p: [*c]const u32, v_p: [*c]const u32, bits: usize) callconv(.C) void {
    const u = u_p[0 .. bits / 32];
    const v = v_p[0 .. bits / 32];
    var r = r_p[0 .. bits / 32];
    @call(.always_inline, divmod, .{null, r, u, v}) catch unreachable;
}

test "__udivei4/__umodei4" {
    const RndGen = std.rand.DefaultPrng;
    var rnd = RndGen.init(42);
    var i: usize = 100000;
    while (i > 0) : (i -= 1) {
        const u = rnd.random().int(u1000);
        const v = 1 + rnd.random().int(u1200);
        const q = u / v;
        const r = u % v;
        const z = q * v + r;
        try std.testing.expectEqual(z, u);
    }
}
