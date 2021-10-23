const std = @import("std");
const expect = std.testing.expect;
const expectError = std.testing.expectError;
const expectEqual = std.testing.expectEqual;

test "switch prong with variable" {
    try switchProngWithVarFn(SwitchProngWithVarEnum{ .One = 13 });
    try switchProngWithVarFn(SwitchProngWithVarEnum{ .Two = 13.0 });
    try switchProngWithVarFn(SwitchProngWithVarEnum{ .Meh = {} });
}
const SwitchProngWithVarEnum = union(enum) {
    One: i32,
    Two: f32,
    Meh: void,
};
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
    try testSwitchEnumPtrCapture();
    comptime try testSwitchEnumPtrCapture();
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
    try testSwitchHandleAllCases();
    comptime try testSwitchHandleAllCases();
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

test "switch all prongs unreachable" {
    try testAllProngsUnreachable();
    comptime try testAllProngsUnreachable();
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

fn return_a_number() anyerror!i32 {
    return 1;
}

test "capture value of switch with all unreachable prongs" {
    const x = return_a_number() catch |err| switch (err) {
        else => unreachable,
    };
    try expect(x == 1);
}

test "anon enum literal used in switch on union enum" {
    const Foo = union(enum) {
        a: i32,
    };

    var foo = Foo{ .a = 1234 };
    switch (foo) {
        .a => |x| {
            try expect(x == 1234);
        },
    }
}

test "else prong of switch on error set excludes other cases" {
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
    comptime try S.doTheTest();
}

test "switch prongs with error set cases make a new error set type for capture value" {
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
    comptime try S.doTheTest();
}

test "return result loc and then switch with range implicit casted to error union" {
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
    comptime try S.doTheTest();
}

test "switch with null and T peer types and inferred result location type" {
    const S = struct {
        fn doTheTest(c: u8) !void {
            if (switch (c) {
                0 => true,
                else => null,
            }) |v| {
                _ = v;
                @panic("fail");
            }
        }
    };
    try S.doTheTest(1);
    comptime try S.doTheTest(1);
}

test "switch prongs with cases with identical payload types" {
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
                    try expect(@TypeOf(e) == usize);
                    try expect(e == 8);
                },
                .B => |e| {
                    _ = e;
                    @panic("fail");
                },
            }
        }
        fn doTheSwitch2(u: Union) !void {
            switch (u) {
                .A, .C => |e| {
                    _ = e;
                    @panic("fail");
                },
                .B => |e| {
                    try expect(@TypeOf(e) == isize);
                    try expect(e == -8);
                },
            }
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
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

    try expect(1 == S.doTheTest(S.P1));
    try expect(2 == S.doTheTest(S.P2));
    try expect(3 == S.doTheTest(S.P3));
    comptime try expect(1 == S.doTheTest(S.P1));
    comptime try expect(2 == S.doTheTest(S.P2));
    comptime try expect(3 == S.doTheTest(S.P3));
}

test "switch on error set with single else" {
    const S = struct {
        fn doTheTest() !void {
            var some: error{Foo} = error.Foo;
            try expect(switch (some) {
                else => |a| blk: {
                    a catch {};
                    break :blk true;
                },
            });
        }
    };

    try S.doTheTest();
    comptime try S.doTheTest();
}

test "switch capture copies its payload" {
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
    comptime try S.doTheTest();
}
