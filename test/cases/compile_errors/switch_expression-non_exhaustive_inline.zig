const E = enum(u8) {
    a,
    b,
    _,
};

export fn f(e: E) void {
    switch (e) {
        .a => {},
        inline _ => {},
    }
}

export fn g(e: E) void {
    switch (e) {
        .a => {},
        else => {},
        inline _ => {},
    }
}

// error
//
// :10:16: error: cannot inline '_' prong
// :18:16: error: cannot inline '_' prong
