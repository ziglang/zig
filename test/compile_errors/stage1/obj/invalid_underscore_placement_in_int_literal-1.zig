fn main() void {
    var bad: u128 = 0010_;
    _ = bad;
}

// invalid underscore placement in int literal - 1
//
// tmp.zig:2:21: error: expected expression, found 'invalid bytes'
// tmp.zig:2:26: note: invalid byte: ';'
