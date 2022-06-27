const Foo = union {};

// error
// backend=stage2
// target=native
//
// :1:13: error: union declarations must have at least one tag
