export fn a() void {
    var x: bool = false;
    _ = &x;
    if (comptime x) {}
}

// error
// backend=stage2
// target=native
//
// :4:18: error: unable to resolve comptime value
