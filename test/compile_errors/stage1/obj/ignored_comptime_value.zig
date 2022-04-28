export fn foo() void {
    comptime 1;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:5: error: expression value is ignored
