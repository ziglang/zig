const std = @import("std");
const common = @import("common.zig");
const builtin = @import("builtin");
const intmax_t = std.c.intmax_t;

comptime {
    if (builtin.target.isMuslLibC() or builtin.target.isWasiLibC()) {
        // Functions specific to musl and wasi-libc.
        @export(&imaxabs, .{ .name = "imaxabs", .linkage = common.linkage, .visibility = common.visibility });
    }

    if (builtin.target.isMuslLibC()) {
        // Functions specific to musl.
    }

    if (builtin.target.isWasiLibC()) {
        // Functions specific to wasi-libc.
    }

    if (builtin.target.isMinGW()) {
        // Functions specific to MinGW-w64.
    }
}

fn imaxabs(a: intmax_t) callconv(.c) intmax_t {
    return if (a > 0) a else -a;
}
