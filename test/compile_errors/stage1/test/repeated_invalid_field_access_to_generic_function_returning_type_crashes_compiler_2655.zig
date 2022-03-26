pub fn A() type {
    return Q;
}
test "1" {
    _ = A().a;
    _ = A().a;
}

// repeated invalid field access to generic function returning type crashes compiler. #2655
//
// tmp.zig:2:12: error: use of undeclared identifier 'Q'
