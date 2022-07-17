fn main() void {
    var bad: f128 = 0_x0.0;
    _ = bad;
}

// error
// backend=stage2
// target=native
//
// :2:21: error: expected expression, found 'invalid bytes'
// :2:23: note: invalid byte: 'x'
