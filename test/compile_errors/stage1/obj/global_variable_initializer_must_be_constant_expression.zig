extern fn foo() i32;
const x = foo();
export fn entry() i32 { return x; }

// error
// backend=stage1
// target=native
//
// tmp.zig:2:11: error: unable to evaluate constant expression
