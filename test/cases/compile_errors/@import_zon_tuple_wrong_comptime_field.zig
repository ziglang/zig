pub fn main() void {
    const T = struct {
        comptime f32 = 1.5,
        comptime f32 = 2.5,
    };
    const f: T = @import("zon/tuple.zon");
    _ = f;
}

// error
// backend=stage2
// output_mode=Exe
// imports=zon/tuple.zon
//
// zon/tuple.zon:1:9: error: value stored in comptime field does not match the default value of the field
// tmp.zig:6:26: note: imported here
