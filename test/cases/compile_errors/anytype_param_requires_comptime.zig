const S = struct {
    fn foo(b: u32, c: anytype) void {
        const C = struct {
            c: @TypeOf(c),
            b: u32,
        };
        bar(C{ .c = c, .b = b });
    }
    fn bar(_: anytype) void {}
};
pub export fn entry() void {
    S.foo(0, u32);
}

// error
// backend=stage2
// target=native
//
// :7:14: error: unable to resolve comptime value
// :7:14: note: argument to parameter with comptime-only type must be comptime-known
