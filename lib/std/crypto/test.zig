// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../std.zig");
const testing = std.testing;
const fmt = std.fmt;

// Hash using the specified hasher `H` asserting `expected == H(input)`.
pub fn assertEqualHash(comptime Hasher: anytype, comptime expected_hex: *const [Hasher.digest_length * 2:0]u8, input: []const u8) void {
    var h: [Hasher.digest_length]u8 = undefined;
    Hasher.hash(input, &h, .{});

    assertEqual(expected_hex, &h);
}

// Assert `expected` == hex(`input`) where `input` is a bytestring
pub fn assertEqual(comptime expected_hex: [:0]const u8, input: []const u8) void {
    var expected_bytes: [expected_hex.len / 2]u8 = undefined;
    for (expected_bytes) |*r, i| {
        r.* = fmt.parseInt(u8, expected_hex[2 * i .. 2 * i + 2], 16) catch unreachable;
    }

    testing.expectEqualSlices(u8, &expected_bytes, input);
}
