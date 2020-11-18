const std = @import("std");

pub const Error = error{ InputMatchFailure, TooFewArguments, TooManyArguments, UnknownSpecifier, NegationOfSignedInteger, ConversionFailure, InvalidCharacter };

fn parseInt(input: []const u8, radix: u8, isValid: fn (u8) bool, value: anytype, neg: bool) Error!usize {
    std.debug.assert(@typeInfo(@TypeOf(value)) == .Pointer);
    const Int = @TypeOf(value.*);
    if (neg and !@typeInfo(Int).Int.is_signed) return error.NegationOfSignedInteger;

    var i: usize = 0;
    const radix_adj = @intCast(Int, radix);

    value.* = 0;
    while (i < input.len) : (i += 1) {
        const c = input[i];
        if (!isValid(c)) break;
        value.* = value.* * radix_adj + @intCast(Int, try std.fmt.charToDigit(c, radix));
    }
    if (@typeInfo(Int).Int.is_signed) {
        if (neg) value.* = -value.*;
    }
    if (i == 0) return error.ConversionFailure;
    return i;
}

fn isOctalDigit(c: u8) bool {
    return '0' <= c and c <= '7';
}

fn isBinaryDigit(c: u8) bool {
    return c == '0' or c == '1';
}

/// similar to scanf in c except conversion specifiers are given like "{d}" rather than "%d"
/// valid specifiers include
/// - {c}     - match exactly one character, don't parse. '0' -> '0' (48)
/// - {d}, {} - match and parse a base 10 number
/// - {e}     - match and parse a floating point number
/// - {x}     - match and parse a hex number with optional leading "0x" or "0X"
/// - {o}     - match and parse an octal number with optional leading "0o"
/// - {b}     - match and parse a binary number with optional leading "0b"
/// - {s}     - match any input until a whitespace or the following character in fmt string
/// Notes: curly braces can be escaped in fmt "{{}}"
///        each whitespace in fmt will skip zero or more input whitespaces
pub fn scan(input: []const u8, comptime fmt: []const u8, args: anytype) Error!usize {
    comptime var arg_i: usize = 0;
    var i: usize = 0; // input index
    const State = enum { start, specifier, specifier_end };
    comptime var state: State = .start;
    inline for (fmt) |fmt_c, fmt_i| {
        var neg = false;
        if (i == std.math.maxInt(usize)) return error.InputMatchFailure;
        switch (state) {
            .start => switch (fmt_c) {
                '{' => state = .specifier,
                // match }}
                '}' => if (fmt_i > 0 and fmt[fmt_i - 1] == '}') {
                    if (input[i] == '}') {
                        i += 1;
                    } else i = std.math.maxInt(usize);
                },
                else => if (std.ascii.isSpace(fmt_c)) {
                    while (i < input.len and std.ascii.isSpace(input[i])) : (i += 1) {}
                } else if (i < input.len and fmt_c == input[i]) {
                    i += 1;
                } else {
                    i = std.math.maxInt(usize);
                },
            },
            .specifier_end => switch (fmt_c) {
                '}' => state = .start,
                else => return error.UnknownSpecifier,
            },
            .specifier => {
                // special case escaped {{
                if (fmt_c == '{') {
                    if (i < input.len and fmt_c == input[i]) {
                        i += 1;
                        state = .start;
                    } else i = std.math.maxInt(usize);
                    continue;
                }

                if (i < input.len) {
                    if (input[i] == '-') {
                        neg = true;
                        i += 1;
                    } else if (input[i] == '+') {
                        i += 1;
                    }
                }
                if (arg_i >= args.len) return error.TooFewArguments;
                var arg = args[arg_i];
                switch (fmt_c) {
                    '}', 'd' => {
                        if (i < input.len) i += try parseInt(input[i..], 10, std.ascii.isDigit, arg, neg);
                        arg_i += 1;
                        if (fmt_c == '}') {
                            state = .start; // skip specifier_end state
                            continue;
                        }
                    },
                    'c' => {
                        arg.* = input[i];
                        i += 1;
                        arg_i += 1;
                    },
                    'e' => {
                        var digit_count: usize = 0;
                        while (i + digit_count < input.len) : (digit_count += 1) {
                            const c = input[i + digit_count];
                            if (!(std.ascii.isDigit(c) or c == '.' or c == 'e' or c == 'E' or c == '-')) break;
                        }
                        const start_i = if (neg) i - 1 else i;
                        arg.* = std.fmt.parseFloat(@TypeOf(arg.*), input[start_i .. i + digit_count]) catch |e| return error.ConversionFailure;
                        i += digit_count;
                        arg_i += 1;
                    },
                    'x', 'X' => {
                        if (std.mem.startsWith(u8, input[i..], "0x") or
                            std.mem.startsWith(u8, input[i..], "0X")) i += 2;
                        i += try parseInt(input[i..], 16, std.ascii.isXDigit, arg, neg);
                        arg_i += 1;
                    },
                    'o' => {
                        if (std.mem.startsWith(u8, input[i..], "0o")) i += 2;
                        i += try parseInt(input[i..], 8, isOctalDigit, arg, neg);
                        arg_i += 1;
                    },
                    'b' => {
                        if (std.mem.startsWith(u8, input[i..], "0b")) i += 2;
                        i += try parseInt(input[i..], 2, isBinaryDigit, arg, neg);
                        arg_i += 1;
                    },
                    's' => {
                        var si: usize = 0;
                        while (i < input.len) {
                            if (std.ascii.isSpace(input[i]) or (fmt_i + 2 < fmt.len and input[i] == fmt[fmt_i + 2])) break;
                            arg[si] = input[i];
                            i += 1;
                            si += 1;
                        }
                        arg_i += 1;
                    },
                    else => return error.UnknownSpecifier,
                }
                state = .specifier_end;
            },
        }
    }
    if (arg_i < args.len) return error.TooManyArguments;
    if (arg_i > args.len) return error.TooFewArguments;
    if (i == std.math.maxInt(usize)) return error.InputMatchFailure;
    return i;
}

