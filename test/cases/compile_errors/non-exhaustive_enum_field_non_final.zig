const B = enum(u1) {
    a,
    _,
    b,
};

// error
//
// :3:5: error: '_' field of non-exhaustive enum must be last
