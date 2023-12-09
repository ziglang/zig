pub fn main() void {
    const f: i32 = @import("zon/type_expr_tuple.zon");
    _ = f;
}

// error
// backend=stage2
// output_mode=Exe
// imports=zon/type_expr_tuple.zon
//
// type_expr_tuple.zon:1:1: error: type expressions not allowed in ZON
