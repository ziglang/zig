export fn entry(byte: u8) void {
    var oops: u7 = @bitCast(byte);
    _ = oops;
}

// error
// backend=stage2
// target=native
//
// :2:20: error: @bitCast size mismatch: destination type 'u7' has 7 bits but source type 'u8' has 8 bits
