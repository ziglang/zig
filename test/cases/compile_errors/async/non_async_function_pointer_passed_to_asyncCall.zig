export fn entry() void {
    var ptr = afunc;
    var bytes: [100]u8 align(16) = undefined;
    _ = @asyncCall(&bytes, {}, ptr, .{});
    _ = &ptr;
}
fn afunc() void {}

// error
// backend=stage1
// target=native
//
// tmp.zig:4:32: error: expected async function, found 'fn () void'
