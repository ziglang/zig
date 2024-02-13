const V = @Vector(8, u8);
const A = [8]u8;
comptime {
    var v: V = V{1};
    _ = &v;
}
comptime {
    var v: V = V{};
    _ = &v;
}
comptime {
    var a: A = A{1};
    _ = &a;
}
comptime {
    var a: A = A{};
    _ = &a;
}
pub export fn entry1() void {
    var bla: V = .{ 1, 2, 3, 4 };
    _ = &bla;
}
pub export fn entry2() void {
    var bla: A = .{ 1, 2, 3, 4 };
    _ = &bla;
}
const S = struct {
    list: [2]u8 = .{0},
};
export fn entry3() void {
    _ = S{};
}

// error
// backend=stage2
// target=native
//
// :4:17: error: expected 8 vector elements; found 1
// :8:17: error: expected 8 vector elements; found 0
// :12:17: error: expected 8 array elements; found 1
// :16:17: error: expected 8 array elements; found 0
// :20:19: error: expected 8 vector elements; found 4
// :24:19: error: expected 8 array elements; found 4
// :28:20: error: expected 2 array elements; found 1
