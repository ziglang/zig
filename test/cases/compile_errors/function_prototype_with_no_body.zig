fn foo() void;
export fn entry() void {
    foo();
}

// error
// backend=stage2
// target=native
//
// :1:1: error: non-extern function has no body
