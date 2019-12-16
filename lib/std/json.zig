// JSON parser conforming to RFC8259.
//
// https://tools.ietf.org/html/rfc8259

const std = @import("std.zig");
const debug = std.debug;
const testing = std.testing;
const mem = std.mem;
const maxInt = std.math.maxInt;

pub const WriteStream = @import("json/write_stream.zig").WriteStream;

// A single token slice into the parent string.
//
// Use `token.slice()` on the input at the current position to get the current slice.
pub const Token = struct {
    id: Id,
    // How many bytes do we skip before counting
    offset: u1,
    // Whether string contains a \uXXXX sequence and cannot be zero-copied
    string_has_escape: bool,
    // Whether number is simple and can be represented by an integer (i.e. no `.` or `e`)
    number_is_integer: bool,
    // How many bytes from the current position behind the start of this token is.
    count: usize,

    pub const Id = enum {
        ObjectBegin,
        ObjectEnd,
        ArrayBegin,
        ArrayEnd,
        String,
        Number,
        True,
        False,
        Null,
    };

    pub fn init(id: Id, count: usize, offset: u1) Token {
        return Token{
            .id = id,
            .offset = offset,
            .string_has_escape = false,
            .number_is_integer = true,
            .count = count,
        };
    }

    pub fn initString(count: usize, has_unicode_escape: bool) Token {
        return Token{
            .id = Id.String,
            .offset = 0,
            .string_has_escape = has_unicode_escape,
            .number_is_integer = true,
            .count = count,
        };
    }

    pub fn initNumber(count: usize, number_is_integer: bool) Token {
        return Token{
            .id = Id.Number,
            .offset = 0,
            .string_has_escape = false,
            .number_is_integer = number_is_integer,
            .count = count,
        };
    }

    // A marker token is a zero-length
    pub fn initMarker(id: Id) Token {
        return Token{
            .id = id,
            .offset = 0,
            .string_has_escape = false,
            .number_is_integer = true,
            .count = 0,
        };
    }

    // Slice into the underlying input string.
    pub fn slice(self: Token, input: []const u8, i: usize) []const u8 {
        return input[i + self.offset - self.count .. i + self.offset];
    }
};

