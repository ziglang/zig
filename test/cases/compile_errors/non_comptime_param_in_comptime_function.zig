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
//
// :8:11: error: unable to resolve comptime value
// :8:10: note: call to function with comptime-only return type 'type' is evaluated at comptime
// :1:20: note: return type declared here
// :8:10: note: types are not available at runtime
