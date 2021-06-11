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

fn testRemoveDotDirs(str: []const u8, expected: []const u8) !void {
    const mutable = try testing.allocator.dupe(u8, str);
    defer testing.allocator.free(mutable);
    const actual = mutable[0..try windows.removeDotDirsSanitized(u8, mutable)];
    try testing.expect(mem.eql(u8, actual, expected));
}
fn testRemoveDotDirsError(err: anyerror, str: []const u8) !void {
    const mutable = try testing.allocator.dupe(u8, str);
    defer testing.allocator.free(mutable);
    try testing.expectError(err, windows.removeDotDirsSanitized(u8, mutable));
}
test "removeDotDirs" {
    try testRemoveDotDirs("", "");
    try testRemoveDotDirs(".", "");
    try testRemoveDotDirs(".\\", "");
    try testRemoveDotDirs(".\\.", "");
    try testRemoveDotDirs(".\\.\\", "");
    try testRemoveDotDirs(".\\.\\.", "");

    try testRemoveDotDirs("a", "a");
    try testRemoveDotDirs("a\\", "a\\");
    try testRemoveDotDirs("a\\b", "a\\b");
    try testRemoveDotDirs("a\\.", "a\\");
    try testRemoveDotDirs("a\\b\\.", "a\\b\\");
    try testRemoveDotDirs("a\\.\\b", "a\\b");

    try testRemoveDotDirs(".a", ".a");
    try testRemoveDotDirs(".a\\", ".a\\");
    try testRemoveDotDirs(".a\\.b", ".a\\.b");
    try testRemoveDotDirs(".a\\.", ".a\\");
    try testRemoveDotDirs(".a\\.\\.", ".a\\");
    try testRemoveDotDirs(".a\\.\\.\\.b", ".a\\.b");
    try testRemoveDotDirs(".a\\.\\.\\.b\\", ".a\\.b\\");

    try testRemoveDotDirsError(error.TooManyParentDirs, "..");
    try testRemoveDotDirsError(error.TooManyParentDirs, "..\\");
    try testRemoveDotDirsError(error.TooManyParentDirs, ".\\..\\");
    try testRemoveDotDirsError(error.TooManyParentDirs, ".\\.\\..\\");

    try testRemoveDotDirs("a\\..", "");
    try testRemoveDotDirs("a\\..\\", "");
    try testRemoveDotDirs("a\\..\\.", "");
    try testRemoveDotDirs("a\\..\\.\\", "");
    try testRemoveDotDirs("a\\..\\.\\.", "");
    try testRemoveDotDirsError(error.TooManyParentDirs, "a\\..\\.\\.\\..");

    try testRemoveDotDirs("a\\..\\.\\.\\b", "b");
    try testRemoveDotDirs("a\\..\\.\\.\\b\\", "b\\");
    try testRemoveDotDirs("a\\..\\.\\.\\b\\.", "b\\");
    try testRemoveDotDirs("a\\..\\.\\.\\b\\.\\", "b\\");
    try testRemoveDotDirs("a\\..\\.\\.\\b\\.\\..", "");
    try testRemoveDotDirs("a\\..\\.\\.\\b\\.\\..\\", "");
    try testRemoveDotDirs("a\\..\\.\\.\\b\\.\\..\\.", "");
    try testRemoveDotDirsError(error.TooManyParentDirs, "a\\..\\.\\.\\b\\.\\..\\.\\..");

    try testRemoveDotDirs("a\\b\\..\\", "a\\");
    try testRemoveDotDirs("a\\b\\..\\c", "a\\c");
}
