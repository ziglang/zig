export fn entry() void {
    const S = struct {
        fn a() void {
            var x: u24 = 42;
            _ = &x;
            _ = x >> 24;
        }
        fn b() void {
            var x: u24 = 42;
            _ = &x;
            _ = x << 24;
        }
        fn c() void {
            var x: u24 = 42;
            _ = &x;
            _ = @shlExact(x, 24);
        }
        fn d() void {
            var x: u24 = 42;
            _ = &x;
            _ = @shrExact(x, 24);
        }
    };
    S.a();
    S.b();
    S.c();
    S.d();
}

// error
// backend=stage2
// target=native
//
// :6:22: error: shift amount '24' is too large for operand type 'u24'
// :11:22: error: shift amount '24' is too large for operand type 'u24'
// :16:30: error: shift amount '24' is too large for operand type 'u24'
// :21:30: error: shift amount '24' is too large for operand type 'u24'
