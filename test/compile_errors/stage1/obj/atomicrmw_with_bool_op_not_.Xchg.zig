export fn entry() void {
    var x = false;
    _ = @atomicRmw(bool, &x, .Add, true, .SeqCst);
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:30: error: @atomicRmw with bool only allowed with .Xchg
