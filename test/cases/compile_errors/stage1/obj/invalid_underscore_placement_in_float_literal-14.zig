fn main() void {
    var bad: f128 = 0x0.0_p1;
    _ = bad;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:21: error: expected expression, found 'invalid bytes'
// tmp.zig:2:27: note: invalid byte: 'p'
