fn main() void {
    var bad: f128 = 1.0e-1__0;
    _ = bad;
}

// invalid underscore placement in float literal - 11
//
// tmp.zig:2:21: error: expected expression, found 'invalid bytes'
// tmp.zig:2:28: note: invalid byte: '_'
