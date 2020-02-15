// JSON parser conforming to RFC8259.
//
// https://tools.ietf.org/html/rfc8259

const std = @import("std.zig");
const debug = std.debug;
const assert = debug.assert;
const testing = std.testing;
const mem = std.mem;
const maxInt = std.math.maxInt;

pub const WriteStream = @import("json/write_stream.zig").WriteStream;

const StringEscapes = union(enum) {
    None,

    Some: struct {
        size_diff: isize,
    },
};

/// A single token slice into the parent string.
///
/// Use `token.slice()` on the input at the current position to get the current slice.
pub const Token = union(enum) {
    ObjectBegin,
    ObjectEnd,
    ArrayBegin,
    ArrayEnd,
    String: struct {
        /// How many bytes the token is.
        count: usize,

        /// Whether string contains an escape sequence and cannot be zero-copied
        escapes: StringEscapes,

        pub fn decodedLength(self: @This()) usize {
            return self.count +% switch (self.escapes) {
                .None => 0,
                .Some => |s| @bitCast(usize, s.size_diff),
            };
        }

        /// Slice into the underlying input string.
        pub fn slice(self: @This(), input: []const u8, i: usize) []const u8 {
            return input[i - self.count .. i];
        }
    },
    Number: struct {
        /// How many bytes the token is.
        count: usize,

        /// Whether number is simple and can be represented by an integer (i.e. no `.` or `e`)
        is_integer: bool,

        /// Slice into the underlying input string.
        pub fn slice(self: @This(), input: []const u8, i: usize) []const u8 {
            return input[i - self.count .. i];
        }
    },
    True,
    False,
    Null,
};

