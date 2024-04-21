fn F(val: anytype) type {
    _ = val;
    return struct {};
}
export fn entry() void {
    var x: u32 = 0;
    _ = &x;
    _ = F(x);
}

// error
// backend=stage2
// target=native
//
// :8:11: error: unable to resolve comptime value
// :8:11: note: argument to function being called at comptime must be comptime-known
// :1:20: note: expression is evaluated at comptime because the function returns a comptime-only type 'type'
// :1:20: note: types are not available at runtime
