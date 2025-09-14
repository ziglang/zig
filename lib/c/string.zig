const builtin = @import("builtin");
const std = @import("std");
const common = @import("common.zig");

comptime {
    if (builtin.target.isMuslLibC() or builtin.target.isWasiLibC()) {
        // Functions specific to musl and wasi-libc.
        @export(&strcmp, .{ .name = "strcmp", .linkage = common.linkage, .visibility = common.visibility });
        @export(&strncmp, .{ .name = "strncmp", .linkage = common.linkage, .visibility = common.visibility });
        @export(&strcasecmp, .{ .name = "strcasecmp", .linkage = common.linkage, .visibility = common.visibility });
        @export(&strncasecmp, .{ .name = "strncasecmp", .linkage = common.linkage, .visibility = common.visibility });
        @export(&__strcasecmp_l, .{ .name = "__strcasecmp_l", .linkage = common.linkage, .visibility = common.visibility });
        @export(&__strncasecmp_l, .{ .name = "__strncasecmp_l", .linkage = common.linkage, .visibility = common.visibility });
        @export(&__strcasecmp_l, .{ .name = "strcasecmp_l", .linkage = .weak, .visibility = common.visibility });
        @export(&__strncasecmp_l, .{ .name = "strncasecmp_l", .linkage = .weak, .visibility = common.visibility });
        @export(&strspn, .{ .name = "strspn", .linkage = common.linkage, .visibility = common.visibility });
        @export(&strcspn, .{ .name = "strcspn", .linkage = common.linkage, .visibility = common.visibility });
        @export(&strpbrk, .{ .name = "strpbrk", .linkage = common.linkage, .visibility = common.visibility });
        @export(&strstr, .{ .name = "strstr", .linkage = common.linkage, .visibility = common.visibility });
        @export(&strtok, .{ .name = "strtok", .linkage = common.linkage, .visibility = common.visibility });
        @export(&strtok_r, .{ .name = "strtok_r", .linkage = common.linkage, .visibility = common.visibility });
    }

    if (builtin.target.isMinGW()) {
        // Files specific to MinGW-w64.
        @export(&strtok_r, .{ .name = "strtok_r", .linkage = common.linkage, .visibility = common.visibility });
    }
}

fn strcmp(s1: [*:0]const u8, s2: [*:0]const u8) callconv(.c) c_int {
    // We need to perform unsigned comparisons.
    return switch (std.mem.orderZ(u8, s1, s2)) {
        .lt => -1,
        .eq => 0,
        .gt => 1,
    };
}

fn strncmp(s1: [*:0]const u8, s2: [*:0]const u8, n: usize) callconv(.c) c_int {
    if (n == 0) return 0;

    var l = s1;
    var r = s2;
    var i = n - 1;

    while (l[0] != 0 and r[0] != 0 and i != 0 and l[0] == r[0]) {
        l += 1;
        r += 1;
        i -= 1;
    }

    return @as(c_int, l[0]) - @as(c_int, r[0]);
}

fn strcasecmp(s1: [*:0]const u8, s2: [*:0]const u8) callconv(.c) c_int {
    const toLower = std.ascii.toLower;
    var l = s1;
    var r = s2;

    while (l[0] != 0 and r[0] != 0 and (l[0] == r[0] or toLower(l[0]) == toLower(r[0]))) {
        l += 1;
        r += 1;
    }

    return @as(c_int, toLower(l[0])) - @as(c_int, toLower(r[0]));
}

fn __strcasecmp_l(s1: [*:0]const u8, s2: [*:0]const u8, locale: *anyopaque) callconv(.c) c_int {
    _ = locale;
    return strcasecmp(s1, s2);
}

fn strncasecmp(s1: [*:0]const u8, s2: [*:0]const u8, n: usize) callconv(.c) c_int {
    const toLower = std.ascii.toLower;
    var l = s1;
    var r = s2;
    var i = n - 1;

    while (l[0] != 0 and r[0] != 0 and i != 0 and (l[0] == r[0] or toLower(l[0]) == toLower(r[0]))) {
        l += 1;
        r += 1;
        i -= 1;
    }

    return @as(c_int, toLower(l[0])) - @as(c_int, toLower(r[0]));
}

fn __strncasecmp_l(s1: [*:0]const u8, s2: [*:0]const u8, n: usize, locale: *anyopaque) callconv(.c) c_int {
    _ = locale;
    return strncasecmp(s1, s2, n);
}

test strcasecmp {
    try std.testing.expect(strcasecmp("a", "b") < 0);
    try std.testing.expect(strcasecmp("b", "a") > 0);
    try std.testing.expect(strcasecmp("A", "b") < 0);
    try std.testing.expect(strcasecmp("b", "A") > 0);
    try std.testing.expect(strcasecmp("A", "A") == 0);
    try std.testing.expect(strcasecmp("B", "b") == 0);
    try std.testing.expect(strcasecmp("bb", "AA") > 0);
}

test strncasecmp {
    try std.testing.expect(strncasecmp("a", "b", 1) < 0);
    try std.testing.expect(strncasecmp("b", "a", 1) > 0);
    try std.testing.expect(strncasecmp("A", "b", 1) < 0);
    try std.testing.expect(strncasecmp("b", "A", 1) > 0);
    try std.testing.expect(strncasecmp("A", "A", 1) == 0);
    try std.testing.expect(strncasecmp("B", "b", 1) == 0);
    try std.testing.expect(strncasecmp("bb", "AA", 2) > 0);
}

