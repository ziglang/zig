export fn entry() void {
    var ptr: fn () callconv(.Async) void = func;
    var bytes: [64]u8 = undefined;
    _ = @asyncCall(&bytes, {}, ptr, .{});
    _ = &ptr;
}
fn func() callconv(.Async) void {}

// error
// backend=stage1
// target=aarch64-linux-none
//
// tmp.zig:4:21: error: expected type '[]align(8) u8', found '*[64]u8'
