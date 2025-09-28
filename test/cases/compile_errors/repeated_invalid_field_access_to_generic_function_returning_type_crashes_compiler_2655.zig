pub fn A() type {
    return Q;
}
test "1" {
    _ = A().a;
    _ = A().a;
}

// error
// is_test=true
//
// :2:12: error: use of undeclared identifier 'Q'
