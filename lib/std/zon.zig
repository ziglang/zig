//! ZON serialization and deserialization.
//!
//! # ZON
//! ZON, or Zig Object Notation, is a subset* of Zig used for data storage. ZON contains no type
//! names.
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
//! ```zon
//! .{
//!     .a = 1.5,
//!     .b = "hello, world!",
//!     .c = .{ true, false },
//!     .d = .{ 1, 2, 3 },
//! }
//! ```
//!
//! Individual primitives are also valid ZON, for example:
//! ```zon
//! "This string is a valid ZON object."
//! ```
//!
//! * ZON is not currently a true subset of Zig, because it supports `nan` and
//!    `inf` literals, which Zig does not.
//!
//! # Deserialization
//!
//! The simplest way to deserialize ZON at runtime is `parseFromSlice`. (For parsing ZON at
//! comptime, you can use `@import`.)
//!
//! Parsing from individual Zoir nodes is also available:
//! * `parseFromZoir`
//! * `parseFromZoirNode`
//! * `parseFromZoirNode`
//!
//! If you need lower level control than provided by this module, you can operate directly on the
//! results of `std.zig.Zoir` directly. This module is a good example of how that can be done.
//!
//!
//! # Serialization
//!
//! The simplest way to serialize to ZON is to call `stringify`.
//!
//! If you need to serialize recursive types, the following functions are also provided:
//! * `stringifyMaxDepth`
//! * `stringifyArbitraryDepth`
//!
//! If you need more control over the serialization process, for example to control which fields are
//! serialized, configure fields individually, or to stringify ZON values that do not exist in
//! memory, you can use `Stringifier`.
//!
//! Note that serializing floats with more than 64 bits may result in a loss of precision
//! (see https://github.com/ziglang/zig/issues/1181).

pub const ParseOptions = @import("zon/parse.zig").Options;
pub const ParseStatus = @import("zon/parse.zig").Status;
pub const parseFromSlice = @import("zon/parse.zig").parseFromSlice;
pub const parseFromZoir = @import("zon/parse.zig").parseFromZoir;
pub const parseFromZoirNode = @import("zon/parse.zig").parseFromZoirNode;
pub const parseFree = @import("zon/parse.zig").parseFree;

pub const StringifierOptions = @import("zon/stringify.zig").StringifierOptions;
pub const StringifyValueOptions = @import("zon/stringify.zig").StringifyValueOptions;
pub const StringifyOptions = @import("zon/stringify.zig").StringifyOptions;
pub const StringifyContainerOptions = @import("zon/stringify.zig").StringifyContainerOptions;
pub const Stringifier = @import("zon/stringify.zig").Stringifier;
pub const stringify = @import("zon/stringify.zig").stringify;
pub const stringifyMaxDepth = @import("zon/stringify.zig").stringifyMaxDepth;
pub const stringifyArbitraryDepth = @import("zon/stringify.zig").stringifyArbitraryDepth;
pub const stringifier = @import("zon/stringify.zig").stringifier;

test {
    _ = @import("zon/parse.zig");
    _ = @import("zon/stringify.zig");
}
