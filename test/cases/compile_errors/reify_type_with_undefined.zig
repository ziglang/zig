comptime {
    _ = @Struct(.{
        .fields = undefined,
        .decls = undefined,
        .is_tuple = false,
        .layout = .auto,
    });
}
comptime {
    const std = @import("std");
    const fields: [1]std.builtin.Type.StructField = undefined;
    _ = @Struct(.{
        .layout = .auto,
        .fields = &fields,
        .decls = &.{},
        .is_tuple = false,
    });
}

// error
//
// :2:18: error: use of undefined value here causes illegal behavior
// :12:18: error: use of undefined value here causes illegal behavior
