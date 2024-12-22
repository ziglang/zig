pub fn main() void {
    const U = union(enum) { a: void };
    const f: U = @import("zon/simple_union.zon");
    _ = f;
}

// error
// backend=stage2
// output_mode=Exe
// imports=zon/simple_union.zon
//
// simple_union.zon:1:9: error: expected type 'void'
// tmp.zig:3:26: note: imported here
