fn main() void {
    var bad: u128 = 0x0010_;
    _ = bad;
}

// invalid underscore placement in int literal - 4
//
// tmp.zig:2:21: error: expected expression, found 'invalid bytes'
// tmp.zig:2:28: note: invalid byte: ';'
