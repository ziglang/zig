fn main() void {
    var bad: f128 = 1__0.0e-1;
    _ = bad;
}

// error
// backend=stage2
// target=native
//
// :2:23: error: repeated digit separator