/// A small streaming JSON parser. This accepts input one byte at a time and returns tokens as
/// they are encountered. No copies or allocations are performed during parsing and the entire
/// parsing state requires ~40-50 bytes of stack space.
///
/// Conforms strictly to RFC8529.
///
/// For a non-byte based wrapper, consider using TokenStream instead.
pub const StreamingParser = struct {
    // Current state
    state: State,
    // How many bytes we have counted for the current token
    count: usize,
    // What state to follow after parsing a string (either property or value string)
    after_string_state: State,
    // What state to follow after parsing a value (either top-level or value end)
    after_value_state: State,
    // If we stopped now, would the complete parsed string to now be a valid json string
    complete: bool,
    // Current token flags to pass through to the next generated, see Token.
    string_escapes: StringEscapes,
    // When in .String states, was the previous character a high surrogate?
    string_last_was_high_surrogate: bool,
    // Used inside of StringEscapeHexUnicode* states
    string_unicode_codepoint: u21,
    // The first byte needs to be stored to validate 3- and 4-byte sequences.
    sequence_first_byte: u8 = undefined,
    // When in .Number states, is the number a (still) valid integer?
    number_is_integer: bool,

    // Bit-stack for nested object/map literals (max 255 nestings).
    stack: u256,
    stack_used: u8,

    const object_bit = 0;
    const array_bit = 1;
    const max_stack_size = maxInt(u8);

    pub fn init() StreamingParser {
        var p: StreamingParser = undefined;
        p.reset();
        return p;
    }

    pub fn reset(p: *StreamingParser) void {
        p.state = .TopLevelBegin;
        p.count = 0;
        // Set before ever read in main transition function
        p.after_string_state = undefined;
        p.after_value_state = .ValueEnd; // handle end of values normally
        p.stack = 0;
        p.stack_used = 0;
        p.complete = false;
        p.string_escapes = undefined;
        p.string_last_was_high_surrogate = undefined;
        p.string_unicode_codepoint = undefined;
        p.number_is_integer = undefined;
    }

    pub const State = enum {
        // These must be first with these explicit values as we rely on them for indexing the
        // bit-stack directly and avoiding a branch.
        ObjectSeparator = 0,
        ValueEnd = 1,

        TopLevelBegin,
        TopLevelEnd,

        ValueBegin,
        ValueBeginNoClosing,

        String,
        StringUtf8Byte2Of2,
        StringUtf8Byte2Of3,
        StringUtf8Byte3Of3,
        StringUtf8Byte2Of4,
        StringUtf8Byte3Of4,
        StringUtf8Byte4Of4,
        StringEscapeCharacter,
        StringEscapeHexUnicode4,
        StringEscapeHexUnicode3,
        StringEscapeHexUnicode2,
        StringEscapeHexUnicode1,

        Number,
        NumberMaybeDotOrExponent,
        NumberMaybeDigitOrDotOrExponent,
        NumberFractionalRequired,
        NumberFractional,
        NumberMaybeExponent,
        NumberExponent,
        NumberExponentDigitsRequired,
        NumberExponentDigits,

        TrueLiteral1,
        TrueLiteral2,
        TrueLiteral3,

        FalseLiteral1,
        FalseLiteral2,
        FalseLiteral3,
        FalseLiteral4,

        NullLiteral1,
        NullLiteral2,
        NullLiteral3,

        // Only call this function to generate array/object final state.
        pub fn fromInt(x: var) State {
            debug.assert(x == 0 or x == 1);
            const T = @TagType(State);
            return @intToEnum(State, @intCast(T, x));
        }
    };

    pub const Error = error{
        InvalidTopLevel,
        TooManyNestedItems,
        TooManyClosingItems,
        InvalidValueBegin,
        InvalidValueEnd,
        UnbalancedBrackets,
        UnbalancedBraces,
        UnexpectedClosingBracket,
        UnexpectedClosingBrace,
        InvalidNumber,
        InvalidSeparator,
        InvalidLiteral,
        InvalidEscapeCharacter,
        InvalidUnicodeHexSymbol,
        InvalidUtf8Byte,
        InvalidTopLevelTrailing,
        InvalidControlCharacter,
    };

    /// Give another byte to the parser and obtain any new tokens. This may (rarely) return two
    /// tokens. token2 is always null if token1 is null.
    ///
    /// There is currently no error recovery on a bad stream.
    pub fn feed(p: *StreamingParser, c: u8, token1: *?Token, token2: *?Token) Error!void {
        token1.* = null;
        token2.* = null;
        p.count += 1;

        // unlikely
        if (try p.transition(c, token1)) {
            _ = try p.transition(c, token2);
        }
    }

    // Perform a single transition on the state machine and return any possible token.
    fn transition(p: *StreamingParser, c: u8, token: *?Token) Error!bool {
        switch (p.state) {
            .TopLevelBegin => switch (c) {
                '{' => {
                    p.stack <<= 1;
                    p.stack |= object_bit;
                    p.stack_used += 1;

                    p.state = .ValueBegin;
                    p.after_string_state = .ObjectSeparator;

                    token.* = Token.ObjectBegin;
                },
                '[' => {
                    p.stack <<= 1;
                    p.stack |= array_bit;
                    p.stack_used += 1;

                    p.state = .ValueBegin;
                    p.after_string_state = .ValueEnd;

                    token.* = Token.ArrayBegin;
                },
                '-' => {
                    p.number_is_integer = true;
                    p.state = .Number;
                    p.after_value_state = .TopLevelEnd;
                    p.count = 0;
                },
                '0' => {
                    p.number_is_integer = true;
                    p.state = .NumberMaybeDotOrExponent;
                    p.after_value_state = .TopLevelEnd;
                    p.count = 0;
                },
                '1'...'9' => {
                    p.number_is_integer = true;
                    p.state = .NumberMaybeDigitOrDotOrExponent;
                    p.after_value_state = .TopLevelEnd;
                    p.count = 0;
                },
                '"' => {
                    p.state = .String;
                    p.after_value_state = .TopLevelEnd;
                    // We don't actually need the following since after_value_state should override.
                    p.after_string_state = .ValueEnd;
                    p.string_escapes = .None;
                    p.string_last_was_high_surrogate = false;
                    p.count = 0;
                },
                't' => {
                    p.state = .TrueLiteral1;
                    p.after_value_state = .TopLevelEnd;
                    p.count = 0;
                },
                'f' => {
                    p.state = .FalseLiteral1;
                    p.after_value_state = .TopLevelEnd;
                    p.count = 0;
                },
                'n' => {
                    p.state = .NullLiteral1;
                    p.after_value_state = .TopLevelEnd;
                    p.count = 0;
                },
                0x09, 0x0A, 0x0D, 0x20 => {
                    // whitespace
                },
                else => {
                    return error.InvalidTopLevel;
                },
            },

            .TopLevelEnd => switch (c) {
                0x09, 0x0A, 0x0D, 0x20 => {
                    // whitespace
                },
                else => {
                    return error.InvalidTopLevelTrailing;
                },
            },

            .ValueBegin => switch (c) {
                // NOTE: These are shared in ValueEnd as well, think we can reorder states to
                // be a bit clearer and avoid this duplication.
                '}' => {
                    // unlikely
                    if (p.stack & 1 != object_bit) {
                        return error.UnexpectedClosingBracket;
                    }
                    if (p.stack_used == 0) {
                        return error.TooManyClosingItems;
                    }

                    p.state = .ValueBegin;
                    p.after_string_state = State.fromInt(p.stack & 1);

                    p.stack >>= 1;
                    p.stack_used -= 1;

                    switch (p.stack_used) {
                        0 => {
                            p.complete = true;
                            p.state = .TopLevelEnd;
                        },
                        else => {
                            p.state = .ValueEnd;
                        },
                    }

                    token.* = Token.ObjectEnd;
                },
                ']' => {
                    if (p.stack & 1 != array_bit) {
                        return error.UnexpectedClosingBrace;
                    }
                    if (p.stack_used == 0) {
                        return error.TooManyClosingItems;
                    }

                    p.state = .ValueBegin;
                    p.after_string_state = State.fromInt(p.stack & 1);

                    p.stack >>= 1;
                    p.stack_used -= 1;

                    switch (p.stack_used) {
                        0 => {
                            p.complete = true;
                            p.state = .TopLevelEnd;
                        },
                        else => {
                            p.state = .ValueEnd;
                        },
                    }

                    token.* = Token.ArrayEnd;
                },
                '{' => {
                    if (p.stack_used == max_stack_size) {
                        return error.TooManyNestedItems;
                    }

                    p.stack <<= 1;
                    p.stack |= object_bit;
                    p.stack_used += 1;

                    p.state = .ValueBegin;
                    p.after_string_state = .ObjectSeparator;

                    token.* = Token.ObjectBegin;
                },
                '[' => {
                    if (p.stack_used == max_stack_size) {
                        return error.TooManyNestedItems;
                    }

                    p.stack <<= 1;
                    p.stack |= array_bit;
                    p.stack_used += 1;

                    p.state = .ValueBegin;
                    p.after_string_state = .ValueEnd;

                    token.* = Token.ArrayBegin;
                },
                '-' => {
                    p.number_is_integer = true;
                    p.state = .Number;
                    p.count = 0;
                },
                '0' => {
                    p.number_is_integer = true;
                    p.state = .NumberMaybeDotOrExponent;
                    p.count = 0;
                },
                '1'...'9' => {
                    p.number_is_integer = true;
                    p.state = .NumberMaybeDigitOrDotOrExponent;
                    p.count = 0;
                },
                '"' => {
                    p.state = .String;
                    p.string_escapes = .None;
                    p.string_last_was_high_surrogate = false;
                    p.count = 0;
                },
                't' => {
                    p.state = .TrueLiteral1;
                    p.count = 0;
                },
                'f' => {
                    p.state = .FalseLiteral1;
                    p.count = 0;
                },
                'n' => {
                    p.state = .NullLiteral1;
                    p.count = 0;
                },
                0x09, 0x0A, 0x0D, 0x20 => {
                    // whitespace
                },
                else => {
                    return error.InvalidValueBegin;
                },
            },

            // TODO: A bit of duplication here and in the following state, redo.
            .ValueBeginNoClosing => switch (c) {
                '{' => {
                    if (p.stack_used == max_stack_size) {
                        return error.TooManyNestedItems;
                    }

                    p.stack <<= 1;
                    p.stack |= object_bit;
                    p.stack_used += 1;

                    p.state = .ValueBegin;
                    p.after_string_state = .ObjectSeparator;

                    token.* = Token.ObjectBegin;
                },
                '[' => {
                    if (p.stack_used == max_stack_size) {
                        return error.TooManyNestedItems;
                    }

                    p.stack <<= 1;
                    p.stack |= array_bit;
                    p.stack_used += 1;

                    p.state = .ValueBegin;
                    p.after_string_state = .ValueEnd;

                    token.* = Token.ArrayBegin;
                },
                '-' => {
                    p.number_is_integer = true;
                    p.state = .Number;
                    p.count = 0;
                },
                '0' => {
                    p.number_is_integer = true;
                    p.state = .NumberMaybeDotOrExponent;
                    p.count = 0;
                },
                '1'...'9' => {
                    p.number_is_integer = true;
                    p.state = .NumberMaybeDigitOrDotOrExponent;
                    p.count = 0;
                },
                '"' => {
                    p.state = .String;
                    p.string_escapes = .None;
                    p.string_last_was_high_surrogate = false;
                    p.count = 0;
                },
                't' => {
                    p.state = .TrueLiteral1;
                    p.count = 0;
                },
                'f' => {
                    p.state = .FalseLiteral1;
                    p.count = 0;
                },
                'n' => {
                    p.state = .NullLiteral1;
                    p.count = 0;
                },
                0x09, 0x0A, 0x0D, 0x20 => {
                    // whitespace
                },
                else => {
                    return error.InvalidValueBegin;
                },
            },

            .ValueEnd => switch (c) {
                ',' => {
                    p.after_string_state = State.fromInt(p.stack & 1);
                    p.state = .ValueBeginNoClosing;
                },
                ']' => {
                    if (p.stack_used == 0) {
                        return error.UnbalancedBrackets;
                    }

                    p.state = .ValueEnd;
                    p.after_string_state = State.fromInt(p.stack & 1);

                    p.stack >>= 1;
                    p.stack_used -= 1;

                    if (p.stack_used == 0) {
                        p.complete = true;
                        p.state = .TopLevelEnd;
                    }

                    token.* = Token.ArrayEnd;
                },
                '}' => {
                    if (p.stack_used == 0) {
                        return error.UnbalancedBraces;
                    }

                    p.state = .ValueEnd;
                    p.after_string_state = State.fromInt(p.stack & 1);

                    p.stack >>= 1;
                    p.stack_used -= 1;

                    if (p.stack_used == 0) {
                        p.complete = true;
                        p.state = .TopLevelEnd;
                    }

                    token.* = Token.ObjectEnd;
                },
                0x09, 0x0A, 0x0D, 0x20 => {
                    // whitespace
                },
                else => {
                    return error.InvalidValueEnd;
                },
            },

            .ObjectSeparator => switch (c) {
                ':' => {
                    p.state = .ValueBegin;
                    p.after_string_state = .ValueEnd;
                },
                0x09, 0x0A, 0x0D, 0x20 => {
                    // whitespace
                },
                else => {
                    return error.InvalidSeparator;
                },
            },

            .String => switch (c) {
                0x00...0x1F => {
                    return error.InvalidControlCharacter;
                },
                '"' => {
                    p.state = p.after_string_state;
                    if (p.after_value_state == .TopLevelEnd) {
                        p.state = .TopLevelEnd;
                        p.complete = true;
                    }

                    token.* = .{
                        .String = .{
                            .count = p.count - 1,
                            .escapes = p.string_escapes,
                        },
                    };
                    p.string_escapes = undefined;
                    p.string_last_was_high_surrogate = undefined;
                },
                '\\' => {
                    p.state = .StringEscapeCharacter;
                    switch (p.string_escapes) {
                        .None => {
                            p.string_escapes = .{ .Some = .{ .size_diff = 0 } };
                        },
                        .Some => {},
                    }
                },
                0x20, 0x21, 0x23...0x5B, 0x5D...0x7F => {
                    // non-control ascii
                    p.string_last_was_high_surrogate = false;
                },
                0xC2...0xDF => {
                    p.state = .StringUtf8Byte2Of2;
                },
                0xE0...0xEF => {
                    p.state = .StringUtf8Byte2Of3;
                    p.sequence_first_byte = c;
                },
                0xF0...0xF4 => {
                    p.state = .StringUtf8Byte2Of4;
                    p.sequence_first_byte = c;
                },
                else => {
                    return error.InvalidUtf8Byte;
                },
            },

            .StringUtf8Byte2Of2 => switch (c >> 6) {
                0b10 => p.state = .String,
                else => return error.InvalidUtf8Byte,
            },
            .StringUtf8Byte2Of3 => {
                switch (p.sequence_first_byte) {
                    0xE0 => switch (c) {
                        0xA0...0xBF => {},
                        else => return error.InvalidUtf8Byte,
                    },
                    0xE1...0xEF => switch (c) {
                        0x80...0xBF => {},
                        else => return error.InvalidUtf8Byte,
                    },
                    else => return error.InvalidUtf8Byte,
                }
                p.state = .StringUtf8Byte3Of3;
            },
            .StringUtf8Byte3Of3 => switch (c) {
                0x80...0xBF => p.state = .String,
                else => return error.InvalidUtf8Byte,
            },
            .StringUtf8Byte2Of4 => {
                switch (p.sequence_first_byte) {
                    0xF0 => switch (c) {
                        0x90...0xBF => {},
                        else => return error.InvalidUtf8Byte,
                    },
                    0xF1...0xF3 => switch (c) {
                        0x80...0xBF => {},
                        else => return error.InvalidUtf8Byte,
                    },
                    0xF4 => switch (c) {
                        0x80...0x8F => {},
                        else => return error.InvalidUtf8Byte,
                    },
                    else => return error.InvalidUtf8Byte,
                }
                p.state = .StringUtf8Byte3Of4;
            },
            .StringUtf8Byte3Of4 => switch (c) {
                0x80...0xBF => p.state = .StringUtf8Byte4Of4,
                else => return error.InvalidUtf8Byte,
            },
            .StringUtf8Byte4Of4 => switch (c) {
                0x80...0xBF => p.state = .String,
                else => return error.InvalidUtf8Byte,
            },

            .StringEscapeCharacter => switch (c) {
                // NOTE: '/' is allowed as an escaped character but it also is allowed
                // as unescaped according to the RFC. There is a reported errata which suggests
                // removing the non-escaped variant but it makes more sense to simply disallow
                // it as an escape code here.
                //
                // The current JSONTestSuite tests rely on both of this behaviour being present
                // however, so we default to the status quo where both are accepted until this
                // is further clarified.
                '"', '\\', '/', 'b', 'f', 'n', 'r', 't' => {
                    p.string_escapes.Some.size_diff -= 1;
                    p.state = .String;
                    p.string_last_was_high_surrogate = false;
                },
                'u' => {
                    p.state = .StringEscapeHexUnicode4;
                },
                else => {
                    return error.InvalidEscapeCharacter;
                },
            },

            .StringEscapeHexUnicode4 => {
                var codepoint: u21 = undefined;
                switch (c) {
                    else => return error.InvalidUnicodeHexSymbol,
                    '0'...'9' => {
                        codepoint = c - '0';
                    },
                    'A'...'F' => {
                        codepoint = c - 'A' + 10;
                    },
                    'a'...'f' => {
                        codepoint = c - 'a' + 10;
                    },
                }
                p.state = .StringEscapeHexUnicode3;
                p.string_unicode_codepoint = codepoint << 12;
            },

            .StringEscapeHexUnicode3 => {
                var codepoint: u21 = undefined;
                switch (c) {
                    else => return error.InvalidUnicodeHexSymbol,
                    '0'...'9' => {
                        codepoint = c - '0';
                    },
                    'A'...'F' => {
                        codepoint = c - 'A' + 10;
                    },
                    'a'...'f' => {
                        codepoint = c - 'a' + 10;
                    },
                }
                p.state = .StringEscapeHexUnicode2;
                p.string_unicode_codepoint |= codepoint << 8;
            },

            .StringEscapeHexUnicode2 => {
                var codepoint: u21 = undefined;
                switch (c) {
                    else => return error.InvalidUnicodeHexSymbol,
                    '0'...'9' => {
                        codepoint = c - '0';
                    },
                    'A'...'F' => {
                        codepoint = c - 'A' + 10;
                    },
                    'a'...'f' => {
                        codepoint = c - 'a' + 10;
                    },
                }
                p.state = .StringEscapeHexUnicode1;
                p.string_unicode_codepoint |= codepoint << 4;
            },

            .StringEscapeHexUnicode1 => {
                var codepoint: u21 = undefined;
                switch (c) {
                    else => return error.InvalidUnicodeHexSymbol,
                    '0'...'9' => {
                        codepoint = c - '0';
                    },
                    'A'...'F' => {
                        codepoint = c - 'A' + 10;
                    },
                    'a'...'f' => {
                        codepoint = c - 'a' + 10;
                    },
                }
                p.state = .String;
                p.string_unicode_codepoint |= codepoint;
                if (p.string_unicode_codepoint < 0xD800 or p.string_unicode_codepoint >= 0xE000) {
                    // not part of surrogate pair
                    p.string_escapes.Some.size_diff -= @as(isize, 6 - (std.unicode.utf8CodepointSequenceLength(p.string_unicode_codepoint) catch unreachable));
                    p.string_last_was_high_surrogate = false;
                } else if (p.string_unicode_codepoint < 0xDC00) {
                    // 'high' surrogate
                    // takes 3 bytes to encode a half surrogate pair into wtf8
                    p.string_escapes.Some.size_diff -= 6 - 3;
                    p.string_last_was_high_surrogate = true;
                } else {
                    // 'low' surrogate
                    p.string_escapes.Some.size_diff -= 6;
                    if (p.string_last_was_high_surrogate) {
                        // takes 4 bytes to encode a full surrogate pair into utf8
                        // 3 bytes are already reserved by high surrogate
                        p.string_escapes.Some.size_diff -= -1;
                    } else {
                        // takes 3 bytes to encode a half surrogate pair into wtf8
                        p.string_escapes.Some.size_diff -= -3;
                    }
                    p.string_last_was_high_surrogate = false;
                }
                p.string_unicode_codepoint = undefined;
            },

            .Number => {
                p.complete = p.after_value_state == .TopLevelEnd;
                switch (c) {
                    '0' => {
                        p.state = .NumberMaybeDotOrExponent;
                    },
                    '1'...'9' => {
                        p.state = .NumberMaybeDigitOrDotOrExponent;
                    },
                    else => {
                        return error.InvalidNumber;
                    },
                }
            },

            .NumberMaybeDotOrExponent => {
                p.complete = p.after_value_state == .TopLevelEnd;
                switch (c) {
                    '.' => {
                        p.number_is_integer = false;
                        p.state = .NumberFractionalRequired;
                    },
                    'e', 'E' => {
                        p.number_is_integer = false;
                        p.state = .NumberExponent;
                    },
                    else => {
                        p.state = p.after_value_state;
                        token.* = .{
                            .Number = .{
                                .count = p.count,
                                .is_integer = p.number_is_integer,
                            },
                        };
                        p.number_is_integer = undefined;
                        return true;
                    },
                }
            },

            .NumberMaybeDigitOrDotOrExponent => {
                p.complete = p.after_value_state == .TopLevelEnd;
                switch (c) {
                    '.' => {
                        p.number_is_integer = false;
                        p.state = .NumberFractionalRequired;
                    },
                    'e', 'E' => {
                        p.number_is_integer = false;
                        p.state = .NumberExponent;
                    },
                    '0'...'9' => {
                        // another digit
                    },
                    else => {
                        p.state = p.after_value_state;
                        token.* = .{
                            .Number = .{
                                .count = p.count,
                                .is_integer = p.number_is_integer,
                            },
                        };
                        return true;
                    },
                }
            },

            .NumberFractionalRequired => {
                p.complete = p.after_value_state == .TopLevelEnd;
                switch (c) {
                    '0'...'9' => {
                        p.state = .NumberFractional;
                    },
                    else => {
                        return error.InvalidNumber;
                    },
                }
            },

            .NumberFractional => {
                p.complete = p.after_value_state == .TopLevelEnd;
                switch (c) {
                    '0'...'9' => {
                        // another digit
                    },
                    'e', 'E' => {
                        p.number_is_integer = false;
                        p.state = .NumberExponent;
                    },
                    else => {
                        p.state = p.after_value_state;
                        token.* = .{
                            .Number = .{
                                .count = p.count,
                                .is_integer = p.number_is_integer,
                            },
                        };
                        return true;
                    },
                }
            },

            .NumberMaybeExponent => {
                p.complete = p.after_value_state == .TopLevelEnd;
                switch (c) {
                    'e', 'E' => {
                        p.number_is_integer = false;
                        p.state = .NumberExponent;
                    },
                    else => {
                        p.state = p.after_value_state;
                        token.* = .{
                            .Number = .{
                                .count = p.count,
                                .is_integer = p.number_is_integer,
                            },
                        };
                        return true;
                    },
                }
            },

            .NumberExponent => switch (c) {
                '-', '+' => {
                    p.complete = false;
                    p.state = .NumberExponentDigitsRequired;
                },
                '0'...'9' => {
                    p.complete = p.after_value_state == .TopLevelEnd;
                    p.state = .NumberExponentDigits;
                },
                else => {
                    return error.InvalidNumber;
                },
            },

            .NumberExponentDigitsRequired => switch (c) {
                '0'...'9' => {
                    p.complete = p.after_value_state == .TopLevelEnd;
                    p.state = .NumberExponentDigits;
                },
                else => {
                    return error.InvalidNumber;
                },
            },

            .NumberExponentDigits => {
                p.complete = p.after_value_state == .TopLevelEnd;
                switch (c) {
                    '0'...'9' => {
                        // another digit
                    },
                    else => {
                        p.state = p.after_value_state;
                        token.* = .{
                            .Number = .{
                                .count = p.count,
                                .is_integer = p.number_is_integer,
                            },
                        };
                        return true;
                    },
                }
            },

            .TrueLiteral1 => switch (c) {
                'r' => p.state = .TrueLiteral2,
                else => return error.InvalidLiteral,
            },

            .TrueLiteral2 => switch (c) {
                'u' => p.state = .TrueLiteral3,
                else => return error.InvalidLiteral,
            },

            .TrueLiteral3 => switch (c) {
                'e' => {
                    p.state = p.after_value_state;
                    p.complete = p.state == .TopLevelEnd;
                    token.* = Token.True;
                },
                else => {
                    return error.InvalidLiteral;
                },
            },

            .FalseLiteral1 => switch (c) {
                'a' => p.state = .FalseLiteral2,
                else => return error.InvalidLiteral,
            },

            .FalseLiteral2 => switch (c) {
                'l' => p.state = .FalseLiteral3,
                else => return error.InvalidLiteral,
            },

            .FalseLiteral3 => switch (c) {
                's' => p.state = .FalseLiteral4,
                else => return error.InvalidLiteral,
            },

            .FalseLiteral4 => switch (c) {
                'e' => {
                    p.state = p.after_value_state;
                    p.complete = p.state == .TopLevelEnd;
                    token.* = Token.False;
                },
                else => {
                    return error.InvalidLiteral;
                },
            },

            .NullLiteral1 => switch (c) {
                'u' => p.state = .NullLiteral2,
                else => return error.InvalidLiteral,
            },

            .NullLiteral2 => switch (c) {
                'l' => p.state = .NullLiteral3,
                else => return error.InvalidLiteral,
            },

            .NullLiteral3 => switch (c) {
                'l' => {
                    p.state = p.after_value_state;
                    p.complete = p.state == .TopLevelEnd;
                    token.* = Token.Null;
                },
                else => {
                    return error.InvalidLiteral;
                },
            },
        }

        return false;
    }
};

