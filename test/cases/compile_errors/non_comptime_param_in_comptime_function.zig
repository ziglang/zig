fn F(val: anytype) type {
    _ = val;
    return struct {};
}
export fn entry() void {
    _ = F(void{});
}
const S = struct {
    foo: fn () void,
};
fn bar(_: u32) S {
    return undefined;
}
export fn entry1() void {
    _ = bar();
}
// prioritize other return type errors
fn foo(a: u32) callconv(.C) comptime_int {
    return a;
}
export fn entry2() void {
    _ = foo(1);
}

// error
// backend=stage2
// target=native
//
// :1:20: error: function with comptime-only return type 'type' requires all parameters to be comptime
// :1:20: note: types are not available at runtime
// :1:6: note: param 'val' is required to be comptime
// :11:16: error: function with comptime-only return type 'tmp.S' requires all parameters to be comptime
// :9:10: note: struct requires comptime because of this field
// :9:10: note: use '*const fn() void' for a function pointer type
// :11:8: note: param is required to be comptime
// :18:29: error: return type 'comptime_int' not allowed in function with calling convention 'C'
