fn main() void {
    var bad: f128 = 0_x0.0;
    _ = bad;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:21: error: expected expression, found 'invalid bytes'
// tmp.zig:2:23: note: invalid byte: 'x'
