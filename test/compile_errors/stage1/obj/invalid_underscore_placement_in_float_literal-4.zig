fn main() void {
    var bad: f128 = 1.0e_1;
    _ = bad;
}

// invalid underscore placement in float literal - 4
//
// tmp.zig:2:21: error: expected expression, found 'invalid bytes'
// tmp.zig:2:25: note: invalid byte: '_'
