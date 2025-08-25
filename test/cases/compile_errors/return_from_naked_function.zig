fn foo() callconv(.naked) void {
    return;
}

comptime {
    _ = &foo;
}

// error
// backend=stage2
// target=native
//
// :2:5: error: cannot return from naked function
// :2:5: note: can only return using assembly
