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
    _ = &list;
    _ = &list2;
    _ = &list3;
}
pub export fn entry3() void {
    const U = struct {
        comptime foo: u32 = 1,
        bar: u32,
        fn qux(x: @This()) void {
            _ = x;
        }
    };
    _ = U.qux(U{ .foo = 2, .bar = 2 });
}
pub export fn entry4() void {
    const U = struct {
        comptime foo: u32 = 1,
        bar: u32,
        fn qux(x: @This()) void {
            _ = x;
        }
    };
    _ = U.qux(.{ .foo = 2, .bar = 2 });
}
pub export fn entry5() void {
    comptime var y = .{ 1, 2 };
    y = .{ 3, 4 };
}
pub export fn entry6() void {
    var x: u32 = 15;
    _ = &x;
    const T = @TypeOf(.{ @as(i32, -1234), @as(u32, 5678), x });
    const S = struct {
        fn foo(_: T) void {}
    };
    _ = S.foo(.{ -1234, 5679, x });
}
pub export fn entry7() void {
    const State = struct {
        comptime id: bool = true,
        fn init(comptime id: bool) @This() {
            return @This(){ .id = id };
        }
    };
    _ = State.init(false);
}
pub export fn entry8() void {
    const list1 = .{ "sss", 1, 2, 3 };
    const list2 = @TypeOf(list1){ .@"0" = "xxx", .@"1" = 4, .@"2" = 5, .@"3" = 6 };
    _ = list2;
}

// error
// target=native
// backend=stage2
//
// :6:9: error: value stored in comptime field does not match the default value of the field
// :14:9: error: value stored in comptime field does not match the default value of the field
// :19:38: error: value stored in comptime field does not match the default value of the field
// :32:19: error: value stored in comptime field does not match the default value of the field
// :26:29: note: default value set here
// :42:19: error: value stored in comptime field does not match the default value of the field
// :36:29: note: default value set here
// :46:12: error: value stored in comptime field does not match the default value of the field
// :55:25: error: value stored in comptime field does not match the default value of the field
// :61:30: error: value stored in comptime field does not match the default value of the field
// :59:29: note: default value set here
// :68:36: error: value stored in comptime field does not match the default value of the field