/// A small wrapper over a StreamingParser for full slices. Returns a stream of json Tokens.
pub const TokenStream = struct {
    i: usize,
    slice: []const u8,
    parser: StreamingParser,
    token: ?Token,

    pub const Error = StreamingParser.Error || error{UnexpectedEndOfJson};

    pub fn init(slice: []const u8) TokenStream {
        return TokenStream{
            .i = 0,
            .slice = slice,
            .parser = StreamingParser.init(),
            .token = null,
        };
    }

    pub fn next(self: *TokenStream) Error!?Token {
        if (self.token) |token| {
            self.token = null;
            return token;
        }

        var t1: ?Token = undefined;
        var t2: ?Token = undefined;

        while (self.i < self.slice.len) {
            try self.parser.feed(self.slice[self.i], &t1, &t2);
            self.i += 1;

            if (t1) |token| {
                self.token = t2;
                return token;
            }
        }

        // Without this a bare number fails, the streaming parser doesn't know the input ended
        try self.parser.feed(' ', &t1, &t2);
        self.i += 1;

        if (t1) |token| {
            return token;
        } else if (self.parser.complete) {
            return null;
        } else {
            return error.UnexpectedEndOfJson;
        }
    }
};

fn checkNext(p: *TokenStream, id: std.meta.TagType(Token)) void {
    const token = (p.next() catch unreachable).?;
    debug.assert(std.meta.activeTag(token) == id);
}

