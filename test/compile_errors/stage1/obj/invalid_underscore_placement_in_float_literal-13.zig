fn main() void {
    var bad: f128 = 0x_0.0;
    _ = bad;
}

// invalid underscore placement in float literal - 13
//
// tmp.zig:2:21: error: expected expression, found 'invalid bytes'
// tmp.zig:2:23: note: invalid byte: '_'
