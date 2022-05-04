export fn f() void {
    b = 3;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:5: error: use of undeclared identifier 'b'
