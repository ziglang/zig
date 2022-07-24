const std = @import("std");
const builtin = @import("builtin");
const native_endian = builtin.cpu.arch.endian();
const arch = builtin.cpu.arch;
const is_test = builtin.is_test;
const linkage: std.builtin.GlobalLinkage = if (builtin.is_test) .Internal else .Weak;
pub const panic = @import("common.zig").panic;

comptime {
    @export(__muldi3, .{ .name = "__muldi3", .linkage = linkage });

    if (!is_test) {
        if (arch.isARM() or arch.isThumb()) {
            @export(__aeabi_lmul, .{ .name = "__aeabi_lmul", .linkage = linkage });
        }
    }
}

// Ported from
// https://github.com/llvm/llvm-project/blob/llvmorg-9.0.0/compiler-rt/lib/builtins/muldi3.c

const dwords = extern union {
    all: i64,
    s: switch (native_endian) {
        .Little => extern struct {
            low: u32,
            high: u32,
        },
        .Big => extern struct {
            high: u32,
            low: u32,
        },
    },
};

pub fn __aeabi_lmul(a: i64, b: i64) callconv(.C) i64 {
    return @call(.{ .modifier = .always_inline }, __muldi3, .{ a, b });
}

pub fn __muldsi3(a: u32, b: u32) i64 {
    @setRuntimeSafety(is_test);

    const bits_in_word_2 = @sizeOf(i32) * 8 / 2;
    const lower_mask = (~@as(u32, 0)) >> bits_in_word_2;

    var r: dwords = undefined;
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

pub fn __muldi3(a: i64, b: i64) callconv(.C) i64 {
    @setRuntimeSafety(is_test);

    const x = dwords{ .all = a };
    const y = dwords{ .all = b };
    var r = dwords{ .all = __muldsi3(x.s.low, y.s.low) };
    r.s.high +%= x.s.high *% y.s.low +% x.s.low *% y.s.high;
    return r.all;
}

test {
    _ = @import("muldi3_test.zig");
}
