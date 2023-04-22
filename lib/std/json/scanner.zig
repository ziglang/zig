//! JSON tokenizer conforming to https://datatracker.ietf.org/doc/html/rfc8259
//! excluding UTF-8 validation.
//! Supports streaming input with a low memory footprint.
//! The memory requirement is O(d) where d is the nesting depth of [] or {} containers in the input.
//! Specifically d/8 bytes are allocated for this purpose,
//! with some extra buffer according to the implementation of ArrayList.
//!
//! This API supports arbitrarily long string and number values in the input
//! and can emit partially parsed values in order to support this.
//!
//! Notes on standards compliance:
//! * RFC 8259 requires JSON documents be valid UTF-8,
//!   but makes an allowance for systems that are "part of a closed ecosystem".
//!   I have no idea what that's supposed to mean in the context of a standard specification.
//!   This implementation does not do UTF-8 validation for simplicity (performance?) reasons,
//!   but this can be changed in a future version.
//! * When RFC 8259 refers to a "character", I assume they really mean a "code point".
//!   (Unicode does not define what a "character" is.)
//! * RFC 8259 contradicts itself regarding whether lowercase is allowed in \u hex digits,
//!   but it seems like every implementation agrees it should be allowed.
//!   (RFC 5234 defines HEXDIG to only allow uppercase,
//!    but RFC 8259 says in pros that lowercase is also allowed.)
//!   This implementation also allows it.
//! * RFC 8259 doesn't explicitly disallow unpaired surrogate halves in \u escape sequences,
//!   but vaguely implies that \u escapes are for encoding Unicode code points,
//!   which would mean that unpaired surrogate halves are forbidden.
//!   This implementation forbids unpaired surrogate halves in \u sequences.

const std = @import("std"); // TODO: change to ../std.zig

const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