test "json.token" {
    const s =
        \\{
        \\  "Image": {
        \\      "Width":  800,
        \\      "Height": 600,
        \\      "Title":  "View from 15th Floor",
        \\      "Thumbnail": {
        \\          "Url":    "http://www.example.com/image/481989943",
        \\          "Height": 125,
        \\          "Width":  100
        \\      },
        \\      "Animated" : false,
        \\      "IDs": [116, 943, 234, 38793]
        \\    }
        \\}
    ;

    var p = TokenStream.init(s);

    checkNext(&p, .ObjectBegin);
    checkNext(&p, .String); // Image
    checkNext(&p, .ObjectBegin);
    checkNext(&p, .String); // Width
    checkNext(&p, .Number);
    checkNext(&p, .String); // Height
    checkNext(&p, .Number);
    checkNext(&p, .String); // Title
    checkNext(&p, .String);
    checkNext(&p, .String); // Thumbnail
    checkNext(&p, .ObjectBegin);
    checkNext(&p, .String); // Url
    checkNext(&p, .String);
    checkNext(&p, .String); // Height
    checkNext(&p, .Number);
    checkNext(&p, .String); // Width
    checkNext(&p, .Number);
    checkNext(&p, .ObjectEnd);
    checkNext(&p, .String); // Animated
    checkNext(&p, .False);
    checkNext(&p, .String); // IDs
    checkNext(&p, .ArrayBegin);
    checkNext(&p, .Number);
    checkNext(&p, .Number);
    checkNext(&p, .Number);
    checkNext(&p, .Number);
    checkNext(&p, .ArrayEnd);
    checkNext(&p, .ObjectEnd);
    checkNext(&p, .ObjectEnd);

    testing.expect((try p.next()) == null);
}

