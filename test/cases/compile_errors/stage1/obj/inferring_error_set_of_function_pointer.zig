comptime {
    const z: ?fn()!void = null;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:19: error: function prototype may not have inferred error set
