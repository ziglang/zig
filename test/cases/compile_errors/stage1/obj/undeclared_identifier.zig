export fn a() void {
    return
    b +
    c;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:5: error: use of undeclared identifier 'b'
