export fn entry() void {
    var ptr = afunc;
    var bytes: [100]u8 align(16) = undefined;
    _ = @asyncCall(&bytes, {}, ptr, .{});
}
fn afunc() void { }

// non async function pointer passed to @asyncCall
//
// tmp.zig:4:32: error: expected async function, found 'fn() void'
