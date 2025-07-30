export fn entry() void {
    var x = false;
    _ = @atomicRmw(bool, &x, .Add, true, .seq_cst);
}

// error
//
// :3:20: error: expected integer, float, packed struct, or pointer type; found 'bool'
// :3:20: note: @atomicRmw with bool only allowed with .Xchg
