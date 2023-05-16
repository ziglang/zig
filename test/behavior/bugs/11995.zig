const std = @import("std");
const testing = std.testing;
const builtin = @import("builtin");

fn wuffs_base__make_io_buffer(arg_data: wuffs_base__slice_u8, arg_meta: *wuffs_base__io_buffer_meta) callconv(.C) void {
    arg_data.ptr[0] = 'w';
    arg_meta.closed = false;
}
const wuffs_base__io_buffer_meta = extern struct {
    wi: usize,
    ri: usize,
    pos: u64,
    closed: bool,
};
const wuffs_base__slice_u8 = extern struct {
    ptr: [*c]u8,
    len: usize,
};
test {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var string: [5]u8 = "hello".*;
    const arg_data = wuffs_base__slice_u8{ .ptr = @ptrCast([*c]u8, &string), .len = string.len };
    var arg_meta = wuffs_base__io_buffer_meta{ .wi = 1, .ri = 2, .pos = 3, .closed = true };
    wuffs_base__make_io_buffer(arg_data, &arg_meta);
    try std.testing.expectEqualStrings("wello", arg_data.ptr[0..arg_data.len]);
    try std.testing.expectEqual(@as(usize, 1), arg_meta.wi);
    try std.testing.expectEqual(@as(usize, 2), arg_meta.ri);
    try std.testing.expectEqual(@as(u64, 3), arg_meta.pos);
    try std.testing.expect(!arg_meta.closed);
}
