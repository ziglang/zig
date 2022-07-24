const builtin = @import("builtin");
const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const mem = std.mem;

/// A more basic implementation of std.testing.expectError which
/// does not require formatter/printing support
fn expectError(expected_err: anyerror, observed_err_union: anytype) !void {
    if (observed_err_union) {
        return error.TestExpectedError;
    } else |err| if (err == expected_err) {
        return; // Success
    }
    return error.TestExpectedError;
}

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
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

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
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    try expect((baz() catch unreachable) == 15);
}

test "unwrap simple value from error" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    const i = unwrapSimpleValueFromErrorDo() catch unreachable;
    try expect(i == 13);
}
fn unwrapSimpleValueFromErrorDo() anyerror!isize {
    return 13;
}

test "error return in assignment" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

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
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

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
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    const SomeError = error{ Hello, Hello2 };
    var a_local_variable: ?SomeError = null;
    _ = a_local_variable;
}

test "implicit cast to optional to error union to return result loc" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

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

test "fn returning empty error set can be passed as fn returning any error" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    entry();
    comptime entry();
}

test "fn returning empty error set can be passed as fn returning any error - pointer" {
    if (builtin.zig_backend == .stage1) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    entryPtr();
    comptime entryPtr();
}

fn entry() void {
    foo2(bar2);
}

fn entryPtr() void {
    var ptr = &bar2;
    fooPtr(ptr);
}

fn foo2(f: fn () anyerror!void) void {
    const x = f();
    x catch {
        @panic("fail");
    };
}

fn fooPtr(f: *const fn () anyerror!void) void {
    const x = f();
    x catch {
        @panic("fail");
    };
}

fn bar2() (error{}!void) {}

test "error union type " {
    try testErrorUnionType();
    comptime try testErrorUnionType();
}

fn testErrorUnionType() !void {
    const x: anyerror!i32 = 1234;
    if (x) |value| try expect(value == 1234) else |_| unreachable;
    try expect(@typeInfo(@TypeOf(x)) == .ErrorUnion);
    try expect(@typeInfo(@typeInfo(@TypeOf(x)).ErrorUnion.error_set) == .ErrorSet);
    try expect(@typeInfo(@TypeOf(x)).ErrorUnion.error_set == anyerror);
}

test "error set type" {
    try testErrorSetType();
    comptime try testErrorSetType();
}

const MyErrSet = error{
    OutOfMemory,
    FileNotFound,
};

fn testErrorSetType() !void {
    try expect(@typeInfo(MyErrSet).ErrorSet.?.len == 2);

    const a: MyErrSet!i32 = 5678;
    const b: MyErrSet!i32 = MyErrSet.OutOfMemory;
    try expect(b catch error.OutOfMemory == error.OutOfMemory);

    if (a) |value| try expect(value == 5678) else |err| switch (err) {
        error.OutOfMemory => unreachable,
        error.FileNotFound => unreachable,
    }
}

test "explicit error set cast" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    try testExplicitErrorSetCast(Set1.A);
    comptime try testExplicitErrorSetCast(Set1.A);
}

const Set1 = error{ A, B };
const Set2 = error{ A, C };

fn testExplicitErrorSetCast(set1: Set1) !void {
    var x = @errSetCast(Set2, set1);
    try expect(@TypeOf(x) == Set2);
    var y = @errSetCast(Set1, x);
    try expect(@TypeOf(y) == Set1);
    try expect(y == error.A);
}

test "comptime test error for empty error set" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    try testComptimeTestErrorEmptySet(1234);
    comptime try testComptimeTestErrorEmptySet(1234);
}

const EmptyErrorSet = error{};

fn testComptimeTestErrorEmptySet(x: EmptyErrorSet!i32) !void {
    if (x) |v| try expect(v == 1234) else |err| {
        _ = err;
        @compileError("bad");
    }
}

test "comptime err to int of error set with only 1 possible value" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

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

test "inferred empty error set comptime catch" {
    const S = struct {
        fn foo() !void {}
    };
    S.foo() catch @compileError("fail");
}

test "error union peer type resolution" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    try testErrorUnionPeerTypeResolution(1);
}

fn testErrorUnionPeerTypeResolution(x: i32) !void {
    const y = switch (x) {
        1 => bar_1(),
        2 => baz_1(),
        else => quux_1(),
    };
    if (y) |_| {
        @panic("expected error");
    } else |e| {
        try expect(e == error.A);
    }
}

