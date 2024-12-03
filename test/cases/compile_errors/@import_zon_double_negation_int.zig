pub fn main() void {
    const f: i32 = @import("zon/double_negation_int.zon");
    _ = f;
}

// error
// backend=stage2
// output_mode=Exe
// imports=zon/double_negation_int.zon
//
// double_negation_int.zon:1:1: error: expected type 'i32'
// tmp.zig:2:28: note: imported here
