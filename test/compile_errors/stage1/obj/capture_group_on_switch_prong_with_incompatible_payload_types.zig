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

// capture group on switch prong with incompatible payload types
//
// tmp.zig:8:20: error: capture group with incompatible types
// tmp.zig:8:9: note: type 'usize' here
// tmp.zig:8:13: note: type 'isize' here
