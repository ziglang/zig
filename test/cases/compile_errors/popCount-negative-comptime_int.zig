export fn entry() void {
    _ = @popCount(-1);
}

// error
// backend=stage2
// target=native
//
// :2:19: error: cannot count number of bits set in negative integer '-1' of type 'comptime_int'
