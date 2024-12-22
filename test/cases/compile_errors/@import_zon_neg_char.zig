pub fn main() void {
    const f: u8 = @import("zon/neg_char.zon");
    _ = f;
}

// error
// backend=stage2
// output_mode=Exe
// imports=zon/neg_char.zon
//
// neg_char.zon:1:1: error: expected number or 'inf' after '-'
