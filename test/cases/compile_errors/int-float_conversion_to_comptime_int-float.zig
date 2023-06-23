export fn foo() void {
    var a: f32 = 2;
    _ = @intFromFloat(comptime_int, a);
}
export fn bar() void {
    var a: u32 = 2;
    _ = @floatFromInt(comptime_float, a);
}

// error
// backend=stage2
// target=native
//
// :3:37: error: unable to resolve comptime value
// :3:37: note: value being casted to 'comptime_int' must be comptime-known
// :7:39: error: unable to resolve comptime value
// :7:39: note: value being casted to 'comptime_float' must be comptime-known
