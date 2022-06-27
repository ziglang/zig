const @"u8" = u16;
export fn entry() void {
    const a: u8 = 300;
    _ = a;
}

// error
// backend=stage2
// target=native
//
// :3:19: error: type 'u8' cannot represent integer value '300'
