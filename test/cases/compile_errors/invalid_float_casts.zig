export fn foo() void {
    var a: f32 = 2;
    _ = @floatCast(comptime_float, a);
}
export fn bar() void {
    var a: f32 = 2;
    _ = @intFromFloat(f32, a);
}
export fn baz() void {
    var a: f32 = 2;
    _ = @floatFromInt(f32, a);
}
export fn qux() void {
    var a: u32 = 2;
    _ = @floatCast(f32, a);
}

// error
// backend=stage2
// target=native
//
// :3:36: error: unable to cast runtime value to 'comptime_float'
// :7:23: error: expected integer type, found 'f32'
// :11:28: error: expected integer type, found 'f32'
// :15:25: error: expected float type, found 'u32'
