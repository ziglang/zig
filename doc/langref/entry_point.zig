/// `std.start` imports this file using `@import("root")`, and uses this declaration as the program's
/// user-provided entry point. It can return any of the following types:
/// * `void`
/// * `E!void`, for any error set `E`
/// * `u8`
/// * `E!u8`, for any error set `E`
/// Returning a `void` value from this function will exit with code 0.
/// Returning a `u8` value from this function will exit with the given status code.
/// Returning an error value from this function will print an Error Return Trace and exit with code 1.
pub fn main() void {
    std.debug.print("Hello, World!\n", .{});
}

// If uncommented, this declaration would suppress the usual std.start logic, causing
// the `main` declaration above to be ignored.
//pub const _start = {};

const std = @import("std");

// exe=succeed
