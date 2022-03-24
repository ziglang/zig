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

// atomicrmw with enum op not .Xchg
//
// tmp.zig:9:27: error: @atomicRmw with enum only allowed with .Xchg
