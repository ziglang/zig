export fn foo() void {
    comptime bar(12, "hi",);
}
fn bar(a: i32, b: []const u8) void {
    @compileLog("begin",);
    @compileLog("a", a, "b", b);
    @compileLog("end",);
}

// compile log
//
// tmp.zig:5:5: error: found compile log statement
// tmp.zig:6:5: error: found compile log statement
// tmp.zig:7:5: error: found compile log statement
