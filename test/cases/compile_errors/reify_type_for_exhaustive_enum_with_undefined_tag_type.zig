const Tag = @Type(.{
    .Enum = .{
        .tag_type = undefined,
        .fields = &.{},
        .decls = &.{},
        .is_exhaustive = false,
    },
});
export fn entry() void {
    _ = @enumFromInt(Tag, 0);
}

// error
// backend=stage2
// target=native
//
// :1:13: error: use of undefined value here causes undefined behavior
