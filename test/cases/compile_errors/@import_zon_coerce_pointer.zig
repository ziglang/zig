pub fn main() void {
    const f: *struct { u8, u8, u8 } = @import("zon/array.zon");
    _ = f;
}

// error
// backend=stage2
// output_mode=Exe
// imports=zon/array.zon
//
// array.zon:1:2: error: ZON import cannot be coerced to non slice pointer
// tmp.zig:2:47: note: imported here
