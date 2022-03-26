fn foo() void;
export fn entry() void {
    foo();
}

// function prototype with no body
//
// tmp.zig:1:1: error: non-extern function has no body
