pub fn main() void {
    const f = @import("zon/invalid_string.zon");
    _ = f;
}

// error
// backend=stage2
// output_mode=Exe
// imports=zon/invalid_string.zon
//
// invalid_string.zon:1:5: error: invalid escape character: 'a'
