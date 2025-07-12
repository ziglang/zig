const C = struct {
    c: type,
    b: u32,
};
const S = struct {
    fn foo(b: u32, c: anytype) void {
        bar(C{ .c = c, .b = b });
    }
    fn bar(_: anytype) void {}
};

pub export fn entry() void {
    S.foo(0, u32);
}

// error
//
//:7:25: error: unable to resolve comptime value
//:7:25: note: initializer of comptime-only struct 'anytype_param_requires_comptime.C' must be comptime-known
//:2:8: note: struct requires comptime because of this field
//:2:8: note: types are not available at runtime
