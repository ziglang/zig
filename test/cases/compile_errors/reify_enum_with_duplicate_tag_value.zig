export fn entry() void {
    _ = @Type(.{
        .@"enum" = .{
            .tag_type = u32,
            .fields = &.{
                .{ .name = "A", .value = 10 },
                .{ .name = "B", .value = 10 },
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
// :2:9: error: enum tag value 10 already taken
// :2:9: note: other enum tag value here
