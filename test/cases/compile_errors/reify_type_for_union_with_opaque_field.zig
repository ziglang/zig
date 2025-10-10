const Untagged = @Union(.{
    .layout = .auto,
    .tag_type = null,
    .fields = &.{
        .{ .name = "foo", .type = opaque {}, .alignment = 1 },
    },
    .decls = &.{},
});
export fn entry() usize {
    return @sizeOf(Untagged);
}

// error
//
// :1:18: error: opaque types have unknown size and therefore cannot be directly embedded in unions
// :5:35: note: opaque declared here
