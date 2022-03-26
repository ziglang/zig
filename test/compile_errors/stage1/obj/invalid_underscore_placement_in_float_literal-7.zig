fn main() void {
    var bad: f128 = 1.0e-1_;
    _ = bad;
}

// invalid underscore placement in float literal - 7
//
// tmp.zig:2:21: error: expected expression, found 'invalid bytes'
// tmp.zig:2:28: note: invalid byte: ';'
