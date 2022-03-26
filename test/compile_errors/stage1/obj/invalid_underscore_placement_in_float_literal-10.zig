fn main() void {
    var bad: f128 = 1.0__0e-1;
    _ = bad;
}

// invalid underscore placement in float literal - 10
//
// tmp.zig:2:21: error: expected expression, found 'invalid bytes'
// tmp.zig:2:25: note: invalid byte: '_'
