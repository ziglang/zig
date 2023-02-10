fn main() void {
    var bad: f128 = 1.0e-1__0;
    _ = bad;
}

// error
// backend=stage2
// target=native
//
// :2:28: error: repeated digit separator
