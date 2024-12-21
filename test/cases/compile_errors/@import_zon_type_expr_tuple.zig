pub fn main() void {
    const f: struct { f32, f32 } = @import("zon/type_expr_tuple.zon");
    _ = f;
}

// error
// backend=stage2
// output_mode=Exe
// imports=zon/type_expr_tuple.zon
//
// type_expr_tuple.zon:1:1: error: types are not available in ZON
// type_expr_tuple.zon:1:1: note: replace the type with '.'
