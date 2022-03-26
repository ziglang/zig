export fn foo() void {
    _ = @wasmMemoryGrow(0, 1);
    return;
}

// wasmMemoryGrow is a compile error in non-Wasm targets
//
// tmp.zig:2:9: error: @wasmMemoryGrow is a wasm32 feature only
