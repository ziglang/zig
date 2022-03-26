export fn entry() void {
    var x: f32 = 0;
    _ = @cmpxchgWeak(f32, &x, 1, 2, .SeqCst, .SeqCst);
}

// cmpxchg with float
//
// tmp.zig:3:22: error: expected bool, integer, enum or pointer type, found 'f32'
