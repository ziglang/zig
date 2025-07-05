export fn f() void {
    const P = packed struct { a: u1, b: u1 };
    const p = P{ .a = 0, .b = 0 };
    switch (p) {
        .{ .a = 0, .b = 0 }....{ .a = 1, .b = 0 } => {},
        else => unreachable,
    }
}

// error
// backend=stage2
// target=native
//
// :4:13: error: ranges not allowed when switching on type 'tmp.f.P'
// :5:28: note: range here
