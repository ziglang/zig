export fn a(value: u32) bool {
    return 1 < value < 1000;
}

// error
// backend=stage2
// target=native
//
// :2:22: error: comparison operators cannot be chained
