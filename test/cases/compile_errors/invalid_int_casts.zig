export fn foo() void {
    var a: u32 = 2;
    _ = @as(comptime_int, @intCast(a));
}
export fn bar() void {
    var a: u32 = 2;
    _ = @as(u32, @floatFromInt(a));
}
export fn baz() void {
    var a: u32 = 2;
    _ = @as(u32, @intFromFloat(a));
}
export fn qux() void {
    var a: f32 = 2;
    _ = @as(u32, @intCast(a));
}

// error
// backend=stage2
// target=native
//
// :3:36: error: unable to cast runtime value to 'comptime_int'
// :7:18: error: expected float type, found 'u32'
// :11:32: error: expected float type, found 'u32'
// :15:27: error: expected integer or vector, found 'f32'
