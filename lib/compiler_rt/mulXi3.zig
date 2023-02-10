const builtin = @import("builtin");
const std = @import("std");
const testing = std.testing;
const common = @import("common.zig");
const native_endian = builtin.cpu.arch.endian();

pub const panic = common.panic;

comptime {
    @export(__mulsi3, .{ .name = "__mulsi3", .linkage = common.linkage, .visibility = common.visibility });
    if (common.want_aeabi) {
        @export(__aeabi_lmul, .{ .name = "__aeabi_lmul", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        @export(__muldi3, .{ .name = "__muldi3", .linkage = common.linkage, .visibility = common.visibility });
    }
    if (common.want_windows_v2u64_abi) {
        @export(__multi3_windows_x86_64, .{ .name = "__multi3", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        @export(__multi3, .{ .name = "__multi3", .linkage = common.linkage, .visibility = common.visibility });
    }
}

pub fn __mulsi3(a: i32, b: i32) callconv(.C) i32 {
    var ua = @bitCast(u32, a);
    var ub = @bitCast(u32, b);
    var r: u32 = 0;

    while (ua > 0) {
        if ((ua & 1) != 0) r +%= ub;
        ua >>= 1;
        ub <<= 1;
    }

    return @bitCast(i32, r);
}

pub fn __muldi3(a: i64, b: i64) callconv(.C) i64 {
    return mul(a, b);
}

fn __aeabi_lmul(a: i64, b: i64) callconv(.AAPCS) i64 {
    return mul(a, b);
}

inline fn mul(a: i64, b: i64) i64 {
    const word_t = common.HalveInt(i64, false);
    const x = word_t{ .all = a };
    const y = word_t{ .all = b };
    var r = word_t{ .all = muldsi3(x.s.low, y.s.low) };
    r.s.high +%= x.s.high *% y.s.low +% x.s.low *% y.s.high;
    return r.all;
}

fn muldsi3(a: u32, b: u32) i64 {
    const bits_in_word_2 = @sizeOf(i32) * 8 / 2;
    const lower_mask = (~@as(u32, 0)) >> bits_in_word_2;
    const word_t = common.HalveInt(i64, false);

    var r: word_t = undefined;
    r.s.low = (a & lower_mask) *% (b & lower_mask);
    var t: u32 = r.s.low >> bits_in_word_2;
    r.s.low &= lower_mask;
    t += (a >> bits_in_word_2) *% (b & lower_mask);
    r.s.low +%= (t & lower_mask) << bits_in_word_2;
    r.s.high = t >> bits_in_word_2;
    t = r.s.low >> bits_in_word_2;
    r.s.low &= lower_mask;
    t +%= (b >> bits_in_word_2) *% (a & lower_mask);
    r.s.low +%= (t & lower_mask) << bits_in_word_2;
    r.s.high +%= t >> bits_in_word_2;
    r.s.high +%= (a >> bits_in_word_2) *% (b >> bits_in_word_2);
    return r.all;
}

pub fn __multi3(a: i128, b: i128) callconv(.C) i128 {
    return mul128(a, b);
}

const v2u64 = @Vector(2, u64);

fn __multi3_windows_x86_64(a: v2u64, b: v2u64) callconv(.C) v2u64 {
    return @bitCast(v2u64, mul128(@bitCast(i128, a), @bitCast(i128, b)));
}

inline fn mul128(a: i128, b: i128) i128 {
    const twords = common.HalveInt(i128, false);
    const x = twords{ .all = a };
    const y = twords{ .all = b };
    var r = twords{ .all = mulddi3(x.s.low, y.s.low) };
    r.s.high +%= x.s.high *% y.s.low +% x.s.low *% y.s.high;
    return r.all;
}

fn mulddi3(a: u64, b: u64) i128 {
    const twords = common.HalveInt(i128, false);
    const bits_in_dword_2 = (@sizeOf(i64) * 8) / 2;
    const lower_mask = ~@as(u64, 0) >> bits_in_dword_2;
    var r: twords = undefined;
    r.s.low = (a & lower_mask) *% (b & lower_mask);
    var t: u64 = r.s.low >> bits_in_dword_2;
    r.s.low &= lower_mask;
    t +%= (a >> bits_in_dword_2) *% (b & lower_mask);
    r.s.low +%= (t & lower_mask) << bits_in_dword_2;
    r.s.high = t >> bits_in_dword_2;
    t = r.s.low >> bits_in_dword_2;
    r.s.low &= lower_mask;
    t +%= (b >> bits_in_dword_2) *% (a & lower_mask);
    r.s.low +%= (t & lower_mask) << bits_in_dword_2;
    r.s.high +%= t >> bits_in_dword_2;
    r.s.high +%= (a >> bits_in_dword_2) *% (b >> bits_in_dword_2);
    return r.all;
}

test {
    _ = @import("mulXi3_test.zig");
}
