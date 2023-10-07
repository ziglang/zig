export fn entry() void {
    const x = []u8{ 1, 2 };
    _ = x;
}

// error
// backend=stage2
// target=native
//
// :2:15: error: type '[]u8' does not support array initialization syntax
// :2:15: note: inferred array length is specified with an underscore: '[_]u8'
