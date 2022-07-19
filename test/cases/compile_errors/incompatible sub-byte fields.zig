const A = packed struct {
    a: u2,
    b: u6,
};
const B = packed struct {
    q: u8,
    a: u2,
    b: u6,
};
export fn entry() void {
    var a = A{ .a = 2, .b = 2 };
    var b = B{ .q = 22, .a = 3, .b = 2 };
    var t: usize = 0;
    const ptr = switch (t) {
        0 => &a.a,
        1 => &b.a,
        else => unreachable,
    };
    if (ptr.* == 2) {
        @compileError("wrong compile error");
    }
}
// error
// backend=stage2
// target=native
//
// :14:17: error: incompatible types: '*align(0:0:1) u2' and '*align(2:8:2) u2'
