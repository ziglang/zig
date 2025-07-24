export fn entry() void {
    var x: u32 = 0;
    _ = @atomicLoad(u32, &x, .monotonic);
}

// error
// target=wasm32-freestanding:baseline
//
// :3:16: error: 4-byte @atomicLoad on wasm32 requires the following missing CPU features: atomics