fn bar_1() anyerror {
    return error.A;
}

fn baz_1() !i32 {
    return error.B;
}

fn quux_1() !i32 {
    return error.C;
}

test "error: Zero sized error set returned with value payload crash" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    _ = try foo3(0);
    _ = comptime try foo3(0);
}

const Error = error{};
fn foo3(b: usize) Error!usize {
    return b;
}

test "error: Infer error set from literals" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    _ = nullLiteral("n") catch |err| handleErrors(err);
    _ = floatLiteral("n") catch |err| handleErrors(err);
    _ = intLiteral("n") catch |err| handleErrors(err);
    _ = comptime nullLiteral("n") catch |err| handleErrors(err);
    _ = comptime floatLiteral("n") catch |err| handleErrors(err);
    _ = comptime intLiteral("n") catch |err| handleErrors(err);
}

fn handleErrors(err: anytype) noreturn {
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

test "nested error union function call in optional unwrap" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    const S = struct {
        const Foo = struct {
            a: i32,
        };

        fn errorable() !i32 {
            var x: Foo = (try getFoo()) orelse return error.Other;
            return x.a;
        }

        fn errorable2() !i32 {
            var x: Foo = (try getFoo2()) orelse return error.Other;
            return x.a;
        }

        fn errorable3() !i32 {
            var x: Foo = (try getFoo3()) orelse return error.Other;
            return x.a;
        }

        fn getFoo() anyerror!?Foo {
            return Foo{ .a = 1234 };
        }

        fn getFoo2() anyerror!?Foo {
            return error.Failure;
        }

        fn getFoo3() anyerror!?Foo {
            return null;
        }
    };
    try expect((try S.errorable()) == 1234);
    try expectError(error.Failure, S.errorable2());
    try expectError(error.Other, S.errorable3());
    comptime {
        try expect((try S.errorable()) == 1234);
        try expectError(error.Failure, S.errorable2());
        try expectError(error.Other, S.errorable3());
    }
}

test "return function call to error set from error union function" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    const S = struct {
        fn errorable() anyerror!i32 {
            return fail();
        }

        fn fail() anyerror {
            return error.Failure;
        }
    };
    try expectError(error.Failure, S.errorable());
    comptime try expectError(error.Failure, S.errorable());
}

test "optional error set is the same size as error set" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    comptime try expect(@sizeOf(?anyerror) == @sizeOf(anyerror));
    comptime try expect(@alignOf(?anyerror) == @alignOf(anyerror));
    const S = struct {
        fn returnsOptErrSet() ?anyerror {
            return null;
        }
    };
    try expect(S.returnsOptErrSet() == null);
    comptime try expect(S.returnsOptErrSet() == null);
}

test "nested catch" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    const S = struct {
        fn entry() !void {
            try expectError(error.Bad, func());
        }
        fn fail() anyerror!Foo {
            return error.Wrong;
        }
        fn func() anyerror!Foo {
            _ = fail() catch
                fail() catch
                return error.Bad;
            unreachable;
        }
        const Foo = struct {
            field: i32,
        };
    };
    try S.entry();
    comptime try S.entry();
}

test "function pointer with return type that is error union with payload which is pointer of parent struct" {
    if (builtin.zig_backend == .stage1) {
        // stage1 has wrong function pointer semantics
        return error.SkipZigTest;
    }

    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    const S = struct {
        const Foo = struct {
            fun: *const fn (a: i32) (anyerror!*Foo),
        };

        const Err = error{UnspecifiedErr};

        fn bar(a: i32) anyerror!*Foo {
            _ = a;
            return Err.UnspecifiedErr;
        }

        fn doTheTest() !void {
            var x = Foo{ .fun = @This().bar };
            try expectError(error.UnspecifiedErr, x.fun(1));
        }
    };
    try S.doTheTest();
}

test "return result loc as peer result loc in inferred error set function" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            if (quux(2)) |x| {
                try expect(x.Two);
            } else |e| switch (e) {
                error.Whatever => @panic("fail"),
            }
            try expectError(error.Whatever, quux(99));
        }
        const FormValue = union(enum) {
            One: void,
            Two: bool,
        };

        fn quux(id: u64) !FormValue {
            return switch (id) {
                2 => FormValue{ .Two = true },
                1 => FormValue{ .One = {} },
                else => return error.Whatever,
            };
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "error payload type is correctly resolved" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    const MyIntWrapper = struct {
        const Self = @This();

        x: i32,

        pub fn create() anyerror!Self {
            return Self{ .x = 42 };
        }
    };

    try expect(std.meta.eql(MyIntWrapper{ .x = 42 }, try MyIntWrapper.create()));
}

