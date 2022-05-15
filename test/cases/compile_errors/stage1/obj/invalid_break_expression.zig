export fn f() void {
    break;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:5: error: break expression outside loop
