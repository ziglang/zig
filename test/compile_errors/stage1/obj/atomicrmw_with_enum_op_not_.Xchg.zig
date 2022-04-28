export fn entry() void {
    const E = enum(u8) {
        a,
        b,
        c,
        d,
    };
    var x: E = .a;
    _ = @atomicRmw(E, &x, .Add, .b, .SeqCst);
}

// error
// backend=stage1
// target=native
//
// tmp.zig:9:27: error: @atomicRmw with enum only allowed with .Xchg
