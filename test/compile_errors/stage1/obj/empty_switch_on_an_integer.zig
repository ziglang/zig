export fn entry() void {
    var x: u32 = 0;
    switch(x) {}
}

// empty switch on an integer
//
// tmp.zig:3:5: error: switch must handle all possibilities
