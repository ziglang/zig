const std = @import("std");
const mem = std.mem;
const expect = std.testing.expect;

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

test "call result of if else expression" {
    try expect(mem.eql(u8, f2(true), "a"));
    try expect(mem.eql(u8, f2(false), "b"));
}
fn f2(x: bool) []const u8 {
    return (if (x) fA else fB)();
}
fn fA() []const u8 {
    return "a";
}
fn fB() []const u8 {
    return "b";
}

test "string concatenation" {
    try expect(mem.eql(u8, "OK" ++ " IT " ++ "WORKED", "OK IT WORKED"));
}

test "array mult operator" {
    try expect(mem.eql(u8, "ab" ** 5, "ababababab"));
}
