const S = struct {
    a: u8,
};

export fn u() void {
    _ = @unionInit(S, "a", 5);
}

// error
// backend=stage2
// target=native
//
// :6:20: error: expected union type, found 'tmp.S'
// :1:11: note: struct declared here
