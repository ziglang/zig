export fn entry() void {
    var x = false;
    _ = @atomicRmw(bool, &x, .Add, true, .SeqCst);
}

// atomicrmw with bool op not .Xchg
//
// tmp.zig:3:30: error: @atomicRmw with bool only allowed with .Xchg
