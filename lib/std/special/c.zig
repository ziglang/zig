//! This is Zig's multi-target implementation of libc.
//! When builtin.link_libc is true, we need to export all the functions and
//! provide an entire C API.
//! Otherwise, only the functions which LLVM generates calls to need to be generated,
//! such as memcpy, memset, and some math functions.

const std = @import("std");
const builtin = @import("builtin");
const native_os = builtin.os.tag;

comptime {
    // When the self-hosted compiler is further along, all the logic from c_stage1.zig will
    // be migrated to this file and then c_stage1.zig will be deleted. Until then we have a
    // simpler implementation of c.zig that only uses features already implemented in self-hosted.
    if (builtin.zig_is_stage2) {
        @export(memset, .{ .name = "memset", .linkage = .Strong });
        @export(memcpy, .{ .name = "memcpy", .linkage = .Strong });
    } else {
        _ = @import("c_stage1.zig");
    }
}

// Avoid dragging in the runtime safety mechanisms into this .o file,
// unless we're trying to test this file.
pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace) noreturn {
    @setCold(true);
    _ = error_return_trace;
    if (builtin.zig_is_stage2) {
        while (true) {
            @breakpoint();
        }
    }
    if (builtin.is_test) {
        std.debug.panic("{s}", .{msg});
    }
    if (native_os != .freestanding and native_os != .other) {
        std.os.abort();
    }
    while (true) {}
}

fn memset(dest: ?[*]u8, c: u8, len: usize) callconv(.C) ?[*]u8 {
    @setRuntimeSafety(false);

    if (len != 0) {
        var d = dest.?;
        var n = len;
        while (true) {
            d.* = c;
            n -= 1;
            if (n == 0) break;
            d += 1;
        }
    }

    return dest;
}

fn memcpy(noalias dest: ?[*]u8, noalias src: ?[*]const u8, len: usize) callconv(.C) ?[*]u8 {
    @setRuntimeSafety(false);

    if (len != 0) {
        var d = dest.?;
        var s = src.?;
        var n = len;
        while (true) {
            d.* = s.*;
            n -= 1;
            if (n == 0) break;
            d += 1;
            s += 1;
        }
    }

    return dest;
}
