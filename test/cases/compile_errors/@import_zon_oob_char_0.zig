pub fn main() void {
    {
        const f: u6 = @import("zon/char_32.zon");
        _ = f;
    }
    {
        const f: u5 = @import("zon/char_32.zon");
        _ = f;
    }
}

// error
// backend=stage2
// output_mode=Exe
// imports=zon/char_32.zon
//
// char_32.zon:1:1: error: type 'u5' cannot represent integer value '32'
// tmp.zig:7:31: note: imported here
