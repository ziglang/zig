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
// error
// target=native
// backend=stage2
//
// :6:19: error: value stored in comptime field does not match the default value of the field
// :14:19: error: value stored in comptime field does not match the default value of the field
