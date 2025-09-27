//! ZON parsing and stringification.
//!
//! ZON ("Zig Object Notation") is a textual file format. Outside of `nan` and `inf` literals, ZON's
//! grammar is a subset of Zig's.
//!
//! Supported Zig primitives:
//! * boolean literals
//! * number literals (including `nan` and `inf`)
//! * character literals
//! * enum literals
//! * `null` literals
//! * string literals
//! * multiline string literals
//!
//! Supported Zig container types:
//! * anonymous struct literals
//! * anonymous tuple literals
//!
//! Here is an example ZON object:
//! ```
//! .{
//!     .a = 1.5,
//!     .b = "hello, world!",
//!     .c = .{ true, false },
//!     .d = .{ 1, 2, 3 },
//!     .e = .{ .x = 13, .y = 67 },
//! }
//! ```
//!
//! Individual primitives are also valid ZON, for example:
//! ```
//! "This string is a valid ZON object."
//! ```
//!
//! ZON may not contain type names.
//!
//! ZON does not have syntax for pointers, but the parsers will allocate as needed to match the
//! given Zig types. Similarly, the serializer will traverse pointers.

const std = @import("std");

pub const parse = @import("zon/parse.zig");
pub const stringify = @import("zon/stringify.zig");
pub const Serializer = @import("zon/Serializer.zig");

/// Returns a formatter that formats the given value using stringify.
pub fn fmt(value: anytype, options: stringify.SerializeOptions) Formatter(@TypeOf(value)) {
    return Formatter(@TypeOf(value)){ .value = value, .options = options };
}

test fmt {
    const expectFmt = std.testing.expectFmt;
    try expectFmt("123", "{f}", .{fmt(@as(u32, 123), .{})});
    try expectFmt(
        \\.{
        \\    .num = 927,
        \\    .msg = "hello",
        \\    .sub = .{ .mybool = true },
        \\}
    , "{f}", .{fmt(struct {
        num: u32,
        msg: []const u8,
        sub: struct {
            mybool: bool,
        },
    }{
        .num = 927,
        .msg = "hello",
        .sub = .{ .mybool = true },
    }, .{})});
}

/// Formats the given value using stringify.
pub fn Formatter(comptime T: type) type {
    return struct {
        value: T,
        options: stringify.SerializeOptions,

        pub fn format(self: @This(), writer: *std.Io.Writer) std.Io.Writer.Error!void {
            try stringify.serialize(self.value, self.options, writer);
        }
    };
}

test {
    _ = parse;
    _ = stringify;
}
