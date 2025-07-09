const E = enum(u8) {
    a,
    b,
    _,
};

export fn f(e: E) void {
    switch (e) {
        .a, .b, _ => {},
        else => {},
    }
}

// error
// backend=stage2
// target=native
//
// :10:14: error: unreachable else prong; all explicit cases already handled
