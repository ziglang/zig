fn main() void {
    var bad: f128 = 0x0.0_p1;
    _ = bad;
}

// invalid underscore placement in float literal - 14
//
// tmp.zig:2:21: error: expected expression, found 'invalid bytes'
// tmp.zig:2:27: note: invalid byte: 'p'
