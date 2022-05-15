const Tag = @Type(.{
    .Enum = .{
        .layout = .Auto,
        .tag_type = undefined,
        .fields = &.{},
        .decls = &.{},
        .is_exhaustive = false,
    },
});
export fn entry() void {
    _ = @intToEnum(Tag, 0);
}

// error
// backend=stage1
// target=native
//
// tmp.zig:1:20: error: use of undefined value here causes undefined behavior
