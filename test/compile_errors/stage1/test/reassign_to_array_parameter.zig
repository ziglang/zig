fn reassign(a: [3]f32) void {
    a = [3]f32{4, 5, 6};
}
export fn entry() void {
    reassign(.{1, 2, 3});
}

// reassign to array parameter
//
// tmp.zig:2:15: error: cannot assign to constant
