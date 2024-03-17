const Untagged = @Type(.{
    .Union = .{
        .layout = .auto,
        .tag_type = null,
        .fields = &.{
            .{ .name = "foo", .type = opaque {}, .alignment = 1 },
        },
        .decls = &.{},
    },
});
export fn entry() usize {
    return @sizeOf(Untagged);
}

// error
// backend=stage2
// target=native
//
// :1:18: error: opaque types have unknown size and therefore cannot be directly embedded in unions
// :6:39: note: opaque declared here
