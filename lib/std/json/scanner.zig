//! JSON tokenizer conforming to RFC 8259 excluding UTF-8 validation.
//! https://datatracker.ietf.org/doc/html/rfc8259
//! Supports streaming input with a low memory footprint.
//! The memory requirement is O(d) where d is the nesting depth of [] or {} containers in the input.
//! Specifically d/8 bytes are required for this purpose,
//! with some extra buffer according to the implementation of ArrayList.
//!
//! The low-level JsonScanner API reads from successive slices of inputs,
//! The JsonReader API connects a std.io.Reader to a JsonScanner.
//!
//! Notes on standards compliance:
//! * RFC 8259 requires JSON documents be valid UTF-8,
//!   but makes an allowance for systems that are "part of a closed ecosystem".
//!   I have no idea what that's supposed to mean in the context of a standard specification.
//!   This implementation does not do UTF-8 validation for simplicity (performance?) reasons,
//!   but this can be changed in a future version.
//! * RFC 8259 contradicts itself regarding whether lowercase is allowed in \u hex digits,
//!   but this is probably a bug in the spec, and it's clear that lowercase is meant to be allowed.
//!   (RFC 5234 defines HEXDIG to only allow uppercase.)
//! * When RFC 8259 refers to a "character", I assume they really mean a "unicode scalar value".
//!   See http://www.unicode.org/glossary/#unicode_scalar_value .
//! * RFC 8259 doesn't explicitly disallow unpaired surrogate halves in \u escape sequences,
//!   but vaguely implies that \u escapes are for encoding Unicode "characters" (i.e. unicode scalar values?),
//!   which would mean that unpaired surrogate halves are forbidden.
//!   By contrast ECMA-404 (a competing(/compatible?) JSON standard, which JavaScript's JSON.parse() conforms to)
//!   excplicitly allows unpaired surrogate halves.
//!   This implementation forbids unpaired surrogate halves in \u sequences.
//!   If a high surrogate half appears in a \u sequence,
//!   then a low surrogate half must immediately follow in \u notiation.

const std = @import("std");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const assert = std.debug.assert;

/// The parsing errors are divided into two categories:
///  * SyntaxError is for clearly malformed JSON documents,
///    such as giving an input document that isn't JSON at all.
///  * UnexpectedEndOfInput is for signaling that everything's been
///    valid so far, but the input appears to be truncated for some reason.
/// Note that a completely empty (or whitespace-only) input will give UnexpectedEndOfInput.
pub const JsonError = error{ SyntaxError, UnexpectedEndOfInput };

/// Calls JsonReader() with default_buffer_size.
pub fn jsonReader(allocator: Allocator, reader: anytype) JsonReader(default_buffer_size, @TypeOf(reader)) {
    return JsonReader(default_buffer_size, @TypeOf(reader)).init(allocator, reader);
}
/// Used by jsonReader().
pub const default_buffer_size = 0x1000;

