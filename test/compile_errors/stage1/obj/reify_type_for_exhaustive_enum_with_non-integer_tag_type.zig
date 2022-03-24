const Tag = @Type(.{
    .Enum = .{
        .layout = .Auto,
        .tag_type = bool,
        .fields = &.{},
        .decls = &.{},
        .is_exhaustive = false,
    },
});
export fn entry() void {
    _ = @intToEnum(Tag, 0);
}

// @Type for exhaustive enum with non-integer tag type
//
// tmp.zig:1:20: error: Type.Enum.tag_type must be an integer type, not 'bool'
