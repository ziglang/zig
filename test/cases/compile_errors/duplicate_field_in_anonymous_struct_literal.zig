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
// :4:14: error: duplicate struct field name
// :7:14: note: duplicate name here
// :3:19: note: struct declared here
