const std = @import("std");
const expect = std.testing.expect;
const expectError = std.testing.expectError;
const expectEqual = std.testing.expectEqual;

test "switch with numbers" {
    testSwitchWithNumbers(13);
}

fn testSwitchWithNumbers(x: u32) void {
    const result = switch (x) {
        1, 2, 3, 4...8 => false,
        13 => true,
        else => false,
    };
    expect(result);
}

test "switch with all ranges" {
    expect(testSwitchWithAllRanges(50, 3) == 1);
    expect(testSwitchWithAllRanges(101, 0) == 2);
    expect(testSwitchWithAllRanges(300, 5) == 3);
    expect(testSwitchWithAllRanges(301, 6) == 6);
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
        expect(result + 1 == 14);
    }
}

test "switch on enum" {
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
    nonConstSwitch(SwitchStatmentFoo.C);
}
fn nonConstSwitch(foo: SwitchStatmentFoo) void {
    const val = switch (foo) {
        SwitchStatmentFoo.A => @as(i32, 1),
        SwitchStatmentFoo.B => 2,
        SwitchStatmentFoo.C => 3,
        SwitchStatmentFoo.D => 4,
    };
    expect(val == 3);
}
const SwitchStatmentFoo = enum {
    A,
    B,
    C,
    D,
};

test "switch prong with variable" {
    switchProngWithVarFn(SwitchProngWithVarEnum{ .One = 13 });
    switchProngWithVarFn(SwitchProngWithVarEnum{ .Two = 13.0 });
    switchProngWithVarFn(SwitchProngWithVarEnum{ .Meh = {} });
}
const SwitchProngWithVarEnum = union(enum) {
    One: i32,
    Two: f32,
    Meh: void,
};
fn switchProngWithVarFn(a: SwitchProngWithVarEnum) void {
    switch (a) {
        SwitchProngWithVarEnum.One => |x| {
            expect(x == 13);
        },
        SwitchProngWithVarEnum.Two => |x| {
            expect(x == 13.0);
        },
        SwitchProngWithVarEnum.Meh => |x| {
            const v: void = x;
        },
    }
}

test "switch on enum using pointer capture" {
    testSwitchEnumPtrCapture();
    comptime testSwitchEnumPtrCapture();
}

fn testSwitchEnumPtrCapture() void {
    var value = SwitchProngWithVarEnum{ .One = 1234 };
    switch (value) {
        SwitchProngWithVarEnum.One => |*x| x.* += 1,
        else => unreachable,
    }
    switch (value) {
        SwitchProngWithVarEnum.One => |x| expect(x == 1235),
        else => unreachable,
    }
}

test "switch with multiple expressions" {
    const x = switch (returnsFive()) {
        1, 2, 3 => 1,
        4, 5, 6 => 2,
        else => @as(i32, 3),
    };
    expect(x == 2);
}
fn returnsFive() i32 {
    return 5;
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
    expect(!returnsFalse());
}

test "switch on type" {
    expect(trueIfBoolFalseOtherwise(bool));
    expect(!trueIfBoolFalseOtherwise(i32));
}

fn trueIfBoolFalseOtherwise(comptime T: type) bool {
    return switch (T) {
        bool => true,
        else => false,
    };
}

test "switch handles all cases of number" {
    testSwitchHandleAllCases();
    comptime testSwitchHandleAllCases();
}

