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

pub const parse = @import("zon/parse.zig");
pub const stringify = @import("zon/stringify.zig");

test {
    _ = parse;
    _ = stringify;
}
