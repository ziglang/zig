export fn entry() void {
    var x: i32 = 1;
    _ = &x == null;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:12: error: comparison of '*i32' with null
