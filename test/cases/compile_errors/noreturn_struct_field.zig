const S = struct {
    s: noreturn,
};
comptime {
    _ = @typeInfo(S);
}

// error
// backend=stage2
// target=native
//
// :2:8: error: struct fields cannot be 'noreturn'
