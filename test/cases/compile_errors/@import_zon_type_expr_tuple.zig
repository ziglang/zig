pub fn main() void {
    const f: struct { f32, f32 } = @import("zon/type_expr_tuple.zon");
    _ = f;
}

// error
// backend=stage2
// output_mode=Exe
// imports=zon/type_expr_tuple.zon
//
// type_expr_tuple.zon:1:1: error: ZON cannot contain type expressions
// tmp.zig:2:44: note: imported here
