export fn entry(byte: u8) void {
    var oops = @bitCast(u7, byte);
    _ = oops;
}

// @bitCast same size but bit count mismatch
//
// tmp.zig:2:25: error: destination type 'u7' has 7 bits but source type 'u8' has 8 bits
