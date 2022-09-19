fn main() void {
    var bad: f128 = 0.0_;
    _ = bad;
}

// error
// backend=stage2
// target=native
//
// :2:24: error: trailing digit separator
