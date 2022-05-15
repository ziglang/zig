export fn a() void {
    if(true);
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:13: error: expected block or assignment, found ';'
