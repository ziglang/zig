comptime {
    _ = @Type(.{ .Array = .{ .len = 0, .child = u8, .sentinel = undefined } });
}
comptime {
    _ = @Type(.{
        .Struct = .{
            .fields = undefined,
            .decls = undefined,
            .is_tuple = false,
            .layout = .Auto,
        },
    });
}

// error
// backend=stage2
// target=native
//
// :2:9: error: use of undefined value here causes undefined behavior
// :5:9: error: use of undefined value here causes undefined behavior
