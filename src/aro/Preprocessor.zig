const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;
const assert = std.debug.assert;
const Compilation = @import("Compilation.zig");
const Error = Compilation.Error;
const Source = @import("Source.zig");
const Tokenizer = @import("Tokenizer.zig");
const RawToken = Tokenizer.Token;
const Parser = @import("Parser.zig");
const Diagnostics = @import("Diagnostics.zig");
const Token = @import("Tree.zig").Token;
const Attribute = @import("Attribute.zig");
const features = @import("features.zig");

const Preprocessor = @This();
const DefineMap = std.StringHashMap(Macro);
const RawTokenList = std.ArrayList(RawToken);
const max_include_depth = 200;

/// Errors that can be returned when expanding a macro.
/// error.UnknownPragma can occur within Preprocessor.pragma() but
/// it is handled there and doesn't escape that function
const MacroError = Error || error{StopPreprocessing};

const Macro = struct {
    /// Parameters of the function type macro
    params: []const []const u8,

    /// Token constituting the macro body
    tokens: []const RawToken,

    /// If the function type macro has variable number of arguments
    var_args: bool,

    /// Is a function type macro
    is_func: bool,

    /// Is a predefined macro
    is_builtin: bool = false,

    /// Location of macro in the source
    /// `byte_offset` and `line` are used to define the range of tokens included
    /// in the macro.
    loc: Source.Location,

    fn eql(a: Macro, b: Macro, pp: *Preprocessor) bool {
        if (a.tokens.len != b.tokens.len) return false;
        if (a.is_builtin != b.is_builtin) return false;
        for (a.tokens) |t, i| if (!tokEql(pp, t, b.tokens[i])) return false;

        if (a.is_func and b.is_func) {
            if (a.var_args != b.var_args) return false;
            if (a.params.len != b.params.len) return false;
            for (a.params) |p, i| if (!mem.eql(u8, p, b.params[i])) return false;
        }

        return true;
    }

    fn tokEql(pp: *Preprocessor, a: RawToken, b: RawToken) bool {
        return mem.eql(u8, pp.tokSlice(a), pp.tokSlice(b));
    }
};

comp: *Compilation,
arena: std.heap.ArenaAllocator,
defines: DefineMap,
tokens: Token.List = .{},
token_buf: RawTokenList,
char_buf: std.ArrayList(u8),
/// Counter that is incremented each time preprocess() is called
/// Can be used to distinguish multiple preprocessings of the same file
preprocess_count: u32 = 0,
generated_line: u32 = 1,
add_expansion_nl: u32 = 0,
include_depth: u8 = 0,
counter: u32 = 0,
expansion_source_loc: Source.Location = undefined,
poisoned_identifiers: std.StringHashMap(void),
/// Memory is retained to avoid allocation on every single token.
top_expansion_buf: ExpandBuf,

pub fn init(comp: *Compilation) Preprocessor {
    const pp = Preprocessor{
        .comp = comp,
        .arena = std.heap.ArenaAllocator.init(comp.gpa),
        .defines = DefineMap.init(comp.gpa),
        .token_buf = RawTokenList.init(comp.gpa),
        .char_buf = std.ArrayList(u8).init(comp.gpa),
        .poisoned_identifiers = std.StringHashMap(void).init(comp.gpa),
        .top_expansion_buf = ExpandBuf.init(comp.gpa),
    };
    comp.pragmaEvent(.before_preprocess);
    return pp;
}

const builtin_macros = struct {
    const args = [1][]const u8{"X"};

    const has_attribute = [1]RawToken{.{
        .id = .macro_param_has_attribute,
        .source = .generated,
    }};
    const has_warning = [1]RawToken{.{
        .id = .macro_param_has_warning,
        .source = .generated,
    }};
    const has_feature = [1]RawToken{.{
        .id = .macro_param_has_feature,
        .source = .generated,
    }};
    const has_extension = [1]RawToken{.{
        .id = .macro_param_has_extension,
        .source = .generated,
    }};
    const has_builtin = [1]RawToken{.{
        .id = .macro_param_has_builtin,
        .source = .generated,
    }};

    const is_identifier = [1]RawToken{.{
        .id = .macro_param_is_identifier,
        .source = .generated,
    }};

    const pragma_operator = [1]RawToken{.{
        .id = .macro_param_pragma_operator,
        .source = .generated,
    }};

    const file = [1]RawToken{.{
        .id = .macro_file,
        .source = .generated,
    }};
    const line = [1]RawToken{.{
        .id = .macro_line,
        .source = .generated,
    }};
    const counter = [1]RawToken{.{
        .id = .macro_counter,
        .source = .generated,
    }};
};

fn addBuiltinMacro(pp: *Preprocessor, name: []const u8, is_func: bool, tokens: []const RawToken) !void {
    try pp.defines.put(name, .{
        .params = &builtin_macros.args,
        .tokens = tokens,
        .var_args = false,
        .is_func = is_func,
        .loc = .{ .id = .generated },
        .is_builtin = true,
    });
}

pub fn addBuiltinMacros(pp: *Preprocessor) !void {
    try pp.addBuiltinMacro("__has_attribute", true, &builtin_macros.has_attribute);
    try pp.addBuiltinMacro("__has_warning", true, &builtin_macros.has_warning);
    try pp.addBuiltinMacro("__has_feature", true, &builtin_macros.has_feature);
    try pp.addBuiltinMacro("__has_extension", true, &builtin_macros.has_extension);
    try pp.addBuiltinMacro("__has_builtin", true, &builtin_macros.has_builtin);
    try pp.addBuiltinMacro("__is_identifier", true, &builtin_macros.is_identifier);
    try pp.addBuiltinMacro("_Pragma", true, &builtin_macros.pragma_operator);

    try pp.addBuiltinMacro("__FILE__", false, &builtin_macros.file);
    try pp.addBuiltinMacro("__LINE__", false, &builtin_macros.line);
    try pp.addBuiltinMacro("__COUNTER__", false, &builtin_macros.counter);
}

pub fn deinit(pp: *Preprocessor) void {
    pp.defines.deinit();
    for (pp.tokens.items(.expansion_locs)) |loc| Token.free(loc, pp.comp.gpa);
    pp.tokens.deinit(pp.comp.gpa);
    pp.arena.deinit();
    pp.token_buf.deinit();
    pp.char_buf.deinit();
    pp.poisoned_identifiers.deinit();
    pp.top_expansion_buf.deinit();
}

/// Preprocess a source file, returns eof token.
pub fn preprocess(pp: *Preprocessor, source: Source) Error!Token {
    return pp.preprocessExtra(source) catch |err| switch (err) {
        // This cannot occur in the main file and is handled in `include`.
        error.StopPreprocessing => unreachable,
        else => |e| return e,
    };
}

