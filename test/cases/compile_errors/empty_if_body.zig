export fn a() void {
    if(true);
}

// error
// backend=stage2
// target=native
//
// :2:13: error: expected block or assignment, found ';'
