export fn a() void {
    while(true);
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:16: error: expected block or assignment, found ';'
