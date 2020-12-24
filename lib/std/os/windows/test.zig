// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../../std.zig");
const builtin = @import("builtin");
const windows = std.os.windows;
const mem = std.mem;
const testing = std.testing;
const expect = testing.expect;

fn testNtPath(input: []const u8, expected: []const u8) !void {
    const input_w = try std.unicode.utf8ToUtf16LeWithNull(testing.allocator, input);
    defer testing.allocator.free(input_w);
    const expected_w = try std.unicode.utf8ToUtf16LeWithNull(testing.allocator, expected);
    defer testing.allocator.free(expected_w);

    const nt_path = try windows.NtPath.init(input_w);
    defer nt_path.deinit();
    const relative_path = try windows.toRelativeNtPath(nt_path.str);
    expect(mem.eql(u16, windows.unicodeSpan(relative_path), expected_w));
}

test "NtPath" {
    try testNtPath("a", "a");
    try testNtPath("a\\b", "a\\b");
    try testNtPath("a\\.\\b", "a\\b");
    try testNtPath("a\\..\\b", "b");
}
