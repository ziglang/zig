const A = struct {
    a: u8,
    bytes: [@sizeOf(A)]u8,
};

comptime {
    _ = A;
}

// error
//
// :1:11: error: struct 'tmp.A' depends on itself
