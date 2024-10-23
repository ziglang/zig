export fn foo() void {
    comptime bar(12, "hi");
    _ = &bar;
}
fn bar(a: i32, b: []const u8) void {
    @compileLog("begin");
    @compileLog("a", a, "b", b);
    @compileLog("end");
}
export fn baz() void {
    const S = struct { a: u32 };
    @compileLog(@sizeOf(S));
}

// error
// backend=llvm
// target=native
//
// :6:5: error: found compile log statement
// :6:5: note: also here
// :12:5: note: also here
//
// Compile Log Output:
// @as(*const [5:0]u8, "begin")
// @as(*const [1:0]u8, "a"), @as(i32, 12), @as(*const [1:0]u8, "b"), @as([]const u8, "hi"[0..2])
// @as(*const [3:0]u8, "end")
// @as(*const [5:0]u8, "begin")
// @as(*const [1:0]u8, "a"), @as(i32, [runtime value]), @as(*const [1:0]u8, "b"), @as([]const u8, [runtime value])
// @as(*const [3:0]u8, "end")
// @as(comptime_int, 4)
