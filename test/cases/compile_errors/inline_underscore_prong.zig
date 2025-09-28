const E = enum(u8) { a, b, c, d, _ };
pub export fn entry() void {
    var x: E = .a;
    switch (x) {
        inline .a, .b => |aorb| @compileLog(aorb),
        .c, .d => |cord| @compileLog(cord),
        inline _ => {},
    }
}

// error
//
// :7:16: error: cannot inline '_' prong
