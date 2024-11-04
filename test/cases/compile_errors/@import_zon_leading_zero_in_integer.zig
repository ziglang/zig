pub fn main() void {
    const f = @import("zon/leading_zero_in_integer.zon");
    _ = f;
}

// error
// backend=stage2
// output_mode=Exe
// imports=zon/leading_zero_in_integer.zon
//
// leading_zero_in_integer.zon:1:1: error: number '0012' has leading zero
// leading_zero_in_integer.zon:1:1: note: use '0o' prefix for octal literals