pub const JsonScanner = struct {
    state: State = .value,
    string_is_object_key: bool = false,
    stack: BitStack,
    value_start: u32 = undefined,
    value_end_offset_back: u1 = 0,
    unicode_code_point: u21 = undefined,

    input: []const u8 = "",
    cursor: u32 = 0,
    end_of_input: bool = false,

    pub fn init(allocator: Allocator) @This() {
        return .{
            .stack = BitStack.init(allocator),
        };
    }
    pub fn deinit(self: *@This()) void {
        self.stack.deinit();
        self.* = undefined;
    }

    /// input.len must be <= 0xffffffff
    pub fn feedInput(self: *@This(), input: []const u8) void {
        assert(self.cursor == self.input.len); // Not done with the last input slice.
        assert(input.len <= 0xffffffff);
        self.input = input;
        self.cursor = 0;
        self.value_start = 0;
    }
    pub fn endInput(self: *@This()) void {
        self.end_of_input = true;
    }

    /// Call this immediately after getting a NextResult with a u32 payload.
    /// The length of the given buffer should be exactly the u32 from the NextResult.
    pub fn readValue(self: *const @This(), out_buffer: []u8) void {
        const end = self.cursor - self.value_end_offset_back;
        const start = end - out_buffer.len;
        std.mem.copy(u8, out_buffer, self.input[start..end]);
    }

    /// The events emitted follow this grammar:
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
    ///  <number> = ( .partial_number )* .number
    ///  <string> = ( <partial_string> )* .string
    ///  <partial_string> =
    ///    | .partial_string
    ///    | .partial_string_escaped_1
    ///    | .partial_string_escaped_2
    ///    | .partial_string_escaped_3
    ///    | .partial_string_escaped_4
    ///
    /// The .partial_* events indicate that a value spans multiple input buffers or that a string contains escape sequences.
    /// To get a complete value in memory, you need to concatenate the values yourself.
    /// (You'll want to do your own limiting on the memory used for this purpose.)
    ///
    /// For tags with a u32 payload, the payload represents the length of the value in bytes.
    /// Call readValue(buffer[0..len]) to receive a copy of the value bytes.
    /// For number values, this is the representation of the number exactly as it appears in the JSON input.
    /// For strings, this is the content of the string after resolving escape sequences.
    /// For tags with [n]u8 payloads, the payload represents the bytes after resolving escape sequences.
    ///
    /// Note that .number and .string payloads may be 0 to indicate that the previously partial value
    /// is completed with no additional bytes. (This can happen when the break between input buffers
    /// happens to land on the exact end of a value. E.g. "[1234", ", 5678]".)
    const NextResult = union(enum) {
        object_begin,
        object_end,
        array_begin,
        array_end,

        true,
        false,
        null,

        number: u32,
        partial_number: u32,

        string: u32,
        partial_string: u32,
        partial_string_escaped_1: [1]u8,
        partial_string_escaped_2: [2]u8,
        partial_string_escaped_3: [3]u8,
        partial_string_escaped_4: [4]u8,

        end_of_document,
    };

    pub fn next(self: *@This()) !NextResult {
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
                            self.state = .number_int;
                            continue :state_loop;
                        },
                        '0' => {
                            self.value_start = self.cursor;
                            self.state = .number_leading_zero;
                            continue :state_loop;
                        },
                        '-' => {
                            self.value_start = self.cursor;
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
                        if (self.end_of_input) {
                            // End of everything.
                            if (self.stack.bit_len == 0) {
                                // We did it!
                                return .end_of_document;
                            }
                            return error.UnexpectedEndOfDocument;
                        }
                        return error.BufferUnderrun;
                    }
                    if (self.stack.bit_len == 0) return error.ExpectedEndOfDocument;

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
                            return NextResult{ .number = self.takeValueLen() };
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
                                return NextResult{ .number = self.takeValueLen() };
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
                                return NextResult{ .number = self.takeValueLen() };
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
                                return NextResult{ .number = self.takeValueLen() };
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
                                const result = NextResult{ .string = self.takeValueLen() };
                                self.cursor += 1;
                                self.value_end_offset_back = 1;
                                self.state = .post_value;
                                return result;
                            },
                            '\\' => {
                                const partial_len = self.takeValueLen();
                                self.cursor += 1;
                                self.value_end_offset_back = 1;
                                self.state = .string_backslash;
                                if (partial_len > 0) return NextResult{ .partial_string = partial_len };
                                continue :state_loop;
                            },
                            // Here is where we might put UTF-8 validation if we wanted to.
                            else => continue,
                        }
                    }
                    if (self.end_of_input) return error.UnexpectedEndOfDocument;
                    return NextResult{ .partial_string = self.takeValueLen() };
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
                            return NextResult{ .partial_string_escaped_1 = [_]u8{0x08} };
                        },
                        'f' => {
                            self.cursor += 1;
                            self.value_start = self.cursor;
                            self.state = .string;
                            return NextResult{ .partial_string_escaped_1 = [_]u8{0x0c} };
                        },
                        'n' => {
                            self.cursor += 1;
                            self.value_start = self.cursor;
                            self.state = .string;
                            return NextResult{ .partial_string_escaped_1 = [_]u8{'\n'} };
                        },
                        'r' => {
                            self.cursor += 1;
                            self.value_start = self.cursor;
                            self.state = .string;
                            return NextResult{ .partial_string_escaped_1 = [_]u8{'\r'} };
                        },
                        't' => {
                            self.cursor += 1;
                            self.value_start = self.cursor;
                            self.state = .string;
                            return NextResult{ .partial_string_escaped_1 = [_]u8{'\t'} };
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
                        'B', 'b' => {
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
        if (self.end_of_input) return error.UnexpectedEndOfDocument;
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

    fn takeValueLen(self: *@This()) u32 {
        const value_len = self.cursor - self.value_start;
        self.value_start = self.cursor;
        self.value_end_offset_back = 0;
        return value_len;
    }

    fn endOfBufferInNumber(self: *@This(), allow_end: bool) !NextResult {
        const value_len = self.takeValueLen();
        if (self.end_of_input) {
            if (!allow_end) return error.UnexpectedEndOfDocument;
            self.state = .post_value;
            return NextResult{ .number = value_len };
        }
        if (value_len == 0) return error.BufferUnderrun;
        return NextResult{ .partial_number = value_len };
    }

    fn partialStringCodepoint(self: *@This()) NextResult {
        const code_point = self.unicode_code_point;
        self.unicode_code_point = undefined;
        var buf: [4]u8 = undefined;
        switch (std.unicode.utf8Encode(code_point, &buf) catch unreachable) {
            1 => return NextResult{ .partial_string_escaped_1 = buf[0..1].* },
            2 => return NextResult{ .partial_string_escaped_2 = buf[0..2].* },
            3 => return NextResult{ .partial_string_escaped_3 = buf[0..3].* },
            4 => return NextResult{ .partial_string_escaped_4 = buf[0..4].* },
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

test "asdf" {
    var scanner = JsonScanner.init(std.testing.allocator);
    defer scanner.deinit();

    scanner.feedInput("0");
    //scanner.endInput();
    _ = try scanner.next();
    _ = try scanner.next();
}
