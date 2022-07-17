fn main() void {
    var bad: u128 = 0x0010_;
    _ = bad;
}

// error
// backend=stage2
// target=native
//
// :2:21: error: expected expression, found 'invalid bytes'
// :2:28: note: invalid byte: ';'
