const U = union {
    foo: u32,
    foo: u32,
};

export fn entry() void {
    const u: U = .{ .foo = 100 };
    _ = u;
}

// error
// target=native
//
// :2:5: error: duplicate union field name
// :3:5: note: duplicate field here
// :1:11: note: union declared here
