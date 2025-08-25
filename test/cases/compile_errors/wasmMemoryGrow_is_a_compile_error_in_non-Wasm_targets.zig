export fn foo() void {
    _ = @wasmMemoryGrow(0, 1);
    return;
}

// error
// backend=stage2
// target=x86_64-native
//
// :2:9: error: builtin @wasmMemoryGrow is available when targeting WebAssembly; targeted CPU architecture is x86_64
