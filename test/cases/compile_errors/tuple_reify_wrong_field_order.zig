export fn f() void {
    _ = @Type(.{ .Struct = .{
        .layout = .Auto,
        .fields = &.{
            .{ .name = "1", .type = u32, .is_comptime = false, .alignment = 0, .default_value = null },
            .{ .name = "0", .type = u32, .is_comptime = false, .alignment = 0, .default_value = null },
        },
        .decls = &.{},
        .is_tuple = true,
    } });
}

// error
// backend=stage2
// target=native
//
// :2:9: error: tuple field at index 0 named '1'
