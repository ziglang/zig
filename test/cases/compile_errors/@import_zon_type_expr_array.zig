pub fn main() void {
    const f: [3]i32 = @import("zon/type_expr_array.zon");
    _ = f;
}

// error
// backend=stage2
// output_mode=Exe
// imports=zon/type_expr_array.zon
//
// type_expr_array.zon:1:1: error: ZON cannot contain type expressions
// tmp.zig:2:31: note: imported here
