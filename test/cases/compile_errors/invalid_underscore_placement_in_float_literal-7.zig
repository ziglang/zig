fn main() void {
    var bad: f128 = 1.0e-1_;
    _ = bad;
}

// error
// backend=stage2
// target=native
//
// :2:27: error: trailing digit separator