fn preprocessExtra(pp: *Preprocessor, source: Source) MacroError!Token {
    if (source.invalid_utf8_loc) |loc| {
        try pp.comp.diag.add(.{
            .tag = .invalid_utf8,
            .loc = loc,
        }, &.{});
        return error.FatalError;
    }

    pp.preprocess_count += 1;
    var tokenizer = Tokenizer{
        .buf = source.buf,
        .comp = pp.comp,
        .source = source.id,
    };

    // Estimate how many new tokens this source will contain.
    const estimated_token_count = source.buf.len / 8;
    try pp.tokens.ensureTotalCapacity(pp.comp.gpa, pp.tokens.len + estimated_token_count);

    var if_level: u8 = 0;
    var if_kind = std.PackedIntArray(u2, 256).init([1]u2{0} ** 256);
    const until_else = 0;
    const until_endif = 1;
    const until_endif_seen_else = 2;

    var start_of_line = true;
    while (true) {
        var tok = tokenizer.next();
        switch (tok.id) {
            .hash => if (start_of_line) {
                const directive = tokenizer.nextNoWS();
                switch (directive.id) {
                    .keyword_error, .keyword_warning => {
                        // #error tokens..
                        pp.top_expansion_buf.items.len = 0;
                        const char_top = pp.char_buf.items.len;
                        defer pp.char_buf.items.len = char_top;

                        while (true) {
                            tok = tokenizer.next();
                            if (tok.id == .nl or tok.id == .eof) break;
                            if (tok.id == .whitespace) tok.id = .macro_ws;
                            try pp.top_expansion_buf.append(tokFromRaw(tok));
                        }
                        try pp.stringify(pp.top_expansion_buf.items);
                        const slice = pp.char_buf.items[char_top + 1 .. pp.char_buf.items.len - 2];
                        const duped = try pp.comp.diag.arena.allocator().dupe(u8, slice);

                        try pp.comp.diag.add(.{
                            .tag = if (directive.id == .keyword_error) .error_directive else .warning_directive,
                            .loc = .{ .id = tok.source, .byte_offset = directive.start, .line = directive.line },
                            .extra = .{ .str = duped },
                        }, &.{});
                    },
                    .keyword_if => {
                        if (@addWithOverflow(u8, if_level, 1, &if_level))
                            return pp.fatal(directive, "too many #if nestings", .{});

                        if (try pp.expr(&tokenizer)) {
                            if_kind.set(if_level, until_endif);
                        } else {
                            if_kind.set(if_level, until_else);
                            try pp.skip(&tokenizer, .until_else);
                        }
                    },
                    .keyword_ifdef => {
                        if (@addWithOverflow(u8, if_level, 1, &if_level))
                            return pp.fatal(directive, "too many #if nestings", .{});

                        const macro_name = (try pp.expectMacroName(&tokenizer)) orelse continue;
                        try pp.expectNl(&tokenizer);
                        if (pp.defines.get(macro_name) != null) {
                            if_kind.set(if_level, until_endif);
                        } else {
                            if_kind.set(if_level, until_else);
                            try pp.skip(&tokenizer, .until_else);
                        }
                    },
                    .keyword_ifndef => {
                        if (@addWithOverflow(u8, if_level, 1, &if_level))
                            return pp.fatal(directive, "too many #if nestings", .{});

                        const macro_name = (try pp.expectMacroName(&tokenizer)) orelse continue;
                        try pp.expectNl(&tokenizer);
                        if (pp.defines.get(macro_name) == null) {
                            if_kind.set(if_level, until_endif);
                        } else {
                            if_kind.set(if_level, until_else);
                            try pp.skip(&tokenizer, .until_else);
                        }
                    },
                    .keyword_elif => {
                        if (if_level == 0) {
                            try pp.err(directive, .elif_without_if);
                            if_level += 1;
                            if_kind.set(if_level, until_else);
                        }
                        switch (if_kind.get(if_level)) {
                            until_else => if (try pp.expr(&tokenizer)) {
                                if_kind.set(if_level, until_endif);
                            } else {
                                try pp.skip(&tokenizer, .until_else);
                            },
                            until_endif => try pp.skip(&tokenizer, .until_endif),
                            until_endif_seen_else => {
                                try pp.err(directive, .elif_after_else);
                                skipToNl(&tokenizer);
                            },
                            else => unreachable,
                        }
                    },
                    .keyword_else => {
                        try pp.expectNl(&tokenizer);
                        if (if_level == 0) {
                            try pp.err(directive, .else_without_if);
                            continue;
                        }
                        switch (if_kind.get(if_level)) {
                            until_else => if_kind.set(if_level, until_endif_seen_else),
                            until_endif => try pp.skip(&tokenizer, .until_endif_seen_else),
                            until_endif_seen_else => {
                                try pp.err(directive, .else_after_else);
                                skipToNl(&tokenizer);
                            },
                            else => unreachable,
                        }
                    },
                    .keyword_endif => {
                        try pp.expectNl(&tokenizer);
                        if (if_level == 0) {
                            try pp.err(directive, .endif_without_if);
                            continue;
                        }
                        if_level -= 1;
                    },
                    .keyword_define => try pp.define(&tokenizer),
                    .keyword_undef => {
                        const macro_name = (try pp.expectMacroName(&tokenizer)) orelse continue;

                        _ = pp.defines.remove(macro_name);
                        try pp.expectNl(&tokenizer);
                    },
                    .keyword_include => try pp.include(&tokenizer),
                    .keyword_pragma => try pp.pragma(&tokenizer, directive, null, &.{}),
                    .keyword_line => {
                        // #line number "file"
                        const digits = tokenizer.nextNoWS();
                        if (digits.id != .integer_literal) try pp.err(digits, .line_simple_digit);
                        if (digits.id == .eof or digits.id == .nl) continue;
                        const name = tokenizer.nextNoWS();
                        if (name.id == .eof or name.id == .nl) continue;
                        if (name.id != .string_literal) try pp.err(name, .line_invalid_filename);
                        try pp.expectNl(&tokenizer);
                    },
                    .integer_literal => {
                        // # number "file" flags
                        const name = tokenizer.nextNoWS();
                        if (name.id == .eof or name.id == .nl) continue;
                        if (name.id != .string_literal) try pp.err(name, .line_invalid_filename);

                        const flag_1 = tokenizer.nextNoWS();
                        if (flag_1.id == .eof or flag_1.id == .nl) continue;
                        const flag_2 = tokenizer.nextNoWS();
                        if (flag_2.id == .eof or flag_2.id == .nl) continue;
                        const flag_3 = tokenizer.nextNoWS();
                        if (flag_3.id == .eof or flag_3.id == .nl) continue;
                        const flag_4 = tokenizer.nextNoWS();
                        if (flag_4.id == .eof or flag_4.id == .nl) continue;
                        try pp.expectNl(&tokenizer);
                    },
                    .nl => {},
                    .eof => {
                        if (if_level != 0) try pp.err(tok, .unterminated_conditional_directive);
                        return tokFromRaw(directive);
                    },
                    else => {
                        try pp.err(tok, .invalid_preprocessing_directive);
                        skipToNl(&tokenizer);
                    },
                }
            },
            .whitespace => if (pp.comp.only_preprocess) try pp.tokens.append(pp.comp.gpa, tokFromRaw(tok)),
            .nl => {
                start_of_line = true;
                if (pp.comp.only_preprocess) try pp.tokens.append(pp.comp.gpa, tokFromRaw(tok));
            },
            .eof => {
                if (if_level != 0) try pp.err(tok, .unterminated_conditional_directive);
                // The following check needs to occur here and not at the top of the function
                // because a pragma may change the level during preprocessing
                if (source.buf.len > 0 and source.buf[source.buf.len - 1] != '\n') {
                    try pp.err(tok, .newline_eof);
                }
                return tokFromRaw(tok);
            },
            else => {
                if (tok.id.isMacroIdentifier() and pp.poisoned_identifiers.get(pp.tokSlice(tok)) != null) {
                    try pp.err(tok, .poisoned_identifier);
                }
                // Add the token to the buffer doing any necessary expansions.
                start_of_line = false;
                try pp.expandMacro(&tokenizer, tok);
            },
        }
    }
}

/// Get raw token source string.
/// Returned slice is invalidated when comp.generated_buf is updated.
pub fn tokSlice(pp: *Preprocessor, token: RawToken) []const u8 {
    if (token.id.lexeme()) |some| return some;
    const source = pp.comp.getSource(token.source);
    return source.buf[token.start..token.end];
}

/// Convert a token from the Tokenizer into a token used by the parser.
fn tokFromRaw(raw: RawToken) Token {
    return .{
        .id = raw.id,
        .loc = .{
            .id = raw.source,
            .byte_offset = raw.start,
            .line = raw.line,
        },
    };
}

fn err(pp: *Preprocessor, raw: RawToken, tag: Diagnostics.Tag) !void {
    try pp.comp.diag.add(.{
        .tag = tag,
        .loc = .{
            .id = raw.source,
            .byte_offset = raw.start,
            .line = raw.line,
        },
    }, &.{});
}

fn fatal(pp: *Preprocessor, raw: RawToken, comptime fmt: []const u8, args: anytype) Compilation.Error {
    const source = pp.comp.getSource(raw.source);
    const line_col = source.lineCol(.{ .id = raw.source, .line = raw.line, .byte_offset = raw.start });
    return pp.comp.diag.fatal(source.path, line_col.line, raw.line, line_col.col, fmt, args);
}

/// Consume next token, error if it is not an identifier.
fn expectMacroName(pp: *Preprocessor, tokenizer: *Tokenizer) Error!?[]const u8 {
    const macro_name = tokenizer.nextNoWS();
    if (!macro_name.id.isMacroIdentifier()) {
        try pp.err(macro_name, .macro_name_missing);
        skipToNl(tokenizer);
        return null;
    }
    return pp.tokSlice(macro_name);
}

/// Skip until after a newline, error if extra tokens before it.
fn expectNl(pp: *Preprocessor, tokenizer: *Tokenizer) Error!void {
    var sent_err = false;
    while (true) {
        const tok = tokenizer.next();
        if (tok.id == .nl or tok.id == .eof) return;
        if (tok.id == .whitespace) continue;
        if (!sent_err) {
            sent_err = true;
            try pp.err(tok, .extra_tokens_directive_end);
        }
    }
}

