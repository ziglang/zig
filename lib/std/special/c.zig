//! This is Zig's multi-target implementation of libc.
//! When builtin.link_libc is true, we need to export all the functions and
//! provide an entire C API.
//! Otherwise, only the functions which LLVM generates calls to need to be generated,
//! such as memcpy, memset, and some math functions.

const std = @import("std");
const builtin = @import("builtin");
const math = std.math;
const native_os = builtin.os.tag;
const long_double_is_f128 = builtin.target.longDoubleIsF128();

comptime {
    // When the self-hosted compiler is further along, all the logic from c_stage1.zig will
    // be migrated to this file and then c_stage1.zig will be deleted. Until then we have a
    // simpler implementation of c.zig that only uses features already implemented in self-hosted.
    if (builtin.zig_backend == .stage1) {
        _ = @import("c_stage1.zig");
    }

    @export(memset, .{ .name = "memset", .linkage = .Strong });
    @export(__memset, .{ .name = "__memset", .linkage = .Strong });
    @export(memcpy, .{ .name = "memcpy", .linkage = .Strong });

    @export(trunc, .{ .name = "trunc", .linkage = .Strong });
    @export(truncf, .{ .name = "truncf", .linkage = .Strong });
    @export(truncl, .{ .name = "truncl", .linkage = .Strong });

    @export(log, .{ .name = "log", .linkage = .Strong });
    @export(logf, .{ .name = "logf", .linkage = .Strong });

    @export(sin, .{ .name = "sin", .linkage = .Strong });
    @export(sinf, .{ .name = "sinf", .linkage = .Strong });

    @export(cos, .{ .name = "cos", .linkage = .Strong });
    @export(cosf, .{ .name = "cosf", .linkage = .Strong });

    @export(exp, .{ .name = "exp", .linkage = .Strong });
    @export(expf, .{ .name = "expf", .linkage = .Strong });

    @export(exp2, .{ .name = "exp2", .linkage = .Strong });
    @export(exp2f, .{ .name = "exp2f", .linkage = .Strong });

    @export(log2, .{ .name = "log2", .linkage = .Strong });
    @export(log2f, .{ .name = "log2f", .linkage = .Strong });

    @export(log10, .{ .name = "log10", .linkage = .Strong });
    @export(log10f, .{ .name = "log10f", .linkage = .Strong });

    @export(ceil, .{ .name = "ceil", .linkage = .Strong });
    @export(ceilf, .{ .name = "ceilf", .linkage = .Strong });
    @export(ceill, .{ .name = "ceill", .linkage = .Strong });
}

// Avoid dragging in the runtime safety mechanisms into this .o file,
// unless we're trying to test this file.
pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace) noreturn {
    @setCold(true);
    _ = error_return_trace;
    if (builtin.zig_backend != .stage1) {
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

fn __memset(dest: ?[*]u8, c: u8, n: usize, dest_n: usize) callconv(.C) ?[*]u8 {
    if (dest_n < n)
        @panic("buffer overflow");
    return memset(dest, c, n);
}

fn memcpy(noalias dest: ?[*]u8, noalias src: ?[*]const u8, len: usize) callconv(.C) ?[*]u8 {
    @setRuntimeSafety(false);

    if (len != 0) {
        var d = dest.?;
        var s = src.?;
        var n = len;
        while (true) {
            d[0] = s[0];
            n -= 1;
            if (n == 0) break;
            d += 1;
            s += 1;
        }
    }

    return dest;
}

fn trunc(a: f64) callconv(.C) f64 {
    return math.trunc(a);
}

fn truncf(a: f32) callconv(.C) f32 {
    return math.trunc(a);
}

fn truncl(a: c_longdouble) callconv(.C) c_longdouble {
    if (!long_double_is_f128) {
        @panic("TODO implement this");
    }
    return math.trunc(a);
}

fn log(a: f64) callconv(.C) f64 {
    return math.ln(a);
}

fn logf(a: f32) callconv(.C) f32 {
    return math.ln(a);
}

fn sin(a: f64) callconv(.C) f64 {
    return math.sin(a);
}

fn sinf(a: f32) callconv(.C) f32 {
    return math.sin(a);
}

fn cos(a: f64) callconv(.C) f64 {
    return math.cos(a);
}

fn cosf(a: f32) callconv(.C) f32 {
    return math.cos(a);
}

fn exp(a: f64) callconv(.C) f64 {
    return math.exp(a);
}

fn expf(a: f32) callconv(.C) f32 {
    return math.exp(a);
}

fn exp2(a: f64) callconv(.C) f64 {
    return math.exp2(a);
}

fn exp2f(a: f32) callconv(.C) f32 {
    return math.exp2(a);
}

fn log2(a: f64) callconv(.C) f64 {
    return math.log2(a);
}

fn log2f(a: f32) callconv(.C) f32 {
    return math.log2(a);
}

fn log10(a: f64) callconv(.C) f64 {
    return math.log10(a);
}

fn log10f(a: f32) callconv(.C) f32 {
    return math.log10(a);
}

fn ceilf(x: f32) callconv(.C) f32 {
    return math.ceil(x);
}

fn ceil(x: f64) callconv(.C) f64 {
    return math.ceil(x);
}

fn ceill(x: c_longdouble) callconv(.C) c_longdouble {
    if (!long_double_is_f128) {
        @panic("TODO implement this");
    }
    return math.ceil(x);
}
