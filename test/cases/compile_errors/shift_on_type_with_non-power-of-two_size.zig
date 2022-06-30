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

// error
// backend=stage2
// target=native
//
// :5:22: error: shift amount '24' is too large for operand type 'u24'
// :9:22: error: shift amount '24' is too large for operand type 'u24'
// :13:30: error: shift amount '24' is too large for operand type 'u24'
// :17:30: error: shift amount '24' is too large for operand type 'u24'