/// The tokens emitted by JsonScanner and JsonReader .next*() functions follow this grammar:
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
///  <number> = <it depends. see below>
///  <string> = <it depends. see below>
///
/// What you get for <number> and <string> values depends on which next*() method you call:
///
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
/// nextAlwaysAlloc():
///  <number> = .allocated_number
///  <string> = .allocated_string
///
/// nextMaybeAlloc():
///  <number> =
///    | .number
///    | .allocated_number
///  <string> = .allocated_string
///    | .string
///    | .allocated_string
///
/// For all tokens with a []const u8 or [n]u8 payload, the payload represents the content of the value.
/// For number values, this is the representation of the number exactly as it appears in the input.
/// For strings, this is the content of the string after resolving escape sequences.
///
/// For .allocated_number and .allocated_string, the []const u8 payloads are allocations made with the given allocator.
/// You are responsible for managing that memory. JsonReader.deinit() does *not* free those allocations.
///
/// The .partial_* tokens indicate that a value spans multiple input buffers or that a string contains escape sequences.
/// To get a complete value in memory, you need to concatenate the values yourself.
/// Calling nextAlwaysAlloc() or nextMaybeAlloc() does this for you, and returns an .allocated_* token with the result.
///
/// For tokens with a []const u8 payload other than .allocated_number and .allocated_string,
/// the payload is a slice into the current input buffer.
/// The memory may become undefined during the next call to JsonReader.next*() or JsonScanner.feedInput().
/// To keep the value persistently, it recommended to make a copy or to use JsonReader.nextAlwaysAlloc(),
/// which makes a copy for you.
///
/// Note that .number and .string tokens that follow .partial_* tokens may have 0 length to indicate that
/// the previously partial value is completed with no additional bytes.
/// (This can happen when the break between input buffers happens to land on the exact end of a value. E.g. "[1234", "]".)
///
/// The recommended strategy for using the different next*() methods is something like this:
///  * When you're expecting an object key, use nextMaybeAlloc().
///    You usually don't need a copy of the key string to persist; you just need to check which field it is.
///    In the case that the key happens to require an allocation, just free it immediately afterward.
///  * When you're expecting a meaningful string value (such as on the right of a `:`), use nextAlwaysAlloc().
///    The reason you're parsing a json document is probably to get this value, so you want it to persist through the parsing process.
///  * When you're expecting a meaningful number value, use nextMaybeAlloc().
///    You're probably going to be parsing the string representation of the number into a numeric representation,
///    so you need the complete string representation only temporarily.
///  * When you're skipping an unrecognized value, use next().
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
    allocated_number: []const u8,

    string: []const u8,
    partial_string: []const u8,
    partial_string_escaped_1: [1]u8,
    partial_string_escaped_2: [2]u8,
    partial_string_escaped_3: [3]u8,
    partial_string_escaped_4: [4]u8,
    allocated_string: []const u8,

    end_of_document,
};

