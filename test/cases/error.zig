const std = @import("std");
const assert = std.debug.assert;
const mem = std.mem;
const builtin = @import("builtin");

pub fn foo() error!i32 {
    const x = try bar();
    return x + 1;
}

pub fn bar() error!i32 {
    return 13;
}

pub fn baz() error!i32 {
    const y = foo() catch 1234;
    return y + 1;
}

test "error wrapping" {
    assert((baz() catch unreachable) == 15);
}

fn gimmeItBroke() []const u8 {
    return @errorName(error.ItBroke);
}

test "@errorName" {
    assert(mem.eql(u8, @errorName(error.AnError), "AnError"));
    assert(mem.eql(u8, @errorName(error.ALongerErrorName), "ALongerErrorName"));
}

test "error values" {
    const a = @errorToInt(error.err1);
    const b = @errorToInt(error.err2);
    assert(a != b);
}

test "redefinition of error values allowed" {
    shouldBeNotEqual(error.AnError, error.SecondError);
}
fn shouldBeNotEqual(a: error, b: error) void {
    if (a == b) unreachable;
}

test "error binary operator" {
    const a = errBinaryOperatorG(true) catch 3;
    const b = errBinaryOperatorG(false) catch 3;
    assert(a == 3);
    assert(b == 10);
}
fn errBinaryOperatorG(x: bool) error!isize {
    return if (x) error.ItBroke else isize(10);
}

test "unwrap simple value from error" {
    const i = unwrapSimpleValueFromErrorDo() catch unreachable;
    assert(i == 13);
}
fn unwrapSimpleValueFromErrorDo() error!isize {
    return 13;
}

test "error return in assignment" {
    doErrReturnInAssignment() catch unreachable;
}

fn doErrReturnInAssignment() error!void {
    var x: i32 = undefined;
    x = try makeANonErr();
}

fn makeANonErr() error!i32 {
    return 1;
}

test "error union type " {
    testErrorUnionType();
    comptime testErrorUnionType();
}

fn testErrorUnionType() void {
    const x: error!i32 = 1234;
    if (x) |value| assert(value == 1234) else |_| unreachable;
    assert(@typeId(@typeOf(x)) == builtin.TypeId.ErrorUnion);
    assert(@typeId(@typeOf(x).ErrorSet) == builtin.TypeId.ErrorSet);
    assert(@typeOf(x).ErrorSet == error);
}

test "error set type " {
    testErrorSetType();
    comptime testErrorSetType();
}

const MyErrSet = error{
    OutOfMemory,
    FileNotFound,
};

fn testErrorSetType() void {
    assert(@memberCount(MyErrSet) == 2);

    const a: MyErrSet!i32 = 5678;
    const b: MyErrSet!i32 = MyErrSet.OutOfMemory;

    if (a) |value| assert(value == 5678) else |err| switch (err) {
        error.OutOfMemory => unreachable,
        error.FileNotFound => unreachable,
    }
}

test "explicit error set cast" {
    testExplicitErrorSetCast(Set1.A);
    comptime testExplicitErrorSetCast(Set1.A);
}

const Set1 = error{
    A,
    B,
};
const Set2 = error{
    A,
    C,
};

fn testExplicitErrorSetCast(set1: Set1) void {
    var x = @errSetCast(Set2, set1);
    var y = @errSetCast(Set1, x);
    assert(y == error.A);
}

test "comptime test error for empty error set" {
    testComptimeTestErrorEmptySet(1234);
    comptime testComptimeTestErrorEmptySet(1234);
}

const EmptyErrorSet = error{};

fn testComptimeTestErrorEmptySet(x: EmptyErrorSet!i32) void {
    if (x) |v| assert(v == 1234) else |err| @compileError("bad");
}

test "syntax: optional operator in front of error union operator" {
    comptime {
        assert(?error!i32 == ?(error!i32));
    }
}

test "comptime err to int of error set with only 1 possible value" {
    testErrToIntWithOnePossibleValue(error.A, @errorToInt(error.A));
    comptime testErrToIntWithOnePossibleValue(error.A, @errorToInt(error.A));
}
fn testErrToIntWithOnePossibleValue(
    x: error{A},
    comptime value: u32,
) void {
    if (@errorToInt(x) != value) {
        @compileError("bad");
    }
}

test "error union peer type resolution" {
    testErrorUnionPeerTypeResolution(1);
    comptime testErrorUnionPeerTypeResolution(1);
}

fn testErrorUnionPeerTypeResolution(x: i32) void {
    const y = switch (x) {
        1 => bar_1(),
        2 => baz_1(),
        else => quux_1(),
    };
}

fn bar_1() error {
    return error.A;
}

fn baz_1() !i32 {
    return error.B;
}

fn quux_1() !i32 {
    return error.C;
}

test "error: fn returning empty error set can be passed as fn returning any error" {
    entry();
    comptime entry();
}

fn entry() void {
    foo2(bar2);
}

fn foo2(f: fn () error!void) void {
    const x = f();
}

fn bar2() (error{}!void) {}

test "error: Zero sized error set returned with value payload crash" {
    _ = foo3(0);
    _ = comptime foo3(0);
}

const Error = error{};
fn foo3(b: usize) Error!usize {
    return b;
}

test "error: Infer error set from literals" {
    _ = nullLiteral("n") catch |err| handleErrors(err);
    _ = floatLiteral("n") catch |err| handleErrors(err);
    _ = intLiteral("n") catch |err| handleErrors(err);
    _ = comptime nullLiteral("n") catch |err| handleErrors(err);
    _ = comptime floatLiteral("n") catch |err| handleErrors(err);
    _ = comptime intLiteral("n") catch |err| handleErrors(err);
}

fn handleErrors(err: var) noreturn {
    switch (err) {
        error.T => {},
    }

    unreachable;
}

fn nullLiteral(str: []const u8) !?i64 {
    if (str[0] == 'n') return null;

    return error.T;
}

fn floatLiteral(str: []const u8) !?f64 {
    if (str[0] == 'n') return 1.0;

    return error.T;
}

fn intLiteral(str: []const u8) !?i64 {
    if (str[0] == 'n') return 1;

    return error.T;
}
