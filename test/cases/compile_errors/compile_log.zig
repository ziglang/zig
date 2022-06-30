export fn foo() void {
    comptime bar(12, "hi",);
}
fn bar(a: i32, b: []const u8) void {
    @compileLog("begin",);
    @compileLog("a", a, "b", b);
    @compileLog("end",);
}

// error
// backend=llvm
// target=native
//
// :5:5: error: found compile log statement
