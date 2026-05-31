fn main() void {
    var bad: f128 = 0x1.0p50F;
    _ = bad;
}

// error
//
// :2:29: error: invalid digit 'F' in exponent
