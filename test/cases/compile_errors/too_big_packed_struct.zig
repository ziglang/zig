pub export fn entry() void {
    const T = packed struct {
        a: u65535,
        b: u65535,
    };
    @compileLog(@sizeOf(T));
}

// error
// backend=stage2
// target=native
//
// :2:22: error: size of packed struct '131070' exceeds maximum bit width of 65535
