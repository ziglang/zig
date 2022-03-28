const U = union {
    a: void,
    b: u64,
};
comptime {
    var u: U = .{.a = {}};
    const v = u.b;
    _ = v;
}

// use of non-active union field - 1
//
// :7:16: error: access of inactive union field
