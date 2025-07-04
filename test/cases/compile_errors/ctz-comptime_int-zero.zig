export fn entry() void {
    _ = @ctz(0);
}

// error
// backend=stage2
// target=native
//
// :2:14: error: cannot count number of least-significant zeroes in integer '0' of type 'comptime_int'
