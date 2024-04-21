const builtin = @import("builtin");
const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;
const expectError = std.testing.expectError;
const expectEqual = std.testing.expectEqual;

test "switch with numbers" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try testSwitchWithNumbers(13);
}

fn testSwitchWithNumbers(x: u32) !void {
    const result = switch (x) {
        1, 2, 3, 4...8 => false,
        13 => true,
        else => false,
    };
    try expect(result);
}

test "switch with all ranges" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try expect(testSwitchWithAllRanges(50, 3) == 1);
    try expect(testSwitchWithAllRanges(101, 0) == 2);
    try expect(testSwitchWithAllRanges(300, 5) == 3);
    try expect(testSwitchWithAllRanges(301, 6) == 6);
}

fn testSwitchWithAllRanges(x: u32, y: u32) u32 {
    return switch (x) {
        0...100 => 1,
        101...200 => 2,
        201...300 => 3,
        else => y,
    };
}

test "implicit comptime switch" {
    const x = 3 + 4;
    const result = switch (x) {
        3 => 10,
        4 => 11,
        5, 6 => 12,
        7, 8 => 13,
        else => 14,
    };

    comptime {
        try expect(result + 1 == 14);
    }
}

test "switch on enum" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const fruit = Fruit.Orange;
    nonConstSwitchOnEnum(fruit);
}
const Fruit = enum {
    Apple,
    Orange,
    Banana,
};
fn nonConstSwitchOnEnum(fruit: Fruit) void {
    switch (fruit) {
        Fruit.Apple => unreachable,
        Fruit.Orange => {},
        Fruit.Banana => unreachable,
    }
}

test "switch statement" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try nonConstSwitch(SwitchStatementFoo.C);
}
fn nonConstSwitch(foo: SwitchStatementFoo) !void {
    const val = switch (foo) {
        SwitchStatementFoo.A => @as(i32, 1),
        SwitchStatementFoo.B => 2,
        SwitchStatementFoo.C => 3,
        SwitchStatementFoo.D => 4,
    };
    try expect(val == 3);
}
const SwitchStatementFoo = enum { A, B, C, D };

test "switch with multiple expressions" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const x = switch (returnsFive()) {
        1, 2, 3 => 1,
        4, 5, 6 => 2,
        else => @as(i32, 3),
    };
    try expect(x == 2);
}
fn returnsFive() i32 {
    return 5;
}

test "switch on type" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try expect(trueIfBoolFalseOtherwise(bool));
    try expect(!trueIfBoolFalseOtherwise(i32));
}

fn trueIfBoolFalseOtherwise(comptime T: type) bool {
    return switch (T) {
        bool => true,
        else => false,
    };
}

test "switching on booleans" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try testSwitchOnBools();
    try comptime testSwitchOnBools();
}

fn testSwitchOnBools() !void {
    try expect(testSwitchOnBoolsTrueAndFalse(true) == false);
    try expect(testSwitchOnBoolsTrueAndFalse(false) == true);

    try expect(testSwitchOnBoolsTrueWithElse(true) == false);
    try expect(testSwitchOnBoolsTrueWithElse(false) == true);

    try expect(testSwitchOnBoolsFalseWithElse(true) == false);
    try expect(testSwitchOnBoolsFalseWithElse(false) == true);
}

fn testSwitchOnBoolsTrueAndFalse(x: bool) bool {
    return switch (x) {
        true => false,
        false => true,
    };
}

fn testSwitchOnBoolsTrueWithElse(x: bool) bool {
    return switch (x) {
        true => false,
        else => true,
    };
}

fn testSwitchOnBoolsFalseWithElse(x: bool) bool {
    return switch (x) {
        false => true,
        else => false,
    };
}

test "u0" {
    var val: u0 = 0;
    _ = &val;
    switch (val) {
        0 => try expect(val == 0),
    }
}

test "undefined.u0" {
    var val: u0 = undefined;
    _ = &val;
    switch (val) {
        0 => try expect(val == 0),
    }
}

