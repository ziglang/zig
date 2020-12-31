// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const udivmodti4 = @import("udivmodti4.zig");
const builtin = @import("builtin");
const compiler_rt = @import("../compiler_rt.zig");

pub fn __umodti3(a: u128, b: u128) callconv(.C) u128 {
    @setRuntimeSafety(builtin.is_test);
    var r: u128 = undefined;
    _ = udivmodti4.__udivmodti4(a, b, &r);
    return r;
}

const v128 = @import("std").meta.Vector(2, u64);
pub fn __umodti3_windows_x86_64(a: v128, b: v128) callconv(.C) v128 {
    return @bitCast(v128, @call(.{ .modifier = .always_inline }, __umodti3, .{
        @bitCast(u128, a),
        @bitCast(u128, b),
    }));
}