// A small streaming JSON parser. This accepts input one byte at a time and returns tokens as
// they are encountered. No copies or allocations are performed during parsing and the entire
// parsing state requires ~40-50 bytes of stack space.
//
// Conforms strictly to RFC8529.
//
// For a non-byte based wrapper, consider using TokenStream instead.
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
    string_has_escape: bool,
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
        p.state = State.TopLevelBegin;
        p.count = 0;
        // Set before ever read in main transition function
        p.after_string_state = undefined;
        p.after_value_state = State.ValueEnd; // handle end of values normally
        p.stack = 0;
        p.stack_used = 0;
        p.complete = false;
        p.string_has_escape = false;
        p.number_is_integer = true;
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
        StringUtf8Byte3,
        StringUtf8Byte2,
        StringUtf8Byte1,
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

    // Give another byte to the parser and obtain any new tokens. This may (rarely) return two
    // tokens. token2 is always null if token1 is null.
    //
    // There is currently no error recovery on a bad stream.
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
            State.TopLevelBegin => switch (c) {
                '{' => {
                    p.stack <<= 1;
                    p.stack |= object_bit;
                    p.stack_used += 1;

                    p.state = State.ValueBegin;
                    p.after_string_state = State.ObjectSeparator;

                    token.* = Token.initMarker(Token.Id.ObjectBegin);
                },
                '[' => {
                    p.stack <<= 1;
                    p.stack |= array_bit;
                    p.stack_used += 1;

                    p.state = State.ValueBegin;
                    p.after_string_state = State.ValueEnd;

                    token.* = Token.initMarker(Token.Id.ArrayBegin);
                },
                '-' => {
                    p.number_is_integer = true;
                    p.state = State.Number;
                    p.after_value_state = State.TopLevelEnd;
                    p.count = 0;
                },
                '0' => {
                    p.number_is_integer = true;
                    p.state = State.NumberMaybeDotOrExponent;
                    p.after_value_state = State.TopLevelEnd;
                    p.count = 0;
                },
                '1'...'9' => {
                    p.number_is_integer = true;
                    p.state = State.NumberMaybeDigitOrDotOrExponent;
                    p.after_value_state = State.TopLevelEnd;
                    p.count = 0;
                },
                '"' => {
                    p.state = State.String;
                    p.after_value_state = State.TopLevelEnd;
                    // We don't actually need the following since after_value_state should override.
                    p.after_string_state = State.ValueEnd;
                    p.string_has_escape = false;
                    p.count = 0;
                },
                't' => {
                    p.state = State.TrueLiteral1;
                    p.after_value_state = State.TopLevelEnd;
                    p.count = 0;
                },
                'f' => {
                    p.state = State.FalseLiteral1;
                    p.after_value_state = State.TopLevelEnd;
                    p.count = 0;
                },
                'n' => {
                    p.state = State.NullLiteral1;
                    p.after_value_state = State.TopLevelEnd;
                    p.count = 0;
                },
                0x09, 0x0A, 0x0D, 0x20 => {
                    // whitespace
                },
                else => {
                    return error.InvalidTopLevel;
                },
            },

            State.TopLevelEnd => switch (c) {
                0x09, 0x0A, 0x0D, 0x20 => {
                    // whitespace
                },
                else => {
                    return error.InvalidTopLevelTrailing;
                },
            },

            State.ValueBegin => switch (c) {
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

                    p.state = State.ValueBegin;
                    p.after_string_state = State.fromInt(p.stack & 1);

                    p.stack >>= 1;
                    p.stack_used -= 1;

                    switch (p.stack_used) {
                        0 => {
                            p.complete = true;
                            p.state = State.TopLevelEnd;
                        },
                        else => {
                            p.state = State.ValueEnd;
                        },
                    }

                    token.* = Token.initMarker(Token.Id.ObjectEnd);
                },
                ']' => {
                    if (p.stack & 1 != array_bit) {
                        return error.UnexpectedClosingBrace;
                    }
                    if (p.stack_used == 0) {
                        return error.TooManyClosingItems;
                    }

                    p.state = State.ValueBegin;
                    p.after_string_state = State.fromInt(p.stack & 1);

                    p.stack >>= 1;
                    p.stack_used -= 1;

                    switch (p.stack_used) {
                        0 => {
                            p.complete = true;
                            p.state = State.TopLevelEnd;
                        },
                        else => {
                            p.state = State.ValueEnd;
                        },
                    }

                    token.* = Token.initMarker(Token.Id.ArrayEnd);
                },
                '{' => {
                    if (p.stack_used == max_stack_size) {
                        return error.TooManyNestedItems;
                    }

                    p.stack <<= 1;
                    p.stack |= object_bit;
                    p.stack_used += 1;

                    p.state = State.ValueBegin;
                    p.after_string_state = State.ObjectSeparator;

                    token.* = Token.initMarker(Token.Id.ObjectBegin);
                },
                '[' => {
                    if (p.stack_used == max_stack_size) {
                        return error.TooManyNestedItems;
                    }

                    p.stack <<= 1;
                    p.stack |= array_bit;
                    p.stack_used += 1;

                    p.state = State.ValueBegin;
                    p.after_string_state = State.ValueEnd;

                    token.* = Token.initMarker(Token.Id.ArrayBegin);
                },
                '-' => {
                    p.number_is_integer = true;
                    p.state = State.Number;
                    p.count = 0;
                },
                '0' => {
                    p.number_is_integer = true;
                    p.state = State.NumberMaybeDotOrExponent;
                    p.count = 0;
                },
                '1'...'9' => {
                    p.number_is_integer = true;
                    p.state = State.NumberMaybeDigitOrDotOrExponent;
                    p.count = 0;
                },
                '"' => {
                    p.state = State.String;
                    p.count = 0;
                },
                't' => {
                    p.state = State.TrueLiteral1;
                    p.count = 0;
                },
                'f' => {
                    p.state = State.FalseLiteral1;
                    p.count = 0;
                },
                'n' => {
                    p.state = State.NullLiteral1;
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
            State.ValueBeginNoClosing => switch (c) {
                '{' => {
                    if (p.stack_used == max_stack_size) {
                        return error.TooManyNestedItems;
                    }

                    p.stack <<= 1;
                    p.stack |= object_bit;
                    p.stack_used += 1;

                    p.state = State.ValueBegin;
                    p.after_string_state = State.ObjectSeparator;

                    token.* = Token.initMarker(Token.Id.ObjectBegin);
                },
                '[' => {
                    if (p.stack_used == max_stack_size) {
                        return error.TooManyNestedItems;
                    }

                    p.stack <<= 1;
                    p.stack |= array_bit;
                    p.stack_used += 1;

                    p.state = State.ValueBegin;
                    p.after_string_state = State.ValueEnd;

                    token.* = Token.initMarker(Token.Id.ArrayBegin);
                },
                '-' => {
                    p.number_is_integer = true;
                    p.state = State.Number;
                    p.count = 0;
                },
                '0' => {
                    p.number_is_integer = true;
                    p.state = State.NumberMaybeDotOrExponent;
                    p.count = 0;
                },
                '1'...'9' => {
                    p.number_is_integer = true;
                    p.state = State.NumberMaybeDigitOrDotOrExponent;
                    p.count = 0;
                },
                '"' => {
                    p.state = State.String;
                    p.count = 0;
                },
                't' => {
                    p.state = State.TrueLiteral1;
                    p.count = 0;
                },
                'f' => {
                    p.state = State.FalseLiteral1;
                    p.count = 0;
                },
                'n' => {
                    p.state = State.NullLiteral1;
                    p.count = 0;
                },
                0x09, 0x0A, 0x0D, 0x20 => {
                    // whitespace
                },
                else => {
                    return error.InvalidValueBegin;
                },
            },

            State.ValueEnd => switch (c) {
                ',' => {
                    p.after_string_state = State.fromInt(p.stack & 1);
                    p.state = State.ValueBeginNoClosing;
                },
                ']' => {
                    if (p.stack_used == 0) {
                        return error.UnbalancedBrackets;
                    }

                    p.state = State.ValueEnd;
                    p.after_string_state = State.fromInt(p.stack & 1);

                    p.stack >>= 1;
                    p.stack_used -= 1;

                    if (p.stack_used == 0) {
                        p.complete = true;
                        p.state = State.TopLevelEnd;
                    }

                    token.* = Token.initMarker(Token.Id.ArrayEnd);
                },
                '}' => {
                    if (p.stack_used == 0) {
                        return error.UnbalancedBraces;
                    }

                    p.state = State.ValueEnd;
                    p.after_string_state = State.fromInt(p.stack & 1);

                    p.stack >>= 1;
                    p.stack_used -= 1;

                    if (p.stack_used == 0) {
                        p.complete = true;
                        p.state = State.TopLevelEnd;
                    }

                    token.* = Token.initMarker(Token.Id.ObjectEnd);
                },
                0x09, 0x0A, 0x0D, 0x20 => {
                    // whitespace
                },
                else => {
                    return error.InvalidValueEnd;
                },
            },

            State.ObjectSeparator => switch (c) {
                ':' => {
                    p.state = State.ValueBegin;
                    p.after_string_state = State.ValueEnd;
                },
                0x09, 0x0A, 0x0D, 0x20 => {
                    // whitespace
                },
                else => {
                    return error.InvalidSeparator;
                },
            },

            State.String => switch (c) {
                0x00...0x1F => {
                    return error.InvalidControlCharacter;
                },
                '"' => {
                    p.state = p.after_string_state;
                    if (p.after_value_state == State.TopLevelEnd) {
                        p.state = State.TopLevelEnd;
                        p.complete = true;
                    }

                    token.* = Token.initString(p.count - 1, p.string_has_escape);
                },
                '\\' => {
                    p.state = State.StringEscapeCharacter;
                },
                0x20, 0x21, 0x23...0x5B, 0x5D...0x7F => {
                    // non-control ascii
                },
                0xC0...0xDF => {
                    p.state = State.StringUtf8Byte1;
                },
                0xE0...0xEF => {
                    p.state = State.StringUtf8Byte2;
                },
                0xF0...0xFF => {
                    p.state = State.StringUtf8Byte3;
                },
                else => {
                    return error.InvalidUtf8Byte;
                },
            },

            State.StringUtf8Byte3 => switch (c >> 6) {
                0b10 => p.state = State.StringUtf8Byte2,
                else => return error.InvalidUtf8Byte,
            },

            State.StringUtf8Byte2 => switch (c >> 6) {
                0b10 => p.state = State.StringUtf8Byte1,
                else => return error.InvalidUtf8Byte,
            },

            State.StringUtf8Byte1 => switch (c >> 6) {
                0b10 => p.state = State.String,
                else => return error.InvalidUtf8Byte,
            },

            State.StringEscapeCharacter => switch (c) {
                // NOTE: '/' is allowed as an escaped character but it also is allowed
                // as unescaped according to the RFC. There is a reported errata which suggests
                // removing the non-escaped variant but it makes more sense to simply disallow
                // it as an escape code here.
                //
                // The current JSONTestSuite tests rely on both of this behaviour being present
                // however, so we default to the status quo where both are accepted until this
                // is further clarified.
                '"', '\\', '/', 'b', 'f', 'n', 'r', 't' => {
                    p.string_has_escape = true;
                    p.state = State.String;
                },
                'u' => {
                    p.string_has_escape = true;
                    p.state = State.StringEscapeHexUnicode4;
                },
                else => {
                    return error.InvalidEscapeCharacter;
                },
            },

            State.StringEscapeHexUnicode4 => switch (c) {
                '0'...'9', 'A'...'F', 'a'...'f' => {
                    p.state = State.StringEscapeHexUnicode3;
                },
                else => return error.InvalidUnicodeHexSymbol,
            },

            State.StringEscapeHexUnicode3 => switch (c) {
                '0'...'9', 'A'...'F', 'a'...'f' => {
                    p.state = State.StringEscapeHexUnicode2;
                },
                else => return error.InvalidUnicodeHexSymbol,
            },

            State.StringEscapeHexUnicode2 => switch (c) {
                '0'...'9', 'A'...'F', 'a'...'f' => {
                    p.state = State.StringEscapeHexUnicode1;
                },
                else => return error.InvalidUnicodeHexSymbol,
            },

            State.StringEscapeHexUnicode1 => switch (c) {
                '0'...'9', 'A'...'F', 'a'...'f' => {
                    p.state = State.String;
                },
                else => return error.InvalidUnicodeHexSymbol,
            },

            State.Number => {
                p.complete = p.after_value_state == State.TopLevelEnd;
                switch (c) {
                    '0' => {
                        p.state = State.NumberMaybeDotOrExponent;
                    },
                    '1'...'9' => {
                        p.state = State.NumberMaybeDigitOrDotOrExponent;
                    },
                    else => {
                        return error.InvalidNumber;
                    },
                }
            },

            State.NumberMaybeDotOrExponent => {
                p.complete = p.after_value_state == State.TopLevelEnd;
                switch (c) {
                    '.' => {
                        p.number_is_integer = false;
                        p.state = State.NumberFractionalRequired;
                    },
                    'e', 'E' => {
                        p.number_is_integer = false;
                        p.state = State.NumberExponent;
                    },
                    else => {
                        p.state = p.after_value_state;
                        token.* = Token.initNumber(p.count, p.number_is_integer);
                        return true;
                    },
                }
            },

            State.NumberMaybeDigitOrDotOrExponent => {
                p.complete = p.after_value_state == State.TopLevelEnd;
                switch (c) {
                    '.' => {
                        p.number_is_integer = false;
                        p.state = State.NumberFractionalRequired;
                    },
                    'e', 'E' => {
                        p.number_is_integer = false;
                        p.state = State.NumberExponent;
                    },
                    '0'...'9' => {
                        // another digit
                    },
                    else => {
                        p.state = p.after_value_state;
                        token.* = Token.initNumber(p.count, p.number_is_integer);
                        return true;
                    },
                }
            },

            State.NumberFractionalRequired => {
                p.complete = p.after_value_state == State.TopLevelEnd;
                switch (c) {
                    '0'...'9' => {
                        p.state = State.NumberFractional;
                    },
                    else => {
                        return error.InvalidNumber;
                    },
                }
            },

            State.NumberFractional => {
                p.complete = p.after_value_state == State.TopLevelEnd;
                switch (c) {
                    '0'...'9' => {
                        // another digit
                    },
                    'e', 'E' => {
                        p.number_is_integer = false;
                        p.state = State.NumberExponent;
                    },
                    else => {
                        p.state = p.after_value_state;
                        token.* = Token.initNumber(p.count, p.number_is_integer);
                        return true;
                    },
                }
            },

            State.NumberMaybeExponent => {
                p.complete = p.after_value_state == State.TopLevelEnd;
                switch (c) {
                    'e', 'E' => {
                        p.number_is_integer = false;
                        p.state = State.NumberExponent;
                    },
                    else => {
                        p.state = p.after_value_state;
                        token.* = Token.initNumber(p.count, p.number_is_integer);
                        return true;
                    },
                }
            },

            State.NumberExponent => switch (c) {
                '-', '+' => {
                    p.complete = false;
                    p.state = State.NumberExponentDigitsRequired;
                },
                '0'...'9' => {
                    p.complete = p.after_value_state == State.TopLevelEnd;
                    p.state = State.NumberExponentDigits;
                },
                else => {
                    return error.InvalidNumber;
                },
            },

            State.NumberExponentDigitsRequired => switch (c) {
                '0'...'9' => {
                    p.complete = p.after_value_state == State.TopLevelEnd;
                    p.state = State.NumberExponentDigits;
                },
                else => {
                    return error.InvalidNumber;
                },
            },

            State.NumberExponentDigits => {
                p.complete = p.after_value_state == State.TopLevelEnd;
                switch (c) {
                    '0'...'9' => {
                        // another digit
                    },
                    else => {
                        p.state = p.after_value_state;
                        token.* = Token.initNumber(p.count, p.number_is_integer);
                        return true;
                    },
                }
            },

            State.TrueLiteral1 => switch (c) {
                'r' => p.state = State.TrueLiteral2,
                else => return error.InvalidLiteral,
            },

            State.TrueLiteral2 => switch (c) {
                'u' => p.state = State.TrueLiteral3,
                else => return error.InvalidLiteral,
            },

            State.TrueLiteral3 => switch (c) {
                'e' => {
                    p.state = p.after_value_state;
                    p.complete = p.state == State.TopLevelEnd;
                    token.* = Token.init(Token.Id.True, p.count + 1, 1);
                },
                else => {
                    return error.InvalidLiteral;
                },
            },

            State.FalseLiteral1 => switch (c) {
                'a' => p.state = State.FalseLiteral2,
                else => return error.InvalidLiteral,
            },

            State.FalseLiteral2 => switch (c) {
                'l' => p.state = State.FalseLiteral3,
                else => return error.InvalidLiteral,
            },

            State.FalseLiteral3 => switch (c) {
                's' => p.state = State.FalseLiteral4,
                else => return error.InvalidLiteral,
            },

            State.FalseLiteral4 => switch (c) {
                'e' => {
                    p.state = p.after_value_state;
                    p.complete = p.state == State.TopLevelEnd;
                    token.* = Token.init(Token.Id.False, p.count + 1, 1);
                },
                else => {
                    return error.InvalidLiteral;
                },
            },

            State.NullLiteral1 => switch (c) {
                'u' => p.state = State.NullLiteral2,
                else => return error.InvalidLiteral,
            },

            State.NullLiteral2 => switch (c) {
                'l' => p.state = State.NullLiteral3,
                else => return error.InvalidLiteral,
            },

            State.NullLiteral3 => switch (c) {
                'l' => {
                    p.state = p.after_value_state;
                    p.complete = p.state == State.TopLevelEnd;
                    token.* = Token.init(Token.Id.Null, p.count + 1, 1);
                },
                else => {
                    return error.InvalidLiteral;
                },
            },
        }

        return false;
    }
};

