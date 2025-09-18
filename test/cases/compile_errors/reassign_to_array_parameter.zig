fn reassign(a: [3]f32) void {
    a = [3]f32{ 4, 5, 6 };
}
export fn entry() void {
    reassign(.{ 1, 2, 3 });
}

// error
//
// :2:5: error: cannot assign to constant
