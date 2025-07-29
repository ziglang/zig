export fn entry() void {
    _ = @Type(.{ .@"struct" = .{ .layout = .@"packed", .fields = &.{
        .{ .name = "one", .type = u4, .default_value_ptr = null, .is_comptime = false, .alignment = 2 },
    }, .decls = &.{}, .is_tuple = false } });
}

// error
//
// :2:9: error: alignment in a packed struct field must be set to 0
