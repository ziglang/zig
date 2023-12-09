pub fn main() void {
    const f: i32 = @import("zon/type_expr_ptr.zon");
    _ = f;
}

// error
// backend=stage2
// output_mode=Exe
// imports=zon/type_expr_ptr.zon
//
// type_expr_ptr.zon:1:2: error: type expressions not allowed in ZON
