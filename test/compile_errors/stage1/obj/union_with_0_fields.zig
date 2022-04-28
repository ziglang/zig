const Foo = union {};

// error
// backend=stage1
// target=native
//
// tmp.zig:1:13: error: union declarations must have at least one tag