test strncmp {
    try std.testing.expect(strncmp("a", "b", 1) < 0);
    try std.testing.expect(strncmp("a", "c", 1) < 0);
    try std.testing.expect(strncmp("b", "a", 1) > 0);
    try std.testing.expect(strncmp("\xff", "\x02", 1) > 0);
}

fn strspn(s1: [*:0]const u8, s2: [*:0]const u8) callconv(.c) usize {
    const slice1 = std.mem.span(s1);
    const slice2 = std.mem.span(s2);
    return std.mem.indexOfNone(u8, slice1, slice2) orelse slice1.len;
}

test strspn {
    try std.testing.expectEqual(0, strspn("foobarbaz", ""));
    try std.testing.expectEqual(0, strspn("foobarbaz", "c"));
    try std.testing.expectEqual(3, strspn("foobarbaz", "fo"));
    try std.testing.expectEqual(9, strspn("foobarbaz", "fobarz"));
    try std.testing.expectEqual(9, strspn("foobarbaz", "abforz"));
}

fn strcspn(s1: [*:0]const u8, s2: [*:0]const u8) callconv(.c) usize {
    const slice1 = std.mem.span(s1);
    const slice2 = std.mem.span(s2);
    return std.mem.indexOfAny(u8, slice1, slice2) orelse slice1.len;
}

test strcspn {
    try std.testing.expectEqual(0, strcspn("foobarbaz", "f"));
    try std.testing.expectEqual(3, strcspn("foobarbaz", "rab"));
    try std.testing.expectEqual(4, strcspn("foobarbaz", "ra"));
    try std.testing.expectEqual(9, strcspn("foobarbaz", ""));
}

fn strpbrk(s1: [*:0]const u8, s2: [*:0]const u8) callconv(.c) ?[*:0]const u8 {
    const slice1 = std.mem.span(s1);
    const slice2 = std.mem.span(s2);
    const index = std.mem.indexOfAny(u8, slice1, slice2) orelse
        return null;
    return s1 + index;
}

test strpbrk {
    try std.testing.expectEqualStrings("barbaz", std.mem.span(strpbrk("foobarbaz", "rab").?));
    try std.testing.expectEqualStrings("arbaz", std.mem.span(strpbrk("foobarbaz", "ra").?));
    try std.testing.expectEqual(null, strpbrk("foobarbaz", ""));
}

fn strstr(s1: [*:0]const u8, s2: [*:0]const u8) callconv(.c) ?[*:0]const u8 {
    const slice1 = std.mem.span(s1);
    const slice2 = std.mem.span(s2);
    const index = std.mem.indexOf(u8, slice1, slice2) orelse
        return null;
    return s1 + index;
}

test strstr {
    try std.testing.expectEqualStrings("barbaz", std.mem.span(strstr("foobarbaz", "ba").?));
    try std.testing.expectEqualStrings("foobarbaz", std.mem.span(strstr("foobarbaz", "fo").?));
    try std.testing.expectEqualStrings("foobarbaz", std.mem.span(strstr("foobarbaz", "f").?));
    try std.testing.expectEqualStrings("foobarbaz", std.mem.span(strstr("foobarbaz", "").?));
    try std.testing.expectEqual(null, strstr("foobarbaz", "boofarfaz"));
    try std.testing.expectEqual(null, strstr("foobarbaz", "fa"));
    try std.testing.expectEqual(null, strstr("foobarbaz", "c"));
}

fn strtok_r(s: ?[*:0]u8, sep: [*:0]const u8, lasts: *?[*:0]u8) callconv(.c) ?[*:0]u8 {
    const slice = std.mem.span(s orelse lasts.* orelse return null);
    const delim = std.mem.span(sep);
    const index = std.mem.indexOfNone(u8, slice, delim) orelse {
        lasts.* = null;
        return null;
    };
    if (std.mem.indexOfAny(u8, slice[index..], delim)) |len| {
        slice[index + len] = 0;
        lasts.* = slice[index + len + 1 ..];
    } else {
        lasts.* = null;
    }
    return slice[index..];
}

fn strtok(s: ?[*:0]u8, sep: [*:0]const u8) callconv(.c) ?[*:0]u8 {
    const static = struct {
        var lasts: ?[*:0]u8 = null;
    };
    return strtok_r(s, sep, &static.lasts);
}

test strtok {
    var str = "?a???b,,,#c?#,".*;
    {
        const ret = strtok(&str, "?");
        try std.testing.expectEqual(str[1..], ret);
        try std.testing.expectEqualStrings("a", std.mem.span(ret.?));
    }
    {
        const ret = strtok(null, ",");
        try std.testing.expectEqual(str[3..], ret);
        try std.testing.expectEqualStrings("??b", std.mem.span(ret.?));
    }
    {
        const ret = strtok(null, "#,");
        try std.testing.expectEqual(str[10..], ret);
        try std.testing.expectEqualStrings("c?", std.mem.span(ret.?));
    }
    {
        const ret = strtok(null, "?");
        try std.testing.expectEqual(str[13..], ret);
        try std.testing.expectEqualStrings(",", std.mem.span(ret.?));
    }
    {
        const ret = strtok(null, "?");
        try std.testing.expectEqual(null, ret);
    }
    try std.testing.expectEqualSlices(u8, "?a" ++ .{0} ++ "??b" ++ .{0} ++ ",,#c?" ++ .{0} ++ ",", &str);
}
