export fn entry() void {
    const S = struct {
        fn a() void {
            var x: u24 = 42;
            _ = x >> 24;
        }
        fn b() void {
            var x: u24 = 42;
            _ = x << 24;
        }
        fn c() void {
            var x: u24 = 42;
            _ = @shlExact(x, 24);
        }
        fn d() void {
            var x: u24 = 42;
            _ = @shrExact(x, 24);
        }
    };
    S.a();
    S.b();
    S.c();
    S.d();
}

// shift on type with non-power-of-two size
//
// tmp.zig:5:19: error: RHS of shift is too large for LHS type
// tmp.zig:9:19: error: RHS of shift is too large for LHS type
// tmp.zig:13:17: error: RHS of shift is too large for LHS type
// tmp.zig:17:17: error: RHS of shift is too large for LHS type
