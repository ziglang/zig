export fn a() void {
    var x: u8 = 10;
    _ = &x;
    switch (comptime x) {}
}

// error
// backend=stage2
// target=native
//
// :4:22: error: unable to resolve comptime value