fn testSwitchHandleAllCases() void {
    expect(testSwitchHandleAllCasesExhaustive(0) == 3);
    expect(testSwitchHandleAllCasesExhaustive(1) == 2);
    expect(testSwitchHandleAllCasesExhaustive(2) == 1);
    expect(testSwitchHandleAllCasesExhaustive(3) == 0);

    expect(testSwitchHandleAllCasesRange(100) == 0);
    expect(testSwitchHandleAllCasesRange(200) == 1);
    expect(testSwitchHandleAllCasesRange(201) == 2);
    expect(testSwitchHandleAllCasesRange(202) == 4);
    expect(testSwitchHandleAllCasesRange(230) == 3);
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

test "switch all prongs unreachable" {
    testAllProngsUnreachable();
    comptime testAllProngsUnreachable();
}

fn testAllProngsUnreachable() void {
    expect(switchWithUnreachable(1) == 2);
    expect(switchWithUnreachable(2) == 10);
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

fn return_a_number() anyerror!i32 {
    return 1;
}

test "capture value of switch with all unreachable prongs" {
    const x = return_a_number() catch |err| switch (err) {
        else => unreachable,
    };
    expect(x == 1);
}

test "switching on booleans" {
    testSwitchOnBools();
    comptime testSwitchOnBools();
}

fn testSwitchOnBools() void {
    expect(testSwitchOnBoolsTrueAndFalse(true) == false);
    expect(testSwitchOnBoolsTrueAndFalse(false) == true);

    expect(testSwitchOnBoolsTrueWithElse(true) == false);
    expect(testSwitchOnBoolsTrueWithElse(false) == true);

    expect(testSwitchOnBoolsFalseWithElse(true) == false);
    expect(testSwitchOnBoolsFalseWithElse(false) == true);
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
    switch (val) {
        0 => expect(val == 0),
    }
}

test "undefined.u0" {
    var val: u0 = undefined;
    switch (val) {
        0 => expect(val == 0),
    }
}

test "anon enum literal used in switch on union enum" {
    const Foo = union(enum) {
        a: i32,
    };

    var foo = Foo{ .a = 1234 };
    switch (foo) {
        .a => |x| {
            expect(x == 1234);
        },
    }
}

test "else prong of switch on error set excludes other cases" {
    const S = struct {
        fn doTheTest() void {
            expectError(error.C, bar());
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
    S.doTheTest();
    comptime S.doTheTest();
}

test "switch prongs with error set cases make a new error set type for capture value" {
    const S = struct {
        fn doTheTest() void {
            expectError(error.B, bar());
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
    S.doTheTest();
    comptime S.doTheTest();
}

test "return result loc and then switch with range implicit casted to error union" {
    const S = struct {
        fn doTheTest() void {
            expect((func(0xb) catch unreachable) == 0xb);
        }
        fn func(d: u8) anyerror!u8 {
            return switch (d) {
                0xa...0xf => d,
                else => unreachable,
            };
        }
    };
    S.doTheTest();
    comptime S.doTheTest();
}

test "switch with null and T peer types and inferred result location type" {
    const S = struct {
        fn doTheTest(c: u8) void {
            if (switch (c) {
                0 => true,
                else => null,
            }) |v| {
                @panic("fail");
            }
        }
    };
    S.doTheTest(1);
    comptime S.doTheTest(1);
}

test "switch prongs with cases with identical payload types" {
    const Union = union(enum) {
        A: usize,
        B: isize,
        C: usize,
    };
    const S = struct {
        fn doTheTest() void {
            doTheSwitch1(Union{ .A = 8 });
            doTheSwitch2(Union{ .B = -8 });
        }
        fn doTheSwitch1(u: Union) void {
            switch (u) {
                .A, .C => |e| {
                    expect(@TypeOf(e) == usize);
                    expect(e == 8);
                },
                .B => |e| @panic("fail"),
            }
        }
        fn doTheSwitch2(u: Union) void {
            switch (u) {
                .A, .C => |e| @panic("fail"),
                .B => |e| {
                    expect(@TypeOf(e) == isize);
                    expect(e == -8);
                },
            }
        }
    };
    S.doTheTest();
    comptime S.doTheTest();
}

test "switch with disjoint range" {
    var q: u8 = 0;
    switch (q) {
        0...125 => {},
        127...255 => {},
        126...126 => {},
    }
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
    while (state < 2) {
        poll();
    }
}

test "switch on pointer type" {
    const S = struct {
        const X = struct {
            field: u32,
        };

        const P1 = @intToPtr(*X, 0x400);
        const P2 = @intToPtr(*X, 0x800);
        const P3 = @intToPtr(*X, 0xC00);

        fn doTheTest(arg: *X) i32 {
            switch (arg) {
                P1 => return 1,
                P2 => return 2,
                else => return 3,
            }
        }
    };

    expect(1 == S.doTheTest(S.P1));
    expect(2 == S.doTheTest(S.P2));
    expect(3 == S.doTheTest(S.P3));
    comptime expect(1 == S.doTheTest(S.P1));
    comptime expect(2 == S.doTheTest(S.P2));
    comptime expect(3 == S.doTheTest(S.P3));
}

test "switch on error set with single else" {
    const S = struct {
        fn doTheTest() void {
            var some: error{Foo} = error.Foo;
            expect(switch (some) {
                else => |a| true,
            });
        }
    };

    S.doTheTest();
    comptime S.doTheTest();
}

test "while copies its payload" {
    const S = struct {
        fn doTheTest() void {
            var tmp: union(enum) {
                A: u8,
                B: u32,
            } = .{ .A = 42 };
            switch (tmp) {
                .A => |value| {
                    // Modify the original union
                    tmp = .{ .B = 0x10101010 };
                    expectEqual(@as(u8, 42), value);
                },
                else => unreachable,
            }
        }
    };
    S.doTheTest();
    comptime S.doTheTest();
}
