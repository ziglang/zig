// Notes on standards compliance: https://datatracker.ietf.org/doc/html/rfc8259
// * RFC 8259 requires JSON documents be valid UTF-8,
//   but makes an allowance for systems that are "part of a closed ecosystem".
//   I have no idea what that's supposed to mean in the context of a standard specification.
//   This implementation requires inputs to be valid UTF-8.
// * RFC 8259 contradicts itself regarding whether lowercase is allowed in \u hex digits,
//   but this is probably a bug in the spec, and it's clear that lowercase is meant to be allowed.
//   (RFC 5234 defines HEXDIG to only allow uppercase.)
// * When RFC 8259 refers to a "character", I assume they really mean a "Unicode scalar value".
//   See http://www.unicode.org/glossary/#unicode_scalar_value .
// * RFC 8259 doesn't explicitly disallow unpaired surrogate halves in \u escape sequences,
//   but vaguely implies that \u escapes are for encoding Unicode "characters" (i.e. Unicode scalar values?),
//   which would mean that unpaired surrogate halves are forbidden.
//   By contrast ECMA-404 (a competing(/compatible?) JSON standard, which JavaScript's JSON.parse() conforms to)
//   explicitly allows unpaired surrogate halves.
//   This implementation forbids unpaired surrogate halves in \u sequences.
//   If a high surrogate half appears in a \u sequence,
//   then a low surrogate half must immediately follow in \u notation.
// * RFC 8259 allows implementations to "accept non-JSON forms or extensions".
//   This implementation does not accept any of that.
// * RFC 8259 allows implementations to put limits on "the size of texts",
//   "the maximum depth of nesting", "the range and precision of numbers",
//   and "the length and character contents of strings".
//   This low-level implementation does not limit these,
//   except where noted above, and except that nesting depth requires memory allocation.
//   Note that this low-level API does not interpret numbers numerically,
//   but simply emits their source form for some higher level code to make sense of.
// * This low-level implementation allows duplicate object keys,
//   and key/value pairs are emitted in the order they appear in the input.

const std = @import("std");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const assert = std.debug.assert;
const BitStack = std.BitStack;

/// Scan the input and check for malformed JSON.
/// On `SyntaxError` or `UnexpectedEndOfInput`, returns `false`.
/// Returns any errors from the allocator as-is, which is unlikely,
/// but can be caused by extreme nesting depth in the input.
pub fn validate(allocator: Allocator, s: []const u8) Allocator.Error!bool {
    var scanner = Scanner.initCompleteInput(allocator, s);
    defer scanner.deinit();

    while (true) {
        const token = scanner.next() catch |err| switch (err) {
            error.SyntaxError, error.UnexpectedEndOfInput => return false,
            error.OutOfMemory => return error.OutOfMemory,
            error.BufferUnderrun => unreachable,
        };
        if (token == .end_of_document) break;
    }

    return true;
}

/// The parsing errors are divided into two categories:
///  * `SyntaxError` is for clearly malformed JSON documents,
///    such as giving an input document that isn't JSON at all.
///  * `UnexpectedEndOfInput` is for signaling that everything's been
///    valid so far, but the input appears to be truncated for some reason.
/// Note that a completely empty (or whitespace-only) input will give `UnexpectedEndOfInput`.
pub const Error = error{ SyntaxError, UnexpectedEndOfInput };

/// Calls `std.json.Reader` with `std.json.default_buffer_size`.
pub fn reader(allocator: Allocator, io_reader: anytype) Reader(default_buffer_size, @TypeOf(io_reader)) {
    return Reader(default_buffer_size, @TypeOf(io_reader)).init(allocator, io_reader);
}
/// Used by `json.reader`.
pub const default_buffer_size = 0x1000;

/// The tokens emitted by `std.json.Scanner` and `std.json.Reader` `.next*()` functions follow this grammar:
/// ```
///  <document> = <value> .end_of_document
///  <value> =
///    | <object>
///    | <array>
///    | <number>
///    | <string>
///    | .true
///    | .false
///    | .null
///  <object> = .object_begin ( <string> <value> )* .object_end
///  <array> = .array_begin ( <value> )* .array_end
///  <number> = <It depends. See below.>
///  <string> = <It depends. See below.>
/// ```
///
/// What you get for `<number>` and `<string>` values depends on which `next*()` method you call:
///
/// ```
/// next():
///  <number> = ( .partial_number )* .number
///  <string> = ( <partial_string> )* .string
///  <partial_string> =
///    | .partial_string
///    | .partial_string_escaped_1
///    | .partial_string_escaped_2
///    | .partial_string_escaped_3
///    | .partial_string_escaped_4
///
/// nextAlloc*(..., .alloc_always):
///  <number> = .allocated_number
///  <string> = .allocated_string
///
/// nextAlloc*(..., .alloc_if_needed):
///  <number> =
///    | .number
///    | .allocated_number
///  <string> =
///    | .string
///    | .allocated_string
/// ```
///
/// For all tokens with a `[]const u8`, `[]u8`, or `[n]u8` payload, the payload represents the content of the value.
/// For number values, this is the representation of the number exactly as it appears in the input.
/// For strings, this is the content of the string after resolving escape sequences.
///
/// For `.allocated_number` and `.allocated_string`, the `[]u8` payloads are allocations made with the given allocator.
/// You are responsible for managing that memory. `json.Reader.deinit()` does *not* free those allocations.
///
/// The `.partial_*` tokens indicate that a value spans multiple input buffers or that a string contains escape sequences.
/// To get a complete value in memory, you need to concatenate the values yourself.
/// Calling `nextAlloc*()` does this for you, and returns an `.allocated_*` token with the result.
///
/// For tokens with a `[]const u8` payload, the payload is a slice into the current input buffer.
/// The memory may become undefined during the next call to `json.Scanner.feedInput()`
/// or any `json.Reader` method whose return error set includes `json.Error`.
/// To keep the value persistently, it recommended to make a copy or to use `.alloc_always`,
/// which makes a copy for you.
///
/// Note that `.number` and `.string` tokens that follow `.partial_*` tokens may have `0` length to indicate that
/// the previously partial value is completed with no additional bytes.
/// (This can happen when the break between input buffers happens to land on the exact end of a value. E.g. `"[1234"`, `"]"`.)
/// `.partial_*` tokens never have `0` length.
///
/// The recommended strategy for using the different `next*()` methods is something like this:
///
/// When you're expecting an object key, use `.alloc_if_needed`.
/// You often don't need a copy of the key string to persist; you might just check which field it is.
/// In the case that the key happens to require an allocation, free it immediately after checking it.
///
/// When you're expecting a meaningful string value (such as on the right of a `:`),
/// use `.alloc_always` in order to keep the value valid throughout parsing the rest of the document.
///
/// When you're expecting a number value, use `.alloc_if_needed`.
/// You're probably going to be parsing the string representation of the number into a numeric representation,
/// so you need the complete string representation only temporarily.
///
/// When you're skipping an unrecognized value, use `skipValue()`.
pub const Token = union(enum) {
    object_begin,
    object_end,
    array_begin,
    array_end,

    true,
    false,
    null,

    number: []const u8,
    partial_number: []const u8,
    allocated_number: []u8,

    string: []const u8,
    partial_string: []const u8,
    partial_string_escaped_1: [1]u8,
    partial_string_escaped_2: [2]u8,
    partial_string_escaped_3: [3]u8,
    partial_string_escaped_4: [4]u8,
    allocated_string: []u8,

    end_of_document,
};

/// This is only used in `peekNextTokenType()` and gives a categorization based on the first byte of the next token that will be emitted from a `next*()` call.
pub const TokenType = enum {
    object_begin,
    object_end,
    array_begin,
    array_end,
    true,
    false,
    null,
    number,
    string,
    end_of_document,
};

