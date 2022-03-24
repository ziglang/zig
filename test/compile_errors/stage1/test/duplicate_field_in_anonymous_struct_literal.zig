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

// duplicate field in anonymous struct literal
//
// tmp.zig:7:13: error: duplicate field
// tmp.zig:4:13: note: other field here
