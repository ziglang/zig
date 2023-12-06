inline fn needComptime(comptime a: u64) void {
    if (a != 0) @compileError("foo");
}
fn acceptRuntime(value: u64) void {
    needComptime(value);
}
pub export fn entry() void {
    var value: u64 = 0;
    acceptRuntime((&value).*);
}

// error
// backend=stage2
// target=native
//
// :5:18: error: unable to resolve comptime value
// :5:18: note: parameter is comptime
