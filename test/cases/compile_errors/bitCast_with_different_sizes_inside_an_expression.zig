export fn entry() void {
    var foo = (@as(u8, @bitCast(@as(f32, 1.0))) == 0xf);
    _ = foo;
}

// error
// backend=stage2
// target=native
//
// :2:24: error: @bitCast size mismatch: destination type 'u8' has 8 bits but source type 'f32' has 32 bits