/// Consume all tokens until a newline and parse the result into a boolean.
fn expr(pp: *Preprocessor, tokenizer: *Tokenizer) MacroError!bool {
    const start = pp.tokens.len;
    defer {
        for (pp.tokens.items(.expansion_locs)[start..]) |loc| Token.free(loc, pp.comp.gpa);
        pp.tokens.len = start;
    }

    while (true) {
        var tok = tokenizer.next();
        switch (tok.id) {
            .nl, .eof => {
                if (pp.tokens.len == start) {
                    try pp.err(tok, .expected_value_in_expr);
                    try pp.expectNl(tokenizer);
                    return false;
                }
                tok.id = .eof;
                try pp.tokens.append(pp.comp.gpa, tokFromRaw(tok));
                break;
            },
            .keyword_defined => {
                const first = tokenizer.nextNoWS();
                const macro_tok = if (first.id == .l_paren) tokenizer.nextNoWS() else first;
                if (!macro_tok.id.isMacroIdentifier()) try pp.err(macro_tok, .macro_name_missing);
                if (first.id == .l_paren) {
                    const r_paren = tokenizer.nextNoWS();
                    if (r_paren.id != .r_paren) {
                        try pp.err(r_paren, .closing_paren);
                        try pp.err(first, .to_match_paren);
                    }
                }
                tok.id = if (pp.defines.get(pp.tokSlice(macro_tok)) != null) .one else .zero;
            },
            .whitespace => continue,
            else => {},
        }
        try pp.expandMacro(tokenizer, tok);
    }

    if (!pp.tokens.items(.id)[start].validPreprocessorExprStart()) {
        const tok = pp.tokens.get(start);
        try pp.comp.diag.add(.{
            .tag = .invalid_preproc_expr_start,
            .loc = tok.loc,
        }, tok.expansionSlice());
        return false;
    }
    // validate the tokens in the expression
    for (pp.tokens.items(.id)[start..]) |*id, i| {
        switch (id.*) {
            .string_literal,
            .string_literal_utf_16,
            .string_literal_utf_8,
            .string_literal_utf_32,
            .string_literal_wide,
            => {
                const tok = pp.tokens.get(start + i);
                try pp.comp.diag.add(.{
                    .tag = .string_literal_in_pp_expr,
                    .loc = tok.loc,
                }, tok.expansionSlice());
                return false;
            },
            .float_literal,
            .float_literal_f,
            .float_literal_l,
            .imaginary_literal,
            .imaginary_literal_f,
            .imaginary_literal_l,
            => {
                const tok = pp.tokens.get(start + i);
                try pp.comp.diag.add(.{
                    .tag = .float_literal_in_pp_expr,
                    .loc = tok.loc,
                }, tok.expansionSlice());
                return false;
            },
            .plus_plus,
            .minus_minus,
            .plus_equal,
            .minus_equal,
            .asterisk_equal,
            .slash_equal,
            .percent_equal,
            .angle_bracket_angle_bracket_left_equal,
            .angle_bracket_angle_bracket_right_equal,
            .ampersand_equal,
            .caret_equal,
            .pipe_equal,
            .l_bracket,
            .r_bracket,
            .l_brace,
            .r_brace,
            .ellipsis,
            .semicolon,
            .hash,
            .hash_hash,
            .equal,
            .arrow,
            .period,
            => {
                const tok = pp.tokens.get(start + i);
                try pp.comp.diag.add(.{
                    .tag = .invalid_preproc_operator,
                    .loc = tok.loc,
                }, tok.expansionSlice());
                return false;
            },
            else => if (id.isMacroIdentifier()) {
                id.* = .zero; // undefined macro
            },
        }
    }

    // Actually parse it.
    var parser = Parser{
        .pp = pp,
        .tok_ids = pp.tokens.items(.id),
        .tok_i = @intCast(u32, start),
        .arena = pp.arena.allocator(),
        .in_macro = true,
        .data = undefined,
        .strings = undefined,
        .value_map = undefined,
        .scopes = undefined,
        .labels = undefined,
        .decl_buf = undefined,
        .list_buf = undefined,
        .param_buf = undefined,
        .enum_buf = undefined,
        .record_buf = undefined,
        .attr_buf = undefined,
    };
    return parser.macroExpr();
}

/// Skip until #else #elif #endif, return last directive token id.
/// Also skips nested #if ... #endifs.
fn skip(
    pp: *Preprocessor,
    tokenizer: *Tokenizer,
    cont: enum { until_else, until_endif, until_endif_seen_else },
) Error!void {
    var ifs_seen: u32 = 0;
    var line_start = true;
    while (tokenizer.index < tokenizer.buf.len) {
        if (line_start) {
            const saved_tokenizer = tokenizer.*;
            const hash = tokenizer.nextNoWS();
            if (hash.id == .nl) continue;
            line_start = false;
            if (hash.id != .hash) continue;
            const directive = tokenizer.nextNoWS();
            switch (directive.id) {
                .keyword_else => {
                    if (ifs_seen != 0) continue;
                    if (cont == .until_endif_seen_else) {
                        try pp.err(directive, .else_after_else);
                        continue;
                    }
                    tokenizer.* = saved_tokenizer;
                    return;
                },
                .keyword_elif => {
                    if (ifs_seen != 0 or cont == .until_endif) continue;
                    if (cont == .until_endif_seen_else) {
                        try pp.err(directive, .elif_after_else);
                        continue;
                    }
                    tokenizer.* = saved_tokenizer;
                    return;
                },
                .keyword_endif => {
                    if (ifs_seen == 0) {
                        tokenizer.* = saved_tokenizer;
                        return;
                    }
                    ifs_seen -= 1;
                },
                .keyword_if, .keyword_ifdef, .keyword_ifndef => ifs_seen += 1,
                else => {},
            }
        } else if (tokenizer.buf[tokenizer.index] == '\n') {
            line_start = true;
            tokenizer.index += 1;
            tokenizer.line += 1;
        } else {
            line_start = false;
            tokenizer.index += 1;
        }
    } else {
        const eof = tokenizer.next();
        return pp.err(eof, .unterminated_conditional_directive);
    }
}

// Skip until newline, ignore other tokens.
fn skipToNl(tokenizer: *Tokenizer) void {
    while (true) {
        const tok = tokenizer.next();
        if (tok.id == .nl or tok.id == .eof) return;
    }
}

const ExpandBuf = std.ArrayList(Token);
const MacroArguments = std.ArrayList([]const Token);
fn deinitMacroArguments(allocator: Allocator, args: *const MacroArguments) void {
    for (args.items) |item| {
        for (item) |tok| Token.free(tok.expansion_locs, allocator);
        allocator.free(item);
    }
    args.deinit();
}

fn expandObjMacro(pp: *Preprocessor, simple_macro: *const Macro) Error!ExpandBuf {
    var buf = ExpandBuf.init(pp.comp.gpa);
    try buf.ensureTotalCapacity(simple_macro.tokens.len);

    // Add all of the simple_macros tokens to the new buffer handling any concats.
    var i: usize = 0;
    while (i < simple_macro.tokens.len) : (i += 1) {
        const raw = simple_macro.tokens[i];
        const tok = tokFromRaw(raw);
        switch (raw.id) {
            .hash_hash => {
                var rhs = tokFromRaw(simple_macro.tokens[i + 1]);
                i += 1;
                while (rhs.id == .whitespace) {
                    rhs = tokFromRaw(simple_macro.tokens[i + 1]);
                    i += 1;
                }
                try pp.pasteTokens(&buf, &.{rhs});
            },
            .whitespace => if (pp.comp.only_preprocess) buf.appendAssumeCapacity(tok),
            .macro_file => {
                const start = pp.comp.generated_buf.items.len;
                const source = pp.comp.getSource(pp.expansion_source_loc.id);
                try pp.comp.generated_buf.writer().print("\"{s}\"\n", .{source.path});

                buf.appendAssumeCapacity(try pp.makeGeneratedToken(start, .string_literal, tok));
            },
            .macro_line => {
                const start = pp.comp.generated_buf.items.len;
                const source = pp.comp.getSource(pp.expansion_source_loc.id);
                try pp.comp.generated_buf.writer().print("{d}\n", .{source.physicalLine(pp.expansion_source_loc)});

                buf.appendAssumeCapacity(try pp.makeGeneratedToken(start, .integer_literal, tok));
            },
            .macro_counter => {
                defer pp.counter += 1;
                const start = pp.comp.generated_buf.items.len;
                try pp.comp.generated_buf.writer().print("{d}\n", .{pp.counter});

                buf.appendAssumeCapacity(try pp.makeGeneratedToken(start, .integer_literal, tok));
            },
            else => buf.appendAssumeCapacity(tok),
        }
    }

    return buf;
}

/// Join a possibly-parenthesized series of string literal tokens into a single string without
/// leading or trailing quotes. The returned slice is invalidated if pp.char_buf changes.
/// Returns error.ExpectedStringLiteral if parentheses are not balanced, a non-string-literal
/// is encountered, or if no string literals are encountered
/// TODO: destringize (replace all '\\' with a single `\` and all '\"' with a '"')
fn pasteStringsUnsafe(pp: *Preprocessor, toks: []const Token) ![]const u8 {
    const char_top = pp.char_buf.items.len;
    defer pp.char_buf.items.len = char_top;
    var unwrapped = toks;
    if (toks.len >= 2 and toks[0].id == .l_paren and toks[toks.len - 1].id == .r_paren) {
        unwrapped = toks[1 .. toks.len - 1];
    }
    if (unwrapped.len == 0) return error.ExpectedStringLiteral;

    for (unwrapped) |tok| {
        if (tok.id == .macro_ws) continue;
        if (tok.id != .string_literal) return error.ExpectedStringLiteral;
        const str = pp.expandedSlice(tok);
        try pp.char_buf.appendSlice(str[1 .. str.len - 1]);
    }
    return pp.char_buf.items[char_top..];
}

