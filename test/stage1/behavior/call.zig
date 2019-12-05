const std = @import("std");
const expect = std.testing.expect;

test "basic invocations" {
    const foo = struct {
        fn foo() i32 {
            return 1234;
        }
    }.foo;
    expect(@call(.{}, foo, .{}) == 1234);
    comptime {
        // modifiers that allow comptime calls
        expect(@call(.{}, foo, .{}) == 1234);
        expect(@call(.{ .modifier = .no_async }, foo, .{}) == 1234);
        expect(@call(.{ .modifier = .always_tail }, foo, .{}) == 1234);
        expect(@call(.{ .modifier = .always_inline }, foo, .{}) == 1234);
    }
    {
        // comptime call without comptime keyword
        const result = @call(.{ .modifier = .compile_time }, foo, .{}) == 1234;
        comptime expect(result);
    }
}

test "tuple parameters" {
    const add = struct {
        fn add(a: i32, b: i32) i32 {
            return a + b;
        }
    }.add;
    expect(@call(.{}, add, .{ 12, 34 }) == 46);
    comptime expect(@call(.{}, add, .{ 12, 34 }) == 46);
    {
        const separate_args = .{ 12, 34 };
        expect(@call(.{ .modifier = .always_inline }, add, separate_args) == 46);
    }
}
