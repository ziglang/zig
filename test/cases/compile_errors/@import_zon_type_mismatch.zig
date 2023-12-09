pub fn main() void {
    const f: bool = @import("zon/struct.zon");
    _ = f;
}

// error
// backend=stage2
// output_mode=Exe
// imports=zon/struct.zon
//
// 2:21: error: expected type 'bool', found 'struct{comptime boolean: bool = true, comptime number: comptime_int = 123}'
