export fn a() void {
    const S = struct {
        fn b() struct { usize, usize } {
            return .{ 0, 0 };
        }
    };
    const c, _ = S.b();
    c += 10;
}

// error
// backend=stage2
// target=native
//
// :8:7: error: cannot assign to constant