/// Validate a JSON string. This does not limit number precision so a decoder may not necessarily
/// be able to decode the string even if this returns true.
pub fn validate(s: []const u8) bool {
    var p = StreamingParser.init();

    for (s) |c, i| {
        var token1: ?Token = undefined;
        var token2: ?Token = undefined;

        p.feed(c, &token1, &token2) catch |err| {
            return false;
        };
    }

    return p.complete;
}

test "json.validate" {
    testing.expect(validate("{}"));
}

const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;

pub const ValueTree = struct {
    arena: ArenaAllocator,
    root: Value,

    pub fn deinit(self: *ValueTree) void {
        self.arena.deinit();
    }
};

pub const ObjectMap = StringHashMap(Value);
pub const Array = ArrayList(Value);

/// Represents a JSON value
/// Currently only supports numbers that fit into i64 or f64.
pub const Value = union(enum) {
    Null,
    Bool: bool,
    Integer: i64,
    Float: f64,
    String: []const u8,
    Array: Array,
    Object: ObjectMap,

    pub fn dump(self: Value) void {
        var held = std.debug.getStderrMutex().acquire();
        defer held.release();

        const stderr = std.debug.getStderrStream();
        self.dumpStream(stderr, 1024) catch return;
    }

    pub fn dumpIndent(self: Value, comptime indent: usize) void {
        if (indent == 0) {
            self.dump();
        } else {
            var held = std.debug.getStderrMutex().acquire();
            defer held.release();

            const stderr = std.debug.getStderrStream();
            self.dumpStreamIndent(indent, stderr, 1024) catch return;
        }
    }

    pub fn dumpStream(self: @This(), stream: var, comptime max_depth: usize) !void {
        var w = std.json.WriteStream(@TypeOf(stream).Child, max_depth).init(stream);
        w.newline = "";
        w.one_indent = "";
        w.space = "";
        try w.emitJson(self);
    }

    pub fn dumpStreamIndent(self: @This(), comptime indent: usize, stream: var, comptime max_depth: usize) !void {
        var one_indent = " " ** indent;

        var w = std.json.WriteStream(@TypeOf(stream).Child, max_depth).init(stream);
        w.one_indent = one_indent;
        try w.emitJson(self);
    }
};

