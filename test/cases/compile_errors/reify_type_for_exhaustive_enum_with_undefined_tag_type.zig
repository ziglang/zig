const Tag = @Type(.{
    .@"enum" = .{
        .tag_type = undefined,
        .fields = &.{},
        .decls = &.{},
        .is_exhaustive = false,
    },
});
export fn entry() void {
    _ = @as(Tag, @enumFromInt(0));
}

// error
//
// :1:20: error: use of undefined value here causes illegal behavior
