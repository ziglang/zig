const P = packed struct(u2) {
    a: u1,
    b: u1,
};

fn foo(p: P) void {
    switch (p) {
        .{ .a = 0, .b = 0 } => {},
        .{ .a = 1, .b = 0 }, .{ .a = 0, .b = 1 } => {},
        .{ .a = 1, .b = 1 } => {},
        else => {},
    }
}

export fn bar() void {
    foo(.{ .a = 1, .b = 1 });
}

// error
// backend=stage2
// target=native
//
// :11:14: error: unreachable else prong; all cases already handled
