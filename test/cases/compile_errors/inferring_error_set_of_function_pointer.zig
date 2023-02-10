comptime {
    const z: ?fn()!void = null;
}

// error
// backend=stage2
// target=native
//
// :2:19: error: function prototype may not have inferred error set
