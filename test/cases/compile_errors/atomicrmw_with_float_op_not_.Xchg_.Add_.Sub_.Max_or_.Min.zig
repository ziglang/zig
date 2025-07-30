export fn entry() void {
    var x: f32 = 0;
    _ = @atomicRmw(f32, &x, .And, 2, .seq_cst);
}

// error
//
// :3:20: error: expected integer, packed struct, or pointer type; found 'f32'
// :3:20: note: @atomicRmw with float only allowed with .Xchg, .Add, .Sub, .Max, and .Min
