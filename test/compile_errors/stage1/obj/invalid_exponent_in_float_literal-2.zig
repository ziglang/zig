fn main() void {
    var bad: f128 = 0x1.0p50F;
    _ = bad;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:21: error: expected expression, found 'invalid bytes'
// tmp.zig:2:29: note: invalid byte: 'F'
