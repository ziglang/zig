export fn a() void {
    for(undefined) |x|;
}

// error
// backend=stage2
// target=native
//
// :2:23: error: expected block or assignment, found ';'
