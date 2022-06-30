fn foo() void;
export fn entry() void {
    foo();
}

// error
// backend=llvm
// target=native
//
// :1:1: error: non-extern function has no body
