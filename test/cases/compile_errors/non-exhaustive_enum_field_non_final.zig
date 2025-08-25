const B = enum(u1) {
    a,
    _,
    b,
};

// error
// backend=stage2
// target=native
//
// :3:5: error: '_' field of non-exhaustive enum must be last
