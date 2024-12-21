pub fn main() void {
    const f: struct { x: f32, y: f32 } = @import("zon/type_expr_struct.zon");
    _ = f;
}

// error
// backend=stage2
// output_mode=Exe
// imports=zon/type_expr_struct.zon
//
// type_expr_struct.zon:1:1: error: types are not available in ZON
// type_expr_struct.zon:1:1: note: replace the type with '.'
