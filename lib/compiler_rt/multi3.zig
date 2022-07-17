//! Ported from git@github.com:llvm-project/llvm-project-20170507.git
//! ae684fad6d34858c014c94da69c15e7774a633c3
//! 2018-08-13

const std = @import("std");
const builtin = @import("builtin");
const native_endian = builtin.cpu.arch.endian();
const common = @import("common.zig");

pub const panic = common.panic;

comptime {
    if (common.want_windows_v2u64_abi) {
        @export(__multi3_windows_x86_64, .{ .name = "__multi3", .linkage = common.linkage });
    } else {
        @export(__multi3, .{ .name = "__multi3", .linkage = common.linkage });
    }
}

pub fn __multi3(a: i128, b: i128) callconv(.C) i128 {
    return mul(a, b);
}

const v2u64 = @Vector(2, u64);

fn __multi3_windows_x86_64(a: v2u64, b: v2u64) callconv(.C) v2u64 {
    return @bitCast(v2u64, mul(@bitCast(i128, a), @bitCast(i128, b)));
}

inline fn mul(a: i128, b: i128) i128 {
    const x = twords{ .all = a };
    const y = twords{ .all = b };
    var r = twords{ .all = mulddi3(x.s.low, y.s.low) };
    r.s.high +%= x.s.high *% y.s.low +% x.s.low *% y.s.high;
    return r.all;
}

fn mulddi3(a: u64, b: u64) i128 {
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

const twords = extern union {
    all: i128,
    s: S,

    const S = if (native_endian == .Little)
        extern struct {
            low: u64,
            high: u64,
        }
    else
        extern struct {
            high: u64,
            low: u64,
        };
};

test {
    _ = @import("multi3_test.zig");
}
