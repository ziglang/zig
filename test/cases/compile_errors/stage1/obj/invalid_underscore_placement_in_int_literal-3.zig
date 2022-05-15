fn main() void {
    var bad: u128 = 0o0010_;
    _ = bad;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:21: error: expected expression, found 'invalid bytes'
// tmp.zig:2:28: note: invalid byte: ';'
