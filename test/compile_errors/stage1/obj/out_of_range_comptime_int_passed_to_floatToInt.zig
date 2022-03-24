export fn entry() void {
    const x = @floatToInt(i8, 200);
    _ = x;
}

// out of range comptime_int passed to @floatToInt
//
// tmp.zig:2:31: error: integer value 200 cannot be coerced to type 'i8'
