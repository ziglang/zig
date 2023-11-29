export fn foo() void {
    var a: f32 = 2;
    _ = &a;
    _ = @as(comptime_float, @floatCast(a));
}
export fn bar() void {
    var a: f32 = 2;
    _ = &a;
    _ = @as(f32, @intFromFloat(a));
}
export fn baz() void {
    var a: f32 = 2;
    _ = &a;
    _ = @as(f32, @floatFromInt(a));
}
export fn qux() void {
    var a: u32 = 2;
    _ = &a;
    _ = @as(f32, @floatCast(a));
}

// error
// backend=stage2
// target=native
//
// :4:40: error: unable to cast runtime value to 'comptime_float'
// :9:18: error: expected integer type, found 'f32'
// :14:32: error: expected integer type, found 'f32'
// :19:29: error: expected float or vector type, found 'u32'
