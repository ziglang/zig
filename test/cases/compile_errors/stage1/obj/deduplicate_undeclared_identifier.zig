export fn a() void {
    x += 1;
}
export fn b() void {
    x += 1;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:5: error: use of undeclared identifier 'x'
