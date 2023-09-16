export fn a() void {
    _ = @ptrFromInt(123);
}
export fn b() void {
    const x = @ptrCast(@alignCast(@as(*u8, undefined)));
    _ = x;
}
export fn c() void {
    _ = &@intCast(@as(u64, 123));
    _ = S;
}
export fn d() void {
    var x: f32 = 0;
    _ = x + @floatFromInt(123);
}
export fn e() void {
    const x: u32, const y: u64 = @intCast(123);
    _ = x + y;
}

// error
// backend=stage2
// target=native
//
// :2:9: error: @ptrFromInt must have a known result type
// :2:9: note: use @as to provide explicit result type
// :5:15: error: @ptrCast must have a known result type
// :5:15: note: use @as to provide explicit result type
// :9:10: error: @intCast must have a known result type
// :9:10: note: use @as to provide explicit result type
// :14:13: error: @floatFromInt must have a known result type
// :14:13: note: use @as to provide explicit result type
// :17:34: error: @intCast must have a known result type
// :17:32: note: destructure expressions do not provide a single result type
// :17:34: note: use @as to provide explicit result type
