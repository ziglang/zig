comptime {
    _ = @Union(.{
        .layout = .auto,
        .tag_type = null,
        .fields = &.{
            .{ .name = "foo", .type = usize, .alignment = 3 },
        },
        .decls = &.{},
    });
}
comptime {
    _ = @Struct(.{
        .layout = .auto,
        .fields = &.{.{
            .name = "0",
            .type = u32,
            .default_value_ptr = null,
            .is_comptime = true,
            .alignment = 5,
        }},
        .decls = &.{},
        .is_tuple = false,
    });
}

// error
//
// :2:9: error: alignment value '3' is not a power of two or zero
// :12:9: error: alignment value '5' is not a power of two or zero
