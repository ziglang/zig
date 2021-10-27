const std = @import("std");
const expect = std.testing.expect;
const expectError = std.testing.expectError;
const expectEqual = std.testing.expectEqual;

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
