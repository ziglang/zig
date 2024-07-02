pub fn main() void {
    const f = @import("zon/invalid_number.zon");
    _ = f;
}

// error
// backend=stage2
// output_mode=Exe
// imports=zon/invalid_number.zon
//
// invalid_number.zon:1:19: error: invalid digit 'a' for decimal base
