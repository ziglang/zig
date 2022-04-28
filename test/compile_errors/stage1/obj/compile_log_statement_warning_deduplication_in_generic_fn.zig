export fn entry() void {
    inner(1);
    inner(2);
}
fn inner(comptime n: usize) void {
    comptime var i = 0;
    inline while (i < n) : (i += 1) { @compileLog("!@#$"); }
}

// error
// backend=stage1
// target=native
//
// tmp.zig:7:39: error: found compile log statement
