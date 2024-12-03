pub fn main() void {
    const f: struct { x: f32, y: f32 } = @import("zon/type_expr_struct.zon");
    _ = f;
}

// error
// backend=stage2
// output_mode=Exe
// imports=zon/type_expr_struct.zon
//
// type_expr_struct.zon:1:1: error: ZON cannot contain type expressions
// tmp.zig:2:50: note: imported here
