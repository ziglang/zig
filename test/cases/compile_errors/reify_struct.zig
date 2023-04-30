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
            .default_value = &@as(u32, 0),
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
            .default_value = &@as(u32, 0),
            .is_comptime = true,
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
            .name = "foo",
            .type = u32,
            .default_value = null,
            .is_comptime = true,
            .alignment = 4,
        }},
        .decls = &.{},
        .is_tuple = false,
    } });
}
comptime {
    @Type(.{ .Struct = .{
        .layout = .Extern,
        .fields = &.{.{
            .name = "foo",
            .type = u32,
            .default_value = &@as(u32, 0),
            .is_comptime = true,
            .alignment = 4,
        }},
        .decls = &.{},
        .is_tuple = false,
    } });
}
comptime {
    @Type(.{ .Struct = .{
        .layout = .Packed,
        .fields = &.{.{
            .name = "foo",
            .type = u32,
            .default_value = &@as(u32, 0),
            .is_comptime = true,
            .alignment = 4,
        }},
        .decls = &.{},
        .is_tuple = false,
    } });
}

// error
// backend=stage2
// target=native
//
// :2:5: error: tuple cannot have non-numeric field 'foo'
// :16:5: error: tuple field at index 0 named '3'
// :30:5: error: comptime field without default initialization value
// :44:5: error: extern tuple fields cannot be marked comptime
// :58:5: error: alignment of a packed tuple field must be set to 0
// :72:5: error: comptime field without default initialization value
// :86:5: error: extern struct fields cannot be marked comptime
// :100:5: error: alignment in a packed struct field must be set to 0
