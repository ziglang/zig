const S = struct {
    s: noreturn,
};
comptime {
    _ = @typeInfo(S);
}

// error
//
// :2:8: error: struct fields cannot be 'noreturn'
