const std = @import("std");
const expect = std.testing.expect;
const expectError = std.testing.expectError;
const expectEqual = std.testing.expectEqual;
const mem = std.mem;

test "error values" {
    const a = @errorToInt(error.err1);
    const b = @errorToInt(error.err2);
    try expect(a != b);
}

test "redefinition of error values allowed" {
    shouldBeNotEqual(error.AnError, error.SecondError);
}
fn shouldBeNotEqual(a: anyerror, b: anyerror) void {
    if (a == b) unreachable;
}

test "error binary operator" {
    const a = errBinaryOperatorG(true) catch 3;
    const b = errBinaryOperatorG(false) catch 3;
    try expect(a == 3);
    try expect(b == 10);
}
fn errBinaryOperatorG(x: bool) anyerror!isize {
    return if (x) error.ItBroke else @as(isize, 10);
}

test "empty error union" {
    const x = error{} || error{};
    _ = x;
}

pub fn foo() anyerror!i32 {
    const x = try bar();
    return x + 1;
}

pub fn bar() anyerror!i32 {
    return 13;
}

pub fn baz() anyerror!i32 {
    const y = foo() catch 1234;
    return y + 1;
}

test "error wrapping" {
    try expect((baz() catch unreachable) == 15);
}

test "unwrap simple value from error" {
    const i = unwrapSimpleValueFromErrorDo() catch unreachable;
    try expect(i == 13);
}
fn unwrapSimpleValueFromErrorDo() anyerror!isize {
    return 13;
}

test "error return in assignment" {
    doErrReturnInAssignment() catch unreachable;
}

fn doErrReturnInAssignment() anyerror!void {
    var x: i32 = undefined;
    x = try makeANonErr();
}

fn makeANonErr() anyerror!i32 {
    return 1;
}

test "syntax: optional operator in front of error union operator" {
    comptime {
        try expect(?(anyerror!i32) == ?(anyerror!i32));
    }
}

test "widen cast integer payload of error union function call" {
    const S = struct {
        fn errorable() !u64 {
            var x = @as(u64, try number());
            return x;
        }

        fn number() anyerror!u32 {
            return 1234;
        }
    };
    try expect((try S.errorable()) == 1234);
}

test "debug info for optional error set" {
    const SomeError = error{Hello};
    var a_local_variable: ?SomeError = null;
    _ = a_local_variable;
}

test "implicit cast to optional to error union to return result loc" {
    const S = struct {
        fn entry() !void {
            var x: Foo = undefined;
            if (func(&x)) |opt| {
                try expect(opt != null);
            } else |_| @panic("expected non error");
        }
        fn func(f: *Foo) anyerror!?*Foo {
            return f;
        }
        const Foo = struct {
            field: i32,
        };
    };
    try S.entry();
    //comptime S.entry(); TODO
}

test "error: fn returning empty error set can be passed as fn returning any error" {
    entry();
    comptime entry();
}

fn entry() void {
    foo2(bar2);
}

fn foo2(f: fn () anyerror!void) void {
    const x = f();
    x catch {};
}

fn bar2() (error{}!void) {}
