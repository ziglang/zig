comptime {
    var a: i64 = undefined;
    a *%= a;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:5: error: use of undefined value here causes undefined behavior
