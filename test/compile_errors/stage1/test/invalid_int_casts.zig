export fn foo() void {
    var a: u32 = 2;
    _ = @intCast(comptime_int, a);
}
export fn bar() void {
    var a: u32 = 2;
    _ = @intToFloat(u32, a);
}
export fn baz() void {
    var a: u32 = 2;
    _ = @floatToInt(u32, a);
}
export fn qux() void {
    var a: f32 = 2;
    _ = @intCast(u32, a);
}

// invalid int casts
//
// tmp.zig:3:32: error: unable to evaluate constant expression
// tmp.zig:7:21: error: expected float type, found 'u32'
// tmp.zig:11:26: error: expected float type, found 'u32'
// tmp.zig:15:23: error: expected integer type, found 'f32'