/// To enable diagnostics, declare `var diagnostics = Diagnostics{};` then call `source.enableDiagnostics(&diagnostics);`
/// where `source` is either a `std.json.Reader` or a `std.json.Scanner` that has just been initialized.
/// At any time, notably just after an error, call `getLine()`, `getColumn()`, and/or `getByteOffset()`
/// to get meaningful information from this.
pub const Diagnostics = struct {
    line_number: u64 = 1,
    line_start_cursor: usize = @as(usize, @bitCast(@as(isize, -1))), // Start just "before" the input buffer to get a 1-based column for line 1.
    total_bytes_before_current_input: u64 = 0,
    cursor_pointer: *const usize = undefined,

    /// Starts at 1.
    pub fn getLine(self: *const @This()) u64 {
        return self.line_number;
    }
    /// Starts at 1.
    pub fn getColumn(self: *const @This()) u64 {
        return self.cursor_pointer.* -% self.line_start_cursor;
    }
    /// Starts at 0. Measures the byte offset since the start of the input.
    pub fn getByteOffset(self: *const @This()) u64 {
        return self.total_bytes_before_current_input + self.cursor_pointer.*;
    }
};

/// See the documentation for `std.json.Token`.
pub const AllocWhen = enum { alloc_if_needed, alloc_always };

/// For security, the maximum size allocated to store a single string or number value is limited to 4MiB by default.
/// This limit can be specified by calling `nextAllocMax()` instead of `nextAlloc()`.
pub const default_max_value_len = 4 * 1024 * 1024;

/// Connects a `std.io.Reader` to a `std.json.Scanner`.
/// All `next*()` methods here handle `error.BufferUnderrun` from `std.json.Scanner`, and then read from the reader.
pub fn Reader(comptime buffer_size: usize, comptime ReaderType: type) type {
    return struct {
        scanner: Scanner,
        reader: ReaderType,

        buffer: [buffer_size]u8 = undefined,

        /// The allocator is only used to track `[]` and `{}` nesting levels.
        pub fn init(allocator: Allocator, io_reader: ReaderType) @This() {
            return .{
                .scanner = Scanner.initStreaming(allocator),
                .reader = io_reader,
            };
        }
        pub fn deinit(self: *@This()) void {
            self.scanner.deinit();
            self.* = undefined;
        }

        /// Calls `std.json.Scanner.enableDiagnostics`.
        pub fn enableDiagnostics(self: *@This(), diagnostics: *Diagnostics) void {
            self.scanner.enableDiagnostics(diagnostics);
        }

        pub const NextError = ReaderType.Error || Error || Allocator.Error;
        pub const SkipError = NextError;
        pub const AllocError = NextError || error{ValueTooLong};
        pub const PeekError = ReaderType.Error || Error;

        /// Equivalent to `nextAllocMax(allocator, when, default_max_value_len);`
        /// See also `std.json.Token` for documentation of `nextAlloc*()` function behavior.
        pub fn nextAlloc(self: *@This(), allocator: Allocator, when: AllocWhen) AllocError!Token {
            return self.nextAllocMax(allocator, when, default_max_value_len);
        }
        /// See also `std.json.Token` for documentation of `nextAlloc*()` function behavior.
        pub fn nextAllocMax(self: *@This(), allocator: Allocator, when: AllocWhen, max_value_len: usize) AllocError!Token {
            const token_type = try self.peekNextTokenType();
            switch (token_type) {
                .number, .string => {
                    var value_list = ArrayList(u8).init(allocator);
                    errdefer {
                        value_list.deinit();
                    }
                    if (try self.allocNextIntoArrayListMax(&value_list, when, max_value_len)) |slice| {
                        return if (token_type == .number)
                            Token{ .number = slice }
                        else
                            Token{ .string = slice };
                    } else {
                        return if (token_type == .number)
                            Token{ .allocated_number = try value_list.toOwnedSlice() }
                        else
                            Token{ .allocated_string = try value_list.toOwnedSlice() };
                    }
                },

                // Simple tokens never alloc.
                .object_begin,
                .object_end,
                .array_begin,
                .array_end,
                .true,
                .false,
                .null,
                .end_of_document,
                => return try self.next(),
            }
        }

        /// Equivalent to `allocNextIntoArrayListMax(value_list, when, default_max_value_len);`
        pub fn allocNextIntoArrayList(self: *@This(), value_list: *ArrayList(u8), when: AllocWhen) AllocError!?[]const u8 {
            return self.allocNextIntoArrayListMax(value_list, when, default_max_value_len);
        }
        /// Calls `std.json.Scanner.allocNextIntoArrayListMax` and handles `error.BufferUnderrun`.
        pub fn allocNextIntoArrayListMax(self: *@This(), value_list: *ArrayList(u8), when: AllocWhen, max_value_len: usize) AllocError!?[]const u8 {
            while (true) {
                return self.scanner.allocNextIntoArrayListMax(value_list, when, max_value_len) catch |err| switch (err) {
                    error.BufferUnderrun => {
                        try self.refillBuffer();
                        continue;
                    },
                    else => |other_err| return other_err,
                };
            }
        }

        /// Like `std.json.Scanner.skipValue`, but handles `error.BufferUnderrun`.
        pub fn skipValue(self: *@This()) SkipError!void {
            switch (try self.peekNextTokenType()) {
                .object_begin, .array_begin => {
                    try self.skipUntilStackHeight(self.stackHeight());
                },
                .number, .string => {
                    while (true) {
                        switch (try self.next()) {
                            .partial_number,
                            .partial_string,
                            .partial_string_escaped_1,
                            .partial_string_escaped_2,
                            .partial_string_escaped_3,
                            .partial_string_escaped_4,
                            => continue,

                            .number, .string => break,

                            else => unreachable,
                        }
                    }
                },
                .true, .false, .null => {
                    _ = try self.next();
                },

                .object_end, .array_end, .end_of_document => unreachable, // Attempt to skip a non-value token.
            }
        }
        /// Like `std.json.Scanner.skipUntilStackHeight()` but handles `error.BufferUnderrun`.
        pub fn skipUntilStackHeight(self: *@This(), terminal_stack_height: usize) NextError!void {
            while (true) {
                return self.scanner.skipUntilStackHeight(terminal_stack_height) catch |err| switch (err) {
                    error.BufferUnderrun => {
                        try self.refillBuffer();
                        continue;
                    },
                    else => |other_err| return other_err,
                };
            }
        }

        /// Calls `std.json.Scanner.stackHeight`.
        pub fn stackHeight(self: *const @This()) usize {
            return self.scanner.stackHeight();
        }
        /// Calls `std.json.Scanner.ensureTotalStackCapacity`.
        pub fn ensureTotalStackCapacity(self: *@This(), height: usize) Allocator.Error!void {
            try self.scanner.ensureTotalStackCapacity(height);
        }

        /// See `std.json.Token` for documentation of this function.
        pub fn next(self: *@This()) NextError!Token {
            while (true) {
                return self.scanner.next() catch |err| switch (err) {
                    error.BufferUnderrun => {
                        try self.refillBuffer();
                        continue;
                    },
                    else => |other_err| return other_err,
                };
            }
        }

        /// See `std.json.Scanner.peekNextTokenType()`.
        pub fn peekNextTokenType(self: *@This()) PeekError!TokenType {
            while (true) {
                return self.scanner.peekNextTokenType() catch |err| switch (err) {
                    error.BufferUnderrun => {
                        try self.refillBuffer();
                        continue;
                    },
                    else => |other_err| return other_err,
                };
            }
        }

        fn refillBuffer(self: *@This()) ReaderType.Error!void {
            const input = self.buffer[0..try self.reader.read(self.buffer[0..])];
            if (input.len > 0) {
                self.scanner.feedInput(input);
            } else {
                self.scanner.endInput();
            }
        }
    };
}

