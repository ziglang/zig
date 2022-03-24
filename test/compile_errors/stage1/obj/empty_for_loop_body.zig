export fn a() void {
    for(undefined) |x|;
}

// empty for loop body
//
// tmp.zig:2:23: error: expected block or assignment, found ';'
