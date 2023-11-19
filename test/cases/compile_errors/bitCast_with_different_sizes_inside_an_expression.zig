export fn entry() void {
    const f: f32 = 1.0;
    const foo = (@as(u8, @bitCast(f)) == 0xf);
    _ = foo;
}

// error
// backend=stage2
// target=native
//
// :3:26: error: @bitCast size mismatch: destination type 'u8' has 8 bits but source type 'f32' has 32 bits
