export fn foo() void {
    var a: f32 = 2;
    _ = @floatToInt(comptime_int, a);
}
export fn bar() void {
    var a: u32 = 2;
    _ = @intToFloat(comptime_float, a);
}

// error
// backend=stage2
// target=native
//
// :3:35: error: unable to resolve comptime value
// :3:35: note: value being casted to 'comptime_int' must be comptime-known
// :7:37: error: unable to resolve comptime value
// :7:37: note: value being casted to 'comptime_float' must be comptime-known
