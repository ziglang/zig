const Tag = @Type(.{
    .Enum = .{
        .layout = .Auto,
        .tag_type = u1,
        .fields = &.{},
        .decls = &.{},
        .is_exhaustive = true,
    },
});
export fn entry() void {
    _ = @intToEnum(Tag, 0);
}

// error
// backend=stage2
// target=native
//
// :1:13: error: enums must have at least one field
