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
// :2:5: error: duplicate union member name 'foo'
// :3:5: note: duplicate name here
// :1:11: note: union declared here
