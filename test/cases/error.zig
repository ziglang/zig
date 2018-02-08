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
    const a = i32(error.err1);
    const b = i32(error.err2);
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
fn unwrapSimpleValueFromErrorDo() error!isize { return 13; }


test "error return in assignment" {
    doErrReturnInAssignment() catch unreachable;
}

fn doErrReturnInAssignment() error!void {
    var x : i32 = undefined;
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

const MyErrSet = error {OutOfMemory, FileNotFound};

fn testErrorSetType() void {
    assert(@memberCount(MyErrSet) == 2);

    const a: MyErrSet!i32 = 5678;
    const b: MyErrSet!i32 = MyErrSet.OutOfMemory;

    if (a) |value| assert(value == 5678) else |err| switch (err) {
        error.OutOfMemory => unreachable,
        error.FileNotFound => unreachable,
    }
}
