export fn foo() void {
    _ = @wasmMemorySize(0);
    return;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:9: error: @wasmMemorySize is a wasm32 feature only
