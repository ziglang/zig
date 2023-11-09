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
// :4:16: error: duplicate field
// :7:16: note: other field here
