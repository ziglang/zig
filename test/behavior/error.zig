const builtin = @import("builtin");
const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const mem = std.mem;

/// A more basic implementation of std.testing.expectError which
/// does not require formatter/printing support
fn expectError(expected_err: anyerror, observed_err_union: anytype) !void {
    if (observed_err_union) |_| {
        return error.TestExpectedError;
    } else |err| if (err == expected_err) {
        return; // Success
    }
    return error.TestExpectedError;
}

test "error values" {
    const a = @intFromError(error.err1);
    const b = @intFromError(error.err2);
    try expect(a != b);
}

test "redefinition of error values allowed" {
    shouldBeNotEqual(error.AnError, error.SecondError);
}
fn shouldBeNotEqual(a: anyerror, b: anyerror) void {
    if (a == b) unreachable;
}

test "error binary operator" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try expect((baz() catch unreachable) == 15);
}

test "unwrap simple value from error" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const i = unwrapSimpleValueFromErrorDo() catch unreachable;
    try expect(i == 13);
}
fn unwrapSimpleValueFromErrorDo() anyerror!isize {
    return 13;
}

test "error return in assignment" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn errorable() !u64 {
            return @as(u64, try number());
        }

        fn number() anyerror!u32 {
            return 1234;
        }
    };
    try expect((try S.errorable()) == 1234);
}

test "debug info for optional error set" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const SomeError = error{ Hello, Hello2 };
    var a_local_variable: ?SomeError = null;
    _ = &a_local_variable;
}

test "implicit cast to optional to error union to return result loc" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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
    entry();
    comptime entry();
}

test "fn returning empty error set can be passed as fn returning any error - pointer" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    entryPtr();
    comptime entryPtr();
}

fn entry() void {
    foo2(bar2);
}

fn entryPtr() void {
    var ptr = &bar2;
    _ = &ptr;
    fooPtr(ptr);
}

fn foo2(comptime f: fn () anyerror!void) void {
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
    try comptime testErrorUnionType();
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
    try comptime testErrorSetType();
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
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try testExplicitErrorSetCast(Set1.A);
    try comptime testExplicitErrorSetCast(Set1.A);
}

const Set1 = error{ A, B };
const Set2 = error{ A, C };

fn testExplicitErrorSetCast(set1: Set1) !void {
    const x: Set2 = @errorCast(set1);
    try expect(@TypeOf(x) == Set2);
    const y: Set1 = @errorCast(x);
    try expect(@TypeOf(y) == Set1);
    try expect(y == error.A);
}

test "@errorCast on error unions" {
    const S = struct {
        fn doTheTest() !void {
            {
                const casted: error{Bad}!i32 = @errorCast(retErrUnion());
                try expect((try casted) == 1234);
            }
            {
                const casted: error{Bad}!i32 = @errorCast(retInferredErrUnion());
                try expect((try casted) == 5678);
            }
        }

        fn retErrUnion() anyerror!i32 {
            return 1234;
        }

        fn retInferredErrUnion() !i32 {
            return 5678;
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}

test "comptime test error for empty error set" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try testComptimeTestErrorEmptySet(1234);
    try comptime testComptimeTestErrorEmptySet(1234);
}

const EmptyErrorSet = error{};

fn testComptimeTestErrorEmptySet(x: EmptyErrorSet!i32) !void {
    if (x) |v| try expect(v == 1234) else |err| {
        _ = err;
        @compileError("bad");
    }
}

test "comptime err to int of error set with only 1 possible value" {
    testErrToIntWithOnePossibleValue(error.A, @intFromError(error.A));
    comptime testErrToIntWithOnePossibleValue(error.A, @intFromError(error.A));
}
fn testErrToIntWithOnePossibleValue(
    x: error{A},
    comptime value: u32,
) void {
    if (@intFromError(x) != value) {
        @compileError("bad");
    }
}

test "inferred empty error set comptime catch" {
    const S = struct {
        fn foo() !void {}
    };
    S.foo() catch @compileError("fail");
}

test "error inference with an empty set" {
    const S = struct {
        const Struct = struct {
            pub fn func() (error{})!usize {
                return 0;
            }
        };

        fn AnotherStruct(comptime SubStruct: type) type {
            return struct {
                fn anotherFunc() !void {
                    try expect(0 == (try SubStruct.func()));
                }
            };
        }
    };

    const GeneratedStruct = S.AnotherStruct(S.Struct);
    try GeneratedStruct.anotherFunc();
}

test "error union peer type resolution" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    _ = try foo3(0);
    _ = try comptime foo3(0);
}