test "switch with disjoint range" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var q: u8 = 0;
    _ = &q;
    switch (q) {
        0...125 => {},
        127...255 => {},
        126...126 => {},
    }
}

test "switch variable for range and multiple prongs" {
    const S = struct {
        fn doTheTest() !void {
            try doTheSwitch(16);
            try doTheSwitch(42);
        }
        fn doTheSwitch(q: u8) !void {
            switch (q) {
                0...40 => |x| try expect(x == 16),
                41, 42, 43 => |x| try expect(x == 42),
                else => try expect(false),
            }
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

var state: u32 = 0;
fn poll() void {
    switch (state) {
        0 => {
            state = 1;
        },
        else => {
            state += 1;
        },
    }
}

test "switch on global mutable var isn't constant-folded" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    while (state < 2) {
        poll();
    }
}

const SwitchProngWithVarEnum = union(enum) {
    One: i32,
    Two: f32,
    Meh: void,
};

test "switch prong with variable" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try switchProngWithVarFn(SwitchProngWithVarEnum{ .One = 13 });
    try switchProngWithVarFn(SwitchProngWithVarEnum{ .Two = 13.0 });
    try switchProngWithVarFn(SwitchProngWithVarEnum{ .Meh = {} });
}
fn switchProngWithVarFn(a: SwitchProngWithVarEnum) !void {
    switch (a) {
        SwitchProngWithVarEnum.One => |x| {
            try expect(x == 13);
        },
        SwitchProngWithVarEnum.Two => |x| {
            try expect(x == 13.0);
        },
        SwitchProngWithVarEnum.Meh => |x| {
            const v: void = x;
            _ = v;
        },
    }
}

test "switch on enum using pointer capture" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try testSwitchEnumPtrCapture();
    try comptime testSwitchEnumPtrCapture();
}

fn testSwitchEnumPtrCapture() !void {
    var value = SwitchProngWithVarEnum{ .One = 1234 };
    switch (value) {
        SwitchProngWithVarEnum.One => |*x| x.* += 1,
        else => unreachable,
    }
    switch (value) {
        SwitchProngWithVarEnum.One => |x| try expect(x == 1235),
        else => unreachable,
    }
}

test "switch handles all cases of number" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try testSwitchHandleAllCases();
    try comptime testSwitchHandleAllCases();
}

fn testSwitchHandleAllCases() !void {
    try expect(testSwitchHandleAllCasesExhaustive(0) == 3);
    try expect(testSwitchHandleAllCasesExhaustive(1) == 2);
    try expect(testSwitchHandleAllCasesExhaustive(2) == 1);
    try expect(testSwitchHandleAllCasesExhaustive(3) == 0);

    try expect(testSwitchHandleAllCasesRange(100) == 0);
    try expect(testSwitchHandleAllCasesRange(200) == 1);
    try expect(testSwitchHandleAllCasesRange(201) == 2);
    try expect(testSwitchHandleAllCasesRange(202) == 4);
    try expect(testSwitchHandleAllCasesRange(230) == 3);
}

fn testSwitchHandleAllCasesExhaustive(x: u2) u2 {
    return switch (x) {
        0 => @as(u2, 3),
        1 => 2,
        2 => 1,
        3 => 0,
    };
}

fn testSwitchHandleAllCasesRange(x: u8) u8 {
    return switch (x) {
        0...100 => @as(u8, 0),
        101...200 => 1,
        201, 203 => 2,
        202 => 4,
        204...255 => 3,
    };
}

test "switch on union with some prongs capturing" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const X = union(enum) {
        a,
        b: i32,
    };

    var x: X = X{ .b = 10 };
    _ = &x;
    const y: i32 = switch (x) {
        .a => unreachable,
        .b => |b| b + 1,
    };
    try expect(y == 11);
}

const Number = union(enum) {
    One: u64,
    Two: u8,
    Three: f32,
};

const number = Number{ .Three = 1.23 };

fn returnsFalse() bool {
    switch (number) {
        Number.One => |x| return x > 1234,
        Number.Two => |x| return x == 'a',
        Number.Three => |x| return x > 12.34,
    }
}
test "switch on const enum with var" {
    try expect(!returnsFalse());
}

