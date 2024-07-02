pub fn main() void {
    const f: i32 = @import("zon/addr_num.zon");
    _ = f;
}

// error
// backend=stage2
// output_mode=Exe
// imports=zon/addr_num.zon
//
// addr_num.zon:2:14: error: invalid ZON value
