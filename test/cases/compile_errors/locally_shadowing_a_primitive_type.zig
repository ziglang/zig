export fn foo() void {
    const u8 = u16;
    const a: u8 = 300;
    _ = a;
}

// error
// backend=stage2
// target=native
//
// :2:11: error: name shadows primitive 'u8'
// :2:11: note: consider using @"u8" to disambiguate
