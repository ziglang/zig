fn foo(a: anytype) !void {
    if (a == 0) return error.A;
    return error.B;
}
const Error = error{ A, B };
export fn entry() void {
    const info = @typeInfo(@TypeOf(foo));
    const ret_type = info.@"fn".return_type.?;
    const error_set = @typeInfo(ret_type).error_union.error_set;
    _ = Error || error_set;
}

// error
// backend=stage2
// target=native
//
// :10:15: error: unable to resolve inferred error set of generic function
// :1:1: note: generic function declared here
