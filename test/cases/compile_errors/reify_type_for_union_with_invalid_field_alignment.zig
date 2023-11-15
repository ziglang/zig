comptime {
    _ = @Type(.{
        .Union = .{
            .layout = .Auto,
            .tag_type = null,
            .fields = &.{
                .{ .name = "foo", .type = usize, .alignment = 3 },
            },
            .decls = &.{},
        },
    });
}

// error
// backend=stage2
// target=native
//
// :2:9: error: alignment value '3' is not a power of two
