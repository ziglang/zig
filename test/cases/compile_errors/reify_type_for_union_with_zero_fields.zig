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
// backend=stage2
// target=native
//
// :1:18: error: unions must have at least one field
