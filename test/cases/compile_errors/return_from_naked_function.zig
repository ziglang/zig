fn foo() callconv(.Naked) void {
    return;
}

comptime {
    _ = &foo;
}

// error
// backend=llvm
// target=native
//
// :2:5: error: cannot return from naked function
// :2:5: note: can only return using assembly
