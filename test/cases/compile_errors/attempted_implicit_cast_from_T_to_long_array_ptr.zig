export fn entry0(single: *u32) void {
    _ = @as(*const [0]u32, single);
}
export fn entry1(single: *u32) void {
    _ = @as(*const [1]u32, single);
}
export fn entry2(single: *u32) void {
    _ = @as(*const [2]u32, single);
}

// error
// backend=stage2
// target=native
//
// :2:28: error: expected type '*const [0]u32', found '*u32'
// :2:28: note: pointer type child 'u32' cannot cast into pointer type child '[0]u32'
// :8:28: error: expected type '*const [2]u32', found '*u32'
// :8:28: note: pointer type child 'u32' cannot cast into pointer type child '[2]u32'
