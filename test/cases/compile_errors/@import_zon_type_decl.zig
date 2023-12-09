pub fn main() void {
    const f: i32 = @import("zon/type_decl.zon");
    _ = f;
}

// error
// backend=stage2
// output_mode=Exe
// imports=zon/type_decl.zon
//
// type_decl.zon:2:12: error: invalid ZON value
