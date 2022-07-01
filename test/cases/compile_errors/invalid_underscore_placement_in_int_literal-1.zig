fn main() void {
    var bad: u128 = 0010_;
    _ = bad;
}

// error
// backend=llvm
// target=native
//
// :2:21: error: expected expression, found 'invalid bytes'
// :2:26: note: invalid byte: ';'
