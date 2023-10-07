export fn a() void {
    bar(@ptrFromInt(123));
}
export fn b() void {
    bar(@ptrCast(@alignCast(@as(*u8, undefined))));
}
export fn c() void {
    bar(@intCast(@as(u64, 123)));
}
export fn d() void {
    bar(@floatFromInt(123));
}
export fn f() void {
    bar(.{
        .x = @intCast(123),
    });
}

fn bar(_: anytype) void {}

// error
// backend=stage2
// target=native
//
// :2:9: error: @ptrFromInt must have a known result type
// :2:8: note: result type is unknown due to anytype parameter
// :2:9: note: use @as to provide explicit result type
// :5:9: error: @ptrCast must have a known result type
// :5:8: note: result type is unknown due to anytype parameter
// :5:9: note: use @as to provide explicit result type
// :8:9: error: @intCast must have a known result type
// :8:8: note: result type is unknown due to anytype parameter
// :8:9: note: use @as to provide explicit result type
// :11:9: error: @floatFromInt must have a known result type
// :11:8: note: result type is unknown due to anytype parameter
// :11:9: note: use @as to provide explicit result type
// :15:14: error: @intCast must have a known result type
// :14:8: note: result type is unknown due to anytype parameter
// :15:14: note: use @as to provide explicit result type
