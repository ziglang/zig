export fn f() void {
    i[i] = i[i];
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:5: error: use of undeclared identifier 'i'
