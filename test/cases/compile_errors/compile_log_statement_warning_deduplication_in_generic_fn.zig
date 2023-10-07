export fn entry() void {
    inner(1);
    inner(2);
}
fn inner(comptime n: usize) void {
    comptime var i = 0;
    inline while (i < n) : (i += 1) {
        @compileLog("!@#$");
    }
}

// error
// backend=llvm
// target=native
//
// :8:9: error: found compile log statement
// :8:9: note: also here
//
// Compile Log Output:
// @as(*const [4:0]u8, "!@#$")
// @as(*const [4:0]u8, "!@#$")
// @as(*const [4:0]u8, "!@#$")
