pub export fn entry() void {
    inline for (&[_]type{
        u8,
        u16,
        struct {},
        anyopaque,
    }) |T| deref(T);
}

fn deref(comptime T: type) void {
    var runtime: *T = undefined;
    _ = runtime.*;
}

// error
// target=native
// backend=llvm
//
// :12:16: error: values of type 'anyopaque' must be comptime-known, but operand value is runtime-known
// :12:16: note: opaque type 'anyopaque' has undefined size
