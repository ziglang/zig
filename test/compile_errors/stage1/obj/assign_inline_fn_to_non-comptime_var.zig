export fn entry() void {
    var a = b;
    _ = a;
}
fn b() callconv(.Inline) void { }

// error
// backend=stage1
// target=native
//
// tmp.zig:2:5: error: functions marked inline must be stored in const or comptime var
// tmp.zig:5:1: note: declared here
