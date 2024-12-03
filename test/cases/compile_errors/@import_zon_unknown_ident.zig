pub fn main() void {
    const f: struct { value: bool } = @import("zon/unknown_ident.zon");
    _ = f;
}

// error
// backend=stage2
// output_mode=Exe
// imports=zon/unknown_ident.zon
//
// unknown_ident.zon:2:14: error: expected type 'bool'
// tmp.zig:2:47: note: imported here
