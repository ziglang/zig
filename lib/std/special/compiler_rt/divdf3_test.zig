// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
// Ported from:
//
// https://github.com/llvm/llvm-project/commit/d674d96bc56c0f377879d01c9d8dfdaaa7859cdb/compiler-rt/test/builtins/Unit/divdf3_test.c

const __divdf3 = @import("divdf3.zig").__divdf3;
const testing = @import("std").testing;

fn compareResultD(result: f64, expected: u64) bool {
    const rep = @bitCast(u64, result);

    if (rep == expected) {
        return true;
    }
    // test other possible NaN representation(signal NaN)
    else if (expected == 0x7ff8000000000000) {
        if ((rep & 0x7ff0000000000000) == 0x7ff0000000000000 and
            (rep & 0xfffffffffffff) > 0)
        {
            return true;
        }
    }
    return false;
}

fn test__divdf3(a: f64, b: f64, expected: u64) void {
    const x = __divdf3(a, b);
    const ret = compareResultD(x, expected);
    testing.expect(ret == true);
}

test "divdf3" {
    test__divdf3(1.0, 3.0, 0x3fd5555555555555);
    test__divdf3(4.450147717014403e-308, 2.0, 0x10000000000000);
}
