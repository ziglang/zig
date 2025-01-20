const std = @import("std");
const common = @import("./common.zig");
const builtin = @import("builtin");

comptime {
    if (builtin.object_format != .c) {
        const export_options: std.builtin.ExportOptions = .{
            .name = "memcpy",
            .linkage = common.linkage,
            .visibility = common.visibility,
        };

        if (builtin.mode == .ReleaseSmall)
            @export(&memcpySmall, export_options)
        else
            @export(&memcpyFast, export_options);
    }
}

fn memcpySmall(noalias dest: ?[*]u8, noalias src: ?[*]const u8, len: usize) callconv(.C) ?[*]u8 {
    @setRuntimeSafety(builtin.is_test);

    for (0..len) |i| {
        dest.?[i] = src.?[i];
    }

    return dest;
}

fn memcpyFast(opt_dest: ?[*]u8, opt_src: ?[*]const u8, len: usize) callconv(.C) ?[*]u8 {
    return @call(.always_inline, @import("memmove.zig").memmove, .{ opt_dest, opt_src, len });
}
