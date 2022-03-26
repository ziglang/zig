export fn entry() void {
    var x: f32 = 0;
    _ = @atomicRmw(f32, &x, .And, 2, .SeqCst);
}

// atomicrmw with float op not .Xchg, .Add or .Sub
//
// tmp.zig:3:29: error: @atomicRmw with float only allowed with .Xchg, .Add and .Sub
