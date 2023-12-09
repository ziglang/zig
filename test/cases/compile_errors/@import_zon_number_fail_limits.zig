pub fn main() void {
    const f: i66 = @import("zon/large_number.zon");
    _ = f;
}

// error
// backend=stage2
// output_mode=Exe
// imports=zon/large_number.zon
//
// 2:20: error: type 'i66' cannot represent integer value '36893488147419103232'
