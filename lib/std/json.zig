//! JSON parsing and stringification conforming to RFC 8259. https://datatracker.ietf.org/doc/html/rfc8259
//!
//! The low-level `Scanner` API reads from an input slice or successive slices of inputs,
//! The `Reader` API connects a `std.io.Reader` to a `Scanner`.
//!
//! The high-level `parseFromSlice` and `parseFromTokenSource` deserializes a JSON document into a Zig type.
//! The high-level `Parser` parses any JSON document into a dynamically typed `ValueTree` that has its own memory arena.
//!
//! The low-level `writeStream` emits syntax-conformant JSON tokens to a `std.io.Writer`.
//! The high-level `stringify` serializes a Zig type into JSON.

pub const ValueTree = @import("json/dynamic.zig").ValueTree;
pub const ObjectMap = @import("json/dynamic.zig").ObjectMap;
pub const Array = @import("json/dynamic.zig").Array;
pub const Value = @import("json/dynamic.zig").Value;
pub const Parser = @import("json/dynamic.zig").Parser;

pub const validate = @import("json/scanner.zig").validate;
pub const Error = @import("json/scanner.zig").Error;
pub const reader = @import("json/scanner.zig").reader;
pub const default_buffer_size = @import("json/scanner.zig").default_buffer_size;
pub const Token = @import("json/scanner.zig").Token;
pub const TokenType = @import("json/scanner.zig").TokenType;
pub const Diagnostics = @import("json/scanner.zig").Diagnostics;
pub const AllocWhen = @import("json/scanner.zig").AllocWhen;
pub const default_max_value_len = @import("json/scanner.zig").default_max_value_len;
pub const Reader = @import("json/scanner.zig").Reader;
pub const Scanner = @import("json/scanner.zig").Scanner;
pub const isNumberFormattedLikeAnInteger = @import("json/scanner.zig").isNumberFormattedLikeAnInteger;

pub const ParseOptions = @import("json/static.zig").ParseOptions;
pub const parseFromSlice = @import("json/static.zig").parseFromSlice;
pub const parseFromTokenSource = @import("json/static.zig").parseFromTokenSource;
pub const ParseError = @import("json/static.zig").ParseError;
pub const parseFree = @import("json/static.zig").parseFree;

pub const StringifyOptions = @import("json/stringify.zig").StringifyOptions;
pub const encodeJsonString = @import("json/stringify.zig").encodeJsonString;
pub const encodeJsonStringChars = @import("json/stringify.zig").encodeJsonStringChars;
pub const stringify = @import("json/stringify.zig").stringify;
pub const stringifyAlloc = @import("json/stringify.zig").stringifyAlloc;

pub const WriteStream = @import("json/write_stream.zig").WriteStream;
pub const writeStream = @import("json/write_stream.zig").writeStream;

// Deprecations
pub const parse = @compileError("Deprecated; use parseFromSlice() or parseFromTokenSource() instead.");
pub const StreamingParser = @compileError("Deprecated; use json.Scanner or json.Reader instead.");
pub const TokenStream = @compileError("Deprecated; use json.Scanner or json.Reader instead.");

test {
    _ = @import("json/test.zig");
    _ = @import("json/scanner.zig");
    _ = @import("json/write_stream.zig");
    _ = @import("json/dynamic.zig");
    _ = @import("json/static.zig");
    _ = @import("json/stringify.zig");
    _ = @import("json/JSONTestSuite_test.zig");
}
