export fn entry() void {
    _ = @Type(.{ .Struct = .{ .layout = .Packed, .fields = &.{
        .{ .name = "one", .field_type = u4, .default_value = null, .is_comptime = false, .alignment = 2 },
    }, .decls = &.{}, .is_tuple = false } });
}

// error
// backend=stage2
// target=native
//
// :2:9: error: alignment in a packed struct field must be set to 0
