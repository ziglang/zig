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
//
// :8:5: error: cannot assign to constant
