const S = struct {
    foo: u32,
    foo: u32,
};

export fn entry() void {
    const s: S = .{ .foo = 100 };
    _ = s;
}

// error
// target=native
//
// :2:5: error: struct field name conflict: 'foo'
// :3:5: note: duplicate field here
// :1:11: note: struct declared here
