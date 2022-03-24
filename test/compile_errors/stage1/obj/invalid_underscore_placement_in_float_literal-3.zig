fn main() void {
    var bad: f128 = 0.0_;
    _ = bad;
}

// invalid underscore placement in float literal - 3
//
// tmp.zig:2:21: error: expected expression, found 'invalid bytes'
// tmp.zig:2:25: note: invalid byte: ';'
