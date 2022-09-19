fn main() void {
    var bad: f128 = 0._0;
    _ = bad;
}

// error
// backend=stage2
// target=native
//
// :2:23: error: expected digit before digit separator
