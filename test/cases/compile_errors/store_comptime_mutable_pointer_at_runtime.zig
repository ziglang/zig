var ptr0: *const u32 = undefined;
export fn a() void {
    comptime var x: u32 = 42;
    ptr0 = &x;
}

export fn b() void {
    comptime var x: u32 = 42;
    var ptr1: *const u32 = &x;
    _ = ptr1;
}

export fn c() void {
    comptime var x: u32 = 42;
    normalFunc(&x);
}
fn normalFunc(_: *const u32) void {}

export fn d() void {
    comptime var x: u32 = 42;
    genericFunc(0, &x);
}
fn genericFunc(comptime _: u8, _: *const u32) void {}

export fn e() void {
    comptime var x: u32 = 42;
    genericFuncGood(&x);
}
fn genericFuncGood(comptime _: *const u32) void {}

export fn f() void {
    comptime var x: u32 = 42;
    inlineGood(&x);
}
inline fn inlineGood(_: *const u32) void {}

// error
// backend=stage2
// target=native
//
// :4:12: error: cannot store reference to comptime-mutable state at runtime
// :4:12: note: copy comptime data to a const to use it at runtime
// :9:28: error: cannot store reference to comptime-mutable state at runtime
// :9:28: note: copy comptime data to a const to use it at runtime
// :15:16: error: cannot store reference to comptime-mutable state at runtime
// :15:16: note: copy comptime data to a const to use it at runtime
// :21:20: error: cannot store reference to comptime-mutable state at runtime
// :21:20: note: copy comptime data to a const to use it at runtime
