fn foo() void;
export fn entry() void {
    foo();
}

// error
// backend=stage1
// target=native
//
// tmp.zig:1:1: error: non-extern function has no body
