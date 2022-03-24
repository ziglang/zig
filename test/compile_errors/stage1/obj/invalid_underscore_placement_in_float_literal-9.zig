fn main() void {
    var bad: f128 = 1__0.0e-1;
    _ = bad;
}

// invalid underscore placement in float literal - 9
//
// tmp.zig:2:21: error: expected expression, found 'invalid bytes'
// tmp.zig:2:23: note: invalid byte: '_'
