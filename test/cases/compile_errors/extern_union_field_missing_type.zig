const Letter = extern union {
    A,
};
export fn entry() void {
    const a: Letter = .{ .A = {} };
    _ = a;
}

// error
// backend=stage2
// target=native
//
// :2:5: error: union field missing type
