//! This is Zig's multi-target implementation of libc.
//! When builtin.link_libc is true, we need to export all the functions and
//! provide an entire C API.

const std = @import("std");
const builtin = @import("builtin");
const math = std.math;
const isNan = std.math.isNan;
const maxInt = std.math.maxInt;
const native_os = builtin.os.tag;
const native_arch = builtin.cpu.arch;
const native_abi = builtin.abi;

const is_wasm = switch (native_arch) {
    .wasm32, .wasm64 => true,
    else => false,
};
const is_msvc = switch (native_abi) {
    .msvc => true,
    else => false,
};
const is_freestanding = switch (native_os) {
    .freestanding => true,
    else => false,
};

comptime {
    if (is_freestanding and is_wasm and builtin.link_libc) {
        @export(&wasm_start, .{ .name = "_start", .linkage = .strong });
    }

    if (builtin.link_libc) {
        @export(&strcmp, .{ .name = "strcmp", .linkage = .strong });
        @export(&strncmp, .{ .name = "strncmp", .linkage = .strong });
        @export(&strerror, .{ .name = "strerror", .linkage = .strong });
        @export(&strlen, .{ .name = "strlen", .linkage = .strong });
        @export(&strcpy, .{ .name = "strcpy", .linkage = .strong });
        @export(&strncpy, .{ .name = "strncpy", .linkage = .strong });
        @export(&strcat, .{ .name = "strcat", .linkage = .strong });
        @export(&strncat, .{ .name = "strncat", .linkage = .strong });
    } else if (is_msvc) {
        @export(&_fltused, .{ .name = "_fltused", .linkage = .strong });
    }
}

// Avoid dragging in the runtime safety mechanisms into this .o file,
// unless we're trying to test this file.
pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    @branchHint(.cold);
    _ = error_return_trace;
    if (builtin.is_test) {
        std.debug.panic("{s}", .{msg});
    }
    switch (native_os) {
        .freestanding, .other, .amdhsa, .amdpal => while (true) {},
        else => std.os.abort(),
    }
}

extern fn main(argc: c_int, argv: [*:null]?[*:0]u8) c_int;
fn wasm_start() callconv(.C) void {
    _ = main(0, undefined);
}

var _fltused: c_int = 1;

fn strcpy(dest: [*:0]u8, src: [*:0]const u8) callconv(.C) [*:0]u8 {
    var i: usize = 0;
    while (src[i] != 0) : (i += 1) {
        dest[i] = src[i];
    }
    dest[i] = 0;

    return dest;
}

test "strcpy" {
    var s1: [9:0]u8 = undefined;

    s1[0] = 0;
    _ = strcpy(&s1, "foobarbaz");
    try std.testing.expectEqualSlices(u8, "foobarbaz", std.mem.sliceTo(&s1, 0));
}

fn strncpy(dest: [*:0]u8, src: [*:0]const u8, n: usize) callconv(.C) [*:0]u8 {
    var i: usize = 0;
    while (i < n and src[i] != 0) : (i += 1) {
        dest[i] = src[i];
    }
    while (i < n) : (i += 1) {
        dest[i] = 0;
    }

    return dest;
}

test "strncpy" {
    var s1: [9:0]u8 = undefined;

    s1[0] = 0;
    _ = strncpy(&s1, "foobarbaz", @sizeOf(@TypeOf(s1)));
    try std.testing.expectEqualSlices(u8, "foobarbaz", std.mem.sliceTo(&s1, 0));
}

fn strcat(dest: [*:0]u8, src: [*:0]const u8) callconv(.C) [*:0]u8 {
    var dest_end: usize = 0;
    while (dest[dest_end] != 0) : (dest_end += 1) {}

    var i: usize = 0;
    while (src[i] != 0) : (i += 1) {
        dest[dest_end + i] = src[i];
    }
    dest[dest_end + i] = 0;

    return dest;
}

test "strcat" {
    var s1: [9:0]u8 = undefined;

    s1[0] = 0;
    _ = strcat(&s1, "foo");
    _ = strcat(&s1, "bar");
    _ = strcat(&s1, "baz");
    try std.testing.expectEqualSlices(u8, "foobarbaz", std.mem.sliceTo(&s1, 0));
}

fn strncat(dest: [*:0]u8, src: [*:0]const u8, avail: usize) callconv(.C) [*:0]u8 {
    var dest_end: usize = 0;
    while (dest[dest_end] != 0) : (dest_end += 1) {}

    var i: usize = 0;
    while (i < avail and src[i] != 0) : (i += 1) {
        dest[dest_end + i] = src[i];
    }
    dest[dest_end + i] = 0;

    return dest;
}

test "strncat" {
    var s1: [9:0]u8 = undefined;

    s1[0] = 0;
    _ = strncat(&s1, "foo1111", 3);
    _ = strncat(&s1, "bar1111", 3);
    _ = strncat(&s1, "baz1111", 3);
    try std.testing.expectEqualSlices(u8, "foobarbaz", std.mem.sliceTo(&s1, 0));
}

fn strcmp(s1: [*:0]const u8, s2: [*:0]const u8) callconv(.C) c_int {
    return switch (std.mem.orderZ(u8, s1, s2)) {
        .lt => -1,
        .eq => 0,
        .gt => 1,
    };
}

fn strlen(s: [*:0]const u8) callconv(.C) usize {
    return std.mem.len(s);
}

fn strncmp(_l: [*:0]const u8, _r: [*:0]const u8, _n: usize) callconv(.C) c_int {
    if (_n == 0) return 0;
    var l = _l;
    var r = _r;
    var n = _n - 1;
    while (l[0] != 0 and r[0] != 0 and n != 0 and l[0] == r[0]) {
        l += 1;
        r += 1;
        n -= 1;
    }
    return @as(c_int, l[0]) - @as(c_int, r[0]);
}

fn strerror(errnum: c_int) callconv(.C) [*:0]const u8 {
    _ = errnum;
    return "TODO strerror implementation";
}

test "strncmp" {
    try std.testing.expect(strncmp("a", "b", 1) < 0);
    try std.testing.expect(strncmp("a", "c", 1) < 0);
    try std.testing.expect(strncmp("b", "a", 1) > 0);
    try std.testing.expect(strncmp("\xff", "\x02", 1) > 0);
}
