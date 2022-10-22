const std = @import("std");
const common = @import("./common.zig");

comptime {
    @export(memcpy, .{ .name = "memcpy", .linkage = common.linkage });
}

pub fn memcpy(noalias dest: ?[*]u8, noalias src: ?[*]const u8, len: usize) callconv(.C) ?[*]u8 {
    @setRuntimeSafety(false);
    if (len == 0) return dest;

    var d = dest.?;
    var s = src.?;
    const wsize = @sizeOf(usize);
    const off = len % wsize;

    // align comparison to usize
    var n = off;
    while (true) {
        if (n == 0) break;
        d[0] = s[0];
        n -= 1;
        d += 1;
        s += 1;
    }

    // compare whole words at a time rather than single bytes
    var dw = @ptrCast([*]usize, @alignCast(@alignOf(usize), d));
    var sw = @ptrCast([*]const usize, @alignCast(@alignOf(usize), s));
    n = (len - off) / 8;
    while (true) {
        if (n == 0) break;
        dw[0] = sw[0];
        n -= 1;
        dw += 1;
        sw += 1;
    }

    return dest;
}