const Error = error{};
fn foo3(b: usize) Error!usize {
    return b;
}

test "error: Infer error set from literals" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

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
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        const Foo = struct {
            a: i32,
        };

        fn errorable() !i32 {
            const x: Foo = (try getFoo()) orelse return error.Other;
            return x.a;
        }

        fn errorable2() !i32 {
            const x: Foo = (try getFoo2()) orelse return error.Other;
            return x.a;
        }

        fn errorable3() !i32 {
            const x: Foo = (try getFoo3()) orelse return error.Other;
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
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn errorable() anyerror!i32 {
            return fail();
        }

        fn fail() anyerror {
            return error.Failure;
        }
    };
    try expectError(error.Failure, S.errorable());
    comptime assert(error.Failure == S.errorable());
}

test "optional error set is the same size as error set" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    comptime assert(@sizeOf(?anyerror) == @sizeOf(anyerror));
    comptime assert(@alignOf(?anyerror) == @alignOf(anyerror));
    const S = struct {
        fn returnsOptErrSet() ?anyerror {
            return null;
        }
    };
    try expect(S.returnsOptErrSet() == null);
    comptime assert(S.returnsOptErrSet() == null);
}

test "nested catch" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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
    try comptime S.entry();
}

test "function pointer with return type that is error union with payload which is pointer of parent struct" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

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
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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
    try comptime S.doTheTest();
}

test "error payload type is correctly resolved" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    try expect(mem.eql(u8, @errorName(error.AnError), "AnError"));
    try expect(mem.eql(u8, @errorName(error.ALongerErrorName), "ALongerErrorName"));
    try expect(mem.eql(u8, @errorName(gimmeItBroke()), "ItBroke"));
}
fn gimmeItBroke() anyerror {
    return error.ItBroke;
}

test "@errorName sentinel length matches slice length" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const name = testBuiltinErrorName(error.FooBar);
    const length: usize = 6;
    try expect(length == std.mem.indexOfSentinel(u8, 0, name.ptr));
    try expect(length == name.len);
}

pub fn testBuiltinErrorName(err: anyerror) [:0]const u8 {
    return @errorName(err);
}

test "error set equality" {
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
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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
    _ = &cond;
    const err = if (cond) a else b;
    try err;
}

test "coerce error set to the current inferred error set" {
    const S = struct {
        fn foo() !void {
            var a = false;
            _ = &a;
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
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

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
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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

test "pointer to error union payload" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var err_union: anyerror!u8 = 15;

    const payload_ptr = &(err_union catch unreachable);
    try expect(payload_ptr.* == 15);
}

const NoReturn = struct {
    var a: u32 = undefined;
    fn someData() bool {
        a -= 1;
        return a == 0;
    }
    fn loop() !noreturn {
        while (true) {
            if (someData())
                return error.GenericFailure;
        }
    }
    fn testTry() anyerror {
        try loop();
    }
    fn testCatch() anyerror {
        loop() catch return error.OtherFailure;
        @compileError("bad");
    }
};

test "error union of noreturn used with if" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    NoReturn.a = 64;
    if (NoReturn.loop()) {
        @compileError("bad");
    } else |err| {
        try expect(err == error.GenericFailure);
    }
}

test "error union of noreturn used with try" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    NoReturn.a = 64;
    const err = NoReturn.testTry();
    try expect(err == error.GenericFailure);
}

test "error union of noreturn used with catch" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    NoReturn.a = 64;
    const err = NoReturn.testCatch();
    try expect(err == error.OtherFailure);
}

test "alignment of wrapping an error union payload" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const S = struct {
        const I = extern struct { x: i128 };

        fn foo() anyerror!I {
            var i: I = .{ .x = 1234 };
            _ = &i;
            return i;
        }
    };
    try expect((S.foo() catch unreachable).x == 1234);
}

test "compare error union and error set" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var a: anyerror = error.Foo;
    var b: anyerror!u32 = error.Bar;
    _ = &a;

    try expect(a != b);
    try expect(b != a);

    b = error.Foo;

    try expect(a == b);
    try expect(b == a);

    b = 2;

    try expect(a != b);
    try expect(b != a);
}

