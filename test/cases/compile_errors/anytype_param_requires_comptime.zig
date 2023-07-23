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
// :7:14: error: runtime-known argument passed to comptime-only type parameter
// :9:12: note: declared here
// :4:16: note: struct requires comptime because of this field
// :4:16: note: types are not available at runtime
