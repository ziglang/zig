fn main() void {
    var bad: f128 = 1_x0.0;
    _ = bad;
}

// error
// backend=stage2
// target=native
//
// :2:23: error: invalid digit 'x' for decimal base
