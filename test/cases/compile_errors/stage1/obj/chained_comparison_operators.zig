export fn a(value: u32) bool {
    return 1 < value < 1000;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:22: error: comparison operators cannot be chained
