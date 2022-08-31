fn main() void {
    var bad: f128 = 1.0__0e-1;
    _ = bad;
}

// error
// backend=stage2
// target=native
//
// :2:25: error: repeated digit separator
