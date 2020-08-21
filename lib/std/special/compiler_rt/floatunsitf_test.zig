// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const __floatunsitf = @import("floatunsitf.zig").__floatunsitf;

fn test__floatunsitf(a: u64, expected_hi: u64, expected_lo: u64) void {
    const x = __floatunsitf(a);

    const x_repr = @bitCast(u128, x);
    const x_hi = @intCast(u64, x_repr >> 64);
    const x_lo = @truncate(u64, x_repr);

    if (x_hi == expected_hi and x_lo == expected_lo) {
        return;
    }
    // nan repr
    else if (expected_hi == 0x7fff800000000000 and expected_lo == 0x0) {
        if ((x_hi & 0x7fff000000000000) == 0x7fff000000000000 and ((x_hi & 0xffffffffffff) > 0 or x_lo > 0)) {
            return;
        }
    }

    @panic("__floatunsitf test failure");
}

test "floatunsitf" {
    test__floatunsitf(0x7fffffff, 0x401dfffffffc0000, 0x0);
    test__floatunsitf(0, 0x0, 0x0);
    test__floatunsitf(0xffffffff, 0x401efffffffe0000, 0x0);
    test__floatunsitf(0x12345678, 0x401b234567800000, 0x0);
}
