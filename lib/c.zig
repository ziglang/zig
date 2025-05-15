//! This is Zig's multi-target implementation of libc.
//!
//! When `builtin.link_libc` is true, we need to export all the functions and
//! provide a libc API compatible with the target (e.g. musl, wasi-libc, ...).

const builtin = @import("builtin");
const std = @import("std");

// Avoid dragging in the runtime safety mechanisms into this .o file, unless
// we're trying to test zigc.
pub const panic = if (builtin.is_test)
    std.debug.FullPanic(std.debug.defaultPanic)
else
    std.debug.no_panic;

comptime {
    if (builtin.target.isMuslLibC() or builtin.target.isWasiLibC()) {
        // Files specific to musl and wasi-libc.
        _ = @import("c/string.zig");
        _ = @import("c/strings.zig");
    }

    if (builtin.target.isMuslLibC()) {
        // Files specific to musl.
    }

    if (builtin.target.isWasiLibC()) {
        // Files specific to wasi-libc.
    }

    if (builtin.target.isMinGW()) {
        // Files specific to MinGW-w64.
    }
}
