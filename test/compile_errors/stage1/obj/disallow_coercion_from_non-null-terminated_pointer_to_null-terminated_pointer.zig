extern fn puts(s: [*:0]const u8) c_int;
pub fn main() void {
    const no_zero_array = [_]u8{'h', 'e', 'l', 'l', 'o'};
    const no_zero_ptr: [*]const u8 = &no_zero_array;
    _ = puts(no_zero_ptr);
}

// disallow coercion from non-null-terminated pointer to null-terminated pointer
//
// tmp.zig:5:14: error: expected type '[*:0]const u8', found '[*]const u8'
