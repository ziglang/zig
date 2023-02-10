export fn entry1() void {
    @call(.auto, foo, {});
}
export fn entry2() void {
    comptime @call(.never_inline, foo, .{});
}
export fn entry3() void {
    comptime @call(.never_tail, foo, .{});
}
export fn entry4() void {
    @call(.never_inline, bar, .{});
}
export fn entry5(c: bool) void {
    var baz = if (c) &baz1 else &baz2;
    @call(.compile_time, baz, .{});
}
pub export fn entry() void {
    var call_me: *const fn () void = undefined;
    @call(.always_inline, call_me, .{});
}
fn foo() void {}
fn bar() callconv(.Inline) void {}
fn baz1() void {}
fn baz2() void {}

// error
// backend=stage2
// target=native
//
// :2:23: error: expected a tuple, found 'void'
// :5:21: error: unable to perform 'never_inline' call at compile-time
// :8:21: error: unable to perform 'never_tail' call at compile-time
// :11:5: error: no-inline call of inline function
// :15:26: error: modifier 'compile_time' requires a comptime-known function
// :19:27: error: modifier 'always_inline' requires a comptime-known function

