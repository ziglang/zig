export fn entry() void {
    const f: i32 = @import("zon/type_expr_fn.zon");
    _ = f;
}

// error
// imports=zon/type_expr_fn.zon
//
// type_expr_fn.zon:1:1: error: types are not available in ZON
// type_expr_fn.zon:1:1: note: replace the type with '.'