/// A non-stream JSON parser which constructs a tree of Value's.
pub const Parser = struct {
    allocator: *Allocator,
    state: State,
    copy_strings: bool,
    // Stores parent nodes and un-combined Values.
    stack: Array,

    const State = enum {
        ObjectKey,
        ObjectValue,
        ArrayValue,
        Simple,
    };

    pub fn init(allocator: *Allocator, copy_strings: bool) Parser {
        return Parser{
            .allocator = allocator,
            .state = .Simple,
            .copy_strings = copy_strings,
            .stack = Array.init(allocator),
        };
    }

    pub fn deinit(p: *Parser) void {
        p.stack.deinit();
    }

    pub fn reset(p: *Parser) void {
        p.state = .Simple;
        p.stack.shrink(0);
    }

    pub fn parse(p: *Parser, input: []const u8) !ValueTree {
        var s = TokenStream.init(input);

        var arena = ArenaAllocator.init(p.allocator);
        errdefer arena.deinit();

        while (try s.next()) |token| {
            try p.transition(&arena.allocator, input, s.i - 1, token);
        }

        debug.assert(p.stack.len == 1);

        return ValueTree{
            .arena = arena,
            .root = p.stack.at(0),
        };
    }

    // Even though p.allocator exists, we take an explicit allocator so that allocation state
    // can be cleaned up on error correctly during a `parse` on call.
    fn transition(p: *Parser, allocator: *Allocator, input: []const u8, i: usize, token: Token) !void {
        switch (p.state) {
            .ObjectKey => switch (token) {
                .ObjectEnd => {
                    if (p.stack.len == 1) {
                        return;
                    }

                    var value = p.stack.pop();
                    try p.pushToParent(&value);
                },
                .String => |s| {
                    try p.stack.append(try p.parseString(allocator, s, input, i));
                    p.state = .ObjectValue;
                },
                else => {
                    // The streaming parser would return an error eventually.
                    // To prevent invalid state we return an error now.
                    // TODO make the streaming parser return an error as soon as it encounters an invalid object key
                    return error.InvalidLiteral;
                },
            },
            .ObjectValue => {
                var object = &p.stack.items[p.stack.len - 2].Object;
                var key = p.stack.items[p.stack.len - 1].String;

                switch (token) {
                    .ObjectBegin => {
                        try p.stack.append(Value{ .Object = ObjectMap.init(allocator) });
                        p.state = .ObjectKey;
                    },
                    .ArrayBegin => {
                        try p.stack.append(Value{ .Array = Array.init(allocator) });
                        p.state = .ArrayValue;
                    },
                    .String => |s| {
                        _ = try object.put(key, try p.parseString(allocator, s, input, i));
                        _ = p.stack.pop();
                        p.state = .ObjectKey;
                    },
                    .Number => |n| {
                        _ = try object.put(key, try p.parseNumber(n, input, i));
                        _ = p.stack.pop();
                        p.state = .ObjectKey;
                    },
                    .True => {
                        _ = try object.put(key, Value{ .Bool = true });
                        _ = p.stack.pop();
                        p.state = .ObjectKey;
                    },
                    .False => {
                        _ = try object.put(key, Value{ .Bool = false });
                        _ = p.stack.pop();
                        p.state = .ObjectKey;
                    },
                    .Null => {
                        _ = try object.put(key, Value.Null);
                        _ = p.stack.pop();
                        p.state = .ObjectKey;
                    },
                    .ObjectEnd, .ArrayEnd => {
                        unreachable;
                    },
                }
            },
            .ArrayValue => {
                var array = &p.stack.items[p.stack.len - 1].Array;

                switch (token) {
                    .ArrayEnd => {
                        if (p.stack.len == 1) {
                            return;
                        }

                        var value = p.stack.pop();
                        try p.pushToParent(&value);
                    },
                    .ObjectBegin => {
                        try p.stack.append(Value{ .Object = ObjectMap.init(allocator) });
                        p.state = .ObjectKey;
                    },
                    .ArrayBegin => {
                        try p.stack.append(Value{ .Array = Array.init(allocator) });
                        p.state = .ArrayValue;
                    },
                    .String => |s| {
                        try array.append(try p.parseString(allocator, s, input, i));
                    },
                    .Number => |n| {
                        try array.append(try p.parseNumber(n, input, i));
                    },
                    .True => {
                        try array.append(Value{ .Bool = true });
                    },
                    .False => {
                        try array.append(Value{ .Bool = false });
                    },
                    .Null => {
                        try array.append(Value.Null);
                    },
                    .ObjectEnd => {
                        unreachable;
                    },
                }
            },
            .Simple => switch (token) {
                .ObjectBegin => {
                    try p.stack.append(Value{ .Object = ObjectMap.init(allocator) });
                    p.state = .ObjectKey;
                },
                .ArrayBegin => {
                    try p.stack.append(Value{ .Array = Array.init(allocator) });
                    p.state = .ArrayValue;
                },
                .String => |s| {
                    try p.stack.append(try p.parseString(allocator, s, input, i));
                },
                .Number => |n| {
                    try p.stack.append(try p.parseNumber(n, input, i));
                },
                .True => {
                    try p.stack.append(Value{ .Bool = true });
                },
                .False => {
                    try p.stack.append(Value{ .Bool = false });
                },
                .Null => {
                    try p.stack.append(Value.Null);
                },
                .ObjectEnd, .ArrayEnd => {
                    unreachable;
                },
            },
        }
    }

    fn pushToParent(p: *Parser, value: *const Value) !void {
        switch (p.stack.toSlice()[p.stack.len - 1]) {
            // Object Parent -> [ ..., object, <key>, value ]
            Value.String => |key| {
                _ = p.stack.pop();

                var object = &p.stack.items[p.stack.len - 1].Object;
                _ = try object.put(key, value.*);
                p.state = .ObjectKey;
            },
            // Array Parent -> [ ..., <array>, value ]
            Value.Array => |*array| {
                try array.append(value.*);
                p.state = .ArrayValue;
            },
            else => {
                unreachable;
            },
        }
    }

    fn parseString(p: *Parser, allocator: *Allocator, s: std.meta.TagPayloadType(Token, Token.String), input: []const u8, i: usize) !Value {
        const slice = s.slice(input, i);
        switch (s.escapes) {
            .None => return Value{ .String = if (p.copy_strings) try mem.dupe(allocator, u8, slice) else slice },
            .Some => |some_escapes| {
                const output = try allocator.alloc(u8, s.decodedLength());
                errdefer allocator.free(output);
                try unescapeString(output, slice);
                return Value{ .String = output };
            },
        }
    }

    fn parseNumber(p: *Parser, n: std.meta.TagPayloadType(Token, Token.Number), input: []const u8, i: usize) !Value {
        return if (n.is_integer)
            Value{ .Integer = try std.fmt.parseInt(i64, n.slice(input, i), 10) }
        else
            Value{ .Float = try std.fmt.parseFloat(f64, n.slice(input, i)) };
    }
};

