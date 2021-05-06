// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const __popcountdi2 = @import("popcountdi2.zig").__popcountdi2;
const testing = @import("std").testing;

fn naive_popcount(a_param: i64) i32 {
    var a = a_param;
    var r: i32 = 0;
    while (a != 0) : (a = @bitCast(i64, @bitCast(u64, a) >> 1)) {
        r += @intCast(i32, a & 1);
    }
    return r;
}

fn test__popcountdi2(a: i64) !void {
    const x = __popcountdi2(a);
    const expected = naive_popcount(a);
    try testing.expect(expected == x);
}

test "popcountdi2" {
    try test__popcountdi2(0);
    try test__popcountdi2(1);
    try test__popcountdi2(2);
    try test__popcountdi2(@bitCast(i64, @as(u64, 0xFFFFFFFFFFFFFFFD)));
    try test__popcountdi2(@bitCast(i64, @as(u64, 0xFFFFFFFFFFFFFFFE)));
    try test__popcountdi2(@bitCast(i64, @as(u64, 0xFFFFFFFFFFFFFFFF)));
    // TODO some fuzz testing
}
