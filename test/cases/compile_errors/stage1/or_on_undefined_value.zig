comptime {
    var a: bool = undefined;
    _ = a or a;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:9: error: use of undefined value here causes undefined behavior
