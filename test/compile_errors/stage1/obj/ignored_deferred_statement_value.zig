export fn foo() void {
    defer {1;}
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:12: error: expression value is ignored
