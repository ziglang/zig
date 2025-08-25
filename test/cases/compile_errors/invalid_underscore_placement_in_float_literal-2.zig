fn main() void {
    var bad: f128 = 1_.0;
    _ = bad;
}

// error
// backend=stage2
// target=native
//
// :2:23: error: expected digit before '.'
