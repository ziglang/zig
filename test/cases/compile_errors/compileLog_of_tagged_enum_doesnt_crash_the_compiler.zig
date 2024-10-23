const Bar = union(enum(u32)) {
    X: i32 = 1,
};

fn testCompileLog(x: Bar) void {
    @compileLog(x);
}

pub export fn entry() void {
    comptime testCompileLog(Bar{ .X = 123 });
    _ = &testCompileLog;
}

// error
// backend=stage2
// target=native
//
// :6:5: error: found compile log statement
// :6:5: note: also here
//
// Compile Log Output:
// @as(tmp.Bar, .{ .X = 123 })
// @as(tmp.Bar, [runtime value])
