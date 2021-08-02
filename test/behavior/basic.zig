const std = @import("std");
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
