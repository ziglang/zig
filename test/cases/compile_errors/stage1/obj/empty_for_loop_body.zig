export fn a() void {
    for(undefined) |x|;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:23: error: expected block or assignment, found ';'
