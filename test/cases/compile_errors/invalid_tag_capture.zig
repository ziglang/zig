const E = enum { a, b, c, d };
pub export fn entry() void {
    var x: E = .a;
    switch (x) {
        inline .a, .b => |aorb, d| @compileLog(aorb, d),
        inline .c, .d => |*cord| @compileLog(cord),
    }
}

// error
// backend=stage2
// target=native
//
// :5:33: error: cannot capture tag of non-union type 'tmp.E'
// :1:11: note: enum declared here
