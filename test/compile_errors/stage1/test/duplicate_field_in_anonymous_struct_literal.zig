export fn entry() void {
    const anon = .{
        .inner = .{
            .a = .{
                .something = "text",
            },
            .a = .{},
        },
    };
    _ = anon;
}

// error
// backend=stage1
// target=native
// is_test=1
//
// tmp.zig:7:13: error: duplicate field
// tmp.zig:4:13: note: other field here
