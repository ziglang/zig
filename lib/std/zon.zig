//! ZON serialization and deserialization.
//!
//! # ZON
//! ZON, or Zig Object Notation, is a subset of Zig use for data representation.
//!
//! (Strictly speaking, ZON is not currently a true subset of Zig, solely because of support for
//! `nan` and `inf` literals.)
//!
//! ZON supports the following Zig primitives:
//! * boolean literals
//! * number literals (including `nan` and `inf`)
//! * character literals
//! * enum literals
//! * the `null` and `void` literals
//! * string literals, multiline string literals
//!
//! In addition, the following container types are supported:
//! * anonymous struct literals
//! * anonymous tuple literals
//! * slices (noted as a reference to a tuple literal)
//!     * the reference (`&`) will likely be removed from ZON in the future, at which point ZON will
//!       not distinguish between slices and tuples
//!
//! ZON objects do not contain type names.
//!
//! Here is an example ZON object:
//! ```zon
//! .{
//!     .a = 1.5,
//!     .b = "hello, world!",
//!     .c = .{ true, false },
//!     .d = &.{ 1, 2, 3 },
//! }
//! ```
//!
//! Individual primitives are also valid ZON, for example:
//! ```zon
//! "This string is a valid ZON object."
//! ```
//!
//! # Deserialization
//!
//! The simplest way to deserialize ZON at runtime is to call `parseFromSlice`. (For reading ZON at
//! comptime, you can use `@import`.)
//!
//! If you need lower level control or more detailed diagnostics on failure, you can generate the
//! AST yourself with `std.zig.Ast.parse` and then deserialize it with:
//! * `parseFromAst`
//! * `parseFromAstNoAlloc`
//!
//! The following functions are also provided if you'd like to deserialize only part of an AST:
//! * `parseFromAstNode`
//! * `parseFromAstNodeNoAlloc`
//!
//! If you want absolute control over deserialization, you can bypass this module completely and
//! operate directly on the results of `std.zig.Ast.parse`.
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
//! If you need more control over the serialization process, you can call `stringifier` to create
//! a `Stringifier` instance. This is used under the hood by `stringify` and its companion
//! functions, and allows for writing out values/fields/items individually.
//!
//! This can be used to control which fields are serialized, to configure fields individually, or to
//! stringify a ZON value that does not actually exist in memory.
//!
//! Note that serializing floats with more than 64 bits may result in a loss of precision for now
//! (see https://github.com/ziglang/zig/issues/1181).

pub const ParseOptions = @import("zon/parse.zig").ParseOptions;
pub const ParseStatus = @import("zon/parse.zig").ParseStatus;
pub const parseFromSlice = @import("zon/parse.zig").parseFromSlice;
pub const parseFromAst = @import("zon/parse.zig").parseFromAst;
pub const parseFromAstNoAlloc = @import("zon/parse.zig").parseFromAstNoAlloc;
pub const parseFromAstNode = @import("zon/parse.zig").parseFromAstNode;
pub const parseFromAstNodeNoAlloc = @import("zon/parse.zig").parseFromAstNodeNoAlloc;
pub const paseFree = @import("zon/parse.zig").parseFree;

pub const StringifierOptions = @import("zon/stringify.zig").StringifierOptions;
pub const StringifyValueOptions = @import("zon/stringify.zig").StringifyValueOptions;
pub const StringifyOptions = @import("zon/stringify.zig").StringifyOptions;
pub const StringifyContainerOptions = @import("zon/stringify.zig").StringifyContainerOptions;
pub const Stringifier = @import("zon/stringify.zig").Stringifier;
pub const stringify = @import("zon/stringify.zig").stringify;
pub const stringifyMaxDepth = @import("zon/stringify.zig").stringifyMaxDepth;
pub const stringifyArbitraryDepth = @import("zon/stringify.zig").stringifyArbitraryDepth;
pub const stringier = @import("zon/stringify.zig").stringifier;

test {
    _ = @import("zon/parse.zig");
    _ = @import("zon/stringify.zig");
}
