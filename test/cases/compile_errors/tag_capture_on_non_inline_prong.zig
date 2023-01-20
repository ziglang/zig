const E = enum { a, b, c, d };
pub export fn entry() void {
    var x: E = .a;
    switch (x) {
        .a, .b => |aorb, d| @compileLog(aorb, d),
        inline .c, .d => |*cord| @compileLog(cord),
    }
}

// error
// backend=stage2
// target=native
//
// :5:26: error: tag capture on non-inline prong
