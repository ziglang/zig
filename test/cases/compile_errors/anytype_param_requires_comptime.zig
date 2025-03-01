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
//
// :7:25: error: unable to resolve comptime value
// :7:25: note: initializer of comptime-only struct 'tmp.S.foo__anon_461.C' must be comptime-known
// :4:16: note: struct requires comptime because of this field
// :4:16: note: types are not available at runtime
