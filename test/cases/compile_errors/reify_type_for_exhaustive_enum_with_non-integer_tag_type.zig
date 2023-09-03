const Tag = @Type(.{
    .Enum = .{
        .tag_type = bool,
        .fields = &.{},
        .decls = &.{},
        .is_exhaustive = false,
    },
});
export fn entry() void {
    _ = @as(Tag, @enumFromInt(0));
}

// error
// backend=stage2
// target=native
//
// :1:13: error: Type.Enum.tag_type must be an integer type