// A small wrapper over a StreamingParser for full slices. Returns a stream of json Tokens.
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
            // TODO: Audit this pattern once #2915 is closed
            const copy = token;
            self.token = null;
            return copy;
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

        if (self.parser.complete) {
            return null;
        } else {
            return error.UnexpectedEndOfJson;
        }
    }
};

fn checkNext(p: *TokenStream, id: Token.Id) void {
    const token = (p.next() catch unreachable).?;
    debug.assert(token.id == id);
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

    checkNext(&p, Token.Id.ObjectBegin);
    checkNext(&p, Token.Id.String); // Image
    checkNext(&p, Token.Id.ObjectBegin);
    checkNext(&p, Token.Id.String); // Width
    checkNext(&p, Token.Id.Number);
    checkNext(&p, Token.Id.String); // Height
    checkNext(&p, Token.Id.Number);
    checkNext(&p, Token.Id.String); // Title
    checkNext(&p, Token.Id.String);
    checkNext(&p, Token.Id.String); // Thumbnail
    checkNext(&p, Token.Id.ObjectBegin);
    checkNext(&p, Token.Id.String); // Url
    checkNext(&p, Token.Id.String);
    checkNext(&p, Token.Id.String); // Height
    checkNext(&p, Token.Id.Number);
    checkNext(&p, Token.Id.String); // Width
    checkNext(&p, Token.Id.Number);
    checkNext(&p, Token.Id.ObjectEnd);
    checkNext(&p, Token.Id.String); // Animated
    checkNext(&p, Token.Id.False);
    checkNext(&p, Token.Id.String); // IDs
    checkNext(&p, Token.Id.ArrayBegin);
    checkNext(&p, Token.Id.Number);
    checkNext(&p, Token.Id.Number);
    checkNext(&p, Token.Id.Number);
    checkNext(&p, Token.Id.Number);
    checkNext(&p, Token.Id.ArrayEnd);
    checkNext(&p, Token.Id.ObjectEnd);
    checkNext(&p, Token.Id.ObjectEnd);

    testing.expect((try p.next()) == null);
}

