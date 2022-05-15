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
// backend=stage1
// target=native
//
// tmp.zig:2:16: error: use of undefined value here causes undefined behavior
// tmp.zig:5:16: error: use of undefined value here causes undefined behavior
