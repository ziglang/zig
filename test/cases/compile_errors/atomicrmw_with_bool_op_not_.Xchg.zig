export fn entry() void {
    var x = false;
    _ = @atomicRmw(bool, &x, .Add, true, .seq_cst);
}

// error
// backend=stage2
// target=native
//
// :3:31: error: @atomicRmw with bool only allowed with .Xchg
