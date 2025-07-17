const Tag = @Type(.{
    .@"enum" = .{
        .tag_type = u2,
        .fields = &.{
            .{ .name = "signed", .value = 0 },
            .{ .name = "unsigned", .value = 1 },
        },
        .decls = &.{},
        .is_exhaustive = true,
    },
});

const Extern = @Type(.{
    .@"union" = .{
        .layout = .@"extern",
        .tag_type = Tag,
        .fields = &.{
            .{ .name = "signed", .type = i32, .alignment = @alignOf(i32) },
            .{ .name = "unsigned", .type = u32, .alignment = @alignOf(u32) },
        },
        .decls = &.{},
    },
});

export fn entry() void {
    const tagged: Extern = .{ .signed = -1 };
    _ = tagged;
}

// error
// backend=stage2
// target=native
//
// :13:16: error: extern union does not support enum tag type
