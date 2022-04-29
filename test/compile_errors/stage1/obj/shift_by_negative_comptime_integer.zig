comptime {
    var a = 1 >> -1;
    _ = a;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:18: error: shift by negative value -1
