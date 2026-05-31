//! Parsing and classification of string and character literals

const std = @import("std");
const mem = std.mem;

const Compilation = @import("Compilation.zig");
const Diagnostics = @import("Diagnostics.zig");
const Tokenizer = @import("Tokenizer.zig");
const QualType = @import("TypeStore.zig").QualType;
const Source = @import("Source.zig");

pub const Item = union(enum) {
    /// decoded hex or character escape
    value: u32,
    /// validated unicode codepoint
    codepoint: u21,
    /// Char literal in the source text is not utf8 encoded
    improperly_encoded: []const u8,
    /// 1 or more unescaped bytes
    utf8_text: std.unicode.Utf8View,
};

pub const Kind = enum {
    char,
    wide,
    utf_8,
    utf_16,
    utf_32,
    /// Error kind that halts parsing
    unterminated,

    pub fn classify(id: Tokenizer.Token.Id, context: enum { string_literal, char_literal }) ?Kind {
        return switch (context) {
            .string_literal => switch (id) {
                .string_literal => .char,
                .string_literal_utf_8 => .utf_8,
                .string_literal_wide => .wide,
                .string_literal_utf_16 => .utf_16,
                .string_literal_utf_32 => .utf_32,
                .unterminated_string_literal => .unterminated,
                else => null,
            },
            .char_literal => switch (id) {
                .char_literal => .char,
                .char_literal_utf_8 => .utf_8,
                .char_literal_wide => .wide,
                .char_literal_utf_16 => .utf_16,
                .char_literal_utf_32 => .utf_32,
                else => null,
            },
        };
    }

    /// Should only be called for string literals. Determines the result kind of two adjacent string
    /// literals
    pub fn concat(self: Kind, other: Kind) !Kind {
        if (self == .unterminated or other == .unterminated) return .unterminated;
        if (self == other) return self; // can always concat with own kind
        if (self == .char) return other; // char + X -> X
        if (other == .char) return self; // X + char -> X
        return error.CannotConcat;
    }

    /// Largest unicode codepoint that can be represented by this character kind
    /// May be smaller than the largest value that can be represented.
    /// For example u8 char literals may only specify 0-127 via literals or
    /// character escapes, but may specify up to \xFF via hex escapes.
    pub fn maxCodepoint(kind: Kind, comp: *const Compilation) u21 {
        return @intCast(switch (kind) {
            .char => std.math.maxInt(u7),
            .wide => @min(0x10FFFF, comp.wcharMax()),
            .utf_8 => std.math.maxInt(u7),
            .utf_16 => std.math.maxInt(u16),
            .utf_32 => 0x10FFFF,
            .unterminated => unreachable,
        });
    }

    /// Largest integer that can be represented by this character kind
    pub fn maxInt(kind: Kind, comp: *const Compilation) u32 {
        return @intCast(switch (kind) {
            .char, .utf_8 => std.math.maxInt(u8),
            .wide => comp.wcharMax(),
            .utf_16 => std.math.maxInt(u16),
            .utf_32 => std.math.maxInt(u32),
            .unterminated => unreachable,
        });
    }

    /// The C type of a character literal of this kind
    pub fn charLiteralType(kind: Kind, comp: *const Compilation) QualType {
        return switch (kind) {
            .char => .int,
            .wide => comp.type_store.wchar,
            .utf_8 => .uchar,
            .utf_16 => comp.type_store.uint_least16_t,
            .utf_32 => comp.type_store.uint_least32_t,
            .unterminated => unreachable,
        };
    }

    /// Return the actual contents of the literal with leading / trailing quotes and
    /// specifiers removed
    pub fn contentSlice(kind: Kind, delimited: []const u8) []const u8 {
        const end = delimited.len - 1; // remove trailing quote
        return switch (kind) {
            .char => delimited[1..end],
            .wide => delimited[2..end],
            .utf_8 => delimited[3..end],
            .utf_16 => delimited[2..end],
            .utf_32 => delimited[2..end],
            .unterminated => unreachable,
        };
    }

    /// The size of a character unit for a string literal of this kind
    pub fn charUnitSize(kind: Kind, comp: *const Compilation) Compilation.CharUnitSize {
        return switch (kind) {
            .char => .@"1",
            .wide => switch (comp.type_store.wchar.sizeof(comp)) {
                2 => .@"2",
                4 => .@"4",
                else => unreachable,
            },
            .utf_8 => .@"1",
            .utf_16 => .@"2",
            .utf_32 => .@"4",
            .unterminated => unreachable,
        };
    }

    /// Required alignment within aro (on compiler host) for writing to Interner.strings.
    pub fn internalStorageAlignment(kind: Kind, comp: *const Compilation) usize {
        return switch (kind.charUnitSize(comp)) {
            inline else => |size| @alignOf(size.Type()),
        };
    }

    /// The C type of an element of a string literal of this kind
    pub fn elementType(kind: Kind, comp: *const Compilation) QualType {
        return switch (kind) {
            .unterminated => unreachable,
            .char => .char,
            .utf_8 => if (comp.langopts.hasChar8_T()) .uchar else .char,
            else => kind.charLiteralType(comp),
        };
    }
};

