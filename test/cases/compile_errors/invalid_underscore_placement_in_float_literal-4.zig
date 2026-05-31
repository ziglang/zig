fn main() void {
    var bad: f128 = 1.0e_1;
    _ = bad;
}

// error
//
// :2:25: error: expected digit before digit separator
