export fn entry() void {
    const f: [3]i32 = @import("zon/type_expr_array.zon");
    _ = f;
}

// error
// imports=zon/type_expr_array.zon
//
// type_expr_array.zon:1:1: error: types are not available in ZON
// type_expr_array.zon:1:1: note: replace the type with '.'
