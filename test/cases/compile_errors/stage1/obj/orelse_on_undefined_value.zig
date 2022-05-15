comptime {
    var a: ?bool = undefined;
    _ = a orelse false;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:11: error: use of undefined value here causes undefined behavior
