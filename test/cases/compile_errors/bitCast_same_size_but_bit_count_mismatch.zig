export fn entry(byte: u8) void {
    var oops = @bitCast(u7, byte);
    _ = oops;
}

// error
// backend=stage2
// target=native
//
// :2:16: error: @bitCast size mismatch: destination type 'u7' has 7 bits but source type 'u8' has 8 bits
