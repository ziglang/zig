export fn a() void {
    var ptr: [*c]u8 = (1 << 64) + 1;
    _ = ptr;
}
export fn b() void {
    var x: u65 = 0x1234;
    var ptr: [*c]u8 = x;
    _ = ptr;
}

// implicit casting too big integers to C pointers
//
// tmp.zig:2:33: error: integer value 18446744073709551617 cannot be coerced to type 'usize'
// tmp.zig:7:23: error: integer type 'u65' too big for implicit @intToPtr to type '[*c]u8'
