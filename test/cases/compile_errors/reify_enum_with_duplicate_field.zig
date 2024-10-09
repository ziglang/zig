export fn entry() void {
    _ = @Type(.{
        .@"enum" = .{
            .tag_type = u32,
            .fields = &.{
                .{ .name = "A", .value = 0 },
                .{ .name = "A", .value = 1 },
            },
            .decls = &.{},
            .is_exhaustive = false,
        },
    });
}

// error
// backend=stage2
// target=native
//
// :2:9: error: duplicate enum field 'A'
// :2:9: note: other field here
