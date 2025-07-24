export fn entry() void {
    var x: u32 = 0;
    @atomicRmw(u32, &x, .Min, 1, .monotonic);
}

// error
// target=wasm32-freestanding:bleeding_edge
//
// :3:16: error: @atoimcRmw(.Min) is not supported on wasm32
