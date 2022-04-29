const @"u8" = u16;
export fn entry() void {
    const a: u8 = 300;
    _ = a;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:19: error: integer value 300 cannot be coerced to type 'u8'
