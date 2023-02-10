export fn entry() void {
    const c = 4;
    var v = @splat(4, c);
    _ = v;
}

// error
// backend=stage2
// target=native
//
// :3:23: error: expected integer, float, bool, or pointer for the vector element type; found 'comptime_int'
