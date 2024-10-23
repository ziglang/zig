const Tag = @Type(.{
    .@"enum" = .{
        .tag_type = u1,
        .fields = &.{
            .{ .name = "signed", .value = 0 },
            .{ .name = "unsigned", .value = 1 },
        },
        .decls = &.{},
        .is_exhaustive = true,
    },
});
const Tagged = @Type(.{
    .@"union" = .{
        .layout = .auto,
        .tag_type = Tag,
        .fields = &.{},
        .decls = &.{},
    },
});
export fn entry() void {
    const tagged: Tagged = undefined;
    _ = tagged;
}

// error
// backend=stage2
// target=native
//
// :12:16: error: enum fields missing in union
// :1:13: note: field 'signed' missing, declared here
// :1:13: note: field 'unsigned' missing, declared here
// :1:13: note: enum declared here
