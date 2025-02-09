extern fn foo() i32;
const x = foo();
export fn entry() i32 {
    return x;
}

// error
//
// :2:14: error: comptime call of extern function
// :2:14: note: initializer of container-level variable must be comptime-known
