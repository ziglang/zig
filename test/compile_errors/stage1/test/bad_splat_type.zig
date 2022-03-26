export fn entry() void {
    const c = 4;
    var v = @splat(4, c);
    _ = v;
}

// bad @splat type
//
// tmp.zig:3:23: error: vector element type must be integer, float, bool, or pointer; 'comptime_int' is invalid
