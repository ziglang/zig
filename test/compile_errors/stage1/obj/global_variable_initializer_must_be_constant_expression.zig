extern fn foo() i32;
const x = foo();
export fn entry() i32 { return x; }

// global variable initializer must be constant expression
//
// tmp.zig:2:11: error: unable to evaluate constant expression
