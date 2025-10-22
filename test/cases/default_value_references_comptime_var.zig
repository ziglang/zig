export fn foo() void {
    comptime var a: u8 = 0;
    _ = struct { comptime *u8 = &a };
}
export fn bar() void {
    comptime var a: u8 = 0;
    _ = @Type(.{ .@"struct" = .{
        .layout = .auto,
        .fields = &.{.{
            .name = "0",
            .type = *u8,
            .default_value_ptr = @ptrCast(&&a),
            .is_comptime = true,
            .alignment = @alignOf(*u8),
        }},
        .decls = &.{},
        .is_tuple = true,
    } });
}

export fn baz() void {
    comptime var a: u8 = 0;
    _ = struct { foo: *u8 = &a };
}
export fn qux() void {
    comptime var a: u8 = 0;
    _ = @Type(.{ .@"struct" = .{
        .layout = .auto,
        .fields = &.{.{
            .name = "foo",
            .type = *u8,
            .default_value_ptr = @ptrCast(&&a),
            .is_comptime = false,
            .alignment = @alignOf(*u8),
        }},
        .decls = &.{},
        .is_tuple = false,
    } });
}

// error
//
// :3:33: error: field default value contains reference to comptime var
// :2:14: note: '0' points to comptime var declared here
// :7:9: error: field default value contains reference to comptime var
// :6:14: note: '0' points to comptime var declared here
// :23:9: error: captured value contains reference to comptime var
// :22:14: note: 'a' points to comptime var declared here
// :27:9: error: field default value contains reference to comptime var
// :26:14: note: 'foo' points to comptime var declared here
