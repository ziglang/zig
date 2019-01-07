const std = @import("std");
const assertOrPanic = std.debug.assertOrPanic;
const mem = std.mem;
const builtin = @import("builtin");

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
    assertOrPanic((baz() catch unreachable) == 15);
}

fn gimmeItBroke() []const u8 {
    return @errorName(error.ItBroke);
}

test "@errorName" {
    assertOrPanic(mem.eql(u8, @errorName(error.AnError), "AnError"));
    assertOrPanic(mem.eql(u8, @errorName(error.ALongerErrorName), "ALongerErrorName"));
}

test "error values" {
    const a = @errorToInt(error.err1);
    const b = @errorToInt(error.err2);
    assertOrPanic(a != b);
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
    assertOrPanic(a == 3);
    assertOrPanic(b == 10);
}
fn errBinaryOperatorG(x: bool) anyerror!isize {
    return if (x) error.ItBroke else isize(10);
}

test "unwrap simple value from error" {
    const i = unwrapSimpleValueFromErrorDo() catch unreachable;
    assertOrPanic(i == 13);
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

test "error union type " {
    testErrorUnionType();
    comptime testErrorUnionType();
}

fn testErrorUnionType() void {
    const x: anyerror!i32 = 1234;
    if (x) |value| assertOrPanic(value == 1234) else |_| unreachable;
    assertOrPanic(@typeId(@typeOf(x)) == builtin.TypeId.ErrorUnion);
    assertOrPanic(@typeId(@typeOf(x).ErrorSet) == builtin.TypeId.ErrorSet);
    assertOrPanic(@typeOf(x).ErrorSet == anyerror);
}

test "error set type" {
    testErrorSetType();
    comptime testErrorSetType();
}

const MyErrSet = error{
    OutOfMemory,
    FileNotFound,
};

fn testErrorSetType() void {
    assertOrPanic(@memberCount(MyErrSet) == 2);

    const a: MyErrSet!i32 = 5678;
    const b: MyErrSet!i32 = MyErrSet.OutOfMemory;

    if (a) |value| assertOrPanic(value == 5678) else |err| switch (err) {
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
    assertOrPanic(y == error.A);
}

test "comptime test error for empty error set" {
    testComptimeTestErrorEmptySet(1234);
    comptime testComptimeTestErrorEmptySet(1234);
}

const EmptyErrorSet = error{};

fn testComptimeTestErrorEmptySet(x: EmptyErrorSet!i32) void {
    if (x) |v| assertOrPanic(v == 1234) else |err| @compileError("bad");
}

test "syntax: optional operator in front of error union operator" {
    comptime {
        assertOrPanic(?(anyerror!i32) == ?(anyerror!i32));
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

// test "error union peer type resolution" {

test "error: fn returning empty error set can be passed as fn returning any error" {
    entry();
    comptime entry();
}

fn entry() void {
    foo2(bar2);
}

fn foo2(f: fn () anyerror!void) void {
    const x = f();
}

fn bar2() (error{}!void) {}

// test "error: Zero sized error set returned with value payload crash" {
// test "error: Infer error set from literals" {
