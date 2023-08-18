export fn foo() void {
    var a: f32 = 2;
    _ = @as(comptime_int, @intFromFloat(a));
}
export fn bar() void {
    var a: u32 = 2;
    _ = @as(comptime_float, @floatFromInt(a));
}

// error
// backend=stage2
// target=native
//
// :3:41: error: unable to resolve comptime value
// :3:41: note: value being casted to 'comptime_int' must be comptime-known
// :7:43: error: unable to resolve comptime value
// :7:43: note: value being casted to 'comptime_float' must be comptime-known
