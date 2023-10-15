const x = 42;
const y = @intFromPtr(&x);
pub export fn entry() void {
    _ = y;
}

// error
// backend=stage2
// target=native
//
// :2:27: error: cannot accept pointer to comptime-only type 'comptime_int'
