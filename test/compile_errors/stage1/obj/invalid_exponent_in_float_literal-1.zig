fn main() void {
    var bad: f128 = 0x1.0p1ab1;
    _ = bad;
}

// invalid exponent in float literal - 1
//
// tmp.zig:2:21: error: expected expression, found 'invalid bytes'
// tmp.zig:2:28: note: invalid byte: 'a'
