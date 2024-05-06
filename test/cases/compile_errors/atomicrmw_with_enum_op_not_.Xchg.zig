export fn entry() void {
    const E = enum(u8) {
        a,
        b,
        c,
        d,
    };
    var x: E = .a;
    _ = @atomicRmw(E, &x, .Add, .b, .seq_cst);
}

// error
// backend=stage2
// target=native
//
// :9:28: error: @atomicRmw with enum only allowed with .Xchg
