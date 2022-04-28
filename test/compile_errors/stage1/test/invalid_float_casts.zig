export fn foo() void {
    var a: f32 = 2;
    _ = @floatCast(comptime_float, a);
}
export fn bar() void {
    var a: f32 = 2;
    _ = @floatToInt(f32, a);
}
export fn baz() void {
    var a: f32 = 2;
    _ = @intToFloat(f32, a);
}
export fn qux() void {
    var a: u32 = 2;
    _ = @floatCast(f32, a);
}

// error
// backend=stage1
// target=native
// is_test=1
//
// tmp.zig:3:36: error: unable to evaluate constant expression
// tmp.zig:7:21: error: expected integer type, found 'f32'
// tmp.zig:11:26: error: expected int type, found 'f32'
// tmp.zig:15:25: error: expected float type, found 'u32'
