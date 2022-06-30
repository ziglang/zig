fn main() void {
    var bad: f128 = 1.0e_1;
    _ = bad;
}

// error
// backend=stage2
// target=native
//
// :2:21: error: expected expression, found 'invalid bytes'
// :2:25: note: invalid byte: '_'
