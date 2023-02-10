const u8 = u16;
export fn entry() void {
    const a: u8 = 300;
    _ = a;
}

// error
// backend=stage2
// target=native
//
// :1:7: error: name shadows primitive 'u8'
// :1:7: note: consider using @"u8" to disambiguate
