fn main() void {
    var bad: f128 = 1.0e_1;
    _ = bad;
}

// error
// backend=stage2
// target=native
//
// :2:25: error: expected digit before digit separator
