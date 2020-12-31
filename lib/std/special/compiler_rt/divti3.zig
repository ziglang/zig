// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const udivmod = @import("udivmod.zig").udivmod;
const builtin = @import("builtin");

pub fn __divti3(a: i128, b: i128) callconv(.C) i128 {
    @setRuntimeSafety(builtin.is_test);

    const s_a = a >> (128 - 1);
    const s_b = b >> (128 - 1);

    const an = (a ^ s_a) -% s_a;
    const bn = (b ^ s_b) -% s_b;

    const r = udivmod(u128, @bitCast(u128, an), @bitCast(u128, bn), null);
    const s = s_a ^ s_b;
    return (@bitCast(i128, r) ^ s) -% s;
}

const v128 = @import("std").meta.Vector(2, u64);
pub fn __divti3_windows_x86_64(a: v128, b: v128) callconv(.C) v128 {
    return @bitCast(v128, @call(.{ .modifier = .always_inline }, __divti3, .{
        @bitCast(i128, a),
        @bitCast(i128, b),
    }));
}

test "import divti3" {
    _ = @import("divti3_test.zig");
}
