//! []Three -> []Two (big to small, does not divide)

const Two = [2]u8;
const Three = [3]u8;

/// A runtime-known value to prevent these safety panics from being compile errors.
var rt: u8 = 0;

pub fn main() void {
    const in: []const Three = &.{.{ 0, 0, rt }};
    const out: []const Two = @ptrCast(in);
    _ = out;
    std.process.exit(1);
}

pub fn panic(message: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    if (std.mem.eql(u8, message, "slice length '1' does not divide exactly into destination elements")) {
        std.process.exit(0);
    }
    std.process.exit(1);
}

const std = @import("std");

// run
// backend=stage2,llvm
// target=x86_64-linux
