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

// error
// backend=stage1
// target=native
//
// tmp.zig:1:25: error: unions must have 1 or more fields
