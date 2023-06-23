extern fn foo() i32;
const x = foo();
export fn entry() i32 {
    return x;
}

// error
// backend=stage2
// target=native
//
// :2:14: error: comptime call of extern function
