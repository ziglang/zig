export fn entry() void {
    var x: u32 = 0;
    switch(x) {}
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:5: error: switch must handle all possibilities
