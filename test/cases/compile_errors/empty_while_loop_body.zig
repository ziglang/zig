export fn a() void {
    while(true);
}

// error
// backend=stage2
// target=native
//
// :2:16: error: expected block or assignment, found ';'
