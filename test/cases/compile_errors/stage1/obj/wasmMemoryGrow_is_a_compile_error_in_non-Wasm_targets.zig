export fn foo() void {
    _ = @wasmMemoryGrow(0, 1);
    return;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:9: error: @wasmMemoryGrow is a wasm32 feature only
