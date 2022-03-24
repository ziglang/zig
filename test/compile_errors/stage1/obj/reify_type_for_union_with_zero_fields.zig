const Untagged = @Type(.{
    .Union = .{
        .layout = .Auto,
        .tag_type = null,
        .fields = &.{},
        .decls = &.{},
    },
});
export fn entry() void {
    _ = Untagged{};
}

// @Type for union with zero fields
//
// tmp.zig:1:25: error: unions must have 1 or more fields