pub const Ascii = struct {
    val: u7,

    pub fn init(val: anytype) Ascii {
        return .{ .val = @intCast(val) };
    }

    pub fn format(ctx: Ascii, w: *std.Io.Writer, fmt: []const u8) !usize {
        const i = Diagnostics.templateIndex(w, fmt, "{c}");
        if (std.ascii.isPrint(ctx.val)) {
            try w.writeByte(ctx.val);
        } else {
            try w.print("x{x:0>2}", .{ctx.val});
        }
        return i;
    }
};

pub const Parser = struct {
    comp: *const Compilation,
    literal: []const u8,
    i: usize = 0,
    kind: Kind,
    max_codepoint: u21,
    loc: Source.Location,
    /// Offset added to `loc.byte_offset` when emitting an error.
    offset: u32 = 0,
    expansion_locs: []const Source.Location,
    /// We only want to issue a max of 1 error per char literal
    errored: bool = false,
    /// Makes incorrect encoding always an error.
    /// Used when concatenating string literals.
    incorrect_encoding_is_error: bool = false,
    /// If this is false, do not issue any diagnostics for incorrect character encoding
    /// Incorrect encoding is allowed if we are unescaping an identifier in the preprocessor
    diagnose_incorrect_encoding: bool = true,

    fn prefixLen(self: *const Parser) usize {
        return switch (self.kind) {
            .unterminated => unreachable,
            .char => 0,
            .utf_8 => 2,
            .wide, .utf_16, .utf_32 => 1,
        };
    }

    const Diagnostic = struct {
        fmt: []const u8,
        kind: Diagnostics.Message.Kind,
        opt: ?Diagnostics.Option = null,
        extension: bool = false,

        pub const illegal_char_encoding_error: Diagnostic = .{
            .fmt = "illegal character encoding in character literal",
            .kind = .@"error",
        };

        pub const illegal_char_encoding_warning: Diagnostic = .{
            .fmt = "illegal character encoding in character literal",
            .kind = .warning,
            .opt = .@"invalid-source-encoding",
        };

        pub const missing_hex_escape: Diagnostic = .{
            .fmt = "\\{c} used with no following hex digits",
            .kind = .@"error",
        };

        pub const escape_sequence_overflow: Diagnostic = .{
            .fmt = "escape sequence out of range",
            .kind = .@"error",
        };

        pub const incomplete_universal_character: Diagnostic = .{
            .fmt = "incomplete universal character name",
            .kind = .@"error",
        };

        pub const invalid_universal_character: Diagnostic = .{
            .fmt = "invalid universal character",
            .kind = .@"error",
        };

        pub const char_too_large: Diagnostic = .{
            .fmt = "character too large for enclosing character literal type",
            .kind = .@"error",
        };

        pub const ucn_basic_char_error: Diagnostic = .{
            .fmt = "character '{c}' cannot be specified by a universal character name",
            .kind = .@"error",
        };

        pub const ucn_basic_char_warning: Diagnostic = .{
            .fmt = "specifying character '{c}' with a universal character name is incompatible with C standards before C23",
            .kind = .off,
            .opt = .@"pre-c23-compat",
        };

        pub const ucn_control_char_error: Diagnostic = .{
            .fmt = "universal character name refers to a control character",
            .kind = .@"error",
        };

        pub const ucn_control_char_warning: Diagnostic = .{
            .fmt = "universal character name referring to a control character is incompatible with C standards before C23",
            .kind = .off,
            .opt = .@"pre-c23-compat",
        };

        pub const c89_ucn_in_literal: Diagnostic = .{
            .fmt = "universal character names are only valid in C99 or later",
            .kind = .warning,
            .opt = .unicode,
        };

        const non_standard_escape_char: Diagnostic = .{
            .fmt = "use of non-standard escape character '\\{c}'",
            .kind = .off,
            .extension = true,
        };

        pub const unknown_escape_sequence: Diagnostic = .{
            .fmt = "unknown escape sequence '\\{c}'",
            .kind = .warning,
            .opt = .@"unknown-escape-sequence",
        };

        pub const four_char_char_literal: Diagnostic = .{
            .fmt = "multi-character character constant",
            .opt = .@"four-char-constants",
            .kind = .off,
        };

        pub const multichar_literal_warning: Diagnostic = .{
            .fmt = "multi-character character constant",
            .kind = .warning,
            .opt = .multichar,
        };

        pub const invalid_multichar_literal: Diagnostic = .{
            .fmt = "{s} character literals may not contain multiple characters",
            .kind = .@"error",
        };

        pub const char_lit_too_wide: Diagnostic = .{
            .fmt = "character constant too long for its type",
            .kind = .warning,
        };

        // pub const wide_multichar_literal: Diagnostic = .{
        //     .fmt = "extraneous characters in character constant ignored",
        //     .kind = .warning,
        // };
    };

    pub fn err(p: *Parser, diagnostic: Diagnostic, args: anytype) !void {
        defer p.offset = 0;
        if (p.errored) return;
        defer p.errored = true;
        try p.warn(diagnostic, args);
    }

    pub fn warn(p: *Parser, diagnostic: Diagnostic, args: anytype) Compilation.Error!void {
        defer p.offset = 0;
        if (p.errored) return;
        if (p.comp.diagnostics.effectiveKind(diagnostic) == .off) return;

        var sf = std.heap.stackFallback(1024, p.comp.gpa);
        var allocating: std.Io.Writer.Allocating = .init(sf.get());
        defer allocating.deinit();

        formatArgs(&allocating.writer, diagnostic.fmt, args) catch return error.OutOfMemory;

        var offset_location = p.loc;
        offset_location.byte_offset += p.offset;
        try p.comp.diagnostics.addWithLocation(p.comp, .{
            .kind = diagnostic.kind,
            .text = allocating.written(),
            .opt = diagnostic.opt,
            .extension = diagnostic.extension,
            .location = offset_location.expand(p.comp),
        }, p.expansion_locs, true);
    }

    fn formatArgs(w: *std.Io.Writer, fmt: []const u8, args: anytype) !void {
        var i: usize = 0;
        inline for (std.meta.fields(@TypeOf(args))) |arg_info| {
            const arg = @field(args, arg_info.name);
            i += switch (@TypeOf(arg)) {
                []const u8 => try Diagnostics.formatString(w, fmt[i..], arg),
                Ascii => try arg.format(w, fmt[i..]),
                else => switch (@typeInfo(@TypeOf(arg))) {
                    .int, .comptime_int => try Diagnostics.formatInt(w, fmt[i..], arg),
                    .pointer => try Diagnostics.formatString(w, fmt[i..], arg),
                    else => comptime unreachable,
                },
            };
        }
        try w.writeAll(fmt[i..]);
    }

    pub fn next(p: *Parser) !?Item {
        if (p.i >= p.literal.len) return null;

        const start = p.i;
        if (p.literal[start] != '\\') {
            p.i = mem.indexOfScalarPos(u8, p.literal, start + 1, '\\') orelse p.literal.len;
            const unescaped_slice = p.literal[start..p.i];

            const view = std.unicode.Utf8View.init(unescaped_slice) catch {
                if (!p.diagnose_incorrect_encoding) {
                    return .{ .improperly_encoded = p.literal[start..p.i] };
                }
                if (p.incorrect_encoding_is_error) {
                    try p.warn(.illegal_char_encoding_error, .{});
                    return .{ .improperly_encoded = p.literal[start..p.i] };
                }
                if (p.kind != .char) {
                    try p.err(.illegal_char_encoding_error, .{});
                    return null;
                }
                try p.warn(.illegal_char_encoding_warning, .{});
                return .{ .improperly_encoded = p.literal[start..p.i] };
            };
            return .{ .utf8_text = view };
        }
        switch (p.literal[start + 1]) {
            'u', 'U' => return try p.parseUnicodeEscape(),
            else => return try p.parseEscapedChar(),
        }
    }

    fn parseUnicodeEscape(p: *Parser) !?Item {
        const start = p.i;

        std.debug.assert(p.literal[p.i] == '\\');

        const kind = p.literal[p.i + 1];
        std.debug.assert(kind == 'u' or kind == 'U');

        p.i += 2;
        if (p.i >= p.literal.len or !std.ascii.isHex(p.literal[p.i])) {
            try p.err(.missing_hex_escape, .{Ascii.init(kind)});
            return null;
        }
        const expected_len: usize = if (kind == 'u') 4 else 8;
        var overflowed = false;
        var count: usize = 0;
        var val: u32 = 0;

        for (p.literal[p.i..], 0..) |c, i| {
            if (i == expected_len) break;

            const char = std.fmt.charToDigit(c, 16) catch break;

            val, const overflow = @shlWithOverflow(val, 4);
            overflowed = overflowed or overflow != 0;
            val |= char;
            count += 1;
        }
        p.i += expected_len;

        if (overflowed) {
            p.offset += @intCast(start + p.prefixLen());
            try p.err(.escape_sequence_overflow, .{});
            return null;
        }

        if (count != expected_len) {
            try p.err(.incomplete_universal_character, .{});
            return null;
        }

        if (val > std.math.maxInt(u21) or !std.unicode.utf8ValidCodepoint(@intCast(val))) {
            p.offset += @intCast(start + p.prefixLen());
            try p.err(.invalid_universal_character, .{});
            return null;
        }

        if (val > p.max_codepoint) {
            try p.err(.char_too_large, .{});
            return null;
        }

        if (val < 0xA0 and (val != '$' and val != '@' and val != '`')) {
            const is_error = !p.comp.langopts.standard.atLeast(.c23);
            if (val >= 0x20 and val <= 0x7F) {
                if (is_error) {
                    try p.err(.ucn_basic_char_error, .{Ascii.init(val)});
                } else if (!p.comp.langopts.standard.atLeast(.c23)) {
                    try p.warn(.ucn_basic_char_warning, .{Ascii.init(val)});
                }
            } else {
                if (is_error) {
                    try p.err(.ucn_control_char_error, .{});
                } else if (!p.comp.langopts.standard.atLeast(.c23)) {
                    try p.warn(.ucn_control_char_warning, .{});
                }
            }
        }

        if (!p.comp.langopts.standard.atLeast(.c99)) try p.warn(.c89_ucn_in_literal, .{});
        return .{ .codepoint = @intCast(val) };
    }

    fn parseEscapedChar(p: *Parser) !Item {
        p.i += 1;
        const c = p.literal[p.i];
        defer if (c != 'x' and (c < '0' or c > '7')) {
            p.i += 1;
        };

        switch (c) {
            '\n' => unreachable, // removed by line splicing
            '\r' => unreachable, // removed by line splicing
            '\'', '\"', '\\', '?' => return .{ .value = c },
            'n' => return .{ .value = '\n' },
            'r' => return .{ .value = '\r' },
            't' => return .{ .value = '\t' },
            'a' => return .{ .value = 0x07 },
            'b' => return .{ .value = 0x08 },
            'e', 'E' => {
                p.offset += @intCast(p.i);
                try p.warn(.non_standard_escape_char, .{Ascii.init(c)});
                return .{ .value = 0x1B };
            },
            '(', '{', '[', '%' => {
                p.offset += @intCast(p.i);
                try p.warn(.non_standard_escape_char, .{Ascii.init(c)});
                return .{ .value = c };
            },
            'f' => return .{ .value = 0x0C },
            'v' => return .{ .value = 0x0B },
            'x' => return .{ .value = try p.parseNumberEscape(.hex) },
            '0'...'7' => return .{ .value = try p.parseNumberEscape(.octal) },
            'u', 'U' => unreachable, // handled by parseUnicodeEscape
            else => {
                p.offset += @intCast(p.i);
                try p.warn(.unknown_escape_sequence, .{Ascii.init(c)});
                return .{ .value = c };
            },
        }
    }

    fn parseNumberEscape(p: *Parser, base: EscapeBase) !u32 {
        var val: u32 = 0;
        var count: usize = 0;
        var overflowed = false;
        const start = p.i;
        defer p.i += count;

        const slice = switch (base) {
            .octal => p.literal[p.i..@min(p.literal.len, p.i + 3)], // max 3 chars
            .hex => blk: {
                p.i += 1;
                break :blk p.literal[p.i..]; // skip over 'x'; could have an arbitrary number of chars
            },
        };
        for (slice) |c| {
            const char = std.fmt.charToDigit(c, @intFromEnum(base)) catch break;
            val, const overflow = @shlWithOverflow(val, base.log2());
            if (overflow != 0) overflowed = true;
            val += char;
            count += 1;
        }
        if (overflowed or val > p.kind.maxInt(p.comp)) {
            p.offset += @intCast(start + p.prefixLen());
            try p.err(.escape_sequence_overflow, .{});
            return 0;
        }
        if (count == 0) {
            std.debug.assert(base == .hex);
            try p.err(.missing_hex_escape, .{Ascii.init('x')});
        }
        return val;
    }
};

const EscapeBase = enum(u8) {
    octal = 8,
    hex = 16,

    fn log2(base: EscapeBase) u4 {
        return switch (base) {
            .octal => 3,
            .hex => 4,
        };
    }
};
