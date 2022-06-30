fn main() void {
    var bad: f128 = 0x1.0p1ab1;
    _ = bad;
}

// error
// backend=stage2
// target=native
//
// :2:21: error: expected expression, found 'invalid bytes'
// :2:28: note: invalid byte: 'a'
