export fn a() void {
    for(undefined) |x|;
}

// error
//
// :2:23: error: expected block or assignment, found ';'
