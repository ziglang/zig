const U = union(enum) {
    int: isize,
    float: f64,
};

export fn entry() void {
    const f = U{ .int = 20 };
    _ = f.float();
}

// error
// backend=stage2
// target=native
//
// :8:10: error: access of union field 'float' while field 'int' is active
// :1:11: note: union declared here
