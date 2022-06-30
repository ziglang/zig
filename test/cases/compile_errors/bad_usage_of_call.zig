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
    var baz = if (c) &baz1 else &baz2;
    @call(.{ .modifier = .compile_time }, baz, .{});
}
pub export fn entry() void {
    var call_me: *const fn () void = undefined;
    @call(.{ .modifier = .always_inline }, call_me, .{});
}
fn foo() void {}
fn bar() callconv(.Inline) void {}
fn baz1() void {}
fn baz2() void {}

// error
// backend=stage2
// target=native
//
// :2:21: error: expected a tuple, found 'void'
// :5:21: error: unable to perform 'never_inline' call at compile-time
// :8:21: error: unable to perform 'never_tail' call at compile-time
// :11:5: error: no-inline call of inline function
// :15:43: error: modifier 'compile_time' requires a comptime-known function
// :19:44: error: modifier 'always_inline' requires a comptime-known function
