comptime {
    const z: ?fn()!void = null;
}

// inferring error set of function pointer
//
// tmp.zig:2:19: error: function prototype may not have inferred error set
