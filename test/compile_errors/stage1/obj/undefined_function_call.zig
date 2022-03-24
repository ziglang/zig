export fn a() void {
    b();
}

// undefined function call
//
// tmp.zig:2:5: error: use of undeclared identifier 'b'
