export fn optionalVector() void {
    var x: ?@Vector(10, i32) = undefined;
    var y: @Vector(11, i32) = undefined;
    _ = .{ &x, &y };
    _ = @TypeOf(x, y);
}
export fn badTupleField() void {
    var x = .{ @as(u8, 0), @as(u32, 1) };
    var y = .{ @as(u8, 1), "hello" };
    _ = .{ &x, &y };
    _ = @TypeOf(x, y);
}
export fn badNestedField() void {
    const x = .{ .foo = "hi", .bar = .{ 0, 1 } };
    const y = .{ .foo = "hello", .bar = .{ 2, "hi" } };
    _ = @TypeOf(x, y);
}
export fn incompatiblePointers() void {
    const x: []const u8 = "foo";
    const y: [*:0]const u8 = "bar";
    _ = @TypeOf(x, y);
}
export fn incompatiblePointers4() void {
    const a: *const [5]u8 = "hello";
    const b: *const [3:0]u8 = "foo";
    const c: []const u8 = "baz"; // The conflict must be reported against this element!
    const d: [*]const u8 = "bar";
    _ = @TypeOf(a, b, c, d);
}

// error
// backend=llvm
// target=native
//
// :5:9: error: incompatible types: '?@Vector(10, i32)' and '@Vector(11, i32)'
// :5:17: note: type '?@Vector(10, i32)' here
// :5:20: note: type '@Vector(11, i32)' here
// :11:9: error: struct field '1' has conflicting types
// :11:9: note: incompatible types: 'u32' and '*const [5:0]u8'
// :11:17: note: type 'u32' here
// :11:20: note: type '*const [5:0]u8' here
// :16:9: error: struct field 'bar' has conflicting types
// :16:9: note: struct field '1' has conflicting types
// :16:9: note: incompatible types: 'comptime_int' and '*const [2:0]u8'
// :16:17: note: type 'comptime_int' here
// :16:20: note: type '*const [2:0]u8' here
// :21:9: error: incompatible types: '[]const u8' and '[*:0]const u8'
// :21:17: note: type '[]const u8' here
// :21:20: note: type '[*:0]const u8' here
// :28:9: error: incompatible types: '[]const u8' and '[*]const u8'
// :28:23: note: type '[]const u8' here
// :28:26: note: type '[*]const u8' here
