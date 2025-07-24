const E = enum(u8) {
    a,
    b,
    c,
    d,
};
export fn entry() void {
    var x: E = .a;
    _ = @atomicRmw(E, &x, .Add, .b, .seq_cst);
}

// error
//
// :9:20: error: expected integer, float, packed struct, or pointer type; found 'tmp.E'
// :9:20: note: @atomicRmw with enum only allowed with .Xchg
// :1:11: note: enum declared here
