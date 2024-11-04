pub fn main() void {
    const f: *struct { u8, u8, u8 } = @import("zon/array.zon");
    _ = f;
}

// error
// backend=stage2
// output_mode=Exe
// imports=zon/array.zon
//
// found 'struct{comptime comptime_int = 97, comptime comptime_int = 98, comptime comptime_int = 99}'