/// Handle the _Pragma operator (implemented as a builtin macro)
fn pragmaOperator(pp: *Preprocessor, arg_tok: Token, operator_loc: Source.Location) !void {
    const arg_slice = pp.expandedSlice(arg_tok);
    const content = arg_slice[1 .. arg_slice.len - 1];
    const directive = "#pragma ";

    pp.char_buf.clearRetainingCapacity();
    const total_len = directive.len + content.len + 1; // destringify can never grow the string, + 1 for newline
    try pp.char_buf.ensureUnusedCapacity(total_len);
    pp.char_buf.appendSliceAssumeCapacity(directive);
    pp.destringify(content);
    pp.char_buf.appendAssumeCapacity('\n');

    const start = pp.comp.generated_buf.items.len;
    try pp.comp.generated_buf.appendSlice(pp.char_buf.items);
    var tmp_tokenizer = Tokenizer{
        .buf = pp.comp.generated_buf.items,
        .comp = pp.comp,
        .index = @intCast(u32, start),
        .source = .generated,
        .line = pp.generated_line,
    };
    pp.generated_line += 1;
    const hash_tok = tmp_tokenizer.next();
    assert(hash_tok.id == .hash);
    const pragma_tok = tmp_tokenizer.next();
    assert(pragma_tok.id == .keyword_pragma);
    try pp.pragma(&tmp_tokenizer, pragma_tok, operator_loc, arg_tok.expansionSlice());
}

/// Inverts the output of the preprocessor stringify (#) operation
/// (except all whitespace is condensed to a single space)
/// writes output to pp.char_buf; assumes capacity is sufficient
/// backslash backslash -> backslash
/// backslash doublequote -> doublequote
/// All other characters remain the same
fn destringify(pp: *Preprocessor, str: []const u8) void {
    var state: enum { start, backslash_seen } = .start;
    for (str) |c| {
        switch (c) {
            '\\' => {
                if (state == .backslash_seen) pp.char_buf.appendAssumeCapacity(c);
                state = if (state == .start) .backslash_seen else .start;
            },
            else => {
                if (state == .backslash_seen and c != '"') pp.char_buf.appendAssumeCapacity('\\');
                pp.char_buf.appendAssumeCapacity(c);
                state = .start;
            },
        }
    }
}

/// Stringify `tokens` into pp.char_buf.
/// See https://gcc.gnu.org/onlinedocs/gcc-11.2.0/cpp/Stringizing.html#Stringizing
fn stringify(pp: *Preprocessor, tokens: []const Token) !void {
    try pp.char_buf.append('"');
    var ws_state: enum { start, need, not_needed } = .start;
    for (tokens) |tok| {
        if (tok.id == .macro_ws) {
            if (ws_state == .start) continue;
            ws_state = .need;
            continue;
        }
        if (ws_state == .need) try pp.char_buf.append(' ');
        ws_state = .not_needed;

        // backslashes not inside strings are not escaped
        const is_str = switch (tok.id) {
            .string_literal,
            .string_literal_utf_16,
            .string_literal_utf_8,
            .string_literal_utf_32,
            .string_literal_wide,
            .char_literal,
            .char_literal_utf_16,
            .char_literal_utf_32,
            .char_literal_wide,
            => true,
            else => false,
        };

        for (pp.expandedSlice(tok)) |c| {
            if (c == '"')
                try pp.char_buf.appendSlice("\\\"")
            else if (c == '\\' and is_str)
                try pp.char_buf.appendSlice("\\\\")
            else
                try pp.char_buf.append(c);
        }
    }
    try pp.char_buf.appendSlice("\"\n");
}

fn handleBuiltinMacro(pp: *Preprocessor, builtin: RawToken.Id, param_toks: []const Token, src_loc: Source.Location) Error!bool {
    switch (builtin) {
        .macro_param_has_attribute,
        .macro_param_has_feature,
        .macro_param_has_extension,
        .macro_param_has_builtin,
        => {
            var invalid: ?Token = null;
            var identifier: ?Token = null;
            for (param_toks) |tok| switch (tok.id) {
                .identifier, .extended_identifier, .builtin_choose_expr, .builtin_va_arg => {
                    if (identifier) |_| invalid = tok else identifier = tok;
                },
                .macro_ws => continue,
                else => {
                    invalid = tok;
                    break;
                },
            };
            if (identifier == null and invalid == null) invalid = .{ .id = .eof, .loc = src_loc };
            if (invalid) |some| {
                try pp.comp.diag.add(
                    .{ .tag = .feature_check_requires_identifier, .loc = some.loc },
                    some.expansionSlice(),
                );
                return false;
            }

            const ident_str = pp.expandedSlice(identifier.?);
            return switch (builtin) {
                .macro_param_has_attribute => Attribute.fromString(.gnu, null, ident_str) != null,
                .macro_param_has_feature => features.hasFeature(pp.comp, ident_str),
                .macro_param_has_extension => features.hasExtension(pp.comp, ident_str),
                .macro_param_has_builtin => pp.comp.builtins.hasBuiltin(ident_str),
                else => unreachable,
            };
        },
        .macro_param_has_warning => {
            const actual_param = pp.pasteStringsUnsafe(param_toks) catch |err| switch (err) {
                error.ExpectedStringLiteral => {
                    try pp.comp.diag.add(.{
                        .tag = .expected_str_literal_in,
                        .loc = param_toks[0].loc,
                        .extra = .{ .str = "__has_warning" },
                    }, param_toks[0].expansionSlice());
                    return false;
                },
                else => |e| return e,
            };
            if (!mem.startsWith(u8, actual_param, "-W")) {
                try pp.comp.diag.add(.{
                    .tag = .malformed_warning_check,
                    .loc = param_toks[0].loc,
                    .extra = .{ .str = "__has_warning" },
                }, param_toks[0].expansionSlice());
                return false;
            }
            const warning_name = actual_param[2..];
            return Diagnostics.warningExists(warning_name);
        },
        .macro_param_is_identifier => {
            var invalid: ?Token = null;
            var identifier: ?Token = null;
            for (param_toks) |tok| switch (tok.id) {
                .macro_ws => continue,
                else => {
                    if (identifier) |_| invalid = tok else identifier = tok;
                },
            };
            if (identifier == null and invalid == null) invalid = .{ .id = .eof, .loc = src_loc };
            if (invalid) |some| {
                try pp.comp.diag.add(.{
                    .tag = .missing_tok_builtin,
                    .loc = some.loc,
                    .extra = .{ .tok_id_expected = .r_paren },
                }, some.expansionSlice());
                return false;
            }

            const id = identifier.?.id;
            return id == .identifier or id == .extended_identifier;
        },
        else => unreachable,
    }
}

