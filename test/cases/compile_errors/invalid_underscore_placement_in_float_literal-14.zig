fn main() void {
    var bad: f128 = 0x0.0_p1;
    _ = bad;
}

// error
// backend=stage2
// target=native
//
// :2:21: error: expected expression, found 'invalid bytes'
// :2:27: note: invalid byte: 'p'