// Unescape a JSON string
// Only to be used on strings already validated by the parser
// (note the unreachable statements and lack of bounds checking)
fn unescapeString(output: []u8, input: []const u8) !void {
    var inIndex: usize = 0;
    var outIndex: usize = 0;

    while (inIndex < input.len) {
        if (input[inIndex] != '\\') {
            // not an escape sequence
            output[outIndex] = input[inIndex];
            inIndex += 1;
            outIndex += 1;
        } else if (input[inIndex + 1] != 'u') {
            // a simple escape sequence
            output[outIndex] = @as(u8, switch (input[inIndex + 1]) {
                '\\' => '\\',
                '/' => '/',
                'n' => '\n',
                'r' => '\r',
                't' => '\t',
                'f' => 12,
                'b' => 8,
                '"' => '"',
                else => unreachable,
            });
            inIndex += 2;
            outIndex += 1;
        } else {
            // a unicode escape sequence
            const firstCodeUnit = std.fmt.parseInt(u16, input[inIndex + 2 .. inIndex + 6], 16) catch unreachable;

            // guess optimistically that it's not a surrogate pair
            if (std.unicode.utf8Encode(firstCodeUnit, output[outIndex..])) |byteCount| {
                outIndex += byteCount;
                inIndex += 6;
            } else |err| {
                // it might be a surrogate pair
                if (err != error.Utf8CannotEncodeSurrogateHalf) {
                    return error.InvalidUnicodeHexSymbol;
                }
                // check if a second code unit is present
                if (inIndex + 7 >= input.len or input[inIndex + 6] != '\\' or input[inIndex + 7] != 'u') {
                    return error.InvalidUnicodeHexSymbol;
                }

                const secondCodeUnit = std.fmt.parseInt(u16, input[inIndex + 8 .. inIndex + 12], 16) catch unreachable;

                if (std.unicode.utf16leToUtf8(output[outIndex..], &[2]u16{ firstCodeUnit, secondCodeUnit })) |byteCount| {
                    outIndex += byteCount;
                    inIndex += 12;
                } else |_| {
                    return error.InvalidUnicodeHexSymbol;
                }
            }
        }
    }
    assert(outIndex == output.len);
}