fn expandFuncMacro(
    pp: *Preprocessor,
    loc: Source.Location,
    func_macro: *const Macro,
    args: *const MacroArguments,
    expanded_args: *const MacroArguments,
) MacroError!ExpandBuf {
    var buf = ExpandBuf.init(pp.comp.gpa);
    try buf.ensureTotalCapacity(func_macro.tokens.len);
    errdefer buf.deinit();

    var expanded_variable_arguments = ExpandBuf.init(pp.comp.gpa);
    defer expanded_variable_arguments.deinit();
    var variable_arguments = ExpandBuf.init(pp.comp.gpa);
    defer variable_arguments.deinit();

    if (func_macro.var_args) {
        var i: usize = func_macro.params.len;
        while (i < expanded_args.items.len) : (i += 1) {
            try variable_arguments.appendSlice(args.items[i]);
            try expanded_variable_arguments.appendSlice(expanded_args.items[i]);
            if (i != expanded_args.items.len - 1) {
                const comma = Token{ .id = .comma, .loc = .{ .id = .generated } };
                try variable_arguments.append(comma);
                try expanded_variable_arguments.append(comma);
            }
        }
    }

    // token concatenation and expansion phase
    var tok_i: usize = 0;
    while (tok_i < func_macro.tokens.len) : (tok_i += 1) {
        const raw = func_macro.tokens[tok_i];
        switch (raw.id) {
            .hash_hash => while (tok_i + 1 < func_macro.tokens.len) {
                const raw_next = func_macro.tokens[tok_i + 1];
                tok_i += 1;

                const next = switch (raw_next.id) {
                    .macro_ws => continue,
                    .hash_hash => continue,
                    .macro_param, .macro_param_no_expand => args.items[raw_next.end],
                    .keyword_va_args => variable_arguments.items,
                    else => &[1]Token{tokFromRaw(raw_next)},
                };

                try pp.pasteTokens(&buf, next);
                if (next.len != 0) break;
            },
            .macro_param_no_expand => {
                const slice = args.items[raw.end];
                const raw_loc = Source.Location{ .id = raw.source, .byte_offset = raw.start, .line = raw.line };
                try bufCopyTokens(&buf, slice, &.{raw_loc});
            },
            .macro_param => {
                const arg = expanded_args.items[raw.end];
                const raw_loc = Source.Location{ .id = raw.source, .byte_offset = raw.start, .line = raw.line };
                try bufCopyTokens(&buf, arg, &.{raw_loc});
            },
            .keyword_va_args => {
                const raw_loc = Source.Location{ .id = raw.source, .byte_offset = raw.start, .line = raw.line };
                try bufCopyTokens(&buf, expanded_variable_arguments.items, &.{raw_loc});
            },
            .stringify_param, .stringify_va_args => {
                const arg = if (raw.id == .stringify_va_args)
                    variable_arguments.items
                else
                    args.items[raw.end];

                pp.char_buf.clearRetainingCapacity();
                try pp.stringify(arg);

                const start = pp.comp.generated_buf.items.len;
                try pp.comp.generated_buf.appendSlice(pp.char_buf.items);

                try buf.append(try pp.makeGeneratedToken(start, .string_literal, tokFromRaw(raw)));
            },
            .macro_param_has_attribute,
            .macro_param_has_warning,
            .macro_param_has_feature,
            .macro_param_has_extension,
            .macro_param_has_builtin,
            .macro_param_is_identifier,
            => {
                const arg = expanded_args.items[0];
                const result = if (arg.len == 0) blk: {
                    const extra = Diagnostics.Message.Extra{ .arguments = .{ .expected = 1, .actual = 0 } };
                    try pp.comp.diag.add(.{ .tag = .expected_arguments, .loc = loc, .extra = extra }, &.{});
                    break :blk false;
                } else try pp.handleBuiltinMacro(raw.id, arg, loc);
                const start = pp.comp.generated_buf.items.len;
                try pp.comp.generated_buf.writer().print("{}\n", .{@boolToInt(result)});
                try buf.append(try pp.makeGeneratedToken(start, .integer_literal, tokFromRaw(raw)));
            },
            .macro_param_pragma_operator => {
                const param_toks = expanded_args.items[0];
                // Clang and GCC require exactly one token (so, no parentheses or string pasting)
                // even though their error messages indicate otherwise. Ours is slightly more
                // descriptive.
                var invalid: ?Token = null;
                var string: ?Token = null;
                for (param_toks) |tok| switch (tok.id) {
                    .string_literal => {
                        if (string) |_| invalid = tok else string = tok;
                    },
                    .macro_ws => continue,
                    else => {
                        invalid = tok;
                        break;
                    },
                };
                if (string == null and invalid == null) invalid = .{ .loc = loc, .id = .eof };
                if (invalid) |some| try pp.comp.diag.add(
                    .{ .tag = .pragma_operator_string_literal, .loc = some.loc },
                    some.expansionSlice(),
                ) else try pp.pragmaOperator(string.?, loc);
            },
            else => try buf.append(tokFromRaw(raw)),
        }
    }

    return buf;
}

fn shouldExpand(tok: Token, macro: *Macro) bool {
    // macro.loc.line contains the macros end index
    if (tok.loc.id == macro.loc.id and
        tok.loc.byte_offset >= macro.loc.byte_offset and
        tok.loc.byte_offset <= macro.loc.line)
        return false;
    for (tok.expansionSlice()) |loc| {
        if (loc.id == macro.loc.id and
            loc.byte_offset >= macro.loc.byte_offset and
            loc.byte_offset <= macro.loc.line)
            return false;
    }

    return true;
}

fn bufCopyTokens(buf: *ExpandBuf, tokens: []const Token, src: []const Source.Location) !void {
    try buf.ensureUnusedCapacity(tokens.len);
    for (tokens) |tok| {
        var copy = try tok.dupe(buf.allocator);
        try copy.addExpansionLocation(buf.allocator, src);
        buf.appendAssumeCapacity(copy);
    }
}

fn nextBufToken(
    pp: *Preprocessor,
    tokenizer: *Tokenizer,
    buf: *ExpandBuf,
    start_idx: *usize,
    end_idx: *usize,
    extend_buf: bool,
) Error!Token {
    start_idx.* += 1;
    if (start_idx.* == buf.items.len and start_idx.* >= end_idx.*) {
        if (extend_buf) {
            const raw_tok = tokenizer.next();
            if (raw_tok.id.isMacroIdentifier() and
                pp.poisoned_identifiers.get(pp.tokSlice(raw_tok)) != null)
                try pp.err(raw_tok, .poisoned_identifier);

            if (raw_tok.id == .nl) pp.add_expansion_nl += 1;

            const new_tok = tokFromRaw(raw_tok);
            end_idx.* += 1;
            try buf.append(new_tok);
            return new_tok;
        } else {
            return Token{ .id = .eof, .loc = .{ .id = .generated } };
        }
    } else {
        return buf.items[start_idx.*];
    }
}

fn collectMacroFuncArguments(
    pp: *Preprocessor,
    tokenizer: *Tokenizer,
    buf: *ExpandBuf,
    start_idx: *usize,
    end_idx: *usize,
    extend_buf: bool,
    is_builtin: bool,
) Error!(?MacroArguments) {
    const name_tok = buf.items[start_idx.*];
    const saved_tokenizer = tokenizer.*;
    const old_end = end_idx.*;

    while (true) {
        const tok = try nextBufToken(pp, tokenizer, buf, start_idx, end_idx, extend_buf);
        switch (tok.id) {
            .nl, .whitespace, .macro_ws => {},
            .l_paren => break,
            else => {
                if (is_builtin) {
                    try pp.comp.diag.add(.{
                        .tag = .missing_tok_builtin,
                        .loc = tok.loc,
                        .extra = .{ .tok_id_expected = .l_paren },
                    }, tok.expansionSlice());
                }
                // Not a macro function call, go over normal identifier, rewind
                tokenizer.* = saved_tokenizer;
                end_idx.* = old_end;
                return null;
            },
        }
    }

    // collect the arguments.
    var parens: u32 = 0;
    var args = MacroArguments.init(pp.comp.gpa);
    errdefer deinitMacroArguments(pp.comp.gpa, &args);
    var curArgument = std.ArrayList(Token).init(pp.comp.gpa);
    defer curArgument.deinit();
    while (true) {
        var tok = try nextBufToken(pp, tokenizer, buf, start_idx, end_idx, extend_buf);
        switch (tok.id) {
            .comma => {
                if (parens == 0) {
                    try args.append(curArgument.toOwnedSlice());
                } else {
                    try curArgument.append(try tok.dupe(pp.comp.gpa));
                }
            },
            .l_paren => {
                try curArgument.append(try tok.dupe(pp.comp.gpa));
                parens += 1;
            },
            .r_paren => {
                if (parens == 0) {
                    try args.append(curArgument.toOwnedSlice());
                    break;
                } else {
                    try curArgument.append(try tok.dupe(pp.comp.gpa));
                    parens -= 1;
                }
            },
            .eof => {
                deinitMacroArguments(pp.comp.gpa, &args);
                tokenizer.* = saved_tokenizer;
                end_idx.* = old_end;
                try pp.comp.diag.add(
                    .{ .tag = .unterminated_macro_arg_list, .loc = name_tok.loc },
                    name_tok.expansionSlice(),
                );
                return null;
            },
            .nl, .whitespace => {
                try curArgument.append(.{ .id = .macro_ws, .loc = .{ .id = .generated } });
            },
            else => {
                try curArgument.append(try tok.dupe(pp.comp.gpa));
            },
        }
    }

    return args;
}

