comptime {
    @Type(.{ .Struct = .{
        .layout = .Auto,
        .fields = &.{.{
            .name = "foo",
            .type = u32,
            .default_value = null,
            .is_comptime = false,
            .alignment = 4,
        }},
        .decls = &.{},
        .is_tuple = true,
    } });
}
comptime {
    @Type(.{ .Struct = .{
        .layout = .Auto,
        .fields = &.{.{
            .name = "3",
            .type = u32,
            .default_value = null,
            .is_comptime = false,
            .alignment = 4,
        }},
        .decls = &.{},
        .is_tuple = true,
    } });
}
comptime {
    @Type(.{ .Struct = .{
        .layout = .Auto,
        .fields = &.{.{
            .name = "0",
            .type = u32,
            .default_value = null,
            .is_comptime = true,
            .alignment = 4,
        }},
        .decls = &.{},
        .is_tuple = true,
    } });
}
comptime {
    @Type(.{ .Struct = .{
        .layout = .Extern,
        .fields = &.{.{
            .name = "0",
            .type = u32,
            .default_value = null,
            .is_comptime = true,
            .alignment = 4,
        }},
        .decls = &.{},
        .is_tuple = true,
    } });
}
comptime {
    @Type(.{ .Struct = .{
        .layout = .Packed,
        .fields = &.{.{
            .name = "0",
            .type = u32,
            .default_value = null,
            .is_comptime = true,
            .alignment = 4,
        }},
        .decls = &.{},
        .is_tuple = true,
    } });
}

// error
// backend=stage2
// target=native
//
// :2:5: error: tuple cannot have non-numeric field 'foo'
// :16:5: error: tuple field 3 exceeds tuple field count
// :30:5: error: comptime field without default initialization value
// :44:5: error: extern struct fields cannot be marked comptime
// :58:5: error: alignment in a packed struct field must be set to 0
