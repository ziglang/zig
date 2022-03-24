const Foo = struct {
    ptr: ?*usize,
    uval: u32,
};
fn get_uval(x: u32) !u32 {
    _ = x;
    return error.NotFound;
}
export fn entry() void {
    const afoo = Foo{
        .ptr = null,
        .uval = get_uval(42),
    };
    _ = afoo;
}

// regression test #2980: base type u32 is not type checked properly when assigning a value within a struct
//
// tmp.zig:12:25: error: cannot convert error union to payload type. consider using `try`, `catch`, or `if`. expected type 'u32', found '@typeInfo(@typeInfo(@TypeOf(get_uval)).Fn.return_type.?).ErrorUnion.error_set!u32'
