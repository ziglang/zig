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

// @Type for exhaustive enum with zero fields
//
// tmp.zig:1:20: error: enums must have 1 or more fields
