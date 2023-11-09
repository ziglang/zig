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
// backend=stage2
// target=native
//
// :4:14: error: duplicate field
// :7:14: note: other field here
