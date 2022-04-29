export fn a() void {
    b();
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:5: error: use of undeclared identifier 'b'
