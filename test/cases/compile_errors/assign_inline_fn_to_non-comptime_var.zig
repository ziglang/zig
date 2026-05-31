export fn entry() void {
    var a = &b;
    _ = &a;
}
inline fn b() void {}

// error
//
// :2:9: error: variable of type '*const fn () callconv(.@"inline") void' must be const or comptime
// :2:9: note: function has inline calling convention
