comptime {
    _ = @Type(.{ .array = .{ .len = 0, .child = u8, .sentinel = undefined } });
}
comptime {
    _ = @Type(.{
        .@"struct" = .{
            .fields = undefined,
            .decls = undefined,
            .is_tuple = false,
            .layout = .auto,
        },
    });
}
comptime {
    const std = @import("std");
    const fields: [1]std.builtin.Type.StructField = undefined;
    _ = @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .fields = &fields,
            .decls = &.{},
            .is_tuple = false,
        },
    });
}

// error
// backend=stage2
// target=native
//
// :2:16: error: use of undefined value here causes undefined behavior
// :5:16: error: use of undefined value here causes undefined behavior
// :17:16: error: use of undefined value here causes undefined behavior
