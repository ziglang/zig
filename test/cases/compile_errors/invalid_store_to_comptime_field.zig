pub export fn entry() void {
    const S = struct {
        comptime a: [2]u32 = [2]u32{ 1, 2 },
    };
    var s: S = .{};
    s.a = [2]u32{ 2, 2 };
}
pub export fn entry1() void {
    const T = struct { a: u32, b: u32 };
    const S = struct {
        comptime a: T = T{ .a = 1, .b = 2 },
    };
    var s: S = .{};
    s.a = T{ .a = 2, .b = 2 };
}
pub export fn entry2() void {
    var list = .{ 1, 2, 3 };
    var list2 = @TypeOf(list){ .@"0" = 1, .@"1" = 2, .@"2" = 3 };
    var list3 = @TypeOf(list){ 1, 2, 4 };
    _ = list2;
    _ = list3;
}

// error
// target=native
// backend=stage2
//
// :6:19: error: value stored in comptime field does not match the default value of the field
// :14:19: error: value stored in comptime field does not match the default value of the field
// :19:38: error: value stored in comptime field does not match the default value of the field
