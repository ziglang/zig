const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const expect = std.testing.expect;
const expectEqualStrings = std.testing.expectEqualStrings;

// normal comment

/// this is a documentation comment
/// doc comment line 2
fn emptyFunctionWithComments() void {}

test "empty function with comments" {
    emptyFunctionWithComments();
}

test "truncate" {
    try expect(testTruncate(0x10fd) == 0xfd);
    comptime try expect(testTruncate(0x10fd) == 0xfd);
}
fn testTruncate(x: u32) u8 {
    return @truncate(u8, x);
}

test "truncate to non-power-of-two integers" {
    try testTrunc(u32, u1, 0b10101, 0b1);
    try testTrunc(u32, u1, 0b10110, 0b0);
    try testTrunc(u32, u2, 0b10101, 0b01);
    try testTrunc(u32, u2, 0b10110, 0b10);
    try testTrunc(i32, i5, -4, -4);
    try testTrunc(i32, i5, 4, 4);
    try testTrunc(i32, i5, -28, 4);
    try testTrunc(i32, i5, 28, -4);
    try testTrunc(i32, i5, std.math.maxInt(i32), -1);
}

fn testTrunc(comptime Big: type, comptime Little: type, big: Big, little: Little) !void {
    try expect(@truncate(Little, big) == little);
}

const g1: i32 = 1233 + 1;
var g2: i32 = 0;

test "global variables" {
    try expect(g2 == 0);
    g2 = g1;
    try expect(g2 == 1234);
}

test "comptime keyword on expressions" {
    const x: i32 = comptime x: {
        break :x 1 + 2 + 3;
    };
    try expect(x == comptime 6);
}

test "type equality" {
    try expect(*const u8 != *u8);
}

test "pointer dereferencing" {
    var x = @as(i32, 3);
    const y = &x;

    y.* += 1;

    try expect(x == 4);
    try expect(y.* == 4);
}

test "const expression eval handling of variables" {
    var x = true;
    while (x) {
        x = false;
    }
}

test "character literals" {
    try expect('\'' == single_quote);
}
const single_quote = '\'';

test "non const ptr to aliased type" {
    const int = i32;
    try expect(?*int == ?*i32);
}

test "cold function" {
    thisIsAColdFn();
    comptime thisIsAColdFn();
}

fn thisIsAColdFn() void {
    @setCold(true);
}

test "unicode escape in character literal" {
    var a: u24 = '\u{01f4a9}';
    try expect(a == 128169);
}

test "unicode character in character literal" {
    try expect('💩' == 128169);
}

fn first4KeysOfHomeRow() []const u8 {
    return "aoeu";
}

test "return string from function" {
    try expect(mem.eql(u8, first4KeysOfHomeRow(), "aoeu"));
}

test "hex escape" {
    try expect(mem.eql(u8, "\x68\x65\x6c\x6c\x6f", "hello"));
}

test "multiline string" {
    const s1 =
        \\one
        \\two)
        \\three
    ;
    const s2 = "one\ntwo)\nthree";
    try expect(mem.eql(u8, s1, s2));
}

test "multiline string comments at start" {
    const s1 =
        //\\one
        \\two)
        \\three
    ;
    const s2 = "two)\nthree";
    try expect(mem.eql(u8, s1, s2));
}

test "multiline string comments at end" {
    const s1 =
        \\one
        \\two)
        //\\three
    ;
    const s2 = "one\ntwo)";
    try expect(mem.eql(u8, s1, s2));
}

test "multiline string comments in middle" {
    const s1 =
        \\one
        //\\two)
        \\three
    ;
    const s2 = "one\nthree";
    try expect(mem.eql(u8, s1, s2));
}

test "multiline string comments at multiple places" {
    const s1 =
        \\one
        //\\two
        \\three
        //\\four
        \\five
    ;
    const s2 = "one\nthree\nfive";
    try expect(mem.eql(u8, s1, s2));
}

test "string concatenation" {
    try expect(mem.eql(u8, "OK" ++ " IT " ++ "WORKED", "OK IT WORKED"));
}

test "array mult operator" {
    try expect(mem.eql(u8, "ab" ** 5, "ababababab"));
}

const OpaqueA = opaque {};
const OpaqueB = opaque {};

test "opaque types" {
    try expect(*OpaqueA != *OpaqueB);
    if (!builtin.zig_is_stage2) {
        try expect(mem.eql(u8, @typeName(OpaqueA), "OpaqueA"));
        try expect(mem.eql(u8, @typeName(OpaqueB), "OpaqueB"));
    }
}

const global_a: i32 = 1234;
const global_b: *const i32 = &global_a;
const global_c: *const f32 = @ptrCast(*const f32, global_b);
test "compile time global reinterpret" {
    const d = @ptrCast(*const i32, global_c);
    try expect(d.* == 1234);
}

test "cast undefined" {
    const array: [100]u8 = undefined;
    const slice = @as([]const u8, &array);
    testCastUndefined(slice);
}
fn testCastUndefined(x: []const u8) void {
    _ = x;
}

test "implicit cast after unreachable" {
    try expect(outer() == 1234);
}
fn inner() i32 {
    return 1234;
}
fn outer() i64 {
    return inner();
}

test "comptime if inside runtime while which unconditionally breaks" {
    testComptimeIfInsideRuntimeWhileWhichUnconditionallyBreaks(true);
    comptime testComptimeIfInsideRuntimeWhileWhichUnconditionallyBreaks(true);
}
fn testComptimeIfInsideRuntimeWhileWhichUnconditionallyBreaks(cond: bool) void {
    while (cond) {
        if (false) {}
        break;
    }
}

test "implicit comptime while" {
    while (false) {
        @compileError("bad");
    }
}

fn fnThatClosesOverLocalConst() type {
    const c = 1;
    return struct {
        fn g() i32 {
            return c;
        }
    };
}

test "function closes over local const" {
    const x = fnThatClosesOverLocalConst().g();
    try expect(x == 1);
}

test "volatile load and store" {
    var number: i32 = 1234;
    const ptr = @as(*volatile i32, &number);
    ptr.* += 1;
    try expect(ptr.* == 1235);
}

fn fA() []const u8 {
    return "a";
}
fn fB() []const u8 {
    return "b";
}

test "call function pointer in struct" {
    try expect(mem.eql(u8, f3(true), "a"));
    try expect(mem.eql(u8, f3(false), "b"));
}

fn f3(x: bool) []const u8 {
    var wrapper: FnPtrWrapper = .{
        .fn_ptr = fB,
    };

    if (x) {
        wrapper.fn_ptr = fA;
    }

    return wrapper.fn_ptr();
}

const FnPtrWrapper = struct {
    fn_ptr: fn () []const u8,
};

test "const ptr from var variable" {
    var x: u64 = undefined;
    var y: u64 = undefined;

    x = 78;
    copy(&x, &y);

    try expect(x == y);
}

fn copy(src: *const u64, dst: *u64) void {
    dst.* = src.*;
}