fn expandMacroExhaustive(
    pp: *Preprocessor,
    tokenizer: *Tokenizer,
    buf: *ExpandBuf,
    start_idx: usize,
    end_idx: usize,
    extend_buf: bool,
) MacroError!void {
    var moving_end_idx = end_idx;
    var advance_index: usize = 0;
    // rescan loop
    var do_rescan = true;
    while (do_rescan) {
        do_rescan = false;
        // expansion loop
        var idx: usize = start_idx + advance_index;
        while (idx < moving_end_idx) {
            const macro_tok = buf.items[idx];
            const macro_entry = pp.defines.getPtr(pp.expandedSlice(macro_tok));
            if (macro_entry == null or !shouldExpand(buf.items[idx], macro_entry.?)) {
                idx += 1;
                continue;
            }
            if (macro_entry) |macro| macro_handler: {
                if (macro.is_func) {
                    var macro_scan_idx = idx;
                    // to be saved in case this doesn't turn out to be a call
                    const args = (try pp.collectMacroFuncArguments(
                        tokenizer,
                        buf,
                        &macro_scan_idx,
                        &moving_end_idx,
                        extend_buf,
                        macro.is_builtin,
                    )) orelse {
                        idx += 1;
                        break :macro_handler;
                    };
                    defer {
                        for (args.items) |item| {
                            pp.comp.gpa.free(item);
                        }
                        args.deinit();
                    }

                    var args_count = @intCast(u32, args.items.len);
                    // if the macro has zero arguments g() args_count is still 1
                    if (args_count == 1 and macro.params.len == 0) args_count = 0;

                    // Validate argument count.
                    const extra = Diagnostics.Message.Extra{
                        .arguments = .{ .expected = @intCast(u32, macro.params.len), .actual = args_count },
                    };
                    if (macro.var_args and args_count < macro.params.len) {
                        try pp.comp.diag.add(
                            .{ .tag = .expected_at_least_arguments, .loc = buf.items[idx].loc, .extra = extra },
                            buf.items[idx].expansionSlice(),
                        );
                        idx += 1;
                        continue;
                    }
                    if (!macro.var_args and args_count != macro.params.len) {
                        try pp.comp.diag.add(
                            .{ .tag = .expected_arguments, .loc = buf.items[idx].loc, .extra = extra },
                            buf.items[idx].expansionSlice(),
                        );
                        idx += 1;
                        continue;
                    }
                    var expanded_args = MacroArguments.init(pp.comp.gpa);
                    defer deinitMacroArguments(pp.comp.gpa, &expanded_args);
                    try expanded_args.ensureTotalCapacity(args.items.len);
                    for (args.items) |arg| {
                        var expand_buf = ExpandBuf.init(pp.comp.gpa);
                        try expand_buf.appendSlice(arg);

                        try pp.expandMacroExhaustive(tokenizer, &expand_buf, 0, expand_buf.items.len, false);

                        expanded_args.appendAssumeCapacity(expand_buf.toOwnedSlice());
                    }

                    var res = try pp.expandFuncMacro(macro_tok.loc, macro, &args, &expanded_args);
                    defer res.deinit();

                    const macro_expansion_locs = macro_tok.expansionSlice();
                    for (res.items) |*tok| {
                        try tok.addExpansionLocation(pp.comp.gpa, &.{macro_tok.loc});
                        try tok.addExpansionLocation(pp.comp.gpa, macro_expansion_locs);
                    }

                    const count = macro_scan_idx - idx + 1;
                    for (buf.items[idx .. idx + count]) |tok| Token.free(tok.expansion_locs, pp.comp.gpa);
                    try buf.replaceRange(idx, count, res.items);
                    // TODO: moving_end_idx += res.items.len - (macro_scan_idx-idx+1)
                    // doesn't work when the RHS is negative (unsigned!)
                    moving_end_idx = moving_end_idx + res.items.len - count;
                    idx += res.items.len;
                    do_rescan = true;
                } else {
                    const res = try pp.expandObjMacro(macro);
                    defer res.deinit();

                    const macro_expansion_locs = macro_tok.expansionSlice();
                    for (res.items) |*tok| {
                        try tok.addExpansionLocation(pp.comp.gpa, &.{macro_tok.loc});
                        try tok.addExpansionLocation(pp.comp.gpa, macro_expansion_locs);
                    }

                    Token.free(buf.items[idx].expansion_locs, pp.comp.gpa);
                    try buf.replaceRange(idx, 1, res.items);
                    idx += res.items.len;
                    moving_end_idx = moving_end_idx + res.items.len - 1;
                    do_rescan = true;
                }
            }
            if (idx - start_idx == advance_index + 1 and !do_rescan) {
                advance_index += 1;
            }
        } // end of replacement phase
    }
    // end of scanning phase

    // trim excess buffer
    for (buf.items[moving_end_idx..]) |item| {
        Token.free(item.expansion_locs, pp.comp.gpa);
    }
    buf.items.len = moving_end_idx;
}

/// Try to expand a macro after a possible candidate has been read from the `tokenizer`
/// into the `raw` token passed as argument
fn expandMacro(pp: *Preprocessor, tokenizer: *Tokenizer, raw: RawToken) MacroError!void {
    var source_tok = tokFromRaw(raw);
    if (!raw.id.isMacroIdentifier()) {
        source_tok.id.simplifyMacroKeyword();
        return pp.tokens.append(pp.comp.gpa, source_tok);
    }
    pp.top_expansion_buf.items.len = 0;
    try pp.top_expansion_buf.append(source_tok);
    pp.expansion_source_loc = source_tok.loc;

    try pp.expandMacroExhaustive(tokenizer, &pp.top_expansion_buf, 0, 1, true);
    try pp.tokens.ensureUnusedCapacity(pp.comp.gpa, pp.top_expansion_buf.items.len);
    for (pp.top_expansion_buf.items) |*tok| {
        if (tok.id == .macro_ws and !pp.comp.only_preprocess) {
            Token.free(tok.expansion_locs, pp.comp.gpa);
            continue;
        }
        tok.id.simplifyMacroKeyword();
        pp.tokens.appendAssumeCapacity(tok.*);
    }
    if (pp.comp.only_preprocess) {
        try pp.tokens.ensureUnusedCapacity(pp.comp.gpa, pp.add_expansion_nl);
        while (pp.add_expansion_nl > 0) : (pp.add_expansion_nl -= 1) {
            pp.tokens.appendAssumeCapacity(.{ .id = .nl, .loc = .{ .id = .generated } });
        }
    }
}

/// Get expanded token source string.
pub fn expandedSlice(pp: *Preprocessor, tok: Token) []const u8 {
    if (tok.id.lexeme()) |some| return some;
    var tmp_tokenizer = Tokenizer{
        .buf = pp.comp.getSource(tok.loc.id).buf,
        .comp = pp.comp,
        .index = tok.loc.byte_offset,
        .source = .generated,
    };
    if (tok.id == .macro_string) {
        while (true) : (tmp_tokenizer.index += 1) {
            if (tmp_tokenizer.buf[tmp_tokenizer.index] == '>') break;
        }
        return tmp_tokenizer.buf[tok.loc.byte_offset .. tmp_tokenizer.index + 1];
    }
    const res = tmp_tokenizer.next();
    return tmp_tokenizer.buf[res.start..res.end];
}

/// Concat two tokens and add the result to pp.generated
fn pasteTokens(pp: *Preprocessor, lhs_toks: *ExpandBuf, rhs_toks: []const Token) Error!void {
    const lhs = while (lhs_toks.popOrNull()) |lhs| {
        if (lhs.id == .macro_ws)
            Token.free(lhs.expansion_locs, pp.comp.gpa)
        else
            break lhs;
    } else {
        return bufCopyTokens(lhs_toks, rhs_toks, &.{});
    };

    var rhs_rest: u32 = 1;
    const rhs = for (rhs_toks) |rhs| {
        if (rhs.id != .macro_ws) break rhs;
        rhs_rest += 1;
    } else {
        return lhs_toks.appendAssumeCapacity(lhs);
    };
    defer Token.free(lhs.expansion_locs, pp.comp.gpa);

    const start = pp.comp.generated_buf.items.len;
    const end = start + pp.expandedSlice(lhs).len + pp.expandedSlice(rhs).len;
    try pp.comp.generated_buf.ensureTotalCapacity(end + 1); // +1 for a newline
    // We cannot use the same slices here since they might be invalidated by `ensureCapacity`
    pp.comp.generated_buf.appendSliceAssumeCapacity(pp.expandedSlice(lhs));
    pp.comp.generated_buf.appendSliceAssumeCapacity(pp.expandedSlice(rhs));
    pp.comp.generated_buf.appendAssumeCapacity('\n');

    // Try to tokenize the result.
    var tmp_tokenizer = Tokenizer{
        .buf = pp.comp.generated_buf.items,
        .comp = pp.comp,
        .index = @intCast(u32, start),
        .source = .generated,
    };
    const pasted_token = tmp_tokenizer.nextNoWS();
    const next = tmp_tokenizer.nextNoWS().id;
    if (next != .nl and next != .eof) {
        try pp.comp.diag.add(.{
            .tag = .pasting_formed_invalid,
            .loc = lhs.loc,
            .extra = .{ .str = try pp.comp.diag.arena.allocator().dupe(
                u8,
                pp.comp.generated_buf.items[start..end],
            ) },
        }, lhs.expansionSlice());
    }

    try lhs_toks.append(try pp.makeGeneratedToken(start, pasted_token.id, lhs));
    try bufCopyTokens(lhs_toks, rhs_toks[rhs_rest..], &.{});
}

fn makeGeneratedToken(pp: *Preprocessor, start: usize, id: Token.Id, source: Token) !Token {
    var pasted_token = Token{ .id = id, .loc = .{
        .id = .generated,
        .byte_offset = @intCast(u32, start),
        .line = pp.generated_line,
    } };
    pp.generated_line += 1;
    try pasted_token.addExpansionLocation(pp.comp.gpa, &.{source.loc});
    try pasted_token.addExpansionLocation(pp.comp.gpa, source.expansionSlice());
    return pasted_token;
}

/// Defines a new macro and warns if it is a duplicate
fn defineMacro(pp: *Preprocessor, name_tok: RawToken, macro: Macro) Error!void {
    const name_str = pp.tokSlice(name_tok);
    const gop = try pp.defines.getOrPut(name_str);
    if (gop.found_existing and !gop.value_ptr.eql(macro, pp)) {
        try pp.comp.diag.add(.{
            .tag = if (gop.value_ptr.is_builtin) .builtin_macro_redefined else .macro_redefined,
            .loc = .{ .id = name_tok.source, .byte_offset = name_tok.start, .line = name_tok.line },
            .extra = .{ .str = name_str },
        }, &.{});
        // TODO add a previous definition note
    }
    gop.value_ptr.* = macro;
}

