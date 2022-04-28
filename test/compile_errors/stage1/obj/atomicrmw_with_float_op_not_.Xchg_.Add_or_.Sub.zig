export fn entry() void {
    var x: f32 = 0;
    _ = @atomicRmw(f32, &x, .And, 2, .SeqCst);
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:29: error: @atomicRmw with float only allowed with .Xchg, .Add and .Sub
