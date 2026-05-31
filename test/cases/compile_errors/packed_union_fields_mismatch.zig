export fn entry1() void {
    _ = packed union {
        a: u1,
        b: u2,
    };
}

// error
//
// :2:16: error: packed union has fields with mismatching bit sizes
// :3:12: note: 1 bits here
// :4:12: note: 2 bits here
