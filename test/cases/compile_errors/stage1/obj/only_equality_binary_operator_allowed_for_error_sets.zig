comptime {
    const z = error.A > error.B;
    _ = z;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:23: error: operator not allowed for errors
