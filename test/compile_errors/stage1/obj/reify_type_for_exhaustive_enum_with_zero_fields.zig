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
// backend=stage1
// target=native
//
// tmp.zig:1:20: error: enums must have 1 or more fields
