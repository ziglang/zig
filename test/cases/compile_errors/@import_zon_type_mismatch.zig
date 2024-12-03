pub fn main() void {
    const f: bool = @import("zon/struct.zon");
    _ = f;
}

// error
// backend=stage2
// output_mode=Exe
// imports=zon/struct.zon
//
// struct.zon:1:1: error: expected type 'bool'
// tmp.zig:2:29: note: imported here
