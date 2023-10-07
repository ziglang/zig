export fn foo() void {
    const ptr: [*]const u8 = "abc";
    _ = @as([]const u8, ptr);
}
export fn bar() void {
    const ptr: [*c]const u8 = "def";
    _ = @as([]const u8, ptr);
}
export fn baz() void {
    const ptr: *const u8 = &@as(u8, 123);
    _ = @as([]const u8, ptr);
}

// error
// backend=stage2
// target=native
//
// :3:25: error: expected type '[]const u8', found '[*]const u8'
// :7:25: error: expected type '[]const u8', found '[*c]const u8'
// :11:25: error: expected type '[]const u8', found '*const u8'