/// The lowest level parsing API in this package;
/// supports streaming input with a low memory footprint.
/// The memory requirement is `O(d)` where d is the nesting depth of `[]` or `{}` containers in the input.
/// Specifically `d/8` bytes are required for this purpose,
/// with some extra buffer according to the implementation of `std.ArrayList`.
///
/// This scanner can emit partial tokens; see `std.json.Token`.
/// The input to this class is a sequence of input buffers that you must supply one at a time.
/// Call `feedInput()` with the first buffer, then call `next()` repeatedly until `error.BufferUnderrun` is returned.
/// Then call `feedInput()` again and so forth.
/// Call `endInput()` when the last input buffer has been given to `feedInput()`, either immediately after calling `feedInput()`,
/// or when `error.BufferUnderrun` requests more data and there is no more.
/// Be sure to call `next()` after calling `endInput()` until `Token.end_of_document` has been returned.
pub const Scanner = struct {
    state: State = .value,
    string_is_object_key: bool = false,
    stack: BitStack,
    value_start: usize = undefined,
    utf16_code_units: [2]u16 = undefined,

    input: []const u8 = "",
    cursor: usize = 0,
    is_end_of_input: bool = false,
    diagnostics: ?*Diagnostics = null,

    /// The allocator is only used to track `[]` and `{}` nesting levels.
    pub fn initStreaming(allocator: Allocator) @This() {
        return .{
            .stack = BitStack.init(allocator),
        };
    }
    /// Use this if your input is a single slice.
    /// This is effectively equivalent to:
    /// ```
    /// initStreaming(allocator);
    /// feedInput(complete_input);
    /// endInput();
    /// ```
    pub fn initCompleteInput(allocator: Allocator, complete_input: []const u8) @This() {
        return .{
            .stack = BitStack.init(allocator),
            .input = complete_input,
            .is_end_of_input = true,
        };
    }
    pub fn deinit(self: *@This()) void {
        self.stack.deinit();
        self.* = undefined;
    }

    pub fn enableDiagnostics(self: *@This(), diagnostics: *Diagnostics) void {
        diagnostics.cursor_pointer = &self.cursor;
        self.diagnostics = diagnostics;
    }

    /// Call this whenever you get `error.BufferUnderrun` from `next()`.
    /// When there is no more input to provide, call `endInput()`.
    pub fn feedInput(self: *@This(), input: []const u8) void {
        assert(self.cursor == self.input.len); // Not done with the last input slice.
        if (self.diagnostics) |diag| {
            diag.total_bytes_before_current_input += self.input.len;
            // This usually goes "negative" to measure how far before the beginning
            // of the new buffer the current line started.
            diag.line_start_cursor -%= self.cursor;
        }
        self.input = input;
        self.cursor = 0;
        self.value_start = 0;
    }
    /// Call this when you will no longer call `feedInput()` anymore.
    /// This can be called either immediately after the last `feedInput()`,
    /// or at any time afterward, such as when getting `error.BufferUnderrun` from `next()`.
    /// Don't forget to call `next*()` after `endInput()` until you get `.end_of_document`.
    pub fn endInput(self: *@This()) void {
        self.is_end_of_input = true;
    }

    pub const NextError = Error || Allocator.Error || error{BufferUnderrun};
    pub const AllocError = Error || Allocator.Error || error{ValueTooLong};
    pub const PeekError = Error || error{BufferUnderrun};
    pub const SkipError = Error || Allocator.Error;
    pub const AllocIntoArrayListError = AllocError || error{BufferUnderrun};

    /// Equivalent to `nextAllocMax(allocator, when, default_max_value_len);`
    /// This function is only available after `endInput()` (or `initCompleteInput()`) has been called.
    /// See also `std.json.Token` for documentation of `nextAlloc*()` function behavior.
    pub fn nextAlloc(self: *@This(), allocator: Allocator, when: AllocWhen) AllocError!Token {
        return self.nextAllocMax(allocator, when, default_max_value_len);
    }

    /// This function is only available after `endInput()` (or `initCompleteInput()`) has been called.
    /// See also `std.json.Token` for documentation of `nextAlloc*()` function behavior.
    pub fn nextAllocMax(self: *@This(), allocator: Allocator, when: AllocWhen, max_value_len: usize) AllocError!Token {
        assert(self.is_end_of_input); // This function is not available in streaming mode.
        const token_type = self.peekNextTokenType() catch |e| switch (e) {
            error.BufferUnderrun => unreachable,
            else => |err| return err,
        };
        switch (token_type) {
            .number, .string => {
                var value_list = ArrayList(u8).init(allocator);
                errdefer {
                    value_list.deinit();
                }
                if (self.allocNextIntoArrayListMax(&value_list, when, max_value_len) catch |e| switch (e) {
                    error.BufferUnderrun => unreachable,
                    else => |err| return err,
                }) |slice| {
                    return if (token_type == .number)
                        Token{ .number = slice }
                    else
                        Token{ .string = slice };
                } else {
                    return if (token_type == .number)
                        Token{ .allocated_number = try value_list.toOwnedSlice() }
                    else
                        Token{ .allocated_string = try value_list.toOwnedSlice() };
                }
            },

            // Simple tokens never alloc.
            .object_begin,
            .object_end,
            .array_begin,
            .array_end,
            .true,
            .false,
            .null,
            .end_of_document,
            => return self.next() catch |e| switch (e) {
                error.BufferUnderrun => unreachable,
                else => |err| return err,
            },
        }
    }

    /// Equivalent to `allocNextIntoArrayListMax(value_list, when, default_max_value_len);`
    pub fn allocNextIntoArrayList(self: *@This(), value_list: *ArrayList(u8), when: AllocWhen) AllocIntoArrayListError!?[]const u8 {
        return self.allocNextIntoArrayListMax(value_list, when, default_max_value_len);
    }
    /// The next token type must be either `.number` or `.string`. See `peekNextTokenType()`.
    /// When allocation is not necessary with `.alloc_if_needed`,
    /// this method returns the content slice from the input buffer, and `value_list` is not touched.
    /// When allocation is necessary or with `.alloc_always`, this method concatenates partial tokens into the given `value_list`,
    /// and returns `null` once the final `.number` or `.string` token has been written into it.
    /// In case of an `error.BufferUnderrun`, partial values will be left in the given value_list.
    /// The given `value_list` is never reset by this method, so an `error.BufferUnderrun` situation
    /// can be resumed by passing the same array list in again.
    /// This method does not indicate whether the token content being returned is for a `.number` or `.string` token type;
    /// the caller of this method is expected to know which type of token is being processed.
    pub fn allocNextIntoArrayListMax(self: *@This(), value_list: *ArrayList(u8), when: AllocWhen, max_value_len: usize) AllocIntoArrayListError!?[]const u8 {
        while (true) {
            const token = try self.next();
            switch (token) {
                // Accumulate partial values.
                .partial_number, .partial_string => |slice| {
                    try appendSlice(value_list, slice, max_value_len);
                },
                .partial_string_escaped_1 => |buf| {
                    try appendSlice(value_list, buf[0..], max_value_len);
                },
                .partial_string_escaped_2 => |buf| {
                    try appendSlice(value_list, buf[0..], max_value_len);
                },
                .partial_string_escaped_3 => |buf| {
                    try appendSlice(value_list, buf[0..], max_value_len);
                },
                .partial_string_escaped_4 => |buf| {
                    try appendSlice(value_list, buf[0..], max_value_len);
                },

                // Return complete values.
                .number => |slice| {
                    if (when == .alloc_if_needed and value_list.items.len == 0) {
                        // No alloc necessary.
                        return slice;
                    }
                    try appendSlice(value_list, slice, max_value_len);
                    // The token is complete.
                    return null;
                },
                .string => |slice| {
                    if (when == .alloc_if_needed and value_list.items.len == 0) {
                        // No alloc necessary.
                        return slice;
                    }
                    try appendSlice(value_list, slice, max_value_len);
                    // The token is complete.
                    return null;
                },

                .object_begin,
                .object_end,
                .array_begin,
                .array_end,
                .true,
                .false,
                .null,
                .end_of_document,
                => unreachable, // Only .number and .string token types are allowed here. Check peekNextTokenType() before calling this.

                .allocated_number, .allocated_string => unreachable,
            }
        }
    }

    /// This function is only available after `endInput()` (or `initCompleteInput()`) has been called.
    /// If the next token type is `.object_begin` or `.array_begin`,
    /// this function calls `next()` repeatedly until the corresponding `.object_end` or `.array_end` is found.
    /// If the next token type is `.number` or `.string`,
    /// this function calls `next()` repeatedly until the (non `.partial_*`) `.number` or `.string` token is found.
    /// If the next token type is `.true`, `.false`, or `.null`, this function calls `next()` once.
    /// The next token type must not be `.object_end`, `.array_end`, or `.end_of_document`;
    /// see `peekNextTokenType()`.
    pub fn skipValue(self: *@This()) SkipError!void {
        assert(self.is_end_of_input); // This function is not available in streaming mode.
        switch (self.peekNextTokenType() catch |e| switch (e) {
            error.BufferUnderrun => unreachable,
            else => |err| return err,
        }) {
            .object_begin, .array_begin => {
                self.skipUntilStackHeight(self.stackHeight()) catch |e| switch (e) {
                    error.BufferUnderrun => unreachable,
                    else => |err| return err,
                };
            },
            .number, .string => {
                while (true) {
                    switch (self.next() catch |e| switch (e) {
                        error.BufferUnderrun => unreachable,
                        else => |err| return err,
                    }) {
                        .partial_number,
                        .partial_string,
                        .partial_string_escaped_1,
                        .partial_string_escaped_2,
                        .partial_string_escaped_3,
                        .partial_string_escaped_4,
                        => continue,

                        .number, .string => break,

                        else => unreachable,
                    }
                }
            },
            .true, .false, .null => {
                _ = self.next() catch |e| switch (e) {
                    error.BufferUnderrun => unreachable,
                    else => |err| return err,
                };
            },

            .object_end, .array_end, .end_of_document => unreachable, // Attempt to skip a non-value token.
        }
    }

    /// Skip tokens until an `.object_end` or `.array_end` token results in a `stackHeight()` equal the given stack height.
    /// Unlike `skipValue()`, this function is available in streaming mode.
    pub fn skipUntilStackHeight(self: *@This(), terminal_stack_height: usize) NextError!void {
        while (true) {
            switch (try self.next()) {
                .object_end, .array_end => {
                    if (self.stackHeight() == terminal_stack_height) break;
                },
                .end_of_document => unreachable,
                else => continue,
            }
        }
    }

    /// The depth of `{}` or `[]` nesting levels at the current position.
    pub fn stackHeight(self: *const @This()) usize {
        return self.stack.bit_len;
    }

    /// Pre allocate memory to hold the given number of nesting levels.
    /// `stackHeight()` up to the given number will not cause allocations.
    pub fn ensureTotalStackCapacity(self: *@This(), height: usize) Allocator.Error!void {
        try self.stack.ensureTotalCapacity(height);
    }

    /// See `std.json.Token` for documentation of this function.
    pub fn next(self: *@This()) NextError!Token {
        state_loop: while (true) {
            switch (self.state) {
                .value => {
                    switch (try self.skipWhitespaceExpectByte()) {
                        // Object, Array
                        '{' => {
                            try self.stack.push(OBJECT_MODE);
                            self.cursor += 1;
                            self.state = .object_start;
                            return .object_begin;
                        },
                        '[' => {
                            try self.stack.push(ARRAY_MODE);
                            self.cursor += 1;
                            self.state = .array_start;
                            return .array_begin;
                        },

                        // String
                        '"' => {
                            self.cursor += 1;
                            self.value_start = self.cursor;
                            self.state = .string;
                            continue :state_loop;
                        },

                        // Number
                        '1'...'9' => {
                            self.value_start = self.cursor;
                            self.cursor += 1;
                            self.state = .number_int;
                            continue :state_loop;
                        },
                        '0' => {
                            self.value_start = self.cursor;
                            self.cursor += 1;
                            self.state = .number_leading_zero;
                            continue :state_loop;
                        },
                        '-' => {
                            self.value_start = self.cursor;
                            self.cursor += 1;
                            self.state = .number_minus;
                            continue :state_loop;
                        },

                        // literal values
                        't' => {
                            self.cursor += 1;
                            self.state = .literal_t;
                            continue :state_loop;
                        },
                        'f' => {
                            self.cursor += 1;
                            self.state = .literal_f;
                            continue :state_loop;
                        },
                        'n' => {
                            self.cursor += 1;
                            self.state = .literal_n;
                            continue :state_loop;
                        },

                        else => return error.SyntaxError,
                    }
                },

                .post_value => {
                    if (try self.skipWhitespaceCheckEnd()) return .end_of_document;

                    const c = self.input[self.cursor];
                    if (self.string_is_object_key) {
                        self.string_is_object_key = false;
                        switch (c) {
                            ':' => {
                                self.cursor += 1;
                                self.state = .value;
                                continue :state_loop;
                            },
                            else => return error.SyntaxError,
                        }
                    }

                    switch (c) {
                        '}' => {
                            if (self.stack.pop() != OBJECT_MODE) return error.SyntaxError;
                            self.cursor += 1;
                            // stay in .post_value state.
                            return .object_end;
                        },
                        ']' => {
                            if (self.stack.pop() != ARRAY_MODE) return error.SyntaxError;
                            self.cursor += 1;
                            // stay in .post_value state.
                            return .array_end;
                        },
                        ',' => {
                            switch (self.stack.peek()) {
                                OBJECT_MODE => {
                                    self.state = .object_post_comma;
                                },
                                ARRAY_MODE => {
                                    self.state = .value;
                                },
                            }
                            self.cursor += 1;
                            continue :state_loop;
                        },
                        else => return error.SyntaxError,
                    }
                },

                .object_start => {
                    switch (try self.skipWhitespaceExpectByte()) {
                        '"' => {
                            self.cursor += 1;
                            self.value_start = self.cursor;
                            self.state = .string;
                            self.string_is_object_key = true;
                            continue :state_loop;
                        },
                        '}' => {
                            self.cursor += 1;
                            _ = self.stack.pop();
                            self.state = .post_value;
                            return .object_end;
                        },
                        else => return error.SyntaxError,
                    }
                },
                .object_post_comma => {
                    switch (try self.skipWhitespaceExpectByte()) {
                        '"' => {
                            self.cursor += 1;
                            self.value_start = self.cursor;
                            self.state = .string;
                            self.string_is_object_key = true;
                            continue :state_loop;
                        },
                        else => return error.SyntaxError,
                    }
                },

                .array_start => {
                    switch (try self.skipWhitespaceExpectByte()) {
                        ']' => {
                            self.cursor += 1;
                            _ = self.stack.pop();
                            self.state = .post_value;
                            return .array_end;
                        },
                        else => {
                            self.state = .value;
                            continue :state_loop;
                        },
                    }
                },

                .number_minus => {
                    if (self.cursor >= self.input.len) return self.endOfBufferInNumber(false);
                    switch (self.input[self.cursor]) {
                        '0' => {
                            self.cursor += 1;
                            self.state = .number_leading_zero;
                            continue :state_loop;
                        },
                        '1'...'9' => {
                            self.cursor += 1;
                            self.state = .number_int;
                            continue :state_loop;
                        },
                        else => return error.SyntaxError,
                    }
                },
                .number_leading_zero => {
                    if (self.cursor >= self.input.len) return self.endOfBufferInNumber(true);
                    switch (self.input[self.cursor]) {
                        '.' => {
                            self.cursor += 1;
                            self.state = .number_post_dot;
                            continue :state_loop;
                        },
                        'e', 'E' => {
                            self.cursor += 1;
                            self.state = .number_post_e;
                            continue :state_loop;
                        },
                        else => {
                            self.state = .post_value;
                            return Token{ .number = self.takeValueSlice() };
                        },
                    }
                },
                .number_int => {
                    while (self.cursor < self.input.len) : (self.cursor += 1) {
                        switch (self.input[self.cursor]) {
                            '0'...'9' => continue,
                            '.' => {
                                self.cursor += 1;
                                self.state = .number_post_dot;
                                continue :state_loop;
                            },
                            'e', 'E' => {
                                self.cursor += 1;
                                self.state = .number_post_e;
                                continue :state_loop;
                            },
                            else => {
                                self.state = .post_value;
                                return Token{ .number = self.takeValueSlice() };
                            },
                        }
                    }
                    return self.endOfBufferInNumber(true);
                },
                .number_post_dot => {
                    if (self.cursor >= self.input.len) return self.endOfBufferInNumber(false);
                    switch (self.input[self.cursor]) {
                        '0'...'9' => {
                            self.cursor += 1;
                            self.state = .number_frac;
                            continue :state_loop;
                        },
                        else => return error.SyntaxError,
                    }
                },
                .number_frac => {
                    while (self.cursor < self.input.len) : (self.cursor += 1) {
                        switch (self.input[self.cursor]) {
                            '0'...'9' => continue,
                            'e', 'E' => {
                                self.cursor += 1;
                                self.state = .number_post_e;
                                continue :state_loop;
                            },
                            else => {
                                self.state = .post_value;
                                return Token{ .number = self.takeValueSlice() };
                            },
                        }
                    }
                    return self.endOfBufferInNumber(true);
                },
                .number_post_e => {
                    if (self.cursor >= self.input.len) return self.endOfBufferInNumber(false);
                    switch (self.input[self.cursor]) {
                        '0'...'9' => {
                            self.cursor += 1;
                            self.state = .number_exp;
                            continue :state_loop;
                        },
                        '+', '-' => {
                            self.cursor += 1;
                            self.state = .number_post_e_sign;
                            continue :state_loop;
                        },
                        else => return error.SyntaxError,
                    }
                },
                .number_post_e_sign => {
                    if (self.cursor >= self.input.len) return self.endOfBufferInNumber(false);
                    switch (self.input[self.cursor]) {
                        '0'...'9' => {
                            self.cursor += 1;
                            self.state = .number_exp;
                            continue :state_loop;
                        },
                        else => return error.SyntaxError,
                    }
                },
                .number_exp => {
                    while (self.cursor < self.input.len) : (self.cursor += 1) {
                        switch (self.input[self.cursor]) {
                            '0'...'9' => continue,
                            else => {
                                self.state = .post_value;
                                return Token{ .number = self.takeValueSlice() };
                            },
                        }
                    }
                    return self.endOfBufferInNumber(true);
                },

                .string => {
                    while (self.cursor < self.input.len) : (self.cursor += 1) {
                        switch (self.input[self.cursor]) {
                            0...0x1f => return error.SyntaxError, // Bare ASCII control code in string.

                            // ASCII plain text.
                            0x20...('"' - 1), ('"' + 1)...('\\' - 1), ('\\' + 1)...0x7F => continue,

                            // Special characters.
                            '"' => {
                                const result = Token{ .string = self.takeValueSlice() };
                                self.cursor += 1;
                                self.state = .post_value;
                                return result;
                            },
                            '\\' => {
                                const slice = self.takeValueSlice();
                                self.cursor += 1;
                                self.state = .string_backslash;
                                if (slice.len > 0) return Token{ .partial_string = slice };
                                continue :state_loop;
                            },

                            // UTF-8 validation.
                            // See http://unicode.org/mail-arch/unicode-ml/y2003-m02/att-0467/01-The_Algorithm_to_Valide_an_UTF-8_String
                            0xC2...0xDF => {
                                self.cursor += 1;
                                self.state = .string_utf8_last_byte;
                                continue :state_loop;
                            },
                            0xE0 => {
                                self.cursor += 1;
                                self.state = .string_utf8_second_to_last_byte_guard_against_overlong;
                                continue :state_loop;
                            },
                            0xE1...0xEC, 0xEE...0xEF => {
                                self.cursor += 1;
                                self.state = .string_utf8_second_to_last_byte;
                                continue :state_loop;
                            },
                            0xED => {
                                self.cursor += 1;
                                self.state = .string_utf8_second_to_last_byte_guard_against_surrogate_half;
                                continue :state_loop;
                            },
                            0xF0 => {
                                self.cursor += 1;
                                self.state = .string_utf8_third_to_last_byte_guard_against_overlong;
                                continue :state_loop;
                            },
                            0xF1...0xF3 => {
                                self.cursor += 1;
                                self.state = .string_utf8_third_to_last_byte;
                                continue :state_loop;
                            },
                            0xF4 => {
                                self.cursor += 1;
                                self.state = .string_utf8_third_to_last_byte_guard_against_too_large;
                                continue :state_loop;
                            },
                            0x80...0xC1, 0xF5...0xFF => return error.SyntaxError, // Invalid UTF-8.
                        }
                    }
                    if (self.is_end_of_input) return error.UnexpectedEndOfInput;
                    const slice = self.takeValueSlice();
                    if (slice.len > 0) return Token{ .partial_string = slice };
                    return error.BufferUnderrun;
                },
                .string_backslash => {
                    if (self.cursor >= self.input.len) return self.endOfBufferInString();
                    switch (self.input[self.cursor]) {
                        '"', '\\', '/' => {
                            // Since these characters now represent themselves literally,
                            // we can simply begin the next plaintext slice here.
                            self.value_start = self.cursor;
                            self.cursor += 1;
                            self.state = .string;
                            continue :state_loop;
                        },
                        'b' => {
                            self.cursor += 1;
                            self.value_start = self.cursor;
                            self.state = .string;
                            return Token{ .partial_string_escaped_1 = [_]u8{0x08} };
                        },
                        'f' => {
                            self.cursor += 1;
                            self.value_start = self.cursor;
                            self.state = .string;
                            return Token{ .partial_string_escaped_1 = [_]u8{0x0c} };
                        },
                        'n' => {
                            self.cursor += 1;
                            self.value_start = self.cursor;
                            self.state = .string;
                            return Token{ .partial_string_escaped_1 = [_]u8{'\n'} };
                        },
                        'r' => {
                            self.cursor += 1;
                            self.value_start = self.cursor;
                            self.state = .string;
                            return Token{ .partial_string_escaped_1 = [_]u8{'\r'} };
                        },
                        't' => {
                            self.cursor += 1;
                            self.value_start = self.cursor;
                            self.state = .string;
                            return Token{ .partial_string_escaped_1 = [_]u8{'\t'} };
                        },
                        'u' => {
                            self.cursor += 1;
                            self.state = .string_backslash_u;
                            continue :state_loop;
                        },
                        else => return error.SyntaxError,
                    }
                },
                .string_backslash_u => {
                    if (self.cursor >= self.input.len) return self.endOfBufferInString();
                    const c = self.input[self.cursor];
                    switch (c) {
                        '0'...'9' => {
                            self.utf16_code_units[0] = @as(u16, c - '0') << 12;
                        },
                        'A'...'F' => {
                            self.utf16_code_units[0] = @as(u16, c - 'A' + 10) << 12;
                        },
                        'a'...'f' => {
                            self.utf16_code_units[0] = @as(u16, c - 'a' + 10) << 12;
                        },
                        else => return error.SyntaxError,
                    }
                    self.cursor += 1;
                    self.state = .string_backslash_u_1;
                    continue :state_loop;
                },
                .string_backslash_u_1 => {
                    if (self.cursor >= self.input.len) return self.endOfBufferInString();
                    const c = self.input[self.cursor];
                    switch (c) {
                        '0'...'9' => {
                            self.utf16_code_units[0] |= @as(u16, c - '0') << 8;
                        },
                        'A'...'F' => {
                            self.utf16_code_units[0] |= @as(u16, c - 'A' + 10) << 8;
                        },
                        'a'...'f' => {
                            self.utf16_code_units[0] |= @as(u16, c - 'a' + 10) << 8;
                        },
                        else => return error.SyntaxError,
                    }
                    self.cursor += 1;
                    self.state = .string_backslash_u_2;
                    continue :state_loop;
                },
                .string_backslash_u_2 => {
                    if (self.cursor >= self.input.len) return self.endOfBufferInString();
                    const c = self.input[self.cursor];
                    switch (c) {
                        '0'...'9' => {
                            self.utf16_code_units[0] |= @as(u16, c - '0') << 4;
                        },
                        'A'...'F' => {
                            self.utf16_code_units[0] |= @as(u16, c - 'A' + 10) << 4;
                        },
                        'a'...'f' => {
                            self.utf16_code_units[0] |= @as(u16, c - 'a' + 10) << 4;
                        },
                        else => return error.SyntaxError,
                    }
                    self.cursor += 1;
                    self.state = .string_backslash_u_3;
                    continue :state_loop;
                },
                .string_backslash_u_3 => {
                    if (self.cursor >= self.input.len) return self.endOfBufferInString();
                    const c = self.input[self.cursor];
                    switch (c) {
                        '0'...'9' => {
                            self.utf16_code_units[0] |= c - '0';
                        },
                        'A'...'F' => {
                            self.utf16_code_units[0] |= c - 'A' + 10;
                        },
                        'a'...'f' => {
                            self.utf16_code_units[0] |= c - 'a' + 10;
                        },
                        else => return error.SyntaxError,
                    }
                    self.cursor += 1;
                    if (std.unicode.utf16IsHighSurrogate(self.utf16_code_units[0])) {
                        self.state = .string_surrogate_half;
                        continue :state_loop;
                    } else if (std.unicode.utf16IsLowSurrogate(self.utf16_code_units[0])) {
                        return error.SyntaxError; // Unexpected low surrogate half.
                    } else {
                        self.value_start = self.cursor;
                        self.state = .string;
                        return partialStringCodepoint(self.utf16_code_units[0]);
                    }
                },
                .string_surrogate_half => {
                    if (self.cursor >= self.input.len) return self.endOfBufferInString();
                    switch (self.input[self.cursor]) {
                        '\\' => {
                            self.cursor += 1;
                            self.state = .string_surrogate_half_backslash;
                            continue :state_loop;
                        },
                        else => return error.SyntaxError, // Expected low surrogate half.
                    }
                },
                .string_surrogate_half_backslash => {
                    if (self.cursor >= self.input.len) return self.endOfBufferInString();
                    switch (self.input[self.cursor]) {
                        'u' => {
                            self.cursor += 1;
                            self.state = .string_surrogate_half_backslash_u;
                            continue :state_loop;
                        },
                        else => return error.SyntaxError, // Expected low surrogate half.
                    }
                },
                .string_surrogate_half_backslash_u => {
                    if (self.cursor >= self.input.len) return self.endOfBufferInString();
                    switch (self.input[self.cursor]) {
                        'D', 'd' => {
                            self.cursor += 1;
                            self.utf16_code_units[1] = 0xD << 12;
                            self.state = .string_surrogate_half_backslash_u_1;
                            continue :state_loop;
                        },
                        else => return error.SyntaxError, // Expected low surrogate half.
                    }
                },
                .string_surrogate_half_backslash_u_1 => {
                    if (self.cursor >= self.input.len) return self.endOfBufferInString();
                    const c = self.input[self.cursor];
                    switch (c) {
                        'C'...'F' => {
                            self.cursor += 1;
                            self.utf16_code_units[1] |= @as(u16, c - 'A' + 10) << 8;
                            self.state = .string_surrogate_half_backslash_u_2;
                            continue :state_loop;
                        },
                        'c'...'f' => {
                            self.cursor += 1;
                            self.utf16_code_units[1] |= @as(u16, c - 'a' + 10) << 8;
                            self.state = .string_surrogate_half_backslash_u_2;
                            continue :state_loop;
                        },
                        else => return error.SyntaxError, // Expected low surrogate half.
                    }
                },
                .string_surrogate_half_backslash_u_2 => {
                    if (self.cursor >= self.input.len) return self.endOfBufferInString();
                    const c = self.input[self.cursor];
                    switch (c) {
                        '0'...'9' => {
                            self.cursor += 1;
                            self.utf16_code_units[1] |= @as(u16, c - '0') << 4;
                            self.state = .string_surrogate_half_backslash_u_3;
                            continue :state_loop;
                        },
                        'A'...'F' => {
                            self.cursor += 1;
                            self.utf16_code_units[1] |= @as(u16, c - 'A' + 10) << 4;
                            self.state = .string_surrogate_half_backslash_u_3;
                            continue :state_loop;
                        },
                        'a'...'f' => {
                            self.cursor += 1;
                            self.utf16_code_units[1] |= @as(u16, c - 'a' + 10) << 4;
                            self.state = .string_surrogate_half_backslash_u_3;
                            continue :state_loop;
                        },
                        else => return error.SyntaxError,
                    }
                },
                .string_surrogate_half_backslash_u_3 => {
                    if (self.cursor >= self.input.len) return self.endOfBufferInString();
                    const c = self.input[self.cursor];
                    switch (c) {
                        '0'...'9' => {
                            self.utf16_code_units[1] |= c - '0';
                        },
                        'A'...'F' => {
                            self.utf16_code_units[1] |= c - 'A' + 10;
                        },
                        'a'...'f' => {
                            self.utf16_code_units[1] |= c - 'a' + 10;
                        },
                        else => return error.SyntaxError,
                    }
                    self.cursor += 1;
                    self.value_start = self.cursor;
                    self.state = .string;
                    const code_point = std.unicode.utf16DecodeSurrogatePair(&self.utf16_code_units) catch unreachable;
                    return partialStringCodepoint(code_point);
                },

                .string_utf8_last_byte => {
                    if (self.cursor >= self.input.len) return self.endOfBufferInString();
                    switch (self.input[self.cursor]) {
                        0x80...0xBF => {
                            self.cursor += 1;
                            self.state = .string;
                            continue :state_loop;
                        },
                        else => return error.SyntaxError, // Invalid UTF-8.
                    }
                },
                .string_utf8_second_to_last_byte => {
                    if (self.cursor >= self.input.len) return self.endOfBufferInString();
                    switch (self.input[self.cursor]) {
                        0x80...0xBF => {
                            self.cursor += 1;
                            self.state = .string_utf8_last_byte;
                            continue :state_loop;
                        },
                        else => return error.SyntaxError, // Invalid UTF-8.
                    }
                },
                .string_utf8_second_to_last_byte_guard_against_overlong => {
                    if (self.cursor >= self.input.len) return self.endOfBufferInString();
                    switch (self.input[self.cursor]) {
                        0xA0...0xBF => {
                            self.cursor += 1;
                            self.state = .string_utf8_last_byte;
                            continue :state_loop;
                        },
                        else => return error.SyntaxError, // Invalid UTF-8.
                    }
                },
                .string_utf8_second_to_last_byte_guard_against_surrogate_half => {
                    if (self.cursor >= self.input.len) return self.endOfBufferInString();
                    switch (self.input[self.cursor]) {
                        0x80...0x9F => {
                            self.cursor += 1;
                            self.state = .string_utf8_last_byte;
                            continue :state_loop;
                        },
                        else => return error.SyntaxError, // Invalid UTF-8.
                    }
                },
                .string_utf8_third_to_last_byte => {
                    if (self.cursor >= self.input.len) return self.endOfBufferInString();
                    switch (self.input[self.cursor]) {
                        0x80...0xBF => {
                            self.cursor += 1;
                            self.state = .string_utf8_second_to_last_byte;
                            continue :state_loop;
                        },
                        else => return error.SyntaxError, // Invalid UTF-8.
                    }
                },
                .string_utf8_third_to_last_byte_guard_against_overlong => {
                    if (self.cursor >= self.input.len) return self.endOfBufferInString();
                    switch (self.input[self.cursor]) {
                        0x90...0xBF => {
                            self.cursor += 1;
                            self.state = .string_utf8_second_to_last_byte;
                            continue :state_loop;
                        },
                        else => return error.SyntaxError, // Invalid UTF-8.
                    }
                },
                .string_utf8_third_to_last_byte_guard_against_too_large => {
                    if (self.cursor >= self.input.len) return self.endOfBufferInString();
                    switch (self.input[self.cursor]) {
                        0x80...0x8F => {
                            self.cursor += 1;
                            self.state = .string_utf8_second_to_last_byte;
                            continue :state_loop;
                        },
                        else => return error.SyntaxError, // Invalid UTF-8.
                    }
                },

                .literal_t => {
                    switch (try self.expectByte()) {
                        'r' => {
                            self.cursor += 1;
                            self.state = .literal_tr;
                            continue :state_loop;
                        },
                        else => return error.SyntaxError,
                    }
                },
                .literal_tr => {
                    switch (try self.expectByte()) {
                        'u' => {
                            self.cursor += 1;
                            self.state = .literal_tru;
                            continue :state_loop;
                        },
                        else => return error.SyntaxError,
                    }
                },
                .literal_tru => {
                    switch (try self.expectByte()) {
                        'e' => {
                            self.cursor += 1;
                            self.state = .post_value;
                            return .true;
                        },
                        else => return error.SyntaxError,
                    }
                },
                .literal_f => {
                    switch (try self.expectByte()) {
                        'a' => {
                            self.cursor += 1;
                            self.state = .literal_fa;
                            continue :state_loop;
                        },
                        else => return error.SyntaxError,
                    }
                },
                .literal_fa => {
                    switch (try self.expectByte()) {
                        'l' => {
                            self.cursor += 1;
                            self.state = .literal_fal;
                            continue :state_loop;
                        },
                        else => return error.SyntaxError,
                    }
                },
                .literal_fal => {
                    switch (try self.expectByte()) {
                        's' => {
                            self.cursor += 1;
                            self.state = .literal_fals;
                            continue :state_loop;
                        },
                        else => return error.SyntaxError,
                    }
                },
                .literal_fals => {
                    switch (try self.expectByte()) {
                        'e' => {
                            self.cursor += 1;
                            self.state = .post_value;
                            return .false;
                        },
                        else => return error.SyntaxError,
                    }
                },
                .literal_n => {
                    switch (try self.expectByte()) {
                        'u' => {
                            self.cursor += 1;
                            self.state = .literal_nu;
                            continue :state_loop;
                        },
                        else => return error.SyntaxError,
                    }
                },
                .literal_nu => {
                    switch (try self.expectByte()) {
                        'l' => {
                            self.cursor += 1;
                            self.state = .literal_nul;
                            continue :state_loop;
                        },
                        else => return error.SyntaxError,
                    }
                },
                .literal_nul => {
                    switch (try self.expectByte()) {
                        'l' => {
                            self.cursor += 1;
                            self.state = .post_value;
                            return .null;
                        },
                        else => return error.SyntaxError,
                    }
                },
            }
            unreachable;
        }
    }

    /// Seeks ahead in the input until the first byte of the next token (or the end of the input)
    /// determines which type of token will be returned from the next `next*()` call.
    /// This function is idempotent, only advancing past commas, colons, and inter-token whitespace.
    pub fn peekNextTokenType(self: *@This()) PeekError!TokenType {
        state_loop: while (true) {
            switch (self.state) {
                .value => {
                    switch (try self.skipWhitespaceExpectByte()) {
                        '{' => return .object_begin,
                        '[' => return .array_begin,
                        '"' => return .string,
                        '-', '0'...'9' => return .number,
                        't' => return .true,
                        'f' => return .false,
                        'n' => return .null,
                        else => return error.SyntaxError,
                    }
                },

                .post_value => {
                    if (try self.skipWhitespaceCheckEnd()) return .end_of_document;

                    const c = self.input[self.cursor];
                    if (self.string_is_object_key) {
                        self.string_is_object_key = false;
                        switch (c) {
                            ':' => {
                                self.cursor += 1;
                                self.state = .value;
                                continue :state_loop;
                            },
                            else => return error.SyntaxError,
                        }
                    }

                    switch (c) {
                        '}' => return .object_end,
                        ']' => return .array_end,
                        ',' => {
                            switch (self.stack.peek()) {
                                OBJECT_MODE => {
                                    self.state = .object_post_comma;
                                },
                                ARRAY_MODE => {
                                    self.state = .value;
                                },
                            }
                            self.cursor += 1;
                            continue :state_loop;
                        },
                        else => return error.SyntaxError,
                    }
                },

                .object_start => {
                    switch (try self.skipWhitespaceExpectByte()) {
                        '"' => return .string,
                        '}' => return .object_end,
                        else => return error.SyntaxError,
                    }
                },
                .object_post_comma => {
                    switch (try self.skipWhitespaceExpectByte()) {
                        '"' => return .string,
                        else => return error.SyntaxError,
                    }
                },

                .array_start => {
                    switch (try self.skipWhitespaceExpectByte()) {
                        ']' => return .array_end,
                        else => {
                            self.state = .value;
                            continue :state_loop;
                        },
                    }
                },

                .number_minus,
                .number_leading_zero,
                .number_int,
                .number_post_dot,
                .number_frac,
                .number_post_e,
                .number_post_e_sign,
                .number_exp,
                => return .number,

                .string,
                .string_backslash,
                .string_backslash_u,
                .string_backslash_u_1,
                .string_backslash_u_2,
                .string_backslash_u_3,
                .string_surrogate_half,
                .string_surrogate_half_backslash,
                .string_surrogate_half_backslash_u,
                .string_surrogate_half_backslash_u_1,
                .string_surrogate_half_backslash_u_2,
                .string_surrogate_half_backslash_u_3,
                => return .string,

                .string_utf8_last_byte,
                .string_utf8_second_to_last_byte,
                .string_utf8_second_to_last_byte_guard_against_overlong,
                .string_utf8_second_to_last_byte_guard_against_surrogate_half,
                .string_utf8_third_to_last_byte,
                .string_utf8_third_to_last_byte_guard_against_overlong,
                .string_utf8_third_to_last_byte_guard_against_too_large,
                => return .string,

                .literal_t,
                .literal_tr,
                .literal_tru,
                => return .true,
                .literal_f,
                .literal_fa,
                .literal_fal,
                .literal_fals,
                => return .false,
                .literal_n,
                .literal_nu,
                .literal_nul,
                => return .null,
            }
            unreachable;
        }
    }

    const State = enum {
        value,
        post_value,

        object_start,
        object_post_comma,

        array_start,

        number_minus,
        number_leading_zero,
        number_int,
        number_post_dot,
        number_frac,
        number_post_e,
        number_post_e_sign,
        number_exp,

        string,
        string_backslash,
        string_backslash_u,
        string_backslash_u_1,
        string_backslash_u_2,
        string_backslash_u_3,
        string_surrogate_half,
        string_surrogate_half_backslash,
        string_surrogate_half_backslash_u,
        string_surrogate_half_backslash_u_1,
        string_surrogate_half_backslash_u_2,
        string_surrogate_half_backslash_u_3,

        // From http://unicode.org/mail-arch/unicode-ml/y2003-m02/att-0467/01-The_Algorithm_to_Valide_an_UTF-8_String
        string_utf8_last_byte, // State A
        string_utf8_second_to_last_byte, // State B
        string_utf8_second_to_last_byte_guard_against_overlong, // State C
        string_utf8_second_to_last_byte_guard_against_surrogate_half, // State D
        string_utf8_third_to_last_byte, // State E
        string_utf8_third_to_last_byte_guard_against_overlong, // State F
        string_utf8_third_to_last_byte_guard_against_too_large, // State G

        literal_t,
        literal_tr,
        literal_tru,
        literal_f,
        literal_fa,
        literal_fal,
        literal_fals,
        literal_n,
        literal_nu,
        literal_nul,
    };

    fn expectByte(self: *const @This()) !u8 {
        if (self.cursor < self.input.len) {
            return self.input[self.cursor];
        }
        // No byte.
        if (self.is_end_of_input) return error.UnexpectedEndOfInput;
        return error.BufferUnderrun;
    }

    fn skipWhitespace(self: *@This()) void {
        while (self.cursor < self.input.len) : (self.cursor += 1) {
            switch (self.input[self.cursor]) {
                // Whitespace
                ' ', '\t', '\r' => continue,
                '\n' => {
                    if (self.diagnostics) |diag| {
                        diag.line_number += 1;
                        // This will count the newline itself,
                        // which means a straight-forward subtraction will give a 1-based column number.
                        diag.line_start_cursor = self.cursor;
                    }
                    continue;
                },
                else => return,
            }
        }
    }

    fn skipWhitespaceExpectByte(self: *@This()) !u8 {
        self.skipWhitespace();
        return self.expectByte();
    }

    fn skipWhitespaceCheckEnd(self: *@This()) !bool {
        self.skipWhitespace();
        if (self.cursor >= self.input.len) {
            // End of buffer.
            if (self.is_end_of_input) {
                // End of everything.
                if (self.stackHeight() == 0) {
                    // We did it!
                    return true;
                }
                return error.UnexpectedEndOfInput;
            }
            return error.BufferUnderrun;
        }
        if (self.stackHeight() == 0) return error.SyntaxError;
        return false;
    }

    fn takeValueSlice(self: *@This()) []const u8 {
        const slice = self.input[self.value_start..self.cursor];
        self.value_start = self.cursor;
        return slice;
    }
    fn takeValueSliceMinusTrailingOffset(self: *@This(), trailing_negative_offset: usize) []const u8 {
        // Check if the escape sequence started before the current input buffer.
        // (The algebra here is awkward to avoid unsigned underflow,
        //  but it's just making sure the slice on the next line isn't UB.)
        if (self.cursor <= self.value_start + trailing_negative_offset) return "";
        const slice = self.input[self.value_start .. self.cursor - trailing_negative_offset];
        // When trailing_negative_offset is non-zero, setting self.value_start doesn't matter,
        // because we always set it again while emitting the .partial_string_escaped_*.
        self.value_start = self.cursor;
        return slice;
    }

    fn endOfBufferInNumber(self: *@This(), allow_end: bool) !Token {
        const slice = self.takeValueSlice();
        if (self.is_end_of_input) {
            if (!allow_end) return error.UnexpectedEndOfInput;
            self.state = .post_value;
            return Token{ .number = slice };
        }
        if (slice.len == 0) return error.BufferUnderrun;
        return Token{ .partial_number = slice };
    }

    fn endOfBufferInString(self: *@This()) !Token {
        if (self.is_end_of_input) return error.UnexpectedEndOfInput;
        const slice = self.takeValueSliceMinusTrailingOffset(switch (self.state) {
            // Don't include the escape sequence in the partial string.
            .string_backslash => 1,
            .string_backslash_u => 2,
            .string_backslash_u_1 => 3,
            .string_backslash_u_2 => 4,
            .string_backslash_u_3 => 5,
            .string_surrogate_half => 6,
            .string_surrogate_half_backslash => 7,
            .string_surrogate_half_backslash_u => 8,
            .string_surrogate_half_backslash_u_1 => 9,
            .string_surrogate_half_backslash_u_2 => 10,
            .string_surrogate_half_backslash_u_3 => 11,

            // Include everything up to the cursor otherwise.
            .string,
            .string_utf8_last_byte,
            .string_utf8_second_to_last_byte,
            .string_utf8_second_to_last_byte_guard_against_overlong,
            .string_utf8_second_to_last_byte_guard_against_surrogate_half,
            .string_utf8_third_to_last_byte,
            .string_utf8_third_to_last_byte_guard_against_overlong,
            .string_utf8_third_to_last_byte_guard_against_too_large,
            => 0,

            else => unreachable,
        });
        if (slice.len == 0) return error.BufferUnderrun;
        return Token{ .partial_string = slice };
    }

    fn partialStringCodepoint(code_point: u21) Token {
        var buf: [4]u8 = undefined;
        switch (std.unicode.utf8Encode(code_point, &buf) catch unreachable) {
            1 => return Token{ .partial_string_escaped_1 = buf[0..1].* },
            2 => return Token{ .partial_string_escaped_2 = buf[0..2].* },
            3 => return Token{ .partial_string_escaped_3 = buf[0..3].* },
            4 => return Token{ .partial_string_escaped_4 = buf[0..4].* },
            else => unreachable,
        }
    }
};

const OBJECT_MODE = 0;
const ARRAY_MODE = 1;

fn appendSlice(list: *std.ArrayList(u8), buf: []const u8, max_value_len: usize) !void {
    const new_len = std.math.add(usize, list.items.len, buf.len) catch return error.ValueTooLong;
    if (new_len > max_value_len) return error.ValueTooLong;
    try list.appendSlice(buf);
}

/// For the slice you get from a `Token.number` or `Token.allocated_number`,
/// this function returns true if the number doesn't contain any fraction or exponent components, and is not `-0`.
/// Note, the numeric value encoded by the value may still be an integer, such as `1.0`.
/// This function is meant to give a hint about whether integer parsing or float parsing should be used on the value.
/// This function will not give meaningful results on non-numeric input.
pub fn isNumberFormattedLikeAnInteger(value: []const u8) bool {
    if (std.mem.eql(u8, value, "-0")) return false;
    return std.mem.indexOfAny(u8, value, ".eE") == null;
}

test {
    _ = @import("./scanner_test.zig");
}
