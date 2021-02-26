// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const builtin = @import("builtin");
const compiler_rt = @import("../compiler_rt.zig");

// ported from llvm compiler-rt 8.0.0rc3 95e1c294cb0415a377a7b1d6c7c7d4f89e1c04e4
pub fn __popcountdi2(a: i64) callconv(.C) i32 {
    var x2 = @bitCast(u64, a);
    x2 = x2 - ((x2 >> 1) & 0x5555555555555555);
    // Every 2 bits holds the sum of every pair of bits (32)
    x2 = ((x2 >> 2) & 0x3333333333333333) + (x2 & 0x3333333333333333);
    // Every 4 bits holds the sum of every 4-set of bits (3 significant bits) (16)
    x2 = (x2 + (x2 >> 4)) & 0x0F0F0F0F0F0F0F0F;
    // Every 8 bits holds the sum of every 8-set of bits (4 significant bits) (8)
    var x: u32 = @truncate(u32, x2 + (x2 >> 32));
    // The lower 32 bits hold four 16 bit sums (5 significant bits).
    //   Upper 32 bits are garbage */
    x = x + (x >> 16);
    // The lower 16 bits hold two 32 bit sums (6 significant bits).
    //   Upper 16 bits are garbage */
    return @bitCast(i32, (x + (x >> 8)) & 0x0000007F); // (7 significant bits)
}

test "import popcountdi2" {
    _ = @import("popcountdi2_test.zig");
}
