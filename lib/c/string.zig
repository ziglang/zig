const builtin = @import("builtin");
const std = @import("std");
const common = @import("common.zig");

comptime {
    @export(&strcmp, .{ .name = "strcmp", .linkage = common.linkage, .visibility = common.visibility });
    @export(&strlen, .{ .name = "strlen", .linkage = common.linkage, .visibility = common.visibility });
    @export(&strncmp, .{ .name = "strncmp", .linkage = common.linkage, .visibility = common.visibility });
    @export(&index, .{ .name = "index", .linkage = common.linkage, .visibility = common.visibility });
    @export(&strchr, .{ .name = "strchr", .linkage = common.linkage, .visibility = common.visibility });
    @export(&rindex, .{ .name = "rindex", .linkage = common.linkage, .visibility = common.visibility });
    @export(&memset, .{ .name = "memset", .linkage = common.linkage, .visibility = common.visibility });
    { // TODO: Conditional export for armeabi?
        @export(&__aeabi_memclr, .{ .name = "__aeabi_memclr8", .linkage = common.linkage, .visibility = common.visibility });
        @export(&__aeabi_memclr, .{ .name = "__aeabi_memclr4", .linkage = common.linkage, .visibility = common.visibility });
        @export(&__aeabi_memclr, .{ .name = "__aeabi_memclr", .linkage = common.linkage, .visibility = common.visibility });
        @export(&memset, .{ .name = "__aeabi_memset8", .linkage = common.linkage, .visibility = common.visibility });
        @export(&memset, .{ .name = "__aeabi_memset4", .linkage = common.linkage, .visibility = common.visibility });
        @export(&memset, .{ .name = "__aeabi_memset", .linkage = common.linkage, .visibility = common.visibility });
    }
    @export(&memchr, .{ .name = "memchr", .linkage = common.linkage, .visibility = common.visibility });
    @export(&strrchr, .{ .name = "strrchr", .linkage = common.linkage, .visibility = common.visibility });
    @export(&strchrnul, .{ .name = "__strchrnul", .linkage = .weak, .visibility = .hidden });
    @export(&strchrnul, .{ .name = "strchrnul", .linkage = .weak, .visibility = common.visibility });
    @export(&memrchr, .{ .name = "memrchr", .linkage = .weak, .visibility = common.visibility });
    @export(&memrchr, .{ .name = "__memrchr", .linkage = .weak, .visibility = .hidden });
}

fn strcmp(s1: [*:0]const c_char, s2: [*:0]const c_char) callconv(.c) c_int {
    // We need to perform unsigned comparisons.
    return switch (std.mem.orderZ(u8, @ptrCast(s1), @ptrCast(s2))) {
        .lt => -1,
        .eq => 0,
        .gt => 1,
    };
}

fn strncmp(s1: [*:0]const c_char, s2: [*:0]const c_char, n: usize) callconv(.c) c_int {
    if (n == 0) return 0;

    var l: [*:0]const u8 = @ptrCast(s1);
    var r: [*:0]const u8 = @ptrCast(s2);
    var i = n - 1;

    while (l[0] != 0 and r[0] != 0 and i != 0 and l[0] == r[0]) {
        l += 1;
        r += 1;
        i -= 1;
    }

    return @as(c_int, l[0]) - @as(c_int, r[0]);
}

test strncmp {
    try std.testing.expect(strncmp(@ptrCast("a"), @ptrCast("b"), 1) < 0);
    try std.testing.expect(strncmp(@ptrCast("a"), @ptrCast("c"), 1) < 0);
    try std.testing.expect(strncmp(@ptrCast("b"), @ptrCast("a"), 1) > 0);
    try std.testing.expect(strncmp(@ptrCast("\xff"), @ptrCast("\x02"), 1) > 0);
}

fn strlen(s: [*:0]const c_char) callconv(.c) usize {
    return std.mem.len(s);
}

fn strchrnul(s: [*:0]const c_char, c: c_int) callconv(.c) [*:0]const c_char {
    const needle: u8 = @intCast(c);
    if (needle == 0) return s + strlen(s);

    var it: [*:0]const u8 = @ptrCast(s);
    while (it[0] != 0 and it[0] != needle) : (it += 1) {}
    return @ptrCast(it);
}

