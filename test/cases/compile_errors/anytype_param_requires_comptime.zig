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
// :7:25: error: unable to resolve comptime value
// :7:25: note: initializer of comptime only struct must be comptime-known