/// Handle a #define directive.
fn define(pp: *Preprocessor, tokenizer: *Tokenizer) Error!void {
    // Get macro name and validate it.
    const macro_name = tokenizer.nextNoWS();
    if (macro_name.id == .keyword_defined) {
        try pp.err(macro_name, .defined_as_macro_name);
        return skipToNl(tokenizer);
    }
    if (!macro_name.id.isMacroIdentifier()) {
        try pp.err(macro_name, .macro_name_must_be_identifier);
        return skipToNl(tokenizer);
    }

    // Check for function macros and empty defines.
    var first = tokenizer.next();
    switch (first.id) {
        .nl, .eof => return pp.defineMacro(macro_name, .{
            .params = undefined,
            .tokens = undefined,
            .var_args = false,
            .loc = undefined,
            .is_func = false,
        }),
        .whitespace => first = tokenizer.next(),
        .l_paren => return pp.defineFn(tokenizer, macro_name, first),
        else => try pp.err(first, .whitespace_after_macro_name),
    }
    if (first.id == .hash_hash) {
        try pp.err(first, .hash_hash_at_start);
        return skipToNl(tokenizer);
    }
    first.id.simplifyMacroKeyword();

    pp.token_buf.items.len = 0; // Safe to use since we can only be in one directive at a time.

    var need_ws = false;
    // Collect the token body and validate any ## found.
    var tok = first;
    const end_index = while (true) {
        tok.id.simplifyMacroKeyword();
        switch (tok.id) {
            .hash_hash => {
                const next = tokenizer.nextNoWS();
                switch (next.id) {
                    .nl, .eof => {
                        try pp.err(tok, .hash_hash_at_end);
                        return;
                    },
                    .hash_hash => {
                        try pp.err(next, .hash_hash_at_end);
                        return;
                    },
                    else => {},
                }
                try pp.token_buf.append(tok);
                try pp.token_buf.append(next);
            },
            .nl, .eof => break tok.start,
            .whitespace => need_ws = true,
            else => {
                if (tok.id != .whitespace and need_ws) {
                    need_ws = false;
                    try pp.token_buf.append(.{ .id = .macro_ws, .source = .generated });
                }
                try pp.token_buf.append(tok);
            },
        }
        tok = tokenizer.next();
    } else unreachable;

    const list = try pp.arena.allocator().dupe(RawToken, pp.token_buf.items);
    try pp.defineMacro(macro_name, .{
        .loc = .{
            .id = macro_name.source,
            .byte_offset = first.start,
            .line = end_index,
        },
        .tokens = list,
        .params = undefined,
        .is_func = false,
        .var_args = false,
    });
}

/// Handle a function like #define directive.
fn defineFn(pp: *Preprocessor, tokenizer: *Tokenizer, macro_name: RawToken, l_paren: RawToken) Error!void {
    assert(macro_name.id.isMacroIdentifier());
    var params = std.ArrayList([]const u8).init(pp.comp.gpa);
    defer params.deinit();

    // Parse the parameter list.
    var gnu_var_args: []const u8 = "";
    var var_args = false;
    const start_index = while (true) {
        var tok = tokenizer.nextNoWS();
        if (tok.id == .r_paren) break tok.end;
        if (tok.id == .eof) return pp.err(tok, .unterminated_macro_param_list);
        if (tok.id == .ellipsis) {
            var_args = true;
            const r_paren = tokenizer.nextNoWS();
            if (r_paren.id != .r_paren) {
                try pp.err(r_paren, .missing_paren_param_list);
                try pp.err(l_paren, .to_match_paren);
                return skipToNl(tokenizer);
            }
            break r_paren.end;
        }
        if (!tok.id.isMacroIdentifier()) {
            try pp.err(tok, .invalid_token_param_list);
            return skipToNl(tokenizer);
        }

        try params.append(pp.tokSlice(tok));

        tok = tokenizer.nextNoWS();
        if (tok.id == .ellipsis) {
            try pp.err(tok, .gnu_va_macro);
            gnu_var_args = params.pop();
            const r_paren = tokenizer.nextNoWS();
            if (r_paren.id != .r_paren) {
                try pp.err(r_paren, .missing_paren_param_list);
                try pp.err(l_paren, .to_match_paren);
                return skipToNl(tokenizer);
            }
            break r_paren.end;
        } else if (tok.id == .r_paren) {
            break tok.end;
        } else if (tok.id != .comma) {
            try pp.err(tok, .expected_comma_param_list);
            return skipToNl(tokenizer);
        }
    } else unreachable;

    var need_ws = false;
    // Collect the body tokens and validate # and ##'s found.
    pp.token_buf.items.len = 0; // Safe to use since we can only be in one directive at a time.
    const end_index = tok_loop: while (true) {
        var tok = tokenizer.next();
        switch (tok.id) {
            .nl, .eof => break tok.start,
            .whitespace => need_ws = pp.token_buf.items.len != 0,
            .hash => {
                if (tok.id != .whitespace and need_ws) {
                    need_ws = false;
                    try pp.token_buf.append(.{ .id = .macro_ws, .source = .generated });
                }
                const param = tokenizer.nextNoWS();
                blk: {
                    if (var_args and param.id == .keyword_va_args) {
                        tok.id = .stringify_va_args;
                        try pp.token_buf.append(tok);
                        continue :tok_loop;
                    }
                    if (!param.id.isMacroIdentifier()) break :blk;
                    const s = pp.tokSlice(param);
                    if (mem.eql(u8, s, gnu_var_args)) {
                        tok.id = .stringify_va_args;
                        try pp.token_buf.append(tok);
                        continue :tok_loop;
                    }
                    for (params.items) |p, i| {
                        if (mem.eql(u8, p, s)) {
                            tok.id = .stringify_param;
                            tok.end = @intCast(u32, i);
                            try pp.token_buf.append(tok);
                            continue :tok_loop;
                        }
                    }
                }
                try pp.err(param, .hash_not_followed_param);
                return skipToNl(tokenizer);
            },
            .hash_hash => {
                need_ws = false;
                // if ## appears at the beginning, the token buf is still empty
                // in this case, error out
                if (pp.token_buf.items.len == 0) {
                    try pp.err(tok, .hash_hash_at_start);
                    return skipToNl(tokenizer);
                }
                const saved_tokenizer = tokenizer.*;
                const next = tokenizer.nextNoWS();
                if (next.id == .nl or next.id == .eof) {
                    try pp.err(tok, .hash_hash_at_end);
                    return;
                }
                tokenizer.* = saved_tokenizer;
                // convert the previous token to .macro_param_no_expand if it was .macro_param
                if (pp.token_buf.items[pp.token_buf.items.len - 1].id == .macro_param) {
                    pp.token_buf.items[pp.token_buf.items.len - 1].id = .macro_param_no_expand;
                }
                try pp.token_buf.append(tok);
            },
            else => {
                if (tok.id != .whitespace and need_ws) {
                    need_ws = false;
                    try pp.token_buf.append(.{ .id = .macro_ws, .source = .generated });
                }
                if (var_args and tok.id == .keyword_va_args) {
                    // do nothing
                } else if (tok.id.isMacroIdentifier()) {
                    tok.id.simplifyMacroKeyword();
                    const s = pp.tokSlice(tok);
                    if (mem.eql(u8, gnu_var_args, s)) {
                        tok.id = .keyword_va_args;
                    } else for (params.items) |param, i| {
                        if (mem.eql(u8, param, s)) {
                            // NOTE: it doesn't matter to assign .macro_param_no_expand
                            // here in case a ## was the previous token, because
                            // ## processing will eat this token with the same semantics
                            tok.id = .macro_param;
                            tok.end = @intCast(u32, i);
                            break;
                        }
                    }
                }
                try pp.token_buf.append(tok);
            },
        }
    } else unreachable;

    const param_list = try pp.arena.allocator().dupe([]const u8, params.items);
    const token_list = try pp.arena.allocator().dupe(RawToken, pp.token_buf.items);
    try pp.defineMacro(macro_name, .{
        .is_func = true,
        .params = param_list,
        .var_args = var_args or gnu_var_args.len != 0,
        .tokens = token_list,
        .loc = .{
            .id = macro_name.source,
            .byte_offset = start_index,
            .line = end_index,
        },
    });
}

// Handle a #include directive.
fn include(pp: *Preprocessor, tokenizer: *Tokenizer) MacroError!void {
    const new_source = findIncludeSource(pp, tokenizer) catch |er| switch (er) {
        error.InvalidInclude => return,
        else => |e| return e,
    };

    // Prevent stack overflow
    pp.include_depth += 1;
    defer pp.include_depth -= 1;
    if (pp.include_depth > max_include_depth) return;

    _ = pp.preprocessExtra(new_source) catch |err| switch (err) {
        error.StopPreprocessing => {},
        else => |e| return e,
    };
}

