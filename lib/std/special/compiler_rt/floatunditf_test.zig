// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const __floatunditf = @import("floatunditf.zig").__floatunditf;

fn test__floatunditf(a: u64, expected_hi: u64, expected_lo: u64) void {
    const x = __floatunditf(a);

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

    @panic("__floatunditf test failure");
}

test "floatunditf" {
    test__floatunditf(0xffffffffffffffff, 0x403effffffffffff, 0xfffe000000000000);
    test__floatunditf(0xfffffffffffffffe, 0x403effffffffffff, 0xfffc000000000000);
    test__floatunditf(0x8000000000000000, 0x403e000000000000, 0x0);
    test__floatunditf(0x7fffffffffffffff, 0x403dffffffffffff, 0xfffc000000000000);
    test__floatunditf(0x123456789abcdef1, 0x403b23456789abcd, 0xef10000000000000);
    test__floatunditf(0x2, 0x4000000000000000, 0x0);
    test__floatunditf(0x1, 0x3fff000000000000, 0x0);
    test__floatunditf(0x0, 0x0, 0x0);
}
