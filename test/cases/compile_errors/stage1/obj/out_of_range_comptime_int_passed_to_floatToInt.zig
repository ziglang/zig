export fn entry() void {
    const x = @floatToInt(i8, 200);
    _ = x;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:31: error: integer value 200 cannot be coerced to type 'i8'
