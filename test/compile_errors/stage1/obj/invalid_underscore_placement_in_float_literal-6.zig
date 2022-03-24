fn main() void {
    var bad: f128 = 1.0e-_1;
    _ = bad;
}

// invalid underscore placement in float literal - 6
//
// tmp.zig:2:21: error: expected expression, found 'invalid bytes'
// tmp.zig:2:26: note: invalid byte: '_'
