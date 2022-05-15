export fn foo() align(1) void {
    return;
}

// error
// backend=stage1
// target=wasm32-freestanding-none
//
// tmp.zig:1:23: error: align(N) expr is not allowed on function prototypes in wasm32/wasm64
