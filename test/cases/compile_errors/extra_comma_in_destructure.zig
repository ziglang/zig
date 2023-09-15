export fn foo() void {
    const x, const y, = .{ 1, 2 };
    _ = .{ x, y };
}

// error
// backend=stage2
// target=native
//
// :2:23: error: expected expression or var decl, found '='
