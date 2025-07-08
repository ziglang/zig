export fn f() void {
    const P = struct { a: u1, b: u1 };
    const p = P{ .a = 0, .b = 0 };
    switch (p) {
        .{ .a = 0, .b = 0 } => {},
        else => unreachable,
    }
}

// error
// backend=stage2
// target=native
//
// :4:13: error: switch on struct requires 'packed' layout; type 'tmp.f.P' has 'auto' layout
// :2:15: note: consider 'packed struct' here
