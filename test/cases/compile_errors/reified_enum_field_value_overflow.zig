comptime {
    const E = @Type(.{ .Enum = .{
        .tag_type = u1,
        .fields = &.{
            .{ .name = "f0", .value = 0 },
            .{ .name = "f1", .value = 1 },
            .{ .name = "f2", .value = 2 },
        },
        .decls = &.{},
        .is_exhaustive = true,
    } });
    _ = E;
}

// error
// target=native
// backend=stage2
//
// :2:15: error: field 'f2' with enumeration value '2' is too large for backing int type 'u1'
