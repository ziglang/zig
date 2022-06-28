comptime {
    var a: i64 = undefined;
    _ = a -% a;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:9: error: use of undefined value here causes undefined behavior
