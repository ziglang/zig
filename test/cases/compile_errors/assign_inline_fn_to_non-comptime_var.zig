export fn entry() void {
    var a = &b;
    _ = &a;
}
inline fn b() void {}

// error
// backend=stage2
// target=native
//
// :2:9: error: variable of type '*const fn () callconv(.Inline) void' must be const or comptime
// :2:9: note: function has inline calling convention
