comptime {
    _ = @Type(.{
        .@"union" = .{
            .layout = .auto,
            .tag_type = null,
            .fields = &.{
                .{ .name = "foo", .type = usize, .alignment = 3 },
            },
            .decls = &.{},
        },
    });
}
comptime {
    _ = @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .fields = &.{.{
                .name = "0",
                .type = u32,
                .default_value = null,
                .is_comptime = true,
                .alignment = 5,
            }},
            .decls = &.{},
            .is_tuple = false,
        },
    });
}
comptime {
    _ = @Type(.{
        .pointer = .{
            .size = .Many,
            .is_const = true,
            .is_volatile = false,
            .alignment = 7,
            .address_space = .generic,
            .child = u8,
            .is_allowzero = false,
            .sentinel = null,
        },
    });
}

// error
// backend=stage2
// target=native
//
// :2:9: error: alignment value '3' is not a power of two or zero
// :14:9: error: alignment value '5' is not a power of two or zero
// :30:9: error: alignment value '7' is not a power of two or zero
