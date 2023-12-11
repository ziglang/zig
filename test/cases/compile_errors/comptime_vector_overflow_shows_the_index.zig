comptime {
    var a: @Vector(4, u8) = [_]u8{ 1, 2, 255, 4 };
    var b: @Vector(4, u8) = [_]u8{ 5, 6, 1, 8 };
    var x = a + b;
    _ = .{ &a, &b, &x };
}

// error
// backend=stage2
// target=native
//
// :4:15: error: overflow of vector type '@Vector(4, u8)' with value '.{ 6, 8, 256, 12 }'
// :4:15: note: when computing vector element at index '2'
