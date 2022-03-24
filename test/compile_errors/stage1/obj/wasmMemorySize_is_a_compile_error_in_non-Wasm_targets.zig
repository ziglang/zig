export fn foo() void {
    _ = @wasmMemorySize(0);
    return;
}

// wasmMemorySize is a compile error in non-Wasm targets
//
// tmp.zig:2:9: error: @wasmMemorySize is a wasm32 feature only
