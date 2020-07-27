const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

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
    {
        // call of non comptime-known function
        var alias_foo = foo;
        expect(@call(.{ .modifier = .no_async }, alias_foo, .{}) == 1234);
        expect(@call(.{ .modifier = .never_tail }, alias_foo, .{}) == 1234);
        expect(@call(.{ .modifier = .never_inline }, alias_foo, .{}) == 1234);
    }
}

test "tuple parameters" {
    const add = struct {
        fn add(a: i32, b: i32) i32 {
            return a + b;
        }
    }.add;
    var a: i32 = 12;
    var b: i32 = 34;
    expect(@call(.{}, add, .{ a, 34 }) == 46);
    expect(@call(.{}, add, .{ 12, b }) == 46);
    expect(@call(.{}, add, .{ a, b }) == 46);
    expect(@call(.{}, add, .{ 12, 34 }) == 46);
    comptime expect(@call(.{}, add, .{ 12, 34 }) == 46);
    {
        const separate_args0 = .{ a, b };
        const separate_args1 = .{ a, 34 };
        const separate_args2 = .{ 12, 34 };
        const separate_args3 = .{ 12, b };
        expect(@call(.{ .modifier = .always_inline }, add, separate_args0) == 46);
        expect(@call(.{ .modifier = .always_inline }, add, separate_args1) == 46);
        expect(@call(.{ .modifier = .always_inline }, add, separate_args2) == 46);
        expect(@call(.{ .modifier = .always_inline }, add, separate_args3) == 46);
    }
}

test "comptime call with bound function as parameter" {
    const S = struct {
        fn ReturnType(func: anytype) type {
            return switch (@typeInfo(@TypeOf(func))) {
                .BoundFn => |info| info,
                else => unreachable,
            }.return_type orelse void;
        }

        fn call_me_maybe() ?i32 {
            return 123;
        }
    };

    var inst: S = undefined;
    expectEqual(?i32, S.ReturnType(inst.call_me_maybe));
}
