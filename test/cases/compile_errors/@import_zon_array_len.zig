pub fn main() void {
    const f: [4]u8 = @import("zon/array.zon");
    _ = f;
}

// error
// backend=stage2
// output_mode=Exe
// imports=zon/array.zon
//
// 2:22: error: expected type '[4]u8', found 'struct{comptime comptime_int = 97, comptime comptime_int = 98, comptime comptime_int = 99}'
// note: destination has length 4
// note: source has length 3
