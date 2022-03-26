fn main() void {
    var bad: f128 = 0_x0.0;
    _ = bad;
}

// invalid underscore placement in float literal - 12
//
// tmp.zig:2:21: error: expected expression, found 'invalid bytes'
// tmp.zig:2:23: note: invalid byte: 'x'
