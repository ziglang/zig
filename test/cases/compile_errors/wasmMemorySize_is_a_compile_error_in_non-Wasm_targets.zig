export fn foo() void {
    _ = @wasmMemorySize(0);
    return;
}

// error
// backend=stage2
// target=x86_64-native
//
// :2:9: error: builtin @wasmMemorySize is available when targeting WebAssembly; targeted CPU architecture is x86_64
