const builtin = @import("builtin");
const std = @import("std");
const common = @import("common.zig");

comptime {
    @export(&strcmp, .{ .name = "strcmp", .linkage = common.linkage, .visibility = common.visibility });
    @export(&strlen, .{ .name = "strlen", .linkage = common.linkage, .visibility = common.visibility });
    @export(&strnlen, .{ .name = "strnlen", .linkage = common.linkage, .visibility = common.visibility });
    @export(&strncmp, .{ .name = "strncmp", .linkage = common.linkage, .visibility = common.visibility });
    @export(&strchr, .{ .name = "strchr", .linkage = common.linkage, .visibility = common.visibility });
    @export(&strchr, .{ .name = "index", .linkage = common.linkage, .visibility = common.visibility });
    @export(&strrchr, .{ .name = "strrchr", .linkage = common.linkage, .visibility = common.visibility });
    @export(&strrchr, .{ .name = "rindex", .linkage = common.linkage, .visibility = common.visibility });
    @export(&strcpy, .{ .name = "strcpy", .linkage = common.linkage, .visibility = common.visibility });
    @export(&strcat, .{ .name = "strcat", .linkage = common.linkage, .visibility = common.visibility });
    @export(&strncpy, .{ .name = "strncpy", .linkage = common.linkage, .visibility = common.visibility });
    @export(&memccpy, .{ .name = "memccpy", .linkage = common.linkage, .visibility = common.visibility });
    @export(&mempcpy, .{ .name = "mempcpy", .linkage = common.linkage, .visibility = common.visibility });
    @export(&memmem, .{ .name = "memmem", .linkage = common.linkage, .visibility = common.visibility });
    @export(&memchr, .{ .name = "memchr", .linkage = common.linkage, .visibility = common.visibility });
    @export(&strchrnul, .{ .name = "strchrnul", .linkage = .weak, .visibility = common.visibility });
    @export(&memrchr, .{ .name = "memrchr", .linkage = .weak, .visibility = common.visibility });
    @export(&stpcpy, .{ .name = "stpcpy", .linkage = .weak, .visibility = common.visibility });
    @export(&stpncpy, .{ .name = "stpncpy", .linkage = .weak, .visibility = common.visibility });
    if (builtin.target.isMuslLibC() or builtin.target.isWasiLibC()) {
        @export(&stpncpy, .{ .name = "__stpncpy", .linkage = .weak, .visibility = .hidden });
        @export(&strchrnul, .{ .name = "__strchrnul", .linkage = .weak, .visibility = .hidden });
        @export(&memrchr, .{ .name = "__memrchr", .linkage = .weak, .visibility = .hidden });
        @export(&stpcpy, .{ .name = "__stpcpy", .linkage = .weak, .visibility = .hidden });
    }
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

fn strnlen(s: [*:0]const c_char, n: usize) callconv(.c) usize {
    return if (std.mem.indexOfScalar(c_char, s[0..n], 0)) |idx| idx else n;
}

fn strchrnul(s: [*:0]const c_char, c: c_int) callconv(.c) [*:0]const c_char {
    const needle: c_char = @intCast(c);
    if (needle == 0) return s + strlen(s);

    var it: [*:0]const c_char = @ptrCast(s);
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
    const needle: c_char = @intCast(c);
    return if (result[0] == needle) result else null;
}

test strchr {
    const foo: [*:0]const c_char = @ptrCast("disco");
    try std.testing.expect(strchr(foo, 'd') == foo);
    try std.testing.expect(strchr(foo, 'o') == (foo + 4));
    try std.testing.expect(strchr(foo, 'z') == null);
    try std.testing.expect(strchr(foo, 0) == (foo + 5));
}

fn memchr(m: *const anyopaque, c: c_int, n: usize) callconv(.c) ?*const anyopaque {
    const needle: c_char = @intCast(c);
    const s: [*]const c_char = @ptrCast(m);
    if (std.mem.indexOfScalar(c_char, s[0..n], needle)) |idx| {
        return @ptrCast(s + idx);
    } else {
        return null;
    }
}

test memchr {
    const foo: [*:0]const c_char = @ptrCast("disco");
    try std.testing.expect(memchr(foo, 'd', 5) == @as(*const anyopaque, @ptrCast(foo)));
    try std.testing.expect(memchr(foo, 'o', 5) == @as(*const anyopaque, @ptrCast(foo + 4)));
    try std.testing.expect(memchr(foo, 'z', 5) == null);
}

fn memrchr(m: *const anyopaque, c: c_int, n: usize) callconv(.c) ?*const anyopaque {
    const needle: c_char = @intCast(c);
    const s: [*]const c_char = @ptrCast(m);
    if (std.mem.lastIndexOfScalar(c_char, s[0..n], needle)) |idx| {
        return @ptrCast(s + idx);
    } else {
        return null;
    }
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

fn __aeabi_memclr(dest: *anyopaque, n: usize) callconv(.c) *anyopaque {
    const buf: [*]c_char = @ptrCast(dest);
    @memset(buf[0..n], 0);
    return dest;
}

fn memccpy(noalias dest: *anyopaque, noalias src: *const anyopaque, c: c_int, n: usize) callconv(.c) ?*anyopaque {
    @setRuntimeSafety(false);
    const d: [*]c_char = @ptrCast(dest);
    const s: [*]const c_char = @ptrCast(src);
    const needle: c_char = @intCast(c);
    var idx: usize = 0;
    while (idx < n) : (idx += 1) {
        d[idx] = s[idx];
        if (d[idx] == needle) return d + idx + 1;
    }
    return null;
}

test memccpy {
    const src: []const u8 = "supercalifragilisticexpialidocious";
    var dst: [src.len]u8 = @splat(0);
    const dOffset = std.mem.indexOfScalar(u8, src, 'd').?;
    const endPtr: *anyopaque = @ptrCast(@as([*]u8, &dst) + dOffset + 1);
    try std.testing.expect(memccpy(@ptrCast(&dst), @ptrCast(src.ptr), 'd', src.len) == endPtr);
    try std.testing.expectEqualStrings("supercalifragilisticexpialid", std.mem.trimRight(u8, dst[0..], &.{0}));

    dst = @splat(0);
    try std.testing.expect(memccpy(@constCast(@ptrCast(&dst)), (@ptrCast(src.ptr)), 'z', src.len) == null);
    try std.testing.expectEqualStrings(src, dst[0..]);
}

fn mempcpy(noalias dest: *anyopaque, noalias src: *const anyopaque, n: usize) callconv(.c) *anyopaque {
    @setRuntimeSafety(false);
    const d: [*]u8 = @ptrCast(dest);
    const s: [*]const u8 = @ptrCast(src);
    @memcpy(d[0..n], s[0..n]);
    return @ptrCast(d + n);
}

test mempcpy {
    const bytesToWrite = 3;
    const src: []const u8 = "testing";
    var dst: [src.len]u8 = @splat('z');
    const endPtr: *anyopaque = @ptrCast(@as([*]u8, &dst) + bytesToWrite);
    try std.testing.expect(mempcpy(@ptrCast(&dst), @ptrCast(src.ptr), bytesToWrite) == endPtr);
    try std.testing.expect(@as(*u8, @ptrCast(endPtr)).* == 'z');
}

fn memmem(haystack: *const anyopaque, haystack_len: usize, needle: *const anyopaque, needle_len: usize) callconv(.c) ?*const anyopaque {
    const h: [*]const c_char = @ptrCast(haystack);
    const n: [*]const c_char = @ptrCast(needle);

    if (std.mem.indexOf(c_char, h[0..haystack_len], n[0..needle_len])) |idx| {
        return @ptrCast(h + idx);
    } else {
        return null;
    }
}

fn stpcpy(noalias dest: [*:0]c_char, noalias src: [*:0]const c_char) callconv(.c) [*:0]c_char {
    var d: [*]c_char = @ptrCast(dest);
    var s: [*]const c_char = @ptrCast(src);
    // QUESTION: is std.mem.span -> @memset more efficient here?
    while (true) {
        d[0] = s[0];
        if (s[0] == 0) return @ptrCast(d);
        d += 1;
        s += 1;
    }
}

test stpcpy {
    const src: [:0]const c_char = @ptrCast("bananas");
    var dst: [src.len]c_char = undefined;
    const endPtr: [*:0]c_char = @ptrCast(@as([*]c_char, &dst) + src.len);
    try std.testing.expect(stpcpy(@ptrCast(&dst), @ptrCast(src.ptr)) == endPtr);
    try std.testing.expect(endPtr[0] == 0);
    try std.testing.expectEqualSentinel(c_char, 0, src, @ptrCast(&dst));
}

fn strcpy(noalias dest: [*:0]c_char, noalias src: [*:0]const c_char) callconv(.c) [*:0]c_char {
    _ = stpcpy(dest, src);
    return dest;
}

test strcpy {
    const src: [:0]const c_char = @ptrCast("bananas");
    var dst: [src.len]c_char = undefined;
    try std.testing.expect(strcpy(@ptrCast(&dst), @ptrCast(src.ptr)) == @as([*:0]c_char, @ptrCast(&dst)));
    try std.testing.expectEqualSentinel(c_char, 0, src, @ptrCast(&dst));
}

fn stpncpy(noalias dest: [*:0]c_char, noalias src: [*:0]const c_char, n: usize) callconv(.c) [*:0]c_char {
    const dlen = strnlen(src, n);
    const end = mempcpy(@ptrCast(dest), @ptrCast(src), dlen);
    const remaining: [*]u8 = @ptrCast(end);
    @memset(remaining[0 .. n - dlen], 0);
    return @ptrCast(end);
}

test stpncpy {
    var buf: [5]c_char = undefined;
    const b: [*:0]c_char = @ptrCast(&buf);
    try std.testing.expect(stpncpy(@ptrCast(&buf), @ptrCast("1"), buf.len) == b + 1);
    try std.testing.expectEqualSlices(c_char, &.{ '1', 0, 0, 0, 0 }, buf[0..]);
    try std.testing.expect(stpncpy(@ptrCast(&buf), @ptrCast("12"), buf.len) == b + 2);
    try std.testing.expectEqualSlices(c_char, &.{ '1', '2', 0, 0, 0 }, buf[0..]);
    try std.testing.expect(stpncpy(@ptrCast(&buf), @ptrCast("123"), buf.len) == b + 3);
    try std.testing.expectEqualSlices(c_char, &.{ '1', '2', '3', 0, 0 }, buf[0..]);
    try std.testing.expect(stpncpy(@ptrCast(&buf), @ptrCast("1234"), buf.len) == b + 4);
    try std.testing.expectEqualSlices(c_char, &.{ '1', '2', '3', '4', 0 }, buf[0..]);
    try std.testing.expect(stpncpy(@ptrCast(&buf), @ptrCast("12345"), buf.len) == b + 5);
    try std.testing.expectEqualSlices(c_char, &.{ '1', '2', '3', '4', '5' }, buf[0..]);
}

fn strncpy(noalias dest: [*:0]c_char, noalias src: [*:0]const c_char, n: usize) callconv(.c) [*:0]c_char {
    _ = stpncpy(dest, src, n);
    return dest;
}

test strncpy {
    var buf: [5]c_char = undefined;
    const b: [*:0]c_char = @ptrCast(&buf);
    try std.testing.expect(strncpy(@ptrCast(&buf), @ptrCast("1"), buf.len) == b);
    try std.testing.expectEqualSlices(c_char, &.{ '1', 0, 0, 0, 0 }, buf[0..]);
    try std.testing.expect(strncpy(@ptrCast(&buf), @ptrCast("12"), buf.len) == b);
    try std.testing.expectEqualSlices(c_char, &.{ '1', '2', 0, 0, 0 }, buf[0..]);
    try std.testing.expect(strncpy(@ptrCast(&buf), @ptrCast("123"), buf.len) == b);
    try std.testing.expectEqualSlices(c_char, &.{ '1', '2', '3', 0, 0 }, buf[0..]);
    try std.testing.expect(strncpy(@ptrCast(&buf), @ptrCast("1234"), buf.len) == b);
    try std.testing.expectEqualSlices(c_char, &.{ '1', '2', '3', '4', 0 }, buf[0..]);
    try std.testing.expect(strncpy(@ptrCast(&buf), @ptrCast("12345"), buf.len) == b);
    try std.testing.expectEqualSlices(c_char, &.{ '1', '2', '3', '4', '5' }, buf[0..]);
}

fn strcat(noalias dest: [*:0]c_char, noalias src: [*:0]const c_char) callconv(.c) [*:0]c_char {
    const start = dest + strlen(dest);
    _ = stpcpy(start, src);
    return dest;
}

test strcat {
    const start = "Hello";
    const end = " World!\n";
    var buf: [start.len + end.len:0]c_char = undefined;
    @memcpy(buf[0 .. start.len + 1], @as([*:0]const c_char, @ptrCast(start)));
    try std.testing.expect(strcat(&buf, @as([*:0]const c_char, @ptrCast(end))) == &buf);
    try std.testing.expectEqualStrings("Hello World!\n", @as([]u8, @ptrCast(buf[0..])));
}
