const builtin = @import("builtin");
const std = @import("std");
const common = @import("common.zig");

comptime {
    @export(&strcmp, .{ .name = "strcmp", .linkage = common.linkage, .visibility = common.visibility });
    @export(&strlen, .{ .name = "strlen", .linkage = common.linkage, .visibility = common.visibility });
    @export(&strncmp, .{ .name = "strncmp", .linkage = common.linkage, .visibility = common.visibility });
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
