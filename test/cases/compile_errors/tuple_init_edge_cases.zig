pub export fn entry1() void {
    const T = @TypeOf(.{ 123, 3 });
    var b = T{ .@"1" = 3 };
    _ = &b;
    var c = T{ 123, 3 };
    _ = &c;
    var d = T{};
    _ = &d;
}
pub export fn entry2() void {
    var a: u32 = 2;
    _ = &a;
    const T = @TypeOf(.{ 123, a });
    var b = T{ .@"1" = 3 };
    _ = &b;
    var c = T{ 123, 3 };
    _ = &c;
    var d = T{};
    _ = &d;
}
pub export fn entry3() void {
    var a: u32 = 2;
    _ = &a;
    const T = @TypeOf(.{ 123, a });
    var b = T{ .@"0" = 123 };
    _ = &b;
}
comptime {
    var a: u32 = 2;
    _ = &a;
    const T = @TypeOf(.{ 123, a });
    var b = T{ .@"0" = 123 };
    _ = &b;
    var c = T{ 123, 2 };
    _ = &c;
    var d = T{};
    _ = &d;
}
pub export fn entry4() void {
    var a: u32 = 2;
    _ = &a;
    const T = @TypeOf(.{ 123, a });
    var b = T{ 123, 4, 5 };
    _ = &b;
}
pub export fn entry5() void {
    var a: u32 = 2;
    _ = &a;
    const T = @TypeOf(.{ 123, a });
    var b = T{ .@"0" = 123, .@"2" = 123, .@"1" = 123 };
    _ = &b;
}
pub const Consideration = struct {
    curve: Curve,
    pub const Curve = union(enum) {
        logistic: Parameters,

        pub const Parameters = struct { f32, f32, f32, f32 };
    };
};
pub export fn entry6() void {
    const cons: []Consideration = &.{
        .{ .curve = .{ .logistic = .{ -7, 1.0, 0 } } },
    };
    _ = cons;
}

// error
// backend=stage2
// target=native
//
// :18:14: error: missing tuple field with index 1
// :25:14: error: missing tuple field with index 1
// :43:14: error: expected at most 2 tuple fields; found 3
// :50:30: error: index '2' out of bounds of tuple 'struct{comptime comptime_int = 123, u32}'
// :63:37: error: missing tuple field with index 3
// :58:32: note: struct declared here
