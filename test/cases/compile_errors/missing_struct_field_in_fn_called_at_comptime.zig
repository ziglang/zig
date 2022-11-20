const S = struct {
    a: u32,
    b: comptime_int,
    fn init() S {
        return .{ .a = 1 };
    }
};
comptime {
    _ = S.init();
}

// error
// backend=stage2
// target=native
//
// :5:17: error: missing struct field: b
// :1:11: note: struct 'tmp.S' declared here
// :9:15: note: called from here
