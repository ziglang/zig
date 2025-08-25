fn main() void {
    var bad: f128 = 0x1.0p1ab1;
    _ = bad;
}

// error
// backend=stage2
// target=native
//
// :2:28: error: invalid digit 'a' in exponent
