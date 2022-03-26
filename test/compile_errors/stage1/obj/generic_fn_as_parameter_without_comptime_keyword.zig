fn f(_: fn (anytype) void) void {}
fn g(_: anytype) void {}
export fn entry() void {
    f(g);
}

// generic fn as parameter without comptime keyword
//
// tmp.zig:1:9: error: parameter of type 'fn(anytype) anytype' must be declared comptime
