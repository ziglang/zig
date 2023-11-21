export fn entry() void {
    var ptr = afunc;
    _ = async ptr();
    _ = &ptr;
}

fn afunc() callconv(.Async) void {}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:15: error: function is not comptime-known; @asyncCall required