// Validate a JSON string. This does not limit number precision so a decoder may not necessarily
// be able to decode the string even if this returns true.
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

// A non-stream JSON parser which constructs a tree of Value's.
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
            .state = State.Simple,
            .copy_strings = copy_strings,
            .stack = Array.init(allocator),
        };
    }

    pub fn deinit(p: *Parser) void {
        p.stack.deinit();
    }

    pub fn reset(p: *Parser) void {
        p.state = State.Simple;
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
            State.ObjectKey => switch (token.id) {
                Token.Id.ObjectEnd => {
                    if (p.stack.len == 1) {
                        return;
                    }

                    var value = p.stack.pop();
                    try p.pushToParent(&value);
                },
                Token.Id.String => {
                    try p.stack.append(try p.parseString(allocator, token, input, i));
                    p.state = State.ObjectValue;
                },
                else => {
                    unreachable;
                },
            },
            State.ObjectValue => {
                var object = &p.stack.items[p.stack.len - 2].Object;
                var key = p.stack.items[p.stack.len - 1].String;

                switch (token.id) {
                    Token.Id.ObjectBegin => {
                        try p.stack.append(Value{ .Object = ObjectMap.init(allocator) });
                        p.state = State.ObjectKey;
                    },
                    Token.Id.ArrayBegin => {
                        try p.stack.append(Value{ .Array = Array.init(allocator) });
                        p.state = State.ArrayValue;
                    },
                    Token.Id.String => {
                        _ = try object.put(key, try p.parseString(allocator, token, input, i));
                        _ = p.stack.pop();
                        p.state = State.ObjectKey;
                    },
                    Token.Id.Number => {
                        _ = try object.put(key, try p.parseNumber(token, input, i));
                        _ = p.stack.pop();
                        p.state = State.ObjectKey;
                    },
                    Token.Id.True => {
                        _ = try object.put(key, Value{ .Bool = true });
                        _ = p.stack.pop();
                        p.state = State.ObjectKey;
                    },
                    Token.Id.False => {
                        _ = try object.put(key, Value{ .Bool = false });
                        _ = p.stack.pop();
                        p.state = State.ObjectKey;
                    },
                    Token.Id.Null => {
                        _ = try object.put(key, Value.Null);
                        _ = p.stack.pop();
                        p.state = State.ObjectKey;
                    },
                    Token.Id.ObjectEnd, Token.Id.ArrayEnd => {
                        unreachable;
                    },
                }
            },
            State.ArrayValue => {
                var array = &p.stack.items[p.stack.len - 1].Array;

                switch (token.id) {
                    Token.Id.ArrayEnd => {
                        if (p.stack.len == 1) {
                            return;
                        }

                        var value = p.stack.pop();
                        try p.pushToParent(&value);
                    },
                    Token.Id.ObjectBegin => {
                        try p.stack.append(Value{ .Object = ObjectMap.init(allocator) });
                        p.state = State.ObjectKey;
                    },
                    Token.Id.ArrayBegin => {
                        try p.stack.append(Value{ .Array = Array.init(allocator) });
                        p.state = State.ArrayValue;
                    },
                    Token.Id.String => {
                        try array.append(try p.parseString(allocator, token, input, i));
                    },
                    Token.Id.Number => {
                        try array.append(try p.parseNumber(token, input, i));
                    },
                    Token.Id.True => {
                        try array.append(Value{ .Bool = true });
                    },
                    Token.Id.False => {
                        try array.append(Value{ .Bool = false });
                    },
                    Token.Id.Null => {
                        try array.append(Value.Null);
                    },
                    Token.Id.ObjectEnd => {
                        unreachable;
                    },
                }
            },
            State.Simple => switch (token.id) {
                Token.Id.ObjectBegin => {
                    try p.stack.append(Value{ .Object = ObjectMap.init(allocator) });
                    p.state = State.ObjectKey;
                },
                Token.Id.ArrayBegin => {
                    try p.stack.append(Value{ .Array = Array.init(allocator) });
                    p.state = State.ArrayValue;
                },
                Token.Id.String => {
                    try p.stack.append(try p.parseString(allocator, token, input, i));
                },
                Token.Id.Number => {
                    try p.stack.append(try p.parseNumber(token, input, i));
                },
                Token.Id.True => {
                    try p.stack.append(Value{ .Bool = true });
                },
                Token.Id.False => {
                    try p.stack.append(Value{ .Bool = false });
                },
                Token.Id.Null => {
                    try p.stack.append(Value.Null);
                },
                Token.Id.ObjectEnd, Token.Id.ArrayEnd => {
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
                p.state = State.ObjectKey;
            },
            // Array Parent -> [ ..., <array>, value ]
            Value.Array => |*array| {
                try array.append(value.*);
                p.state = State.ArrayValue;
            },
            else => {
                unreachable;
            },
        }
    }

    fn parseString(p: *Parser, allocator: *Allocator, token: Token, input: []const u8, i: usize) !Value {
        // TODO: We don't strictly have to copy values which do not contain any escape
        // characters if flagged with the option.
        const slice = token.slice(input, i);
        return Value{ .String = try mem.dupe(allocator, u8, slice) };
    }

    fn parseNumber(p: *Parser, token: Token, input: []const u8, i: usize) !Value {
        return if (token.number_is_integer)
            Value{ .Integer = try std.fmt.parseInt(i64, token.slice(input, i), 10) }
        else
            Value{ .Float = try std.fmt.parseFloat(f64, token.slice(input, i)) };
    }
};

