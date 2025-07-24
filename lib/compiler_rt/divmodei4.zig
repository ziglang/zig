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

pub fn __divei4(q_p: [*]u8, u_p: [*]u8, v_p: [*]u8, bits: usize) callconv(.c) void {
    @setRuntimeSafety(common.test_safety);
    const byte_size = std.zig.target.intByteSize(&builtin.target, @intCast(bits));
    const q: []u32 = @ptrCast(@alignCast(q_p[0..byte_size]));
    const u: []u32 = @ptrCast(@alignCast(u_p[0..byte_size]));
    const v: []u32 = @ptrCast(@alignCast(v_p[0..byte_size]));
    @call(.always_inline, divmod, .{ q, null, u, v }) catch unreachable;
}

pub fn __modei4(r_p: [*]u8, u_p: [*]u8, v_p: [*]u8, bits: usize) callconv(.c) void {
    @setRuntimeSafety(common.test_safety);
    const byte_size = std.zig.target.intByteSize(&builtin.target, @intCast(bits));
    const r: []u32 = @ptrCast(@alignCast(r_p[0..byte_size]));
    const u: []u32 = @ptrCast(@alignCast(u_p[0..byte_size]));
    const v: []u32 = @ptrCast(@alignCast(v_p[0..byte_size]));
    @call(.always_inline, divmod, .{ null, r, u, v }) catch unreachable;
}
