const Foo = enum {};

// error
// backend=stage1
// target=native
//
// tmp.zig:1:13: error: enum declarations must have at least one tag
