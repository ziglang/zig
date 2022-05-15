extern var foo: int = 2;

// error
// backend=stage1
// target=native
// is_test=1
//
// tmp.zig:1:23: error: extern variables have no initializers
