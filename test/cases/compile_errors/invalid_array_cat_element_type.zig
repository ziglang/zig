export fn a() void {
    const Foo = enum {
        a,
    };
    const arr = [_]Foo{.a};
    _ = arr ++ .{.b};
}
export fn b() void {
    const Foo = enum {
        a,
    };
    const arr = [_]Foo{.a};
    _ = .{.b} ++ arr;
}

export fn c() void {
    comptime var things: []const i32 = &.{};
    things = things ++ .{&1};
}
export fn d() void {
    comptime var things: []const i32 = &.{};
    things = .{&1} ++ things;
}

// error
// backend=stage2
// target=native
//
// :6:17: error: expected array of element type 'tmp.a.Foo', found 'struct{comptime @TypeOf(.enum_literal) = .b}'
// :13:10: error: expected array of element type 'tmp.b.Foo', found 'struct{comptime @TypeOf(.enum_literal) = .b}'
// :18:25: error: expected array of element type 'i32', found 'struct{comptime *const comptime_int = 1}'
// :22:15: error: expected array of element type 'i32', found 'struct{comptime *const comptime_int = 1}'
