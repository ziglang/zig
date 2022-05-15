fn main() void {
    var bad: f128 = 1.0__0e-1;
    _ = bad;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:21: error: expected expression, found 'invalid bytes'
// tmp.zig:2:25: note: invalid byte: '_'
