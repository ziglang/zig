pub export fn entry() void {
    _ = .{ .a = 0, .a = 1 };
}

// error
// backend=stage2
// target=native
//
// :2:13: error: duplicate struct field name
// :2:21: note: duplicate name here
// :2:10: note: struct declared here
