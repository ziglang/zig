const Union = union(enum) {
    A: usize,
    B: isize,
};
comptime {
    var u = Union{ .A = 8 };
    switch (u) {
        .A, .B => |e| {
            _ = e;
            unreachable;
        },
    }
}

// error
// backend=stage2
// target=native
//
// :8:20: error: capture group with incompatible types
// :8:10: note: type 'usize' here
// :8:14: note: type 'isize' here