/// JsonReader connects a std.io.Reader to a JsonScanner.
/// All next*() methods here handle BufferUnderrun from JsonScanner, and then read from the reader.
pub fn JsonReader(comptime buffer_size: usize, comptime ReaderType: type) type {
    return struct {
        scanner: JsonScanner,
        reader: ReaderType,

        buffer: [buffer_size]u8 = undefined,

        /// The allocator is only used to track [] and {} nesting levels.
        pub fn init(allocator: Allocator, reader: ReaderType) @This() {
            return .{
                .scanner = JsonScanner.initStreaming(allocator),
                .reader = reader,
            };
        }
        pub fn deinit(self: *@This()) void {
            self.scanner.deinit();
            self.* = undefined;
        }

        /// See Token for documentation of this function.
        pub fn nextAlwaysAlloc(self: *@This(), allocator: Allocator, max_value_len: usize) (ReaderType.Error || JsonError || Allocator.Error || error{ValueTooLong})!Token {
            var value_list = ArrayList(u8).init(allocator);
            errdefer {
                value_list.deinit();
            }
            while (true) {
                return nextIntoArrayList(&self.scanner, &value_list, max_value_len, .always) catch |err| switch (err) {
                    error.BufferUnderrun => {
                        try self.refillBuffer();
                        continue;
                    },
                    else => |other_err| return other_err,
                };
            }
        }
        /// See Token for documentation of this function.
        pub fn nextMaybeAlloc(self: *@This(), allocator: Allocator, max_value_len: usize) (ReaderType.Error || JsonError || Allocator.Error || error{ValueTooLong})!Token {
            var value_list = ArrayList(u8).init(allocator);
            errdefer {
                value_list.deinit();
            }
            while (true) {
                return nextIntoArrayList(&self.scanner, &value_list, max_value_len, .maybe) catch |err| switch (err) {
                    error.BufferUnderrun => {
                        try self.refillBuffer();
                        continue;
                    },
                    else => |other_err| return other_err,
                };
            }
        }
        /// See Token for documentation of this function.
        pub fn next(self: *@This()) (ReaderType.Error || JsonError || Allocator.Error)!Token {
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

/// JsonScanner is the lowest level API in this package.
/// This scanner can emit partial tokens and only allocates memory as needed to track [] and {} nesting.
/// The input to this class is a sequence of input buffers that you must supply one at a time.
/// Call feedInput() with the first buffer, then call next() repeatedly until error.BufferUnderrun is returned.
/// Then call feedInput() again and so forth.
/// Call endInput() when the last input buffer has been given to feedInput(), either immediately after calling feedInput(),
/// or when error.BufferUnderrun requests more data and there is no more.
/// Be sure to call next() after calling endInput() until .end_of_document has been returned.
pub const JsonScanner = struct {
    state: State = .value,
    string_is_object_key: bool = false,
    stack: BitStack,
    value_start: usize = undefined,
    unicode_code_point: u21 = undefined,

    input: []const u8 = "",
    cursor: usize = 0,
    is_end_of_input: bool = false,

    /// The allocator is only used to track [] and {} nesting levels.
    pub fn initStreaming(allocator: Allocator) @This() {
        return .{
            .stack = BitStack.init(allocator),
        };
    }
    /// Use this if your input is a single slice.
    /// This is effectively equivalent to:
    /// * initStreaming(allocator);
    /// * feedInput(complete_input);
    /// * endInput()
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

    /// Call this whenever you get error.BufferUnderrun from next().
    /// When there is no more input to provide, call endInput().
    pub fn feedInput(self: *@This(), input: []const u8) void {
        assert(self.cursor == self.input.len); // Not done with the last input slice.
        self.input = input;
        self.cursor = 0;
        self.value_start = 0;
    }
    /// Call this when you will no longer call feedInput() anymore.
    /// This can be called either immediately after the last feedInput(),
    /// or at any time afterward, such as when getting error.BufferUnderrun from next().
    /// Don't forget to call next() after endInput() until you get .end_of_document.
    pub fn endInput(self: *@This()) void {
        self.is_end_of_input = true;
    }

    /// See Token for more documentation of this function.
    /// This function is only available after endInput() (or initCompleteInput()) has been called.
    pub fn nextAlwaysAlloc(self: *@This(), allocator: Allocator, max_value_len: usize) (JsonError || Allocator.Error || error{ValueTooLong})!Token {
        assert(self.is_end_of_input); // This function is not available in streaming mode.

        var value_list = ArrayList(u8).init(allocator);
        errdefer {
            value_list.deinit();
        }
        return nextIntoArrayList(self, &value_list, max_value_len, .always);
    }
    /// See Token for documentation of this function.
    /// This function is only available after endInput() (or initCompleteInput()) has been called.
    pub fn nextMaybeAlloc(self: *@This(), allocator: Allocator, max_value_len: usize) (JsonError || Allocator.Error || error{ValueTooLong})!Token {
        assert(self.is_end_of_input); // This function is not available in streaming mode.

        var value_list = ArrayList(u8).init(allocator);
        errdefer {
            value_list.deinit();
        }
        return nextIntoArrayList(self, &value_list, max_value_len, .maybe);
    }

    /// See Token for documentation of this function.
    pub fn next(self: *@This()) (Allocator.Error || JsonError || error{BufferUnderrun})!Token {
        state_loop: while (true) {
            switch (self.state) {
                .value => {
                    self.skipWhitespace();
                    try self.expectMoreContent();
                    const c = self.input[self.cursor];
                    switch (c) {
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
                    self.skipWhitespace();
                    if (self.cursor >= self.input.len) {
                        // End of buffer.
                        if (self.is_end_of_input) {
                            // End of everything.
                            if (self.stack.bit_len == 0) {
                                // We did it!
                                return .end_of_document;
                            }
                            return error.UnexpectedEndOfInput;
                        }
                        return error.BufferUnderrun;
                    }
                    if (self.stack.bit_len == 0) return error.SyntaxError;

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
                    self.skipWhitespace();
                    try self.expectMoreContent();
                    const c = self.input[self.cursor];
                    switch (c) {
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
                    self.skipWhitespace();
                    try self.expectMoreContent();
                    const c = self.input[self.cursor];
                    switch (c) {
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
                    self.skipWhitespace();
                    try self.expectMoreContent();
                    const c = self.input[self.cursor];
                    switch (c) {
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
                    const c = self.input[self.cursor];
                    switch (c) {
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
                    const c = self.input[self.cursor];
                    switch (c) {
                        '1'...'9' => {
                            self.cursor += 1;
                            self.state = .number_int;
                            continue :state_loop;
                        },
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
                        const c = self.input[self.cursor];
                        switch (c) {
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
                    try self.expectMoreContent();
                    const c = self.input[self.cursor];
                    switch (c) {
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
                        const c = self.input[self.cursor];
                        switch (c) {
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
                    const c = self.input[self.cursor];
                    switch (c) {
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
                    const c = self.input[self.cursor];
                    switch (c) {
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
                        const c = self.input[self.cursor];
                        switch (c) {
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
                        const c = self.input[self.cursor];
                        switch (c) {
                            0...0x1f => return error.SyntaxError,
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
                            // Here is where we might put UTF-8 validation if we wanted to.
                            else => continue,
                        }
                    }
                    if (self.is_end_of_input) return error.UnexpectedEndOfInput;
                    const slice = self.takeValueSlice();
                    if (slice.len > 0) return Token{ .partial_string = slice };
                    return error.BufferUnderrun;
                },
                .string_backslash => {
                    try self.expectMoreContent();
                    const c = self.input[self.cursor];
                    switch (c) {
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
                    try self.expectMoreContent();
                    const c = self.input[self.cursor];
                    switch (c) {
                        '0'...'9' => {
                            self.unicode_code_point = @as(u21, c - '0') << 12;
                        },
                        'A'...'F' => {
                            self.unicode_code_point = @as(u21, c - 'A' + 10) << 12;
                        },
                        'a'...'f' => {
                            self.unicode_code_point = @as(u21, c - 'a' + 10) << 12;
                        },
                        else => return error.SyntaxError,
                    }
                    self.cursor += 1;
                    self.state = .string_backslash_u_1;
                    continue :state_loop;
                },
                .string_backslash_u_1 => {
                    try self.expectMoreContent();
                    const c = self.input[self.cursor];
                    switch (c) {
                        '0'...'9' => {
                            self.unicode_code_point |= @as(u21, c - '0') << 8;
                        },
                        'A'...'F' => {
                            self.unicode_code_point |= @as(u21, c - 'A' + 10) << 8;
                        },
                        'a'...'f' => {
                            self.unicode_code_point |= @as(u21, c - 'a' + 10) << 8;
                        },
                        else => return error.SyntaxError,
                    }
                    self.cursor += 1;
                    self.state = .string_backslash_u_2;
                    continue :state_loop;
                },
                .string_backslash_u_2 => {
                    try self.expectMoreContent();
                    const c = self.input[self.cursor];
                    switch (c) {
                        '0'...'9' => {
                            self.unicode_code_point |= @as(u21, c - '0') << 4;
                        },
                        'A'...'F' => {
                            self.unicode_code_point |= @as(u21, c - 'A' + 10) << 4;
                        },
                        'a'...'f' => {
                            self.unicode_code_point |= @as(u21, c - 'a' + 10) << 4;
                        },
                        else => return error.SyntaxError,
                    }
                    self.cursor += 1;
                    self.state = .string_backslash_u_3;
                    continue :state_loop;
                },
                .string_backslash_u_3 => {
                    try self.expectMoreContent();
                    const c = self.input[self.cursor];
                    switch (c) {
                        '0'...'9' => {
                            self.unicode_code_point |= c - '0';
                        },
                        'A'...'F' => {
                            self.unicode_code_point |= c - 'A' + 10;
                        },
                        'a'...'f' => {
                            self.unicode_code_point |= c - 'a' + 10;
                        },
                        else => return error.SyntaxError,
                    }
                    self.cursor += 1;
                    switch (self.unicode_code_point) {
                        0xD800...0xDBFF => {
                            // High surrogate half.
                            self.unicode_code_point = 0x10000 | (self.unicode_code_point << 10);
                            self.state = .string_surrogate_half;
                            continue :state_loop;
                        },
                        0xDC00...0xDFFF => return error.SyntaxError, // Unexpected low surrogate half.
                        else => {
                            // Code point from a single UTF-16 code unit.
                            self.value_start = self.cursor;
                            self.state = .string;
                            return self.partialStringCodepoint();
                        },
                    }
                },
                .string_surrogate_half => {
                    try self.expectMoreContent();
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
                    try self.expectMoreContent();
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
                    try self.expectMoreContent();
                    switch (self.input[self.cursor]) {
                        'D', 'd' => {
                            self.cursor += 1;
                            self.state = .string_surrogate_half_backslash_u_1;
                            continue :state_loop;
                        },
                        else => return error.SyntaxError, // Expected low surrogate half.
                    }
                },
                .string_surrogate_half_backslash_u_1 => {
                    try self.expectMoreContent();
                    const c = self.input[self.cursor];
                    switch (c) {
                        'C'...'F' => {
                            self.cursor += 1;
                            self.unicode_code_point |= @as(u21, c - 'C') << 8;
                            self.state = .string_surrogate_half_backslash_u_2;
                            continue :state_loop;
                        },
                        'c'...'f' => {
                            self.cursor += 1;
                            self.unicode_code_point |= @as(u21, c - 'c') << 8;
                            self.state = .string_surrogate_half_backslash_u_2;
                            continue :state_loop;
                        },
                        else => return error.SyntaxError, // Expected low surrogate half.
                    }
                },
                .string_surrogate_half_backslash_u_2 => {
                    try self.expectMoreContent();
                    const c = self.input[self.cursor];
                    switch (c) {
                        '0'...'9' => {
                            self.cursor += 1;
                            self.unicode_code_point |= @as(u21, c - '0') << 4;
                            self.state = .string_surrogate_half_backslash_u_3;
                            continue :state_loop;
                        },
                        'A'...'F' => {
                            self.cursor += 1;
                            self.unicode_code_point |= @as(u21, c - 'A' + 10) << 4;
                            self.state = .string_surrogate_half_backslash_u_3;
                            continue :state_loop;
                        },
                        'a'...'f' => {
                            self.cursor += 1;
                            self.unicode_code_point |= @as(u21, c - 'a' + 10) << 4;
                            self.state = .string_surrogate_half_backslash_u_3;
                            continue :state_loop;
                        },
                        else => return error.SyntaxError,
                    }
                },
                .string_surrogate_half_backslash_u_3 => {
                    try self.expectMoreContent();
                    const c = self.input[self.cursor];
                    switch (c) {
                        '0'...'9' => {
                            self.unicode_code_point |= c - '0';
                        },
                        'A'...'F' => {
                            self.unicode_code_point |= c - 'A' + 10;
                        },
                        'a'...'f' => {
                            self.unicode_code_point |= c - 'a' + 10;
                        },
                        else => return error.SyntaxError,
                    }
                    self.cursor += 1;
                    self.value_start = self.cursor;
                    self.state = .string;
                    return self.partialStringCodepoint();
                },

                .literal_t => {
                    try self.expectMoreContent();
                    switch (self.input[self.cursor]) {
                        'r' => {
                            self.cursor += 1;
                            self.state = .literal_tr;
                            continue :state_loop;
                        },
                        else => return error.SyntaxError,
                    }
                },
                .literal_tr => {
                    try self.expectMoreContent();
                    switch (self.input[self.cursor]) {
                        'u' => {
                            self.cursor += 1;
                            self.state = .literal_tru;
                            continue :state_loop;
                        },
                        else => return error.SyntaxError,
                    }
                },
                .literal_tru => {
                    try self.expectMoreContent();
                    switch (self.input[self.cursor]) {
                        'e' => {
                            self.cursor += 1;
                            self.state = .post_value;
                            return .true;
                        },
                        else => return error.SyntaxError,
                    }
                },
                .literal_f => {
                    try self.expectMoreContent();
                    switch (self.input[self.cursor]) {
                        'a' => {
                            self.cursor += 1;
                            self.state = .literal_fa;
                            continue :state_loop;
                        },
                        else => return error.SyntaxError,
                    }
                },
                .literal_fa => {
                    try self.expectMoreContent();
                    switch (self.input[self.cursor]) {
                        'l' => {
                            self.cursor += 1;
                            self.state = .literal_fal;
                            continue :state_loop;
                        },
                        else => return error.SyntaxError,
                    }
                },
                .literal_fal => {
                    try self.expectMoreContent();
                    switch (self.input[self.cursor]) {
                        's' => {
                            self.cursor += 1;
                            self.state = .literal_fals;
                            continue :state_loop;
                        },
                        else => return error.SyntaxError,
                    }
                },
                .literal_fals => {
                    try self.expectMoreContent();
                    switch (self.input[self.cursor]) {
                        'e' => {
                            self.cursor += 1;
                            self.state = .post_value;
                            return .false;
                        },
                        else => return error.SyntaxError,
                    }
                },
                .literal_n => {
                    try self.expectMoreContent();
                    switch (self.input[self.cursor]) {
                        'u' => {
                            self.cursor += 1;
                            self.state = .literal_nu;
                            continue :state_loop;
                        },
                        else => return error.SyntaxError,
                    }
                },
                .literal_nu => {
                    try self.expectMoreContent();
                    switch (self.input[self.cursor]) {
                        'l' => {
                            self.cursor += 1;
                            self.state = .literal_nul;
                            continue :state_loop;
                        },
                        else => return error.SyntaxError,
                    }
                },
                .literal_nul => {
                    try self.expectMoreContent();
                    switch (self.input[self.cursor]) {
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

    fn expectMoreContent(self: *const @This()) !void {
        if (self.cursor < self.input.len) return;
        if (self.is_end_of_input) return error.UnexpectedEndOfInput;
        return error.BufferUnderrun;
    }

    fn skipWhitespace(self: *@This()) void {
        while (self.cursor < self.input.len) : (self.cursor += 1) {
            const c = self.input[self.cursor];
            switch (c) {
                // Whitespace
                ' ', '\t', '\n', '\r' => continue,
                else => return,
            }
        }
    }

    fn takeValueSlice(self: *@This()) []const u8 {
        const slice = self.input[self.value_start..self.cursor];
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

    fn partialStringCodepoint(self: *@This()) Token {
        const code_point = self.unicode_code_point;
        self.unicode_code_point = undefined;
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

const BitStack = struct {
    bytes: std.ArrayList(u8),
    bit_len: u32 = 0,

    pub fn init(allocator: Allocator) @This() {
        return .{
            .bytes = std.ArrayList(u8).init(allocator),
        };
    }

    pub fn deinit(self: *@This()) void {
        self.bytes.deinit();
        self.* = undefined;
    }

    pub fn push(self: *@This(), b: u1) Allocator.Error!void {
        const byte_index = self.bit_len >> 3;
        const bit_index = @intCast(u3, self.bit_len & 7);

        if (self.bytes.items.len <= byte_index) {
            try self.bytes.append(0);
        }

        self.bytes.items[byte_index] &= ~(@as(u8, 1) << bit_index);
        self.bytes.items[byte_index] |= @as(u8, b) << bit_index;

        self.bit_len += 1;
    }

    pub fn peek(self: *const @This()) u1 {
        const byte_index = (self.bit_len - 1) >> 3;
        const bit_index = @intCast(u3, (self.bit_len - 1) & 7);
        return @intCast(u1, (self.bytes.items[byte_index] >> bit_index) & 1);
    }

    pub fn pop(self: *@This()) u1 {
        const b = self.peek();
        self.bit_len -= 1;
        return b;
    }
};

fn nextIntoArrayList(scanner: *JsonScanner, value_list: *ArrayList(u8), max_value_len: usize, when_to_alloc: enum { maybe, always }) !Token {
    while (true) {
        const token = try scanner.next();
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
                if (when_to_alloc == .maybe and value_list.items.len == 0) {
                    // No alloc necessary.
                    return token;
                }
                try appendSlice(value_list, slice, max_value_len);
                return Token{ .allocated_number = try value_list.toOwnedSlice() };
            },
            .string => |slice| {
                if (when_to_alloc == .maybe and value_list.items.len == 0) {
                    // No alloc necessary.
                    return token;
                }
                try appendSlice(value_list, slice, max_value_len);
                return Token{ .allocated_string = try value_list.toOwnedSlice() };
            },

            // Passthrough simple tokens.
            .object_begin,
            .object_end,
            .array_begin,
            .array_end,
            .true,
            .false,
            .null,
            .end_of_document,
            => return token,

            .allocated_number, .allocated_string => unreachable,
        }
    }
}

fn appendSlice(list: *std.ArrayList(u8), buf: []const u8, max_value_len: usize) !void {
    const new_len = std.math.add(usize, list.items.len, buf.len) catch return error.ValueTooLong;
    if (new_len > max_value_len) return error.ValueTooLong;
    try list.appendSlice(buf);
}

/// Scan the input and check for malformed JSON.
/// On SyntaxError or UnexpectedEndOfInput, returns false.
/// Returns any errors from the allocator as errors, which can be caused by extreme nesting depth in the input.
pub fn validate(allocator: Allocator, s: []const u8) Allocator.Error!bool {
    var scanner = JsonScanner.initCompleteInput(allocator, s);
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

test {
    _ = @import("./scanner_test.zig");
}