test "anon enum literal used in switch on union enum" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const Foo = union(enum) {
        a: i32,
    };

    var foo = Foo{ .a = 1234 };
    _ = &foo;
    switch (foo) {
        .a => |x| {
            try expect(x == 1234);
        },
    }
}

test "switch all prongs unreachable" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try testAllProngsUnreachable();
    try comptime testAllProngsUnreachable();
}

fn testAllProngsUnreachable() !void {
    try expect(switchWithUnreachable(1) == 2);
    try expect(switchWithUnreachable(2) == 10);
}

fn switchWithUnreachable(x: i32) i32 {
    while (true) {
        switch (x) {
            1 => return 2,
            2 => break,
            else => continue,
        }
    }
    return 10;
}

test "capture value of switch with all unreachable prongs" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const x = return_a_number() catch |err| switch (err) {
        else => unreachable,
    };
    try expect(x == 1);
}

fn return_a_number() anyerror!i32 {
    return 1;
}

test "switch on integer with else capturing expr" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            var x: i32 = 5;
            _ = &x;
            switch (x + 10) {
                14 => return error.TestFailed,
                16 => return error.TestFailed,
                else => |e| try expect(e == 15),
            }
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "else prong of switch on error set excludes other cases" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() !void {
            try expectError(error.C, bar());
        }
        const E = error{
            A,
            B,
        } || E2;

        const E2 = error{
            C,
            D,
        };

        fn foo() E!void {
            return error.C;
        }

        fn bar() E2!void {
            foo() catch |err| switch (err) {
                error.A, error.B => {},
                else => |e| return e,
            };
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "switch prongs with error set cases make a new error set type for capture value" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() !void {
            try expectError(error.B, bar());
        }
        const E = E1 || E2;

        const E1 = error{
            A,
            B,
        };

        const E2 = error{
            C,
            D,
        };

        fn foo() E!void {
            return error.B;
        }

        fn bar() E1!void {
            foo() catch |err| switch (err) {
                error.A, error.B => |e| return e,
                else => {},
            };
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "return result loc and then switch with range implicit casted to error union" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            try expect((func(0xb) catch unreachable) == 0xb);
        }
        fn func(d: u8) anyerror!u8 {
            return switch (d) {
                0xa...0xf => d,
                else => unreachable,
            };
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "switch with null and T peer types and inferred result location type" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest(c: u8) !void {
            if (switch (c) {
                0 => true,
                else => null,
            }) |v| {
                _ = v;
                return error.TestFailed;
            }
        }
    };
    try S.doTheTest(1);
    try comptime S.doTheTest(1);
}

