const Tag = @Type(.{
    .@"enum" = .{
        .tag_type = u2,
        .fields = &.{
            .{ .name = "signed", .value = 0 },
            .{ .name = "unsigned", .value = 1 },
            .{ .name = "arst", .value = 2 },
        },
        .decls = &.{},
        .is_exhaustive = true,
    },
});
const Tagged = @Type(.{
    .@"union" = .{
        .layout = .auto,
        .tag_type = Tag,
        .fields = &.{
            .{ .name = "signed", .type = i32, .alignment = @alignOf(i32) },
            .{ .name = "unsigned", .type = u32, .alignment = @alignOf(u32) },
        },
        .decls = &.{},
    },
});
export fn entry() void {
    var tagged = Tagged{ .signed = -1 };
    tagged = .{ .unsigned = 1 };
}

// error
// backend=stage2
// target=native
//
// :13:16: error: enum fields missing in union
// :1:13: note: field 'arst' missing, declared here
// :1:13: note: enum declared here
