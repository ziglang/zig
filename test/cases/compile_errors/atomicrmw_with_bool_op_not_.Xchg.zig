export fn entry() void {
    var x = false;
    _ = @atomicRmw(bool, &x, .Add, true, .seq_cst);
}

// error
//
// :3:31: error: @atomicRmw with bool only allowed with .Xchg