test "switch prongs with cases with identical payload types" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const Union = union(enum) {
        A: usize,
        B: isize,
        C: usize,
    };
    const S = struct {
        fn doTheTest() !void {
            try doTheSwitch1(Union{ .A = 8 });
            try doTheSwitch2(Union{ .B = -8 });
        }
        fn doTheSwitch1(u: Union) !void {
            switch (u) {
                .A, .C => |e| {
                    comptime assert(@TypeOf(e) == usize);
                    try expect(e == 8);
                },
                .B => |e| {
                    _ = e;
                    return error.TestFailed;
                },
            }
        }
        fn doTheSwitch2(u: Union) !void {
            switch (u) {
                .A, .C => |e| {
                    _ = e;
                    return error.TestFailed;
                },
                .B => |e| {
                    comptime assert(@TypeOf(e) == isize);
                    try expect(e == -8);
                },
            }
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "switch prong pointer capture alignment" {
    const U = union(enum) {
        a: u8 align(8),
        b: u8 align(4),
        c: u8,
    };

    const S = struct {
        fn doTheTest() !void {
            const u = U{ .a = 1 };
            switch (u) {
                .a => |*a| comptime assert(@TypeOf(a) == *align(8) const u8),
                .b, .c => |*p| {
                    _ = p;
                    return error.TestFailed;
                },
            }

            switch (u) {
                .a, .b => |*p| comptime assert(@TypeOf(p) == *align(4) const u8),
                .c => |*p| {
                    _ = p;
                    return error.TestFailed;
                },
            }

            switch (u) {
                .a, .c => |*p| comptime assert(@TypeOf(p) == *const u8),
                .b => |*p| {
                    _ = p;
                    return error.TestFailed;
                },
            }
        }

        fn doTheTest2() !void {
            const un1 = U{ .b = 1 };
            switch (un1) {
                .b => |*b| comptime assert(@TypeOf(b) == *align(4) const u8),
                .a, .c => |*p| {
                    _ = p;
                    return error.TestFailed;
                },
            }

            const un2 = U{ .c = 1 };
            switch (un2) {
                .c => |*c| comptime assert(@TypeOf(c) == *const u8),
                .a, .b => |*p| {
                    _ = p;
                    return error.TestFailed;
                },
            }
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();

    try S.doTheTest2();
    try comptime S.doTheTest2();
}

test "switch on pointer type" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        const X = struct {
            field: u32,
        };

        const P1 = @as(*X, @ptrFromInt(0x400));
        const P2 = @as(*X, @ptrFromInt(0x800));
        const P3 = @as(*X, @ptrFromInt(0xC00));

        fn doTheTest(arg: *X) i32 {
            switch (arg) {
                P1 => return 1,
                P2 => return 2,
                else => return 3,
            }
        }
    };

    try expect(1 == S.doTheTest(S.P1));
    try expect(2 == S.doTheTest(S.P2));
    try expect(3 == S.doTheTest(S.P3));
    comptime assert(1 == S.doTheTest(S.P1));
    comptime assert(2 == S.doTheTest(S.P2));
    comptime assert(3 == S.doTheTest(S.P3));
}

test "switch on error set with single else" {
    const S = struct {
        fn doTheTest() !void {
            var some: error{Foo} = error.Foo;
            _ = &some;
            try expect(switch (some) {
                else => blk: {
                    break :blk true;
                },
            });
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}

test "switch capture copies its payload" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            var tmp: union(enum) {
                A: u8,
                B: u32,
            } = .{ .A = 42 };
            switch (tmp) {
                .A => |value| {
                    // Modify the original union
                    tmp = .{ .B = 0x10101010 };
                    try expectEqual(@as(u8, 42), value);
                },
                else => unreachable,
            }
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "capture of integer forwards the switch condition directly" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn foo(x: u8) !void {
            switch (x) {
                40...45 => |capture| {
                    try expect(capture == 42);
                },
                else => |capture| {
                    try expect(capture == 100);
                },
            }
        }
    };
    try S.foo(42);
    try S.foo(100);
    try comptime S.foo(42);
    try comptime S.foo(100);
}

test "enum value without tag name used as switch item" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const E = enum(u32) {
        a = 1,
        b = 2,
        _,
    };
    var e: E = @enumFromInt(0);
    _ = &e;
    switch (e) {
        @as(E, @enumFromInt(0)) => {},
        .a => return error.TestFailed,
        .b => return error.TestFailed,
        _ => return error.TestFailed,
    }
}

test "switch item sizeof" {
    const S = struct {
        fn doTheTest() !void {
            var a: usize = 0;
            _ = &a;
            switch (a) {
                @sizeOf(struct {}) => {},
                else => return error.TestFailed,
            }
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "comptime inline switch" {
    const U = union(enum) { a: type, b: type };
    const value = comptime blk: {
        var u: U = .{ .a = u32 };
        _ = &u;
        break :blk switch (u) {
            inline .a, .b => |v| v,
        };
    };

    try expectEqual(u32, value);
}

test "switch capture peer type resolution" {
    const U = union(enum) {
        a: u32,
        b: u64,
        fn innerVal(u: @This()) u64 {
            switch (u) {
                .a, .b => |x| return x,
            }
        }
    };

    try expectEqual(@as(u64, 100), U.innerVal(.{ .a = 100 }));
    try expectEqual(@as(u64, 200), U.innerVal(.{ .b = 200 }));
}

test "switch capture peer type resolution for in-memory coercible payloads" {
    const T1 = c_int;
    const T2 = @Type(@typeInfo(T1));

    comptime assert(T1 != T2);

    const U = union(enum) {
        a: T1,
        b: T2,
        fn innerVal(u: @This()) c_int {
            switch (u) {
                .a, .b => |x| return x,
            }
        }
    };

    try expectEqual(@as(c_int, 100), U.innerVal(.{ .a = 100 }));
    try expectEqual(@as(c_int, 200), U.innerVal(.{ .b = 200 }));
}

test "switch pointer capture peer type resolution" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const T1 = c_int;
    const T2 = @Type(@typeInfo(T1));

    comptime assert(T1 != T2);

    const U = union(enum) {
        a: T1,
        b: T2,
        fn innerVal(u: *@This()) *c_int {
            switch (u.*) {
                .a, .b => |*ptr| return ptr,
            }
        }
    };

    var ua: U = .{ .a = 100 };
    var ub: U = .{ .b = 200 };

    ua.innerVal().* = 111;
    ub.innerVal().* = 222;

    try expectEqual(U{ .a = 111 }, ua);
    try expectEqual(U{ .b = 222 }, ub);
}

test "inline switch range that includes the maximum value of the switched type" {
    const inputs: [3]u8 = .{ 0, 254, 255 };
    for (inputs) |input| {
        switch (input) {
            inline 254...255 => |val| try expectEqual(input, val),
            else => |val| try expectEqual(input, val),
        }
    }
}

test "nested break ignores switch conditions and breaks instead" {
    const S = struct {
        fn register_to_address(ident: []const u8) !u8 {
            const reg: u8 = if (std.mem.eql(u8, ident, "zero")) 0x00 else blk: {
                break :blk switch (ident[0]) {
                    0x61 => (try std.fmt.parseInt(u8, ident[1..], 0)) + 1,
                    0x66 => (try std.fmt.parseInt(u8, ident[1..], 0)) + 1,
                    else => {
                        break :blk 0xFF;
                    },
                };
            };
            return reg;
        }
    };
    // Originally reported at https://github.com/ziglang/zig/issues/10196
    try expect(0x01 == try S.register_to_address("a0"));
}

test "peer type resolution on switch captures ignores unused payload bits" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const Foo = union(enum) {
        a: u32,
        b: u64,
    };

    var val: Foo = undefined;
    @memset(std.mem.asBytes(&val), 0xFF);

    // This is runtime-known so the following store isn't comptime-known.
    var rt: u32 = 123;
    _ = &rt;
    val = .{ .a = rt }; // will not necessarily zero remaning payload memory

    // Fields intentionally backwards here
    const x = switch (val) {
        .b, .a => |x| x,
    };

    try expect(x == 123);
}

test "switch prong captures range" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn a(b: []u3, c: u3) void {
            switch (c) {
                0...1 => b[c] = c,
                2...3 => b[c] = c,
                4...7 => |d| b[d] = c,
            }
        }
    };

    var arr: [8]u3 = undefined;
    S.a(&arr, 5);
    try expect(arr[5] == 5);
}

test "prong with inline call to unreachable" {
    const U = union(enum) {
        void: void,
        bool: bool,

        inline fn unreach() noreturn {
            unreachable;
        }
    };
    var u: U = undefined;
    u = .{ .bool = true };
    switch (u) {
        .void => U.unreach(),
        .bool => |ok| try expect(ok),
    }
}

test "block error return trace index is reset between prongs" {
    const S = struct {
        fn returnError() error{TestFailed} {
            return error.TestFailed;
        }
    };

    var x: u1 = 0;
    _ = &x;

    const result = switch (x) {
        0 => {
            const result: anyerror!i32 = blk: {
                break :blk 1;
            };
            _ = &result;
        },
        1 => blk: {
            const err = switch (x) {
                0 => {},
                1 => S.returnError(),
            };
            break :blk err;
        },
    };
    try result;
}
