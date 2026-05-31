fn foo() void;
export fn entry() void {
    foo();
}

// error
//
// :1:1: error: non-extern function has no body
