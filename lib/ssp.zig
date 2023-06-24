//!
//! Small Zig reimplementation of gcc's libssp.
//!
//! This library implements most of the builtins required by the stack smashing
//! protection as implemented by gcc&clang.
//! Missing exports:
//! - __gets_chk
//! - __mempcpy_chk
//! - __snprintf_chk
//! - __sprintf_chk
//! - __stpcpy_chk
//! - __vsnprintf_chk
//! - __vsprintf_chk

const std = @import("std");

extern fn strncpy(dest: [*:0]u8, src: [*:0]const u8, n: usize) callconv(.C) [*:0]u8;
extern fn memset(dest: ?[*]u8, c: u8, n: usize) callconv(.C) ?[*]u8;
extern fn memcpy(noalias dest: ?[*]u8, noalias src: ?[*]const u8, n: usize) callconv(.C) ?[*]u8;
extern fn memmove(dest: ?[*]u8, src: ?[*]const u8, n: usize) callconv(.C) ?[*]u8;

// Avoid dragging in the runtime safety mechanisms into this .o file.
pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = msg;
    _ = error_return_trace;
    @setCold(true);
    std.os.abort();
}

export fn __stack_chk_fail() callconv(.C) noreturn {
    @panic("stack smashing detected");
}

export fn __chk_fail() callconv(.C) noreturn {
    @panic("buffer overflow detected");
}

// Emitted when targeting some architectures (eg. x86)
// XXX: This symbol should be hidden
export fn __stack_chk_fail_local() callconv(.C) noreturn {
    __stack_chk_fail();
}

// XXX: Initialize the canary with random data
export var __stack_chk_guard: usize = blk: {
    var buf = [1]u8{0} ** @sizeOf(usize);
    buf[@sizeOf(usize) - 1] = 255;
    buf[@sizeOf(usize) - 2] = '\n';
    break :blk @as(usize, @bitCast(buf));
};

export fn __strcpy_chk(dest: [*:0]u8, src: [*:0]const u8, dest_n: usize) callconv(.C) [*:0]u8 {
    @setRuntimeSafety(false);

    var i: usize = 0;
    while (i < dest_n and src[i] != 0) : (i += 1) {
        dest[i] = src[i];
    }

    if (i == dest_n) __chk_fail();

    dest[i] = 0;

    return dest;
}

export fn __strncpy_chk(dest: [*:0]u8, src: [*:0]const u8, n: usize, dest_n: usize) callconv(.C) [*:0]u8 {
    if (dest_n < n) __chk_fail();
    return strncpy(dest, src, n);
}

export fn __strcat_chk(dest: [*:0]u8, src: [*:0]const u8, dest_n: usize) callconv(.C) [*:0]u8 {
    @setRuntimeSafety(false);

    var avail = dest_n;

    var dest_end: usize = 0;
    while (avail > 0 and dest[dest_end] != 0) : (dest_end += 1) {
        avail -= 1;
    }

    if (avail < 1) __chk_fail();

    var i: usize = 0;
    while (avail > 0 and src[i] != 0) : (i += 1) {
        dest[dest_end + i] = src[i];
        avail -= 1;
    }

    if (avail < 1) __chk_fail();

    dest[dest_end + i] = 0;

    return dest;
}

export fn __strncat_chk(dest: [*:0]u8, src: [*:0]const u8, n: usize, dest_n: usize) callconv(.C) [*:0]u8 {
    @setRuntimeSafety(false);

    var avail = dest_n;

    var dest_end: usize = 0;
    while (avail > 0 and dest[dest_end] != 0) : (dest_end += 1) {
        avail -= 1;
    }

    if (avail < 1) __chk_fail();

    var i: usize = 0;
    while (avail > 0 and i < n and src[i] != 0) : (i += 1) {
        dest[dest_end + i] = src[i];
        avail -= 1;
    }

    if (avail < 1) __chk_fail();

    dest[dest_end + i] = 0;

    return dest;
}

export fn __memcpy_chk(noalias dest: ?[*]u8, noalias src: ?[*]const u8, n: usize, dest_n: usize) callconv(.C) ?[*]u8 {
    if (dest_n < n) __chk_fail();
    return memcpy(dest, src, n);
}

export fn __memmove_chk(dest: ?[*]u8, src: ?[*]const u8, n: usize, dest_n: usize) callconv(.C) ?[*]u8 {
    if (dest_n < n) __chk_fail();
    return memmove(dest, src, n);
}

export fn __memset_chk(dest: ?[*]u8, c: u8, n: usize, dest_n: usize) callconv(.C) ?[*]u8 {
    if (dest_n < n) __chk_fail();
    return memset(dest, c, n);
}
