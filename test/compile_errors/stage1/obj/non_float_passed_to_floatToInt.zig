export fn entry() void {
    const x = @floatToInt(i32, @as(i32, 54));
    _ = x;
}

// non float passed to @floatToInt
//
// tmp.zig:2:32: error: expected float type, found 'i32'