test "json.parser.dynamic" {
    var p = Parser.init(debug.global_allocator, false);
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

    var mem_buffer: [1024 * 20]u8 = undefined;
    const allocator = &std.heap.FixedBufferAllocator.init(&mem_buffer).allocator;
    var parser = Parser.init(allocator, false);
    const tree = try parser.parse(slice_out_stream.getWritten());

    testing.expect(tree.root.Object.get("f").?.value.Bool == false);
    testing.expect(tree.root.Object.get("t").?.value.Bool == true);
    testing.expect(tree.root.Object.get("int").?.value.Integer == 1234);
    testing.expect(tree.root.Object.get("array").?.value.Array.at(0).Null == {});
    testing.expect(tree.root.Object.get("array").?.value.Array.at(1).Float == 12.34);
    testing.expect(mem.eql(u8, tree.root.Object.get("str").?.value.String, "hello"));
}

fn test_parse(json_str: []const u8) !Value {
    var p = Parser.init(debug.global_allocator, false);
    return (try p.parse(json_str)).root;
}

test "parsing empty string gives appropriate error" {
    testing.expectError(error.UnexpectedEndOfJson, test_parse(""));
}

test "integer after float has proper type" {
    const json = try test_parse(
        \\{
        \\  "float": 3.14,
        \\  "ints": [1, 2, 3]
        \\}
    );
    std.testing.expect(json.Object.getValue("ints").?.Array.at(0) == .Integer);
}
