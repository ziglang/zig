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

// error
// backend=stage2
// target=native
//
// :12:15: error: expected type 'u32', found '@typeInfo(@typeInfo(@TypeOf(tmp.get_uval)).Fn.return_type.?).ErrorUnion.error_set!u32'
// :12:15: note: cannot convert error union to payload type
// :12:15: note: consider using 'try', 'catch', or 'if'
