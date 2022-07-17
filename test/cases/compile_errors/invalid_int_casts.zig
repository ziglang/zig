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

// error
// backend=stage2
// target=native
//
// :3:32: error: unable to cast runtime value to 'comptime_int'
// :7:21: error: expected float type, found 'u32'
// :11:26: error: expected float type, found 'u32'
// :15:23: error: expected integer or vector, found 'f32'
