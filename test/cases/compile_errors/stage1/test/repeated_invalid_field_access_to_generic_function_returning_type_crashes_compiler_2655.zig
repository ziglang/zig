pub fn A() type {
    return Q;
}
test "1" {
    _ = A().a;
    _ = A().a;
}

// error
// backend=stage1
// target=native
// is_test=1
//
// tmp.zig:2:12: error: use of undeclared identifier 'Q'
