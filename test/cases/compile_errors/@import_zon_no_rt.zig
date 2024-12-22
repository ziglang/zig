pub fn main() void {
    const f = @import("zon/simple_union.zon");
    _ = f;
}

// error
// backend=stage2
// output_mode=Exe
// imports=zon/simple_union.zon
//
// tmp.zig:2:23: error: import ZON must have a known result type
