const Tag = @Type(.{
    .Enum = .{
        .layout = .Auto,
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
    .Union = .{
        .layout = .Auto,
        .tag_type = Tag,
        .fields = &.{
            .{ .name = "signed", .field_type = i32, .alignment = @alignOf(i32) },
            .{ .name = "unsigned", .field_type = u32, .alignment = @alignOf(u32) },
        },
        .decls = &.{},
    },
});
export fn entry() void {
    var tagged = Tagged{ .signed = -1 };
    tagged = .{ .unsigned = 1 };
}

// error
// backend=stage1
// target=native
//
// tmp.zig:14:23: error: enum field missing: 'arst'
