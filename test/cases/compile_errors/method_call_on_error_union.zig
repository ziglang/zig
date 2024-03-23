const X = struct {
    fn init() !X {
        return error.a;
    }

    fn a(x: X) void {
        _ = x;
    }
};

export fn entry() void {
    const x = X.init();
    x.a();
}

// error
// backend=stage2
// target=native
//
// :13:6: error: no field or member function named 'a' in '@typeInfo(@typeInfo(@TypeOf(tmp.X.init)).Fn.return_type.?).ErrorUnion.error_set!tmp.X'
// :13:6: note: consider using 'try', 'catch', or 'if'