const t = std.testing;
test "scan basic" {
    var c: u8 = undefined;
    var d: u8 = undefined;
    const input = "zig is {amazing}. 42 is the answer\n";
    const bytes_read = try scan(input, "zig {c}s {{amazing}}. {} is the answer ", .{ &c, &d });
    t.expectEqual(c, 'i');
    t.expectEqual(d, 42);
    t.expectEqual(input.len, bytes_read);
}

test "scan types" {
    var c: u8 = undefined;
    var d: i32 = undefined;
    var x: i32 = undefined;
    var o: i32 = undefined;
    var s: [20]u8 = undefined;
    var b: u8 = undefined;
    var c2: u8 = undefined;
    var e: f32 = undefined;
    const input = "4 -42 +0x2c 0o55 fortysix 0b0101111 \x30 a";
    const bytes_read = try scan(input, "{c} {} {x} {o} {s} {b} {c} a", .{ &c, &d, &x, &o, &s, &b, &c2 });

    t.expectEqual(c, '4');
    t.expectEqual(d, -42);
    t.expectEqual(x, 44);
    t.expectEqual(o, 45);
    const expected = "fortysix";
    t.expectEqualStrings(expected, s[0..expected.len]);
    t.expectEqual(b, 47);
    t.expectEqual(c2, 48);
    t.expectEqual(input.len, bytes_read);

    t.expectEqual(try scan("0Xaa", "{X}", .{&d}), 4);
    t.expectEqual(d, 170);
    t.expectEqual(try scan("0XBB", "{X}", .{&d}), 4);
    t.expectEqual(d, 187);
    _ = try scan("188", "{d}", .{&d});
    t.expectEqual(d, 188);
    _ = try scan("42.00", "{e}", .{&e});
    t.expectEqual(e, 42.0);
    t.expectEqual(try scan("43aa", "{e}", .{&e}), 2);
    t.expectEqual(e, 43.0);
    t.expectEqual(try scan("-40.0e-1", "{e}", .{&e}), 8);
    t.expectEqual(e, -4.0);

    // skip N whitespace in input for each whitespace in format
    _ = try scan("\n\t\r\n           5          \n\t", " {} ", .{&c});
    t.expectEqual(c, 5);
    // string scan stops at first whitespace or next match character
    // test allowing non-whitespace string end match '['
    var s2: [20]u8 = undefined;
    const sa = "abcde";
    const sb = "[abcde]";
    _ = try scan(sa ++ sb, "{s}[{s}]", .{ &s, &s2 });
    t.expectEqualStrings(s[0..sa.len], sa);
    t.expectEqualStrings(s2[0 .. sb.len - 2], sb[1 .. sb.len - 1]);
    t.expectEqual(try scan(sa, "{s}", .{&s}), sa.len);
    t.expectEqual(try scan("", " ", .{}), 0);

    t.expectEqual(try scan("{", "{{", .{}), 1);
    t.expectEqual(try scan("{}", "{{}}", .{}), 2);
}

test "errors" {
    var s: [20]u8 = undefined;
    var c: u8 = 255;

    t.expectError(error.InputMatchFailure, scan("rust", "zig", .{}));
    // input failure should stop processing further input
    t.expectError(error.InputMatchFailure, scan("a 42", "b {}", .{&c}));
    t.expect(c == 255);
    t.expectError(error.TooFewArguments, scan("", "{c}", .{}));
    t.expectError(error.TooManyArguments, scan("", "", .{&c}));
    t.expectError(error.UnknownSpecifier, scan("", "{sxxx}", .{&s}));
    t.expectError(error.UnknownSpecifier, scan("", "{j}", .{&c}));
    t.expectError(error.NegationOfSignedInteger, scan("-41", "{}", .{&c}));
    t.expectError(error.ConversionFailure, scan("abc", "{}", .{&c}));
    t.expectError(error.ConversionFailure, scan("abc", "{b}", .{&c}));
    t.expectError(error.ConversionFailure, scan("0xzz", "{x}", .{&c}));
    var e: f32 = undefined;
    t.expectError(error.ConversionFailure, scan("aa.aa", "{e}", .{&e}));
}
