export fn entry1() void {
    @call(.{}, foo, {});
}
export fn entry2() void {
    comptime @call(.{ .modifier = .never_inline }, foo, .{});
}
export fn entry3() void {
    comptime @call(.{ .modifier = .never_tail }, foo, .{});
}
export fn entry4() void {
    @call(.{ .modifier = .never_inline }, bar, .{});
}
export fn entry5(c: bool) void {
    var baz = if (c) baz1 else baz2;
    @call(.{ .modifier = .compile_time }, baz, .{});
}
fn foo() void {}
fn bar() callconv(.Inline) void {}
fn baz1() void {}
fn baz2() void {}

// bad usage of @call
//
// tmp.zig:2:21: error: expected tuple or struct, found 'void'
// tmp.zig:5:14: error: unable to perform 'never_inline' call at compile-time
// tmp.zig:8:14: error: unable to perform 'never_tail' call at compile-time
// tmp.zig:11:5: error: no-inline call of inline function
// tmp.zig:15:5: error: the specified modifier requires a comptime-known function
