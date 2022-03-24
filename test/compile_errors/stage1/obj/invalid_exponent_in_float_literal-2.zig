fn main() void {
    var bad: f128 = 0x1.0p50F;
    _ = bad;
}

// invalid exponent in float literal - 2
//
// tmp.zig:2:21: error: expected expression, found 'invalid bytes'
// tmp.zig:2:29: note: invalid byte: 'F'
