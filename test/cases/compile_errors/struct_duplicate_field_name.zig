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
// :2:5: error: duplicate struct field: 'foo'
// :3:5: note: other field here
// :1:11: note: struct declared here
