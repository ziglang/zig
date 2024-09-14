export fn entry() void {
    var buf: [256]u8 = undefined;
    var slice: []u8 = &buf;
    _ = slice[0.. :0];
}

// error
//
// :4:20: error: slice sentinel index always out of bounds
