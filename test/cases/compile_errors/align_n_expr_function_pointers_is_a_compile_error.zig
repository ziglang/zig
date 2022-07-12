export fn foo() align(1) void {
    return;
}

// error
// backend=stage2
// target=wasm32-freestanding-none
//
// :1:8: error: 'align' is not allowed on functions in wasm
