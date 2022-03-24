const Tag = @Type(.{
    .Enum = .{
        .layout = .Auto,
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
    .Union = .{
        .layout = .Auto,
        .tag_type = Tag,
        .fields = &.{
            .{ .name = "signed", .field_type = i32, .alignment = @alignOf(i32) },
            .{ .name = "unsigned", .field_type = u32, .alignment = @alignOf(u32) },
            .{ .name = "arst", .field_type = f32, .alignment = @alignOf(f32) },
        },
        .decls = &.{},
    },
});
export fn entry() void {
    var tagged = Tagged{ .signed = -1 };
    tagged = .{ .unsigned = 1 };
}

// @Type for tagged union with extra union field
//
// tmp.zig:13:23: error: enum field not found: 'arst'
// tmp.zig:1:20: note: enum declared here
