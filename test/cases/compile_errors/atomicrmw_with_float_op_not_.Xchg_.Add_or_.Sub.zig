export fn entry() void {
    var x: f32 = 0;
    _ = @atomicRmw(f32, &x, .And, 2, .SeqCst);
}

// error
// backend=stage2
// target=native
//
// :3:30: error: @atomicRmw with float only allowed with .Xchg, .Add, and .Sub
