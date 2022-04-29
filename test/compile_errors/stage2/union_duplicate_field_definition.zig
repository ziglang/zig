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
// :3:5: error: duplicate union field: 'foo'
// :2:5: note: other field here
// :1:11: note: union declared here
