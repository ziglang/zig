pub fn main() void {
    const f: i32 = @import("zon/unknown_ident.zon");
    _ = f;
}

// error
// backend=stage2
// output_mode=Exe
// imports=zon/unknown_ident.zon
//
// unknown_ident.zon:2:14: error: use of unknown identifier 'truefalse'
