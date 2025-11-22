export fn foo() void {
    comptime var a: u8 = 0;
    _ = struct { comptime *u8 = &a };
}

export fn bar() void {
    comptime var a: u8 = 0;
    _ = struct { foo: *u8 = &a };
}
export fn baz() void {
    comptime var a: u8 = 0;
    _ = @Struct(
        .auto,
        null,
        &.{"foo"},
        &.{*u8},
        &.{.{ .default_value_ptr = @ptrCast(&&a) }},
    );
}

// error
//
// :3:33: error: field default value contains reference to comptime var
// :2:14: note: '0' points to comptime var declared here
// :8:9: error: captured value contains reference to comptime var
// :7:14: note: 'a' points to comptime var declared here
// :17:9: error: field default value contains reference to comptime var
// :11:14: note: 'foo' points to comptime var declared here
