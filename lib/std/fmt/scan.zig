const std = @import("std");
const scan = std.fmt.scan;

const t = std.testing;
test "scan basic" {
    var c: u8 = undefined;
    var d: u8 = undefined;
    const input = "zig is {amazing}. 42 is the answer\n";
    try scan(input, "zig {c}s {{amazing}}. {} is the answer ", .{ &c, &d });
    t.expectEqual(c, 'i');
    t.expectEqual(d, 42);
}

test "scan types" {
    var c: u8 = undefined;
    var d: i32 = undefined;
    var x: i32 = undefined;
    var o: i32 = undefined;
    var buf: [10]u8 = undefined;
    var s: []u8 = &buf;
    var b: u8 = undefined;
    var c2: u8 = undefined;
    var e: f32 = undefined;
    const input = "4 -42 +0x2c 0o55 fortysix 0b0101111 \x30 a";
    try scan(input, "{c} {} {x} {o} {s} {b} {c} a", .{ &c, &d, &x, &o, &s, &b, &c2 });

    t.expectEqual(c, '4');
    t.expectEqual(d, -42);
    t.expectEqual(x, 44);
    t.expectEqual(o, 45);
    const expected = "fortysix";
    t.expectEqualStrings(expected, s);
    t.expectEqual(b, 47);
    t.expectEqual(c2, 48);

    try scan("0Xaa", "{x}", .{&d});
    t.expectEqual(d, 170);
    try scan("0XBB", "{X}", .{&d});
    t.expectEqual(d, 187);
    try scan("188", "{d}", .{&d});
    t.expectEqual(d, 188);
    try scan("42.00", "{e}", .{&e});
    t.expectEqual(e, 42.0);
    try scan("43aa", "{e}", .{&e});
    t.expectEqual(e, 43.0);
    try scan("-40.0e-1", "{e}", .{&e});
    t.expectEqual(e, -4.0);

    // skip N whitespace in input for each whitespace in format
    try scan("\n\t\r\n           5          \n\t", " {} ", .{&c});
    t.expectEqual(c, 5);
    // string scan stops at first whitespace or next match character
    // test allowing non-whitespace string end match '['
    var buf2: [10]u8 = undefined;
    var s2: []u8 = &buf2;
    const sa = "abcde";
    try scan(sa ++ " " ++ sa, "{s} {s}", .{ &s, &s2 });
    t.expectEqualStrings(s[0..sa.len], sa);
    t.expectEqualStrings(s2[0..sa.len], sa);
    try scan(sa, "{s}", .{&s});
    try scan("", " ", .{});
    try scan("{", "{{", .{});
    try scan("{}", "{{}}", .{});
}

test "scan errors" {
    var buf: [20]u8 = undefined;
    var s: []u8 = &buf;
    var c: u8 = 255;

    t.expectError(error.InputMatchFailure, scan("rust", "zig", .{}));
    // input failure should stop processing further input
    t.expectError(error.InputMatchFailure, scan("a 42", "b {}", .{&c}));
    t.expect(c == 255);
    t.expectError(error.NegationOfUnsignedInteger, scan("-41", "{}", .{&c}));
    t.expectError(error.ConversionFailure, scan("abc", "{}", .{&c}));
    t.expectError(error.ConversionFailure, scan("abc", "{b}", .{&c}));
    t.expectError(error.ConversionFailure, scan("0xzz", "{x}", .{&c}));
    var e: f32 = undefined;
    t.expectError(error.ConversionFailure, scan("aa.aa", "{e}", .{&e}));
}

test "scan reader" {
    var buf: [10]u8 = undefined;
    var s: []u8 = &buf;
    var reader = std.io.fixedBufferStream("abcde asdf").reader();
    try std.fmt.scanReader(reader, "abcde {}", .{&s});
    t.expectEqualStrings("asdf", s[0..4]);
}

test "scan bool" {
    var b: bool = false;
    try scan("true", "{}", .{&b});
    t.expect(b);
    try scan("false", "{}", .{&b});
    t.expect(!b);
    t.expectError(error.InputMatchFailure, scan("fabub", "{}", .{&b}));
}

test "scan float" {
    var f: f64 = undefined;
    try scan("123.0", "{e}", .{&f});
    t.expectEqual(f, 123.0);

    const eps = std.math.epsilon(f64);
    try scan("nan", "{e}", .{&f});
    t.expectWithinEpsilon(f, std.math.nan(f64), eps);
    try scan("-nan", "{e}", .{&f});
    t.expectWithinEpsilon(f, -std.math.nan(f64), eps);
    try scan("NaN", "{e}", .{&f});
    t.expectWithinEpsilon(f, std.math.nan(f64), eps);

    try scan("inf", "{e}", .{&f});
    t.expectWithinEpsilon(f, std.math.inf(f64), eps);
    try scan("-inf", "{e}", .{&f});
    t.expectWithinEpsilon(f, -std.math.inf(f64), eps);
    try scan("-INF", "{e}", .{&f});
    t.expectWithinEpsilon(f, -std.math.inf(f64), eps);

    try scan("infinite", "{e}", .{&f});
    t.expectWithinEpsilon(f, std.math.inf(f64), eps);

    t.expectError(error.ConversionFailure, scan("abc", "{e}", .{&f}));
}

test "scan width" {
    var u: u32 = undefined;
    try scan("123456", "{d:3}", .{&u});
    t.expectEqual(u, 123);

    try scan("123456", "{:4}", .{&u});
    t.expectEqual(u, 1234);
}
