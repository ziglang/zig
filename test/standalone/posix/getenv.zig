// test getting environment variables

const std = @import("std");
const builtin = @import("builtin");

pub fn main() !void {
    if (builtin.target.os.tag == .windows) {
        return; // Windows env strings are WTF-16, so not supported by Zig's std.posix.getenv()
    }

    if (builtin.target.os.tag == .wasi and !builtin.link_libc) {
        return; // std.posix.getenv is not supported on WASI due to the need of allocation
    }

    // Test some unset env vars:

    try std.testing.expectEqual(std.posix.getenv(""), null);
    try std.testing.expectEqual(std.posix.getenv("BOGUSDOESNOTEXISTENVVAR"), null);
    try std.testing.expectEqual(std.posix.getenvZ("BOGUSDOESNOTEXISTENVVAR"), null);

    if (builtin.link_libc) {
        // Test if USER matches what C library sees
        const expected = std.mem.span(std.c.getenv("USER") orelse "");
        const actual = std.posix.getenv("USER") orelse "";
        try std.testing.expectEqualStrings(expected, actual);
    }

    // env vars set by our build.zig run step:
    try std.testing.expectEqualStrings("", std.posix.getenv("ZIG_TEST_POSIX_EMPTY") orelse "invalid");
    try std.testing.expectEqualStrings("test=variable", std.posix.getenv("ZIG_TEST_POSIX_1EQ") orelse "invalid");
    try std.testing.expectEqualStrings("=test=variable=", std.posix.getenv("ZIG_TEST_POSIX_3EQ") orelse "invalid");
}
