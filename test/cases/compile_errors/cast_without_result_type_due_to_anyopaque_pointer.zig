export fn foo() void {
    const x: *const anyopaque = &@intCast(123);
    _ = x;
}
export fn bar() void {
    const x: *const anyopaque = &.{
        .x = @intCast(123),
    };
    _ = x;
}

// error
// backend=stage2
// target=native
//
// :2:34: error: @intCast must have a known result type
// :2:34: note: result type is unknown due to opaque pointer type
// :2:34: note: use @as to provide explicit result type
// :7:14: error: @intCast must have a known result type
// :6:35: note: result type is unknown due to opaque pointer type
// :7:14: note: use @as to provide explicit result type
