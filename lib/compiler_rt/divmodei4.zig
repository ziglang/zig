const std = @import("std");
const builtin = @import("builtin");
const common = @import("common.zig");
const udivmod = @import("udivmodei4.zig").divmod;

comptime {
    @export(&__divei4, .{ .name = "__divei4", .linkage = common.linkage, .visibility = common.visibility });
    @export(&__modei4, .{ .name = "__modei4", .linkage = common.linkage, .visibility = common.visibility });
}

const endian = builtin.cpu.arch.endian();

inline fn limb(x: []u32, i: usize) *u32 {
    return if (endian == .little) &x[i] else &x[x.len - 1 - i];
}

inline fn neg(x: []u32) void {
    var ov: u1 = 1;
    for (0..x.len) |limb_index| {
        const l = limb(x, limb_index);
        l.*, ov = @addWithOverflow(~l.*, ov);
    }
}

/// Mutates the arguments!
fn divmod(q: ?[]u32, r: ?[]u32, u: []u32, v: []u32) !void {
    const u_sign: i32 = @bitCast(u[u.len - 1]);
    const v_sign: i32 = @bitCast(v[v.len - 1]);
    if (u_sign < 0) neg(u);
    if (v_sign < 0) neg(v);
    try @call(.always_inline, udivmod, .{ q, r, u, v });
    if (q) |x| if (u_sign ^ v_sign < 0) neg(x);
    if (r) |x| if (u_sign < 0) neg(x);
}

pub fn __divei4(r_q: [*]u32, u_p: [*]u32, v_p: [*]u32, bits: usize) callconv(.C) void {
    @setRuntimeSafety(builtin.is_test);
    const u = u_p[0 .. std.math.divCeil(usize, bits, 32) catch unreachable];
    const v = v_p[0 .. std.math.divCeil(usize, bits, 32) catch unreachable];
    const q = r_q[0 .. std.math.divCeil(usize, bits, 32) catch unreachable];
    @call(.always_inline, divmod, .{ q, null, u, v }) catch unreachable;
}

pub fn __modei4(r_p: [*]u32, u_p: [*]u32, v_p: [*]u32, bits: usize) callconv(.C) void {
    @setRuntimeSafety(builtin.is_test);
    const u = u_p[0 .. std.math.divCeil(usize, bits, 32) catch unreachable];
    const v = v_p[0 .. std.math.divCeil(usize, bits, 32) catch unreachable];
    const r = r_p[0 .. std.math.divCeil(usize, bits, 32) catch unreachable];
    @call(.always_inline, divmod, .{ null, r, u, v }) catch unreachable;
}
