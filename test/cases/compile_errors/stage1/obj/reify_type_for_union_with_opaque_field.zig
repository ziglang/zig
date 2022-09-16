const Untagged = @Type(.{
    .Union = .{
        .layout = .Auto,
        .tag_type = null,
        .fields = &.{
            .{ .name = "foo", .field_type = opaque {}, .alignment = 1 },
        },
        .decls = &.{},
    },
});
export fn entry() usize {
    return @sizeOf(Untagged);
}

// error
// backend=stage1
// target=native
//
// tmp.zig:1:25: error: opaque types have unknown size and therefore cannot be directly embedded in unions
