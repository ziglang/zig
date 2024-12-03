pub fn main() void {
    const f: [4]u8 = @import("zon/array.zon");
    _ = f;
}

// error
// backend=stage2
// output_mode=Exe
// imports=zon/array.zon
//
// array.zon:1:2: error: expected type '[4]u8'
// tmp.zig:2:30: note: imported here
