pub fn main() void {
    const f: []const u8 = @import("zon/invalid_string.zon");
    _ = f;
}

// error
// backend=stage2
// output_mode=Exe
// imports=zon/invalid_string.zon
//
// invalid_string.zon:1:5: error: invalid escape character: 'a'
// tmp.zig:2:35: note: imported here
