fn main() void {
    var bad: f128 = 0._0;
    _ = bad;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:21: error: expected expression, found 'invalid bytes'
// tmp.zig:2:23: note: invalid byte: '_'
