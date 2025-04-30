const Tag = @Enum(.{
    .tag_type = u0,
    .fields = &.{},
    .decls = &.{},
    .is_exhaustive = true,
});
const Tagged = @Union(.{
    .layout = .auto,
    .tag_type = Tag,
    .fields = &.{
        .{ .name = "signed", .type = i32, .alignment = @alignOf(i32) },
        .{ .name = "unsigned", .type = u32, .alignment = @alignOf(u32) },
    },
    .decls = &.{},
});
export fn entry() void {
    const tagged: Tagged = undefined;
    _ = tagged;
}

// error
// backend=stage2
// target=native
//
// :7:16: error: no field named 'signed' in enum 'tmp.Tag'
// :1:13: note: enum declared here
