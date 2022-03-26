export fn entry() void {
    var ptr = afunc;
    _ = async ptr();
}

fn afunc() callconv(.Async) void { }

// runtime-known function called with async keyword
//
// tmp.zig:3:15: error: function is not comptime-known; @asyncCall required
