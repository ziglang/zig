extern fn foo() align(3) void;
export fn entry() void {
    return foo();
}

// error
// backend=stage2
// target=native
//
// :1:23: error: alignment value '3' is not a power of two
