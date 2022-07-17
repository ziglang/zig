const Foo = enum {};

// error
// backend=stage2
// target=native
//
// :1:13: error: enum declarations must have at least one tag
