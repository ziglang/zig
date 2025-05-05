const S = struct {
    data: [1 << 32]u8,
};

const T = struct {
    d1: [1 << 31]u8,
    d2: [1 << 31]u8,
};

const U = union {
    a: u32,
    b: [1 << 32]u8,
};

const V = union {
    a: u32,
    b: T,
};

comptime {
    _ = S;
    _ = T;
    _ = U;
    _ = V;
}

// error
//
// :1:11: error: struct layout requires size 4294967296, this compiler implementation supports up to 4294967295
// :5:11: error: struct layout requires size 4294967296, this compiler implementation supports up to 4294967295
// :10:11: error: union layout requires size 4294967300, this compiler implementation supports up to 4294967295
