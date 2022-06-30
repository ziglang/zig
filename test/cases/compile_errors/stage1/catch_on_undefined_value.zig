comptime {
    var a: anyerror!bool = undefined;
    _ = a catch false;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:11: error: use of undefined value here causes undefined behavior