test "json.parser.dynamic" {
    var p = Parser.init(testing.allocator, false);
    defer p.deinit();

    const s =
        \\{
        \\  "Image": {
        \\      "Width":  800,
        \\      "Height": 600,
        \\      "Title":  "View from 15th Floor",
        \\      "Thumbnail": {
        \\          "Url":    "http://www.example.com/image/481989943",
        \\          "Height": 125,
        \\          "Width":  100
        \\      },
        \\      "Animated" : false,
        \\      "IDs": [116, 943, 234, 38793],
        \\      "ArrayOfObject": [{"n": "m"}],
        \\      "double": 1.3412
        \\    }
        \\}
    ;

    var tree = try p.parse(s);
    defer tree.deinit();

    var root = tree.root;

    var image = root.Object.get("Image").?.value;

    const width = image.Object.get("Width").?.value;
    testing.expect(width.Integer == 800);

    const height = image.Object.get("Height").?.value;
    testing.expect(height.Integer == 600);

    const title = image.Object.get("Title").?.value;
    testing.expect(mem.eql(u8, title.String, "View from 15th Floor"));

    const animated = image.Object.get("Animated").?.value;
    testing.expect(animated.Bool == false);

    const array_of_object = image.Object.get("ArrayOfObject").?.value;
    testing.expect(array_of_object.Array.len == 1);

    const obj0 = array_of_object.Array.at(0).Object.get("n").?.value;
    testing.expect(mem.eql(u8, obj0.String, "m"));

    const double = image.Object.get("double").?.value;
    testing.expect(double.Float == 1.3412);
}

test "import more json tests" {
    _ = @import("json/test.zig");
    _ = @import("json/write_stream.zig");
}

test "write json then parse it" {
    var out_buffer: [1000]u8 = undefined;

    var slice_out_stream = std.io.SliceOutStream.init(&out_buffer);
    const out_stream = &slice_out_stream.stream;
    var jw = WriteStream(@TypeOf(out_stream).Child, 4).init(out_stream);

    try jw.beginObject();

    try jw.objectField("f");
    try jw.emitBool(false);

    try jw.objectField("t");
    try jw.emitBool(true);

    try jw.objectField("int");
    try jw.emitNumber(@as(i32, 1234));

    try jw.objectField("array");
    try jw.beginArray();

    try jw.arrayElem();
    try jw.emitNull();

    try jw.arrayElem();
    try jw.emitNumber(@as(f64, 12.34));

    try jw.endArray();

    try jw.objectField("str");
    try jw.emitString("hello");

    try jw.endObject();

    var parser = Parser.init(testing.allocator, false);
    defer parser.deinit();
    var tree = try parser.parse(slice_out_stream.getWritten());
    defer tree.deinit();

    testing.expect(tree.root.Object.get("f").?.value.Bool == false);
    testing.expect(tree.root.Object.get("t").?.value.Bool == true);
    testing.expect(tree.root.Object.get("int").?.value.Integer == 1234);
    testing.expect(tree.root.Object.get("array").?.value.Array.at(0).Null == {});
    testing.expect(tree.root.Object.get("array").?.value.Array.at(1).Float == 12.34);
    testing.expect(mem.eql(u8, tree.root.Object.get("str").?.value.String, "hello"));
}

fn test_parse(arena_allocator: *std.mem.Allocator, json_str: []const u8) !Value {
    var p = Parser.init(arena_allocator, false);
    return (try p.parse(json_str)).root;
}

test "parsing empty string gives appropriate error" {
    var arena_allocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_allocator.deinit();
    testing.expectError(error.UnexpectedEndOfJson, test_parse(&arena_allocator.allocator, ""));
}

test "integer after float has proper type" {
    var arena_allocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_allocator.deinit();
    const json = try test_parse(&arena_allocator.allocator,
        \\{
        \\  "float": 3.14,
        \\  "ints": [1, 2, 3]
        \\}
    );
    std.testing.expect(json.Object.getValue("ints").?.Array.at(0) == .Integer);
}

test "escaped characters" {
    var arena_allocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_allocator.deinit();
    const input =
        \\{
        \\  "backslash": "\\",
        \\  "forwardslash": "\/",
        \\  "newline": "\n",
        \\  "carriagereturn": "\r",
        \\  "tab": "\t",
        \\  "formfeed": "\f",
        \\  "backspace": "\b",
        \\  "doublequote": "\"",
        \\  "unicode": "\u0105",
        \\  "surrogatepair": "\ud83d\ude02"
        \\}
    ;

    const obj = (try test_parse(&arena_allocator.allocator, input)).Object;

    testing.expectEqualSlices(u8, obj.get("backslash").?.value.String, "\\");
    testing.expectEqualSlices(u8, obj.get("forwardslash").?.value.String, "/");
    testing.expectEqualSlices(u8, obj.get("newline").?.value.String, "\n");
    testing.expectEqualSlices(u8, obj.get("carriagereturn").?.value.String, "\r");
    testing.expectEqualSlices(u8, obj.get("tab").?.value.String, "\t");
    testing.expectEqualSlices(u8, obj.get("formfeed").?.value.String, "\x0C");
    testing.expectEqualSlices(u8, obj.get("backspace").?.value.String, "\x08");
    testing.expectEqualSlices(u8, obj.get("doublequote").?.value.String, "\"");
    testing.expectEqualSlices(u8, obj.get("unicode").?.value.String, "ą");
    testing.expectEqualSlices(u8, obj.get("surrogatepair").?.value.String, "😂");
}

test "string copy option" {
    const input =
        \\{
        \\  "noescape": "aą😂",
        \\  "simple": "\\\/\n\r\t\f\b\"",
        \\  "unicode": "\u0105",
        \\  "surrogatepair": "\ud83d\ude02"
        \\}
    ;

    var arena_allocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_allocator.deinit();

    const tree_nocopy = try Parser.init(&arena_allocator.allocator, false).parse(input);
    const obj_nocopy = tree_nocopy.root.Object;

    const tree_copy = try Parser.init(&arena_allocator.allocator, true).parse(input);
    const obj_copy = tree_copy.root.Object;

    for ([_][]const u8{ "noescape", "simple", "unicode", "surrogatepair" }) |field_name| {
        testing.expectEqualSlices(u8, obj_nocopy.getValue(field_name).?.String, obj_copy.getValue(field_name).?.String);
    }

    const nocopy_addr = &obj_nocopy.getValue("noescape").?.String[0];
    const copy_addr = &obj_copy.getValue("noescape").?.String[0];

    var found_nocopy = false;
    for (input) |_, index| {
        testing.expect(copy_addr != &input[index]);
        if (nocopy_addr == &input[index]) {
            found_nocopy = true;
        }
    }
    testing.expect(found_nocopy);
}
