export fn foo() void {
    _ = -0;
}

// error
// backend=stage2
// target=native
//
// :2:10: error: integer literal '-0' is ambiguous
// :2:10: note: use '0' for an integer zero
// :2:10: note: use '-0.0' for a floating-point signed zero
