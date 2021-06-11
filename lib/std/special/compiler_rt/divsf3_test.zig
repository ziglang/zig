// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
// Ported from:
//
// https://github.com/llvm/llvm-project/commit/d674d96bc56c0f377879d01c9d8dfdaaa7859cdb/compiler-rt/test/builtins/Unit/divsf3_test.c

const __divsf3 = @import("divsf3.zig").__divsf3;
const testing = @import("std").testing;

fn compareResultF(result: f32, expected: u32) bool {
    const rep = @bitCast(u32, result);

    if (rep == expected) {
        return true;
    }
    // test other possible NaN representation(signal NaN)
    else if (expected == 0x7fc00000) {
        if ((rep & 0x7f800000) == 0x7f800000 and
            (rep & 0x7fffff) > 0)
        {
            return true;
        }
    }
    return false;
}

fn test__divsf3(a: f32, b: f32, expected: u32) !void {
    const x = __divsf3(a, b);
    const ret = compareResultF(x, expected);
    try testing.expect(ret == true);
}

test "divsf3" {
    try test__divsf3(1.0, 3.0, 0x3EAAAAAB);
    try test__divsf3(2.3509887e-38, 2.0, 0x00800000);
}
