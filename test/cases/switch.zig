const assertOrPanic = @import("std").debug.assertOrPanic;

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
        SwitchProngWithVarEnum.One => |x| assertOrPanic(x == 1235),
        else => unreachable,
    }
}

test "switch with multiple expressions" {
    const x = switch (returnsFive()) {
        1, 2, 3 => 1,
        4, 5, 6 => 2,
        else => i32(3),
    };
    assertOrPanic(x == 2);
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
    assertOrPanic(!returnsFalse());
}

test "switch on type" {
    assertOrPanic(trueIfBoolFalseOtherwise(bool));
    assertOrPanic(!trueIfBoolFalseOtherwise(i32));
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
    assertOrPanic(testSwitchHandleAllCasesExhaustive(0) == 3);
    assertOrPanic(testSwitchHandleAllCasesExhaustive(1) == 2);
    assertOrPanic(testSwitchHandleAllCasesExhaustive(2) == 1);
    assertOrPanic(testSwitchHandleAllCasesExhaustive(3) == 0);

    assertOrPanic(testSwitchHandleAllCasesRange(100) == 0);
    assertOrPanic(testSwitchHandleAllCasesRange(200) == 1);
    assertOrPanic(testSwitchHandleAllCasesRange(201) == 2);
    assertOrPanic(testSwitchHandleAllCasesRange(202) == 4);
    assertOrPanic(testSwitchHandleAllCasesRange(230) == 3);
}

fn testSwitchHandleAllCasesExhaustive(x: u2) u2 {
    return switch (x) {
        0 => u2(3),
        1 => 2,
        2 => 1,
        3 => 0,
    };
}

fn testSwitchHandleAllCasesRange(x: u8) u8 {
    return switch (x) {
        0...100 => u8(0),
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
    assertOrPanic(switchWithUnreachable(1) == 2);
    assertOrPanic(switchWithUnreachable(2) == 10);
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
    assertOrPanic(x == 1);
}