fn non_errorable() void {
    // Make sure catch works even in a function that does not call any errorable functions.
    //
    // This test is needed because stage 2's fix for #1923 means that catch blocks interact
    // with the error return trace index.
    var x: error{Foo}!void = {};
    _ = &x;
    return x catch {};
}

test "catch within a function that calls no errorable functions" {
    non_errorable();
}

test "error from comptime string" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const name = "Weird error name!";
    const S = struct {
        fn foo() !void {
            return @field(anyerror, name);
        }
    };
    if (S.foo()) unreachable else |err| {
        try expect(mem.eql(u8, name, @errorName(err)));
    }
}

test "field access of anyerror results in smaller error set" {
    const E1 = @TypeOf(error.Foo);
    try expect(@TypeOf(E1.Foo) == E1);
    const E2 = error{ A, B, C };
    try expect(@TypeOf(E2.A) == E2);
    try expect(@TypeOf(@field(anyerror, "NotFound")) == error{NotFound});
}

test "optional error union return type" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    const S = struct {
        fn foo() ?anyerror!u32 {
            var x: u32 = 1234;
            _ = &x;
            return @as(anyerror!u32, x);
        }
    };
    try expect(1234 == try S.foo().?);
}

test "optional error set return type" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    const E = error{ A, B };
    const S = struct {
        fn foo(return_null: bool) ?E {
            return if (return_null) null else E.A;
        }
    };

    try expect(null == S.foo(true));
    try expect(E.A == S.foo(false).?);
}

test "optional error set function parameter" {
    const S = struct {
        fn doTheTest(a: ?anyerror) !void {
            try std.testing.expect(a.? == error.OutOfMemory);
        }
    };
    try S.doTheTest(error.OutOfMemory);
    try comptime S.doTheTest(error.OutOfMemory);
}

test "returning an error union containing a type with no runtime bits" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const ZeroByteType = struct {
        foo: void,

        pub fn init() !@This() {
            return .{ .foo = {} };
        }
    };

    var zero_byte: ZeroByteType = undefined;
    (&zero_byte).* = try ZeroByteType.init();
}

test "try used in recursive function with inferred error set" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    const Value = union(enum) {
        values: []const @This(),
        b,

        fn x(value: @This()) !void {
            switch (value.values[0]) {
                .values => return try x(value.values[0]),
                .b => return error.a,
            }
        }
    };
    const a = Value{
        .values = &[1]Value{
            .{
                .values = &[1]Value{.{ .b = {} }},
            },
        },
    };
    try expectError(error.a, Value.x(a));
}

test "generic inline function returns inferred error set" {
    const S = struct {
        inline fn retErr(comptime T: type) !T {
            return error.AnError;
        }

        fn main0() !void {
            _ = try retErr(u8);
        }
    };
    S.main0() catch |e| {
        try std.testing.expect(e == error.AnError);
    };
}

test "function called at runtime is properly analyzed for inferred error set" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn foo() !void {
            var a = true;
            _ = &a;
            if (a) return error.Foo;
            return error.Bar;
        }
        fn bar() !void {
            try @This().foo();
        }
    };

    S.bar() catch |err| switch (err) {
        error.Foo => {},
        error.Bar => {},
    };
}

test "generic type constructed from inferred error set of unresolved function" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn write(_: void, bytes: []const u8) !usize {
            _ = bytes;
            return 0;
        }
        const T = std.io.Writer(void, @typeInfo(@typeInfo(@TypeOf(write)).Fn.return_type.?).ErrorUnion.error_set, write);
        fn writer() T {
            return .{ .context = {} };
        }
    };
    _ = std.io.multiWriter(.{S.writer()});
}

test "errorCast to adhoc inferred error set" {
    const S = struct {
        inline fn baz() !i32 {
            return @errorCast(err());
        }
        fn err() anyerror!i32 {
            return 1234;
        }
    };
    try std.testing.expect((try S.baz()) == 1234);
}

test "errorCast from error sets to error unions" {
    const err_union: Set1!void = @errorCast(error.A);
    try expectError(error.A, err_union);
}

test "result location initialization of error union with OPV payload" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        x: u0,
    };

    const a: anyerror!S = .{ .x = 0 };
    comptime assert((a catch unreachable).x == 0);

    comptime {
        var b: anyerror!S = .{ .x = 0 };
        _ = &b;
        assert((b catch unreachable).x == 0);
    }

    var c: anyerror!S = .{ .x = 0 };
    _ = &c;
    try expectEqual(0, (c catch return error.TestFailed).x);
}
