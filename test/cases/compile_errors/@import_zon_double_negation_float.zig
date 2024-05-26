pub fn main() void {
    const f: i32 = @import("zon/double_negation_float.zon");
    _ = f;
}

// error
// backend=stage2
// output_mode=Exe
// imports=zon/double_negation_float.zon
//
// double_negation_float.zon:1:2: error: invalid ZON value
