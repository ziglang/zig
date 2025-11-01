const x = 42;
const y = @intFromPtr(&x);
pub export fn entry() void {
    _ = y;
}

// error
//
// :2:23: error: comptime-only type 'comptime_int' has no pointer address
