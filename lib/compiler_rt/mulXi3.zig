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
    var ua: u32 = @bitCast(a);
    var ub: u32 = @bitCast(b);
    var r: u32 = 0;

    while (ua > 0) {
        if ((ua & 1) != 0) r +%= ub;
        ua >>= 1;
        ub <<= 1;
    }

    return @bitCast(r);
}

pub fn __muldi3(a: i64, b: i64) callconv(.C) i64 {
    return mulX(i64, a, b);
}

fn __aeabi_lmul(a: i64, b: i64) callconv(.AAPCS) i64 {
    return mulX(i64, a, b);
}

inline fn mulX(comptime T: type, a: T, b: T) T {
    const word_t = common.HalveInt(T, false);
    const x = word_t{ .all = a };
    const y = word_t{ .all = b };
    var r = switch (T) {
        i64, i128 => word_t{ .all = muldXi(word_t.HalfT, x.s.low, y.s.low) },
        else => unreachable,
    };
    r.s.high +%= x.s.high *% y.s.low +% x.s.low *% y.s.high;
    return r.all;
}

fn DoubleInt(comptime T: type) type {
    return switch (T) {
        u32 => i64,
        u64 => i128,
        i32 => i64,
        i64 => i128,
        else => unreachable,
    };
}

fn muldXi(comptime T: type, a: T, b: T) DoubleInt(T) {
    const DT = DoubleInt(T);
    const word_t = common.HalveInt(DT, false);
    const bits_in_word_2 = @sizeOf(T) * 8 / 2;
    const lower_mask = (~@as(T, 0)) >> bits_in_word_2;

    var r: word_t = undefined;
    r.s.low = (a & lower_mask) *% (b & lower_mask);
    var t: T = r.s.low >> bits_in_word_2;
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
    return mulX(i128, a, b);
}

const v2u64 = @Vector(2, u64);

fn __multi3_windows_x86_64(a: v2u64, b: v2u64) callconv(.C) v2u64 {
    return @bitCast(mulX(i128, @as(i128, @bitCast(a)), @as(i128, @bitCast(b))));
}

test {
    _ = @import("mulXi3_test.zig");
}