/// tokens that are part of a pragma directive can happen in 3 ways:
///     1. directly in the text via `#pragma ...`
///     2. Via a string literal argument to `_Pragma`
///     3. Via a stringified macro argument which is used as an argument to `_Pragma`
/// operator_loc: Location of `_Pragma`; null if this is from #pragma
/// arg_locs: expansion locations of the argument to _Pragma. empty if #pragma or a raw string literal was used
fn makePragmaToken(pp: *Preprocessor, raw: RawToken, operator_loc: ?Source.Location, arg_locs: []const Source.Location) !Token {
    var tok = tokFromRaw(raw);
    if (operator_loc) |loc| {
        try tok.addExpansionLocation(pp.comp.gpa, &.{loc});
    }
    try tok.addExpansionLocation(pp.comp.gpa, arg_locs);
    return tok;
}

/// Handle a pragma directive
fn pragma(pp: *Preprocessor, tokenizer: *Tokenizer, pragma_tok: RawToken, operator_loc: ?Source.Location, arg_locs: []const Source.Location) !void {
    const name_tok = tokenizer.nextNoWS();
    if (name_tok.id == .nl or name_tok.id == .eof) return;

    const name = pp.tokSlice(name_tok);
    try pp.tokens.append(pp.comp.gpa, try pp.makePragmaToken(pragma_tok, operator_loc, arg_locs));
    const pragma_start = @intCast(u32, pp.tokens.len);

    const pragma_name_tok = try pp.makePragmaToken(name_tok, operator_loc, arg_locs);
    try pp.tokens.append(pp.comp.gpa, pragma_name_tok);
    while (true) {
        const next_tok = tokenizer.next();
        if (next_tok.id == .whitespace) continue;
        if (next_tok.id == .eof) {
            try pp.tokens.append(pp.comp.gpa, .{
                .id = .nl,
                .loc = .{ .id = .generated },
            });
            break;
        }
        try pp.tokens.append(pp.comp.gpa, try pp.makePragmaToken(next_tok, operator_loc, arg_locs));
        if (next_tok.id == .nl) break;
    }
    if (pp.comp.getPragma(name)) |prag| unknown: {
        return prag.preprocessorCB(pp, pragma_start) catch |err| switch (err) {
            error.UnknownPragma => break :unknown,
            else => |e| return e,
        };
    }
    return pp.comp.diag.add(.{
        .tag = .unknown_pragma,
        .loc = pragma_name_tok.loc,
    }, pragma_name_tok.expansionSlice());
}

fn findIncludeSource(pp: *Preprocessor, tokenizer: *Tokenizer) !Source {
    const start = pp.tokens.len;
    defer pp.tokens.len = start;

    var first = tokenizer.nextNoWS();
    if (first.id == .angle_bracket_left) to_end: {
        // The tokenizer does not handle <foo> include strings so do it here.
        while (tokenizer.index < tokenizer.buf.len) : (tokenizer.index += 1) {
            switch (tokenizer.buf[tokenizer.index]) {
                '>' => {
                    tokenizer.index += 1;
                    first.end = tokenizer.index;
                    first.id = .macro_string;
                    break :to_end;
                },
                '\n' => break,
                else => {},
            }
        }
        try pp.comp.diag.add(.{
            .tag = .header_str_closing,
            .loc = .{ .id = first.source, .byte_offset = first.start },
        }, &.{});
        try pp.err(first, .header_str_match);
    }
    // Try to expand if the argument is a macro.
    try pp.expandMacro(tokenizer, first);

    // Check that we actually got a string.
    const filename_tok = pp.tokens.get(start);
    switch (filename_tok.id) {
        .string_literal, .macro_string => {},
        else => {
            try pp.err(first, .expected_filename);
            try pp.expectNl(tokenizer);
            return error.InvalidInclude;
        },
    }
    // Error on extra tokens.
    const nl = tokenizer.nextNoWS();
    if ((nl.id != .nl and nl.id != .eof) or pp.tokens.len > start + 1) {
        skipToNl(tokenizer);
        try pp.err(first, .extra_tokens_directive_end);
    }

    // Check for empty filename.
    const tok_slice = pp.expandedSlice(filename_tok);
    if (tok_slice.len < 3) {
        try pp.err(first, .empty_filename);
        return error.InvalidInclude;
    }

    // Find the file.
    const filename = tok_slice[1 .. tok_slice.len - 1];
    return (try pp.comp.findInclude(first, filename, filename_tok.id == .string_literal)) orelse
        pp.fatal(first, "'{s}' not found", .{filename});
}

/// Pretty print tokens and try to preserve whitespace.
pub fn prettyPrintTokens(pp: *Preprocessor, w: anytype) !void {
    var i: u32 = 0;
    while (true) : (i += 1) {
        var cur: Token = pp.tokens.get(i);
        switch (cur.id) {
            .eof => {
                if (pp.tokens.len > 1 and pp.tokens.items(.id)[i - 1] != .nl) try w.writeByte('\n');
                break;
            },
            .nl => try w.writeAll("\n"),
            .keyword_pragma => {
                const pragma_name = pp.expandedSlice(pp.tokens.get(i + 1));
                const end_idx = mem.indexOfScalarPos(Token.Id, pp.tokens.items(.id), i, .nl) orelse i + 1;
                const pragma_len = @intCast(u32, end_idx) - i;

                if (pp.comp.getPragma(pragma_name)) |prag| {
                    if (!prag.shouldPreserveTokens(pp, i + 1)) {
                        i += pragma_len;
                        cur = pp.tokens.get(i);
                        continue;
                    }
                }
                try w.writeAll("#pragma");
                i += 1;
                while (true) : (i += 1) {
                    cur = pp.tokens.get(i);
                    if (cur.id == .nl) {
                        try w.writeByte('\n');
                        break;
                    }
                    try w.writeByte(' ');
                    const slice = pp.expandedSlice(cur);
                    try w.writeAll(slice);
                }
            },
            .whitespace => {
                var slice = pp.expandedSlice(cur);
                while (mem.indexOfScalar(u8, slice, '\n')) |some| {
                    try w.writeByte('\n');
                    slice = slice[some + 1 ..];
                }
                for (slice) |_| try w.writeByte(' ');
            },
            else => {
                const slice = pp.expandedSlice(cur);
                try w.writeAll(slice);
            },
        }
    }
}

test "Preserve pragma tokens sometimes" {
    const allocator = std.testing.allocator;
    const Test = struct {
        fn runPreprocessor(source_text: []const u8) ![]const u8 {
            var buf = std.ArrayList(u8).init(allocator);
            defer buf.deinit();

            var comp = Compilation.init(allocator);
            defer comp.deinit();
            comp.only_preprocess = true;

            try comp.addDefaultPragmaHandlers();

            var pp = Preprocessor.init(&comp);
            defer pp.deinit();

            const test_runner_macros = try comp.addSourceFromBuffer("<test_runner>", source_text);
            const eof = try pp.preprocess(test_runner_macros);
            try pp.tokens.append(pp.comp.gpa, eof);
            try pp.prettyPrintTokens(buf.writer());
            return allocator.dupe(u8, buf.items);
        }

        fn check(source_text: []const u8, expected: []const u8) !void {
            const output = try runPreprocessor(source_text);
            defer allocator.free(output);

            try std.testing.expectEqualStrings(expected, output);
        }
    };
    const preserve_gcc_diagnostic =
        \\#pragma GCC diagnostic error "-Wnewline-eof"
        \\#pragma GCC warning error "-Wnewline-eof"
        \\int x;
        \\#pragma GCC ignored error "-Wnewline-eof"
        \\
    ;
    try Test.check(preserve_gcc_diagnostic, preserve_gcc_diagnostic);

    const omit_once =
        \\#pragma once
        \\int x;
        \\#pragma once
        \\
    ;
    try Test.check(omit_once, "int x;\n");

    const omit_poison =
        \\#pragma GCC poison foobar
        \\
    ;
    try Test.check(omit_poison, "");
}

test "destringify" {
    const allocator = std.testing.allocator;
    const Test = struct {
        fn testDestringify(pp: *Preprocessor, stringified: []const u8, destringified: []const u8) !void {
            pp.char_buf.clearRetainingCapacity();
            try pp.char_buf.ensureUnusedCapacity(stringified.len);
            pp.destringify(stringified);
            try std.testing.expectEqualStrings(destringified, pp.char_buf.items);
        }
    };
    var comp = Compilation.init(allocator);
    defer comp.deinit();
    var pp = Preprocessor.init(&comp);
    defer pp.deinit();

    try Test.testDestringify(&pp, "hello\tworld\n", "hello\tworld\n");
    try Test.testDestringify(&pp,
        \\ \"FOO BAR BAZ\"
    ,
        \\ "FOO BAR BAZ"
    );
    try Test.testDestringify(&pp,
        \\ \\t\\n
        \\
    ,
        \\ \t\n
        \\
    );
}