test strchrnul {
    const foo: [*:0]const c_char = @ptrCast("disco");
    try std.testing.expect(strchrnul(foo, 'd') == foo);
    try std.testing.expect(strchrnul(foo, 'o') == (foo + 4));
    try std.testing.expect(strchrnul(foo, 'z') == (foo + 5));
    try std.testing.expect(strchrnul(foo, 0) == (foo + 5));
}

fn strchr(s: [*:0]const c_char, c: c_int) callconv(.c) ?[*:0]const c_char {
    const result = strchrnul(s, c);
    return if (result[0] != 0) result else null;
}

test strchr {
    const foo: [*:0]const c_char = @ptrCast("disco");
    try std.testing.expect(strchr(foo, 'd') == foo);
    try std.testing.expect(strchr(foo, 'o') == (foo + 4));
    try std.testing.expect(strchr(foo, 'z') == null);
    try std.testing.expect(strchr(foo, 0) == null);
}

fn index(s: [*:0]const c_char, c: c_int) callconv(.c) ?[*:0]const c_char {
    return strchr(s, c);
}

test index {
    const foo: [*:0]const c_char = @ptrCast("disco");
    try std.testing.expect(index(foo, 'd') == foo);
    try std.testing.expect(index(foo, 'o') == (foo + 4));
    try std.testing.expect(index(foo, 'z') == null);
    try std.testing.expect(index(foo, 0) == null);
}

fn memchr(m: *const anyopaque, c: c_int, n: usize) callconv(.c) ?*const anyopaque {
    const needle: u8 = @intCast(c);
    const s: [*:0]const u8 = @ptrCast(m);
    var idx: usize = 0;
    while (idx < n) : (idx += 1) {
        if (s[idx] == needle) return @ptrCast(s + idx);
    }
    return null;
}

test memchr {
    const foo: [*:0]const c_char = @ptrCast("disco");
    try std.testing.expect(memchr(foo, 'd', 5) == @as(*const anyopaque, @ptrCast(foo)));
    try std.testing.expect(memchr(foo, 'o', 5) == @as(*const anyopaque, @ptrCast(foo + 4)));
    try std.testing.expect(memchr(foo, 'z', 5) == null);
}

fn memrchr(m: *const anyopaque, c: c_int, n: usize) callconv(.c) ?*const anyopaque {
    const needle: u8 = @intCast(c);
    const s: [*:0]const u8 = @ptrCast(m);
    var idx: usize = n;
    while (idx > 0) {
        idx -= 1;
        if (s[idx] == needle) return @ptrCast(s + idx);
    }
    return null;
}

test memrchr {
    const foo: [*:0]const c_char = @ptrCast("disco");
    try std.testing.expect(memrchr(foo, 'd', 5) == @as(*const anyopaque, @ptrCast(foo)));
    try std.testing.expect(memrchr(foo, 'o', 5) == @as(*const anyopaque, @ptrCast(foo + 4)));
    try std.testing.expect(memrchr(foo, 'z', 5) == null);
}

fn strrchr(s: [*:0]const c_char, c: c_int) callconv(.c) ?[*:0]const c_char {
    return @ptrCast(memrchr(s, c, strlen(s) + 1));
}

test strrchr {
    const foo: [*:0]const c_char = @ptrCast("disco");
    try std.testing.expect(strrchr(foo, 'd') == foo);
    try std.testing.expect(strrchr(foo, 'o') == (foo + 4));
    try std.testing.expect(strrchr(foo, 'z') == null);
    try std.testing.expect(strrchr(foo, 0) == (foo + 5));
}

fn rindex(s: [*:0]const c_char, c: c_int) callconv(.c) ?[*:0]const c_char {
    return strrchr(s, c);
}

test rindex {
    const foo: [*:0]const c_char = @ptrCast("disco");
    try std.testing.expect(rindex(foo, 'd') == foo);
    try std.testing.expect(rindex(foo, 'o') == (foo + 4));
    try std.testing.expect(rindex(foo, 'z') == null);
    try std.testing.expect(rindex(foo, 0) == null);
}

// NOTE: This is a wrapper because the compiler_rt implementation has a
// differnet function signature (c is u8)
fn memset(dest: *anyopaque, c: c_int, n: usize) callconv(.c) *anyopaque {
    @setRuntimeSafety(false);
    const buf: [*]u8 = @ptrCast(dest);
    const v: u8 = @intCast(c);
    @memset(buf[0..n], v);
    return dest;
}

fn __aeabi_memclr(dest: *anyopaque, n: usize) callconv(.c) *anyopaque {
    return memset(dest, 0, n);
}