test "error union comptime caching" {
    const S = struct {
        fn quux(comptime arg: anytype) void {
            arg catch {};
        }
    };

    S.quux(@as(anyerror!void, {}));
    S.quux(@as(anyerror!void, {}));
}

test "@errorName" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    try expect(mem.eql(u8, @errorName(error.AnError), "AnError"));
    try expect(mem.eql(u8, @errorName(error.ALongerErrorName), "ALongerErrorName"));
    try expect(mem.eql(u8, @errorName(gimmeItBroke()), "ItBroke"));
}
fn gimmeItBroke() anyerror {
    return error.ItBroke;
}

test "@errorName sentinel length matches slice length" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    const name = testBuiltinErrorName(error.FooBar);
    const length: usize = 6;
    try expect(length == std.mem.indexOfSentinel(u8, 0, name.ptr));
    try expect(length == name.len);
}

pub fn testBuiltinErrorName(err: anyerror) [:0]const u8 {
    return @errorName(err);
}

test "error set equality" {
    // This tests using stage2 logic (#11022)
    if (builtin.zig_backend == .stage1) return error.SkipZigTest;

    const a = error{One};
    const b = error{One};

    try expect(a == a);
    try expect(a == b);
    try expect(a == error{One});

    // should treat as a set
    const c = error{ One, Two };
    const d = error{ Two, One };

    try expect(c == d);
}

test "inferred error set equality" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    const S = struct {
        fn foo() !void {
            return @This().bar();
        }

        fn bar() !void {
            return error.Bad;
        }

        fn baz() !void {
            return quux();
        }

        fn quux() anyerror!void {}
    };

    const FooError = @typeInfo(@typeInfo(@TypeOf(S.foo)).Fn.return_type.?).ErrorUnion.error_set;
    const BarError = @typeInfo(@typeInfo(@TypeOf(S.bar)).Fn.return_type.?).ErrorUnion.error_set;
    const BazError = @typeInfo(@typeInfo(@TypeOf(S.baz)).Fn.return_type.?).ErrorUnion.error_set;

    try expect(BarError != error{Bad});

    try expect(FooError != anyerror);
    try expect(BarError != anyerror);
    try expect(BazError != anyerror);

    try expect(FooError != BarError);
    try expect(FooError != BazError);
    try expect(BarError != BazError);

    try expect(FooError == FooError);
    try expect(BarError == BarError);
    try expect(BazError == BazError);
}

test "peer type resolution of two different error unions" {
    const a: error{B}!void = {};
    const b: error{A}!void = {};
    var cond = true;
    const err = if (cond) a else b;
    try err;
}

test "coerce error set to the current inferred error set" {
    const S = struct {
        fn foo() !void {
            var a = false;
            if (a) {
                const b: error{A}!void = error.A;
                return b;
            }
            const b = error.A;
            return b;
        }
    };
    S.foo() catch {};
}

test "error union payload is properly aligned" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    const S = struct {
        a: u128,
        b: u128,
        c: u128,
        fn foo() error{}!@This() {
            return @This(){ .a = 1, .b = 2, .c = 3 };
        }
    };
    const blk = S.foo() catch unreachable;
    if (blk.a != 1) unreachable;
}

test "ret_ptr doesn't cause own inferred error set to be resolved" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    const S = struct {
        fn foo() !void {}

        fn doTheTest() !void {
            errdefer @compileError("bad");

            return try @This().foo();
        }
    };
    try S.doTheTest();
}

test "simple else prong allowed even when all errors handled" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO

    const S = struct {
        fn foo() !u8 {
            return error.Foo;
        }
    };
    var value = S.foo() catch |err| switch (err) {
        error.Foo => @as(u8, 255),
        else => |e| return e,
    };
    try expect(value == 255);
    value = S.foo() catch |err| switch (err) {
        error.Foo => 255,
        else => unreachable,
    };
    try expect(value == 255);
    value = S.foo() catch |err| switch (err) {
        error.Foo => 255,
        else => return,
    };
    try expect(value == 255);
}
