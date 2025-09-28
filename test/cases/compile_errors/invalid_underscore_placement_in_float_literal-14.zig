fn main() void {
    var bad: f128 = 0x0.0_p1;
    _ = bad;
}

// error
//
// :2:27: error: expected digit before exponent
