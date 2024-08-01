pub fn main() void {
    const f: f32 = @import("zon/negative_zero.zon");
    _ = f;
}

// error
// backend=stage2
// output_mode=Exe
// imports=zon/negative_zero.zon
//
// negative_zero.zon:1:1: error: integer literal '-0' is ambiguous
