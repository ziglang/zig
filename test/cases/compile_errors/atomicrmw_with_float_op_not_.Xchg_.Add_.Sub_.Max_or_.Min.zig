export fn entry() void {
    var x: f32 = 0;
    _ = @atomicRmw(f32, &x, .And, 2, .seq_cst);
}

// error
// backend=stage2
// target=native
//
// :3:30: error: @atomicRmw with float only allowed with .Xchg, .Add, .Sub, .Max, and .Min
