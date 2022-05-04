const A = enum {
    a,
    b,
    _ = 1,
};
const B = enum {
    a,
    b,
    _,
};
comptime { _ = A; _ = B; }

// error
// backend=stage1
// target=native
// is_test=1
//
// tmp.zig:4:9: error: '_' is used to mark an enum as non-exhaustive and cannot be assigned a value
// tmp.zig:6:11: error: non-exhaustive enum missing integer tag type
// tmp.zig:9:5: note: marked non-exhaustive here
