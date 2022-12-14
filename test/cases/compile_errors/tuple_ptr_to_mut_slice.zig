export fn entry1() void {
    var a = .{ 1, 2, 3 };
    _ = @as([]u8, &a);
}
export fn entry2() void {
    var a = .{ @as(u8, 1), @as(u8, 2), @as(u8, 3) };
    _ = @as([]u8, &a);
}

// runtime values
var vals = [_]u7{ 4, 5, 6 };
export fn entry3() void {
    var a = .{ vals[0], vals[1], vals[2] };
    _ = @as([]u8, &a);
}
export fn entry4() void {
    var a = .{ @as(u8, vals[0]), @as(u8, vals[1]), @as(u8, vals[2]) };
    _ = @as([]u8, &a);
}

// error
// backend=stage2
// target=native
//
// :3:19: error: cannot cast pointer to tuple to '[]u8'
// :3:19: note: pointers to tuples can only coerce to constant pointers
// :7:19: error: cannot cast pointer to tuple to '[]u8'
// :7:19: note: pointers to tuples can only coerce to constant pointers
// :14:19: error: cannot cast pointer to tuple to '[]u8'
// :14:19: note: pointers to tuples can only coerce to constant pointers
// :18:19: error: cannot cast pointer to tuple to '[]u8'
// :18:19: note: pointers to tuples can only coerce to constant pointers
