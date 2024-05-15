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
const Tree = @import("Tree.zig");
const Token = Tree.Token;
const TokenWithExpansionLocs = Tree.TokenWithExpansionLocs;
const Attribute = @import("Attribute.zig");
const features = @import("features.zig");
const Hideset = @import("Hideset.zig");

const DefineMap = std.StringHashMapUnmanaged(Macro);
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
    loc: Source.Location,

    fn eql(a: Macro, b: Macro, pp: *Preprocessor) bool {
        if (a.tokens.len != b.tokens.len) return false;
        if (a.is_builtin != b.is_builtin) return false;
        for (a.tokens, b.tokens) |a_tok, b_tok| if (!tokEql(pp, a_tok, b_tok)) return false;

        if (a.is_func and b.is_func) {
            if (a.var_args != b.var_args) return false;
            if (a.params.len != b.params.len) return false;
            for (a.params, b.params) |a_param, b_param| if (!mem.eql(u8, a_param, b_param)) return false;
        }

        return true;
    }

    fn tokEql(pp: *Preprocessor, a: RawToken, b: RawToken) bool {
        return mem.eql(u8, pp.tokSlice(a), pp.tokSlice(b));
    }
};

const Preprocessor = @This();

const ExpansionEntry = struct {
    idx: Tree.TokenIndex,
    locs: [*]Source.Location,
};

const TokenState = struct {
    tokens_len: usize,
    expansion_entries_len: usize,
};

comp: *Compilation,
gpa: mem.Allocator,
arena: std.heap.ArenaAllocator,
defines: DefineMap = .{},
/// Do not directly mutate this; use addToken / addTokenAssumeCapacity / ensureTotalTokenCapacity / ensureUnusedTokenCapacity
tokens: Token.List = .{},
/// Do not directly mutate this; must be kept in sync with `tokens`
expansion_entries: std.MultiArrayList(ExpansionEntry) = .{},
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
/// Map from Source.Id to macro name in the `#ifndef` condition which guards the source, if any
include_guards: std.AutoHashMapUnmanaged(Source.Id, []const u8) = .{},

/// Memory is retained to avoid allocation on every single token.
top_expansion_buf: ExpandBuf,

/// Dump current state to stderr.
verbose: bool = false,
preserve_whitespace: bool = false,

/// linemarker tokens. Must be .none unless in -E mode (parser does not handle linemarkers)
linemarkers: Linemarkers = .none,

hideset: Hideset,

pub const parse = Parser.parse;

pub const Linemarkers = enum {
    /// No linemarker tokens. Required setting if parser will run
    none,
    /// #line <num> "filename"
    line_directives,
    /// # <num> "filename" flags
    numeric_directives,
};

pub fn init(comp: *Compilation) Preprocessor {
    const pp = Preprocessor{
        .comp = comp,
        .gpa = comp.gpa,
        .arena = std.heap.ArenaAllocator.init(comp.gpa),
        .token_buf = RawTokenList.init(comp.gpa),
        .char_buf = std.ArrayList(u8).init(comp.gpa),
        .poisoned_identifiers = std.StringHashMap(void).init(comp.gpa),
        .top_expansion_buf = ExpandBuf.init(comp.gpa),
        .hideset = .{ .comp = comp },
    };
    comp.pragmaEvent(.before_preprocess);
    return pp;
}

/// Initialize Preprocessor with builtin macros.
pub fn initDefault(comp: *Compilation) !Preprocessor {
    var pp = init(comp);
    errdefer pp.deinit();
    try pp.addBuiltinMacros();
    return pp;
}

const builtin_macros = struct {
    const args = [1][]const u8{"X"};

    const has_attribute = [1]RawToken{.{
        .id = .macro_param_has_attribute,
        .source = .generated,
    }};
    const has_c_attribute = [1]RawToken{.{
        .id = .macro_param_has_c_attribute,
        .source = .generated,
    }};
    const has_declspec_attribute = [1]RawToken{.{
        .id = .macro_param_has_declspec_attribute,
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
    const has_include = [1]RawToken{.{
        .id = .macro_param_has_include,
        .source = .generated,
    }};
    const has_include_next = [1]RawToken{.{
        .id = .macro_param_has_include_next,
        .source = .generated,
    }};
    const has_embed = [1]RawToken{.{
        .id = .macro_param_has_embed,
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
    try pp.defines.putNoClobber(pp.gpa, name, .{
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
    try pp.addBuiltinMacro("__has_c_attribute", true, &builtin_macros.has_c_attribute);
    try pp.addBuiltinMacro("__has_declspec_attribute", true, &builtin_macros.has_declspec_attribute);
    try pp.addBuiltinMacro("__has_warning", true, &builtin_macros.has_warning);
    try pp.addBuiltinMacro("__has_feature", true, &builtin_macros.has_feature);
    try pp.addBuiltinMacro("__has_extension", true, &builtin_macros.has_extension);
    try pp.addBuiltinMacro("__has_builtin", true, &builtin_macros.has_builtin);
    try pp.addBuiltinMacro("__has_include", true, &builtin_macros.has_include);
    try pp.addBuiltinMacro("__has_include_next", true, &builtin_macros.has_include_next);
    try pp.addBuiltinMacro("__has_embed", true, &builtin_macros.has_embed);
    try pp.addBuiltinMacro("__is_identifier", true, &builtin_macros.is_identifier);
    try pp.addBuiltinMacro("_Pragma", true, &builtin_macros.pragma_operator);

    try pp.addBuiltinMacro("__FILE__", false, &builtin_macros.file);
    try pp.addBuiltinMacro("__LINE__", false, &builtin_macros.line);
    try pp.addBuiltinMacro("__COUNTER__", false, &builtin_macros.counter);
}

pub fn deinit(pp: *Preprocessor) void {
    pp.defines.deinit(pp.gpa);
    pp.tokens.deinit(pp.gpa);
    pp.arena.deinit();
    pp.token_buf.deinit();
    pp.char_buf.deinit();
    pp.poisoned_identifiers.deinit();
    pp.include_guards.deinit(pp.gpa);
    pp.top_expansion_buf.deinit();
    pp.hideset.deinit();
    for (pp.expansion_entries.items(.locs)) |locs| TokenWithExpansionLocs.free(locs, pp.gpa);
    pp.expansion_entries.deinit(pp.gpa);
}

/// Free buffers that are not needed after preprocessing
fn clearBuffers(pp: *Preprocessor) void {
    pp.token_buf.clearAndFree();
    pp.char_buf.clearAndFree();
    pp.top_expansion_buf.clearAndFree();
    pp.hideset.clearAndFree();
}

pub fn expansionSlice(pp: *Preprocessor, tok: Tree.TokenIndex) []Source.Location {
    const S = struct {
        fn order_token_index(context: void, lhs: Tree.TokenIndex, rhs: Tree.TokenIndex) std.math.Order {
            _ = context;
            return std.math.order(lhs, rhs);
        }
    };

    const indices = pp.expansion_entries.items(.idx);
    const idx = std.sort.binarySearch(Tree.TokenIndex, tok, indices, {}, S.order_token_index) orelse return &.{};
    const locs = pp.expansion_entries.items(.locs)[idx];
    var i: usize = 0;
    while (locs[i].id != .unused) : (i += 1) {}
    return locs[0..i];
}

/// Preprocess a compilation unit of sources into a parsable list of tokens.
pub fn preprocessSources(pp: *Preprocessor, sources: []const Source) Error!void {
    assert(sources.len > 1);
    const first = sources[0];
    try pp.addIncludeStart(first);
    for (sources[1..]) |header| {
        try pp.addIncludeStart(header);
        _ = try pp.preprocess(header);
    }
    try pp.addIncludeResume(first.id, 0, 1);
    const eof = try pp.preprocess(first);
    try pp.addToken(eof);
    pp.clearBuffers();
}

/// Preprocess a source file, returns eof token.
pub fn preprocess(pp: *Preprocessor, source: Source) Error!TokenWithExpansionLocs {
    const eof = pp.preprocessExtra(source) catch |er| switch (er) {
        // This cannot occur in the main file and is handled in `include`.
        error.StopPreprocessing => unreachable,
        else => |e| return e,
    };
    try eof.checkMsEof(source, pp.comp);
    return eof;
}

/// Tokenize a file without any preprocessing, returns eof token.
pub fn tokenize(pp: *Preprocessor, source: Source) Error!Token {
    assert(pp.linemarkers == .none);
    assert(pp.preserve_whitespace == false);
    var tokenizer = Tokenizer{
        .buf = source.buf,
        .comp = pp.comp,
        .source = source.id,
    };

    // Estimate how many new tokens this source will contain.
    const estimated_token_count = source.buf.len / 8;
    try pp.ensureTotalTokenCapacity(pp.tokens.len + estimated_token_count);

    while (true) {
        const tok = tokenizer.next();
        if (tok.id == .eof) return tokFromRaw(tok);
        try pp.addToken(tokFromRaw(tok));
    }
}

pub fn addIncludeStart(pp: *Preprocessor, source: Source) !void {
    if (pp.linemarkers == .none) return;
    try pp.addToken(.{ .id = .include_start, .loc = .{
        .id = source.id,
        .byte_offset = std.math.maxInt(u32),
        .line = 1,
    } });
}

pub fn addIncludeResume(pp: *Preprocessor, source: Source.Id, offset: u32, line: u32) !void {
    if (pp.linemarkers == .none) return;
    try pp.addToken(.{ .id = .include_resume, .loc = .{
        .id = source,
        .byte_offset = offset,
        .line = line,
    } });
}

fn invalidTokenDiagnostic(tok_id: Token.Id) Diagnostics.Tag {
    return switch (tok_id) {
        .unterminated_string_literal => .unterminated_string_literal_warning,
        .empty_char_literal => .empty_char_literal_warning,
        .unterminated_char_literal => .unterminated_char_literal_warning,
        else => unreachable,
    };
}

/// Return the name of the #ifndef guard macro that starts a source, if any.
fn findIncludeGuard(pp: *Preprocessor, source: Source) ?[]const u8 {
    var tokenizer = Tokenizer{
        .buf = source.buf,
        .langopts = pp.comp.langopts,
        .source = source.id,
    };
    var hash = tokenizer.nextNoWS();
    while (hash.id == .nl) hash = tokenizer.nextNoWS();
    if (hash.id != .hash) return null;
    const ifndef = tokenizer.nextNoWS();
    if (ifndef.id != .keyword_ifndef) return null;
    const guard = tokenizer.nextNoWS();
    if (guard.id != .identifier) return null;
    return pp.tokSlice(guard);
}

fn preprocessExtra(pp: *Preprocessor, source: Source) MacroError!TokenWithExpansionLocs {
    var guard_name = pp.findIncludeGuard(source);

    pp.preprocess_count += 1;
    var tokenizer = Tokenizer{
        .buf = source.buf,
        .langopts = pp.comp.langopts,
        .source = source.id,
    };

    // Estimate how many new tokens this source will contain.
    const estimated_token_count = source.buf.len / 8;
    try pp.ensureTotalTokenCapacity(pp.tokens.len + estimated_token_count);

    var if_level: u8 = 0;
    var if_kind = std.PackedIntArray(u2, 256).init([1]u2{0} ** 256);
    const until_else = 0;
    const until_endif = 1;
    const until_endif_seen_else = 2;

    var start_of_line = true;
    while (true) {
        var tok = tokenizer.next();
        switch (tok.id) {
            .hash => if (!start_of_line) try pp.addToken(tokFromRaw(tok)) else {
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
                        const duped = try pp.comp.diagnostics.arena.allocator().dupe(u8, slice);

                        try pp.comp.addDiagnostic(.{
                            .tag = if (directive.id == .keyword_error) .error_directive else .warning_directive,
                            .loc = .{ .id = tok.source, .byte_offset = directive.start, .line = directive.line },
                            .extra = .{ .str = duped },
                        }, &.{});
                    },
                    .keyword_if => {
                        const sum, const overflowed = @addWithOverflow(if_level, 1);
                        if (overflowed != 0)
                            return pp.fatal(directive, "too many #if nestings", .{});
                        if_level = sum;

                        if (try pp.expr(&tokenizer)) {
                            if_kind.set(if_level, until_endif);
                            if (pp.verbose) {
                                pp.verboseLog(directive, "entering then branch of #if", .{});
                            }
                        } else {
                            if_kind.set(if_level, until_else);
                            try pp.skip(&tokenizer, .until_else);
                            if (pp.verbose) {
                                pp.verboseLog(directive, "entering else branch of #if", .{});
                            }
                        }
                    },
                    .keyword_ifdef => {
                        const sum, const overflowed = @addWithOverflow(if_level, 1);
                        if (overflowed != 0)
                            return pp.fatal(directive, "too many #if nestings", .{});
                        if_level = sum;

                        const macro_name = (try pp.expectMacroName(&tokenizer)) orelse continue;
                        try pp.expectNl(&tokenizer);
                        if (pp.defines.get(macro_name) != null) {
                            if_kind.set(if_level, until_endif);
                            if (pp.verbose) {
                                pp.verboseLog(directive, "entering then branch of #ifdef", .{});
                            }
                        } else {
                            if_kind.set(if_level, until_else);
                            try pp.skip(&tokenizer, .until_else);
                            if (pp.verbose) {
                                pp.verboseLog(directive, "entering else branch of #ifdef", .{});
                            }
                        }
                    },
                    .keyword_ifndef => {
                        const sum, const overflowed = @addWithOverflow(if_level, 1);
                        if (overflowed != 0)
                            return pp.fatal(directive, "too many #if nestings", .{});
                        if_level = sum;

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
                        } else if (if_level == 1) {
                            guard_name = null;
                        }
                        switch (if_kind.get(if_level)) {
                            until_else => if (try pp.expr(&tokenizer)) {
                                if_kind.set(if_level, until_endif);
                                if (pp.verbose) {
                                    pp.verboseLog(directive, "entering then branch of #elif", .{});
                                }
                            } else {
                                try pp.skip(&tokenizer, .until_else);
                                if (pp.verbose) {
                                    pp.verboseLog(directive, "entering else branch of #elif", .{});
                                }
                            },
                            until_endif => try pp.skip(&tokenizer, .until_endif),
                            until_endif_seen_else => {
                                try pp.err(directive, .elif_after_else);
                                skipToNl(&tokenizer);
                            },
                            else => unreachable,
                        }
                    },
                    .keyword_elifdef => {
                        if (if_level == 0) {
                            try pp.err(directive, .elifdef_without_if);
                            if_level += 1;
                            if_kind.set(if_level, until_else);
                        } else if (if_level == 1) {
                            guard_name = null;
                        }
                        switch (if_kind.get(if_level)) {
                            until_else => {
                                const macro_name = try pp.expectMacroName(&tokenizer);
                                if (macro_name == null) {
                                    if_kind.set(if_level, until_else);
                                    try pp.skip(&tokenizer, .until_else);
                                    if (pp.verbose) {
                                        pp.verboseLog(directive, "entering else branch of #elifdef", .{});
                                    }
                                } else {
                                    try pp.expectNl(&tokenizer);
                                    if (pp.defines.get(macro_name.?) != null) {
                                        if_kind.set(if_level, until_endif);
                                        if (pp.verbose) {
                                            pp.verboseLog(directive, "entering then branch of #elifdef", .{});
                                        }
                                    } else {
                                        if_kind.set(if_level, until_else);
                                        try pp.skip(&tokenizer, .until_else);
                                        if (pp.verbose) {
                                            pp.verboseLog(directive, "entering else branch of #elifdef", .{});
                                        }
                                    }
                                }
                            },
                            until_endif => try pp.skip(&tokenizer, .until_endif),
                            until_endif_seen_else => {
                                try pp.err(directive, .elifdef_after_else);
                                skipToNl(&tokenizer);
                            },
                            else => unreachable,
                        }
                    },
                    .keyword_elifndef => {
                        if (if_level == 0) {
                            try pp.err(directive, .elifdef_without_if);
                            if_level += 1;
                            if_kind.set(if_level, until_else);
                        } else if (if_level == 1) {
                            guard_name = null;
                        }
                        switch (if_kind.get(if_level)) {
                            until_else => {
                                const macro_name = try pp.expectMacroName(&tokenizer);
                                if (macro_name == null) {
                                    if_kind.set(if_level, until_else);
                                    try pp.skip(&tokenizer, .until_else);
                                    if (pp.verbose) {
                                        pp.verboseLog(directive, "entering else branch of #elifndef", .{});
                                    }
                                } else {
                                    try pp.expectNl(&tokenizer);
                                    if (pp.defines.get(macro_name.?) == null) {
                                        if_kind.set(if_level, until_endif);
                                        if (pp.verbose) {
                                            pp.verboseLog(directive, "entering then branch of #elifndef", .{});
                                        }
                                    } else {
                                        if_kind.set(if_level, until_else);
                                        try pp.skip(&tokenizer, .until_else);
                                        if (pp.verbose) {
                                            pp.verboseLog(directive, "entering else branch of #elifndef", .{});
                                        }
                                    }
                                }
                            },
                            until_endif => try pp.skip(&tokenizer, .until_endif),
                            until_endif_seen_else => {
                                try pp.err(directive, .elifdef_after_else);
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
                        } else if (if_level == 1) {
                            guard_name = null;
                        }
                        switch (if_kind.get(if_level)) {
                            until_else => {
                                if_kind.set(if_level, until_endif_seen_else);
                                if (pp.verbose) {
                                    pp.verboseLog(directive, "#else branch here", .{});
                                }
                            },
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
                            guard_name = null;
                            try pp.err(directive, .endif_without_if);
                            continue;
                        } else if (if_level == 1) {
                            const saved_tokenizer = tokenizer;
                            defer tokenizer = saved_tokenizer;

                            var next = tokenizer.nextNoWS();
                            while (next.id == .nl) : (next = tokenizer.nextNoWS()) {}
                            if (next.id != .eof) guard_name = null;
                        }
                        if_level -= 1;
                    },
                    .keyword_define => try pp.define(&tokenizer),
                    .keyword_undef => {
                        const macro_name = (try pp.expectMacroName(&tokenizer)) orelse continue;

                        _ = pp.defines.remove(macro_name);
                        try pp.expectNl(&tokenizer);
                    },
                    .keyword_include => {
                        try pp.include(&tokenizer, .first);
                        continue;
                    },
                    .keyword_include_next => {
                        try pp.comp.addDiagnostic(.{
                            .tag = .include_next,
                            .loc = .{ .id = tok.source, .byte_offset = directive.start, .line = directive.line },
                        }, &.{});
                        if (pp.include_depth == 0) {
                            try pp.comp.addDiagnostic(.{
                                .tag = .include_next_outside_header,
                                .loc = .{ .id = tok.source, .byte_offset = directive.start, .line = directive.line },
                            }, &.{});
                            try pp.include(&tokenizer, .first);
                        } else {
                            try pp.include(&tokenizer, .next);
                        }
                    },
                    .keyword_embed => try pp.embed(&tokenizer),
                    .keyword_pragma => {
                        try pp.pragma(&tokenizer, directive, null, &.{});
                        continue;
                    },
                    .keyword_line => {
                        // #line number "file"
                        const digits = tokenizer.nextNoWS();
                        if (digits.id != .pp_num) try pp.err(digits, .line_simple_digit);
                        // TODO: validate that the pp_num token is solely digits

                        if (digits.id == .eof or digits.id == .nl) continue;
                        const name = tokenizer.nextNoWS();
                        if (name.id == .eof or name.id == .nl) continue;
                        if (name.id != .string_literal) try pp.err(name, .line_invalid_filename);
                        try pp.expectNl(&tokenizer);
                    },
                    .pp_num => {
                        // # number "file" flags
                        // TODO: validate that the pp_num token is solely digits
                        // if not, emit `GNU line marker directive requires a simple digit sequence`
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
                if (pp.preserve_whitespace) {
                    tok.id = .nl;
                    try pp.addToken(tokFromRaw(tok));
                }
            },
            .whitespace => if (pp.preserve_whitespace) try pp.addToken(tokFromRaw(tok)),
            .nl => {
                start_of_line = true;
                if (pp.preserve_whitespace) try pp.addToken(tokFromRaw(tok));
            },
            .eof => {
                if (if_level != 0) try pp.err(tok, .unterminated_conditional_directive);
                // The following check needs to occur here and not at the top of the function
                // because a pragma may change the level during preprocessing
                if (source.buf.len > 0 and source.buf[source.buf.len - 1] != '\n') {
                    try pp.err(tok, .newline_eof);
                }
                if (guard_name) |name| {
                    if (try pp.include_guards.fetchPut(pp.gpa, source.id, name)) |prev| {
                        assert(mem.eql(u8, name, prev.value));
                    }
                }
                return tokFromRaw(tok);
            },
            .unterminated_string_literal, .unterminated_char_literal, .empty_char_literal => |tag| {
                start_of_line = false;
                try pp.err(tok, invalidTokenDiagnostic(tag));
                try pp.expandMacro(&tokenizer, tok);
            },
            .unterminated_comment => try pp.err(tok, .unterminated_comment),
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
pub fn tokSlice(pp: *Preprocessor, token: anytype) []const u8 {
    if (token.id.lexeme()) |some| return some;
    const source = pp.comp.getSource(token.source);
    return source.buf[token.start..token.end];
}

/// Convert a token from the Tokenizer into a token used by the parser.
fn tokFromRaw(raw: RawToken) TokenWithExpansionLocs {
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
    try pp.comp.addDiagnostic(.{
        .tag = tag,
        .loc = .{
            .id = raw.source,
            .byte_offset = raw.start,
            .line = raw.line,
        },
    }, &.{});
}

fn errStr(pp: *Preprocessor, tok: TokenWithExpansionLocs, tag: Diagnostics.Tag, str: []const u8) !void {
    try pp.comp.addDiagnostic(.{
        .tag = tag,
        .loc = tok.loc,
        .extra = .{ .str = str },
    }, tok.expansionSlice());
}

fn fatal(pp: *Preprocessor, raw: RawToken, comptime fmt: []const u8, args: anytype) Compilation.Error {
    try pp.comp.diagnostics.list.append(pp.gpa, .{
        .tag = .cli_error,
        .kind = .@"fatal error",
        .extra = .{ .str = try std.fmt.allocPrint(pp.comp.diagnostics.arena.allocator(), fmt, args) },
        .loc = .{
            .id = raw.source,
            .byte_offset = raw.start,
            .line = raw.line,
        },
    });
    return error.FatalError;
}

fn fatalNotFound(pp: *Preprocessor, tok: TokenWithExpansionLocs, filename: []const u8) Compilation.Error {
    const old = pp.comp.diagnostics.fatal_errors;
    pp.comp.diagnostics.fatal_errors = true;
    defer pp.comp.diagnostics.fatal_errors = old;

    try pp.comp.diagnostics.addExtra(pp.comp.langopts, .{ .tag = .cli_error, .loc = tok.loc, .extra = .{
        .str = try std.fmt.allocPrint(pp.comp.diagnostics.arena.allocator(), "'{s}' not found", .{filename}),
    } }, tok.expansionSlice(), false);
    unreachable; // addExtra should've returned FatalError
}

fn verboseLog(pp: *Preprocessor, raw: RawToken, comptime fmt: []const u8, args: anytype) void {
    const source = pp.comp.getSource(raw.source);
    const line_col = source.lineCol(.{ .id = raw.source, .line = raw.line, .byte_offset = raw.start });

    const stderr = std.io.getStdErr().writer();
    var buf_writer = std.io.bufferedWriter(stderr);
    const writer = buf_writer.writer();
    defer buf_writer.flush() catch {};
    writer.print("{s}:{d}:{d}: ", .{ source.path, line_col.line_no, line_col.col }) catch return;
    writer.print(fmt, args) catch return;
    writer.writeByte('\n') catch return;
    writer.writeAll(line_col.line) catch return;
    writer.writeByte('\n') catch return;
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
        if (tok.id == .whitespace or tok.id == .comment) continue;
        if (!sent_err) {
            sent_err = true;
            try pp.err(tok, .extra_tokens_directive_end);
        }
    }
}

fn getTokenState(pp: *const Preprocessor) TokenState {
    return .{
        .tokens_len = pp.tokens.len,
        .expansion_entries_len = pp.expansion_entries.len,
    };
}

fn restoreTokenState(pp: *Preprocessor, state: TokenState) void {
    pp.tokens.len = state.tokens_len;
    pp.expansion_entries.len = state.expansion_entries_len;
}

/// Consume all tokens until a newline and parse the result into a boolean.
fn expr(pp: *Preprocessor, tokenizer: *Tokenizer) MacroError!bool {
    const token_state = pp.getTokenState();
    defer {
        for (pp.top_expansion_buf.items) |tok| TokenWithExpansionLocs.free(tok.expansion_locs, pp.gpa);
        pp.restoreTokenState(token_state);
    }

    pp.top_expansion_buf.items.len = 0;
    const eof = while (true) {
        const tok = tokenizer.next();
        switch (tok.id) {
            .nl, .eof => break tok,
            .whitespace => if (pp.top_expansion_buf.items.len == 0) continue,
            else => {},
        }
        try pp.top_expansion_buf.append(tokFromRaw(tok));
    } else unreachable;
    if (pp.top_expansion_buf.items.len != 0) {
        pp.expansion_source_loc = pp.top_expansion_buf.items[0].loc;
        pp.hideset.clearRetainingCapacity();
        try pp.expandMacroExhaustive(tokenizer, &pp.top_expansion_buf, 0, pp.top_expansion_buf.items.len, false, .expr);
    }
    for (pp.top_expansion_buf.items) |tok| {
        if (tok.id == .macro_ws) continue;
        if (!tok.id.validPreprocessorExprStart()) {
            try pp.comp.addDiagnostic(.{
                .tag = .invalid_preproc_expr_start,
                .loc = tok.loc,
            }, tok.expansionSlice());
            return false;
        }
        break;
    } else {
        try pp.err(eof, .expected_value_in_expr);
        return false;
    }

    // validate the tokens in the expression
    try pp.ensureUnusedTokenCapacity(pp.top_expansion_buf.items.len);
    var i: usize = 0;
    const items = pp.top_expansion_buf.items;
    while (i < items.len) : (i += 1) {
        var tok = items[i];
        switch (tok.id) {
            .string_literal,
            .string_literal_utf_16,
            .string_literal_utf_8,
            .string_literal_utf_32,
            .string_literal_wide,
            => {
                try pp.comp.addDiagnostic(.{
                    .tag = .string_literal_in_pp_expr,
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
                try pp.comp.addDiagnostic(.{
                    .tag = .invalid_preproc_operator,
                    .loc = tok.loc,
                }, tok.expansionSlice());
                return false;
            },
            .macro_ws, .whitespace => continue,
            .keyword_false => tok.id = .zero,
            .keyword_true => tok.id = .one,
            else => if (tok.id.isMacroIdentifier()) {
                if (tok.id == .keyword_defined) {
                    const tokens_consumed = try pp.handleKeywordDefined(&tok, items[i + 1 ..], eof);
                    i += tokens_consumed;
                } else {
                    try pp.errStr(tok, .undefined_macro, pp.expandedSlice(tok));

                    if (i + 1 < pp.top_expansion_buf.items.len and
                        pp.top_expansion_buf.items[i + 1].id == .l_paren)
                    {
                        try pp.errStr(tok, .fn_macro_undefined, pp.expandedSlice(tok));
                        return false;
                    }

                    tok.id = .zero; // undefined macro
                }
            },
        }
        pp.addTokenAssumeCapacity(tok);
    }
    try pp.addToken(.{
        .id = .eof,
        .loc = tokFromRaw(eof).loc,
    });

    // Actually parse it.
    var parser = Parser{
        .pp = pp,
        .comp = pp.comp,
        .gpa = pp.gpa,
        .tok_ids = pp.tokens.items(.id),
        .tok_i = @intCast(token_state.tokens_len),
        .arena = pp.arena.allocator(),
        .in_macro = true,
        .strings = std.ArrayList(u8).init(pp.comp.gpa),

        .data = undefined,
        .value_map = undefined,
        .labels = undefined,
        .decl_buf = undefined,
        .list_buf = undefined,
        .param_buf = undefined,
        .enum_buf = undefined,
        .record_buf = undefined,
        .attr_buf = undefined,
        .field_attr_buf = undefined,
        .string_ids = undefined,
    };
    defer parser.strings.deinit();
    return parser.macroExpr();
}

/// Turns macro_tok from .keyword_defined into .zero or .one depending on whether the argument is defined
/// Returns the number of tokens consumed
fn handleKeywordDefined(pp: *Preprocessor, macro_tok: *TokenWithExpansionLocs, tokens: []const TokenWithExpansionLocs, eof: RawToken) !usize {
    std.debug.assert(macro_tok.id == .keyword_defined);
    var it = TokenIterator.init(tokens);
    const first = it.nextNoWS() orelse {
        try pp.err(eof, .macro_name_missing);
        return it.i;
    };
    switch (first.id) {
        .l_paren => {},
        else => {
            if (!first.id.isMacroIdentifier()) {
                try pp.errStr(first, .macro_name_must_be_identifier, pp.expandedSlice(first));
            }
            macro_tok.id = if (pp.defines.contains(pp.expandedSlice(first))) .one else .zero;
            return it.i;
        },
    }
    const second = it.nextNoWS() orelse {
        try pp.err(eof, .macro_name_missing);
        return it.i;
    };
    if (!second.id.isMacroIdentifier()) {
        try pp.comp.addDiagnostic(.{
            .tag = .macro_name_must_be_identifier,
            .loc = second.loc,
        }, second.expansionSlice());
        return it.i;
    }
    macro_tok.id = if (pp.defines.contains(pp.expandedSlice(second))) .one else .zero;

    const last = it.nextNoWS();
    if (last == null or last.?.id != .r_paren) {
        const tok = last orelse tokFromRaw(eof);
        try pp.comp.addDiagnostic(.{
            .tag = .closing_paren,
            .loc = tok.loc,
        }, tok.expansionSlice());
        try pp.comp.addDiagnostic(.{
            .tag = .to_match_paren,
            .loc = first.loc,
        }, first.expansionSlice());
    }

    return it.i;
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
                .keyword_elifdef => {
                    if (ifs_seen != 0 or cont == .until_endif) continue;
                    if (cont == .until_endif_seen_else) {
                        try pp.err(directive, .elifdef_after_else);
                        continue;
                    }
                    tokenizer.* = saved_tokenizer;
                    return;
                },
                .keyword_elifndef => {
                    if (ifs_seen != 0 or cont == .until_endif) continue;
                    if (cont == .until_endif_seen_else) {
                        try pp.err(directive, .elifndef_after_else);
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
            if (pp.preserve_whitespace) {
                try pp.addToken(.{ .id = .nl, .loc = .{
                    .id = tokenizer.source,
                    .line = tokenizer.line,
                } });
            }
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

const ExpandBuf = std.ArrayList(TokenWithExpansionLocs);
fn removePlacemarkers(buf: *ExpandBuf) void {
    var i: usize = buf.items.len -% 1;
    while (i < buf.items.len) : (i -%= 1) {
        if (buf.items[i].id == .placemarker) {
            const placemarker = buf.orderedRemove(i);
            TokenWithExpansionLocs.free(placemarker.expansion_locs, buf.allocator);
        }
    }
}

const MacroArguments = std.ArrayList([]const TokenWithExpansionLocs);
fn deinitMacroArguments(allocator: Allocator, args: *const MacroArguments) void {
    for (args.items) |item| {
        for (item) |tok| TokenWithExpansionLocs.free(tok.expansion_locs, allocator);
        allocator.free(item);
    }
    args.deinit();
}

fn expandObjMacro(pp: *Preprocessor, simple_macro: *const Macro) Error!ExpandBuf {
    var buf = ExpandBuf.init(pp.gpa);
    errdefer buf.deinit();
    if (simple_macro.tokens.len == 0) {
        try buf.append(.{ .id = .placemarker, .loc = .{ .id = .generated } });
        return buf;
    }
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
                while (true) {
                    if (rhs.id == .whitespace) {
                        rhs = tokFromRaw(simple_macro.tokens[i + 1]);
                        i += 1;
                    } else if (rhs.id == .comment and !pp.comp.langopts.preserve_comments_in_macros) {
                        rhs = tokFromRaw(simple_macro.tokens[i + 1]);
                        i += 1;
                    } else break;
                }
                try pp.pasteTokens(&buf, &.{rhs});
            },
            .whitespace => if (pp.preserve_whitespace) buf.appendAssumeCapacity(tok),
            .macro_file => {
                const start = pp.comp.generated_buf.items.len;
                const source = pp.comp.getSource(pp.expansion_source_loc.id);
                const w = pp.comp.generated_buf.writer(pp.gpa);
                try w.print("\"{s}\"\n", .{source.path});

                buf.appendAssumeCapacity(try pp.makeGeneratedToken(start, .string_literal, tok));
            },
            .macro_line => {
                const start = pp.comp.generated_buf.items.len;
                const source = pp.comp.getSource(pp.expansion_source_loc.id);
                const w = pp.comp.generated_buf.writer(pp.gpa);
                try w.print("{d}\n", .{source.physicalLine(pp.expansion_source_loc)});

                buf.appendAssumeCapacity(try pp.makeGeneratedToken(start, .pp_num, tok));
            },
            .macro_counter => {
                defer pp.counter += 1;
                const start = pp.comp.generated_buf.items.len;
                const w = pp.comp.generated_buf.writer(pp.gpa);
                try w.print("{d}\n", .{pp.counter});

                buf.appendAssumeCapacity(try pp.makeGeneratedToken(start, .pp_num, tok));
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
fn pasteStringsUnsafe(pp: *Preprocessor, toks: []const TokenWithExpansionLocs) ![]const u8 {
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
fn pragmaOperator(pp: *Preprocessor, arg_tok: TokenWithExpansionLocs, operator_loc: Source.Location) !void {
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
    try pp.comp.generated_buf.appendSlice(pp.gpa, pp.char_buf.items);
    var tmp_tokenizer = Tokenizer{
        .buf = pp.comp.generated_buf.items,
        .langopts = pp.comp.langopts,
        .index = @intCast(start),
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
fn stringify(pp: *Preprocessor, tokens: []const TokenWithExpansionLocs) !void {
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
    if (pp.char_buf.items[pp.char_buf.items.len - 1] == '\\') {
        const tok = tokens[tokens.len - 1];
        try pp.comp.addDiagnostic(.{
            .tag = .invalid_pp_stringify_escape,
            .loc = tok.loc,
        }, tok.expansionSlice());
        pp.char_buf.items.len -= 1;
    }
    try pp.char_buf.appendSlice("\"\n");
}

fn reconstructIncludeString(pp: *Preprocessor, param_toks: []const TokenWithExpansionLocs, embed_args: ?*[]const TokenWithExpansionLocs, first: TokenWithExpansionLocs) !?[]const u8 {
    assert(param_toks.len != 0);
    const char_top = pp.char_buf.items.len;
    defer pp.char_buf.items.len = char_top;

    // Trim leading/trailing whitespace
    var begin: usize = 0;
    var end: usize = param_toks.len;
    while (begin < end and param_toks[begin].id == .macro_ws) : (begin += 1) {}
    while (end > begin and param_toks[end - 1].id == .macro_ws) : (end -= 1) {}
    const params = param_toks[begin..end];

    if (params.len == 0) {
        try pp.comp.addDiagnostic(.{
            .tag = .expected_filename,
            .loc = first.loc,
        }, first.expansionSlice());
        return null;
    }
    // no string pasting
    if (embed_args == null and params[0].id == .string_literal and params.len > 1) {
        try pp.comp.addDiagnostic(.{
            .tag = .closing_paren,
            .loc = params[1].loc,
        }, params[1].expansionSlice());
        return null;
    }

    for (params, 0..) |tok, i| {
        const str = pp.expandedSliceExtra(tok, .preserve_macro_ws);
        try pp.char_buf.appendSlice(str);
        if (embed_args) |some| {
            if ((i == 0 and tok.id == .string_literal) or tok.id == .angle_bracket_right) {
                some.* = params[i + 1 ..];
                break;
            }
        }
    }

    const include_str = pp.char_buf.items[char_top..];
    if (include_str.len < 3) {
        if (include_str.len == 0) {
            try pp.comp.addDiagnostic(.{
                .tag = .expected_filename,
                .loc = first.loc,
            }, first.expansionSlice());
            return null;
        }
        try pp.comp.addDiagnostic(.{
            .tag = .empty_filename,
            .loc = params[0].loc,
        }, params[0].expansionSlice());
        return null;
    }

    switch (include_str[0]) {
        '<' => {
            if (include_str[include_str.len - 1] != '>') {
                // Ugly hack to find out where the '>' should go, since we don't have the closing ')' location
                const start = params[0].loc;
                try pp.comp.addDiagnostic(.{
                    .tag = .header_str_closing,
                    .loc = .{ .id = start.id, .byte_offset = start.byte_offset + @as(u32, @intCast(include_str.len)) + 1, .line = start.line },
                }, params[0].expansionSlice());
                try pp.comp.addDiagnostic(.{
                    .tag = .header_str_match,
                    .loc = params[0].loc,
                }, params[0].expansionSlice());
                return null;
            }
            return include_str;
        },
        '"' => return include_str,
        else => {
            try pp.comp.addDiagnostic(.{
                .tag = .expected_filename,
                .loc = params[0].loc,
            }, params[0].expansionSlice());
            return null;
        },
    }
}

fn handleBuiltinMacro(pp: *Preprocessor, builtin: RawToken.Id, param_toks: []const TokenWithExpansionLocs, src_loc: Source.Location) Error!bool {
    switch (builtin) {
        .macro_param_has_attribute,
        .macro_param_has_declspec_attribute,
        .macro_param_has_feature,
        .macro_param_has_extension,
        .macro_param_has_builtin,
        => {
            var invalid: ?TokenWithExpansionLocs = null;
            var identifier: ?TokenWithExpansionLocs = null;
            for (param_toks) |tok| {
                if (tok.id == .macro_ws) continue;
                if (tok.id == .comment) continue;
                if (!tok.id.isMacroIdentifier()) {
                    invalid = tok;
                    break;
                }
                if (identifier) |_| invalid = tok else identifier = tok;
            }
            if (identifier == null and invalid == null) invalid = .{ .id = .eof, .loc = src_loc };
            if (invalid) |some| {
                try pp.comp.addDiagnostic(
                    .{ .tag = .feature_check_requires_identifier, .loc = some.loc },
                    some.expansionSlice(),
                );
                return false;
            }

            const ident_str = pp.expandedSlice(identifier.?);
            return switch (builtin) {
                .macro_param_has_attribute => Attribute.fromString(.gnu, null, ident_str) != null,
                .macro_param_has_declspec_attribute => {
                    return if (pp.comp.langopts.declspec_attrs)
                        Attribute.fromString(.declspec, null, ident_str) != null
                    else
                        false;
                },
                .macro_param_has_feature => features.hasFeature(pp.comp, ident_str),
                .macro_param_has_extension => features.hasExtension(pp.comp, ident_str),
                .macro_param_has_builtin => pp.comp.hasBuiltin(ident_str),
                else => unreachable,
            };
        },
        .macro_param_has_warning => {
            const actual_param = pp.pasteStringsUnsafe(param_toks) catch |er| switch (er) {
                error.ExpectedStringLiteral => {
                    try pp.errStr(param_toks[0], .expected_str_literal_in, "__has_warning");
                    return false;
                },
                else => |e| return e,
            };
            if (!mem.startsWith(u8, actual_param, "-W")) {
                try pp.errStr(param_toks[0], .malformed_warning_check, "__has_warning");
                return false;
            }
            const warning_name = actual_param[2..];
            return Diagnostics.warningExists(warning_name);
        },
        .macro_param_is_identifier => {
            var invalid: ?TokenWithExpansionLocs = null;
            var identifier: ?TokenWithExpansionLocs = null;
            for (param_toks) |tok| switch (tok.id) {
                .macro_ws => continue,
                .comment => continue,
                else => {
                    if (identifier) |_| invalid = tok else identifier = tok;
                },
            };
            if (identifier == null and invalid == null) invalid = .{ .id = .eof, .loc = src_loc };
            if (invalid) |some| {
                try pp.comp.addDiagnostic(.{
                    .tag = .missing_tok_builtin,
                    .loc = some.loc,
                    .extra = .{ .tok_id_expected = .r_paren },
                }, some.expansionSlice());
                return false;
            }

            const id = identifier.?.id;
            return id == .identifier or id == .extended_identifier;
        },
        .macro_param_has_include, .macro_param_has_include_next => {
            const include_str = (try pp.reconstructIncludeString(param_toks, null, param_toks[0])) orelse return false;
            const include_type: Compilation.IncludeType = switch (include_str[0]) {
                '"' => .quotes,
                '<' => .angle_brackets,
                else => unreachable,
            };
            const filename = include_str[1 .. include_str.len - 1];
            if (builtin == .macro_param_has_include or pp.include_depth == 0) {
                if (builtin == .macro_param_has_include_next) {
                    try pp.comp.addDiagnostic(.{
                        .tag = .include_next_outside_header,
                        .loc = src_loc,
                    }, &.{});
                }
                return pp.comp.hasInclude(filename, src_loc.id, include_type, .first);
            }
            return pp.comp.hasInclude(filename, src_loc.id, include_type, .next);
        },
        else => unreachable,
    }
}

/// Treat whitespace-only paste arguments as empty
fn getPasteArgs(args: []const TokenWithExpansionLocs) []const TokenWithExpansionLocs {
    for (args) |tok| {
        if (tok.id != .macro_ws) return args;
    }
    return &[1]TokenWithExpansionLocs{.{
        .id = .placemarker,
        .loc = .{ .id = .generated, .byte_offset = 0, .line = 0 },
    }};
}

fn expandFuncMacro(
    pp: *Preprocessor,
    loc: Source.Location,
    func_macro: *const Macro,
    args: *const MacroArguments,
    expanded_args: *const MacroArguments,
) MacroError!ExpandBuf {
    var buf = ExpandBuf.init(pp.gpa);
    try buf.ensureTotalCapacity(func_macro.tokens.len);
    errdefer buf.deinit();

    var expanded_variable_arguments = ExpandBuf.init(pp.gpa);
    defer expanded_variable_arguments.deinit();
    var variable_arguments = ExpandBuf.init(pp.gpa);
    defer variable_arguments.deinit();

    if (func_macro.var_args) {
        var i: usize = func_macro.params.len;
        while (i < expanded_args.items.len) : (i += 1) {
            try variable_arguments.appendSlice(args.items[i]);
            try expanded_variable_arguments.appendSlice(expanded_args.items[i]);
            if (i != expanded_args.items.len - 1) {
                const comma = TokenWithExpansionLocs{ .id = .comma, .loc = .{ .id = .generated } };
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

                var va_opt_buf = ExpandBuf.init(pp.gpa);
                defer va_opt_buf.deinit();

                const next = switch (raw_next.id) {
                    .macro_ws => continue,
                    .hash_hash => continue,
                    .comment => if (!pp.comp.langopts.preserve_comments_in_macros)
                        continue
                    else
                        &[1]TokenWithExpansionLocs{tokFromRaw(raw_next)},
                    .macro_param, .macro_param_no_expand => getPasteArgs(args.items[raw_next.end]),
                    .keyword_va_args => variable_arguments.items,
                    .keyword_va_opt => blk: {
                        try pp.expandVaOpt(&va_opt_buf, raw_next, variable_arguments.items.len != 0);
                        if (va_opt_buf.items.len == 0) break;
                        break :blk va_opt_buf.items;
                    },
                    else => &[1]TokenWithExpansionLocs{tokFromRaw(raw_next)},
                };

                try pp.pasteTokens(&buf, next);
                if (next.len != 0) break;
            },
            .macro_param_no_expand => {
                const slice = getPasteArgs(args.items[raw.end]);
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
            .keyword_va_opt => {
                try pp.expandVaOpt(&buf, raw, variable_arguments.items.len != 0);
            },
            .stringify_param, .stringify_va_args => {
                const arg = if (raw.id == .stringify_va_args)
                    variable_arguments.items
                else
                    args.items[raw.end];

                pp.char_buf.clearRetainingCapacity();
                try pp.stringify(arg);

                const start = pp.comp.generated_buf.items.len;
                try pp.comp.generated_buf.appendSlice(pp.gpa, pp.char_buf.items);

                try buf.append(try pp.makeGeneratedToken(start, .string_literal, tokFromRaw(raw)));
            },
            .macro_param_has_attribute,
            .macro_param_has_declspec_attribute,
            .macro_param_has_warning,
            .macro_param_has_feature,
            .macro_param_has_extension,
            .macro_param_has_builtin,
            .macro_param_has_include,
            .macro_param_has_include_next,
            .macro_param_is_identifier,
            => {
                const arg = expanded_args.items[0];
                const result = if (arg.len == 0) blk: {
                    const extra = Diagnostics.Message.Extra{ .arguments = .{ .expected = 1, .actual = 0 } };
                    try pp.comp.addDiagnostic(.{ .tag = .expected_arguments, .loc = loc, .extra = extra }, &.{});
                    break :blk false;
                } else try pp.handleBuiltinMacro(raw.id, arg, loc);
                const start = pp.comp.generated_buf.items.len;
                const w = pp.comp.generated_buf.writer(pp.gpa);
                try w.print("{}\n", .{@intFromBool(result)});
                try buf.append(try pp.makeGeneratedToken(start, .pp_num, tokFromRaw(raw)));
            },
            .macro_param_has_c_attribute => {
                const arg = expanded_args.items[0];
                const not_found = "0\n";
                const result = if (arg.len == 0) blk: {
                    const extra = Diagnostics.Message.Extra{ .arguments = .{ .expected = 1, .actual = 0 } };
                    try pp.comp.addDiagnostic(.{ .tag = .expected_arguments, .loc = loc, .extra = extra }, &.{});
                    break :blk not_found;
                } else res: {
                    var invalid: ?TokenWithExpansionLocs = null;
                    var vendor_ident: ?TokenWithExpansionLocs = null;
                    var colon_colon: ?TokenWithExpansionLocs = null;
                    var attr_ident: ?TokenWithExpansionLocs = null;
                    for (arg) |tok| {
                        if (tok.id == .macro_ws) continue;
                        if (tok.id == .comment) continue;
                        if (tok.id == .colon_colon) {
                            if (colon_colon != null or attr_ident == null) {
                                invalid = tok;
                                break;
                            }
                            vendor_ident = attr_ident;
                            attr_ident = null;
                            colon_colon = tok;
                            continue;
                        }
                        if (!tok.id.isMacroIdentifier()) {
                            invalid = tok;
                            break;
                        }
                        if (attr_ident) |_| {
                            invalid = tok;
                            break;
                        } else attr_ident = tok;
                    }
                    if (vendor_ident != null and attr_ident == null) {
                        invalid = vendor_ident;
                    } else if (attr_ident == null and invalid == null) {
                        invalid = .{ .id = .eof, .loc = loc };
                    }
                    if (invalid) |some| {
                        try pp.comp.addDiagnostic(
                            .{ .tag = .feature_check_requires_identifier, .loc = some.loc },
                            some.expansionSlice(),
                        );
                        break :res not_found;
                    }
                    if (vendor_ident) |some| {
                        const vendor_str = pp.expandedSlice(some);
                        const attr_str = pp.expandedSlice(attr_ident.?);
                        const exists = Attribute.fromString(.gnu, vendor_str, attr_str) != null;

                        const start = pp.comp.generated_buf.items.len;
                        try pp.comp.generated_buf.appendSlice(pp.gpa, if (exists) "1\n" else "0\n");
                        try buf.append(try pp.makeGeneratedToken(start, .pp_num, tokFromRaw(raw)));
                        continue;
                    }
                    if (!pp.comp.langopts.standard.atLeast(.c23)) break :res not_found;

                    const attrs = std.StaticStringMap([]const u8).initComptime(.{
                        .{ "deprecated", "201904L\n" },
                        .{ "fallthrough", "201904L\n" },
                        .{ "maybe_unused", "201904L\n" },
                        .{ "nodiscard", "202003L\n" },
                        .{ "noreturn", "202202L\n" },
                        .{ "_Noreturn", "202202L\n" },
                        .{ "unsequenced", "202207L\n" },
                        .{ "reproducible", "202207L\n" },
                    });

                    const attr_str = Attribute.normalize(pp.expandedSlice(attr_ident.?));
                    break :res attrs.get(attr_str) orelse not_found;
                };
                const start = pp.comp.generated_buf.items.len;
                try pp.comp.generated_buf.appendSlice(pp.gpa, result);
                try buf.append(try pp.makeGeneratedToken(start, .pp_num, tokFromRaw(raw)));
            },
            .macro_param_has_embed => {
                const arg = expanded_args.items[0];
                const not_found = "0\n";
                const result = if (arg.len == 0) blk: {
                    const extra = Diagnostics.Message.Extra{ .arguments = .{ .expected = 1, .actual = 0 } };
                    try pp.comp.addDiagnostic(.{ .tag = .expected_arguments, .loc = loc, .extra = extra }, &.{});
                    break :blk not_found;
                } else res: {
                    var embed_args: []const TokenWithExpansionLocs = &.{};
                    const include_str = (try pp.reconstructIncludeString(arg, &embed_args, arg[0])) orelse
                        break :res not_found;

                    var prev = tokFromRaw(raw);
                    prev.id = .eof;
                    var it: struct {
                        i: u32 = 0,
                        slice: []const TokenWithExpansionLocs,
                        prev: TokenWithExpansionLocs,
                        fn next(it: *@This()) TokenWithExpansionLocs {
                            while (it.i < it.slice.len) switch (it.slice[it.i].id) {
                                .macro_ws, .whitespace => it.i += 1,
                                else => break,
                            } else return it.prev;
                            defer it.i += 1;
                            it.prev = it.slice[it.i];
                            it.prev.id = .eof;
                            return it.slice[it.i];
                        }
                    } = .{ .slice = embed_args, .prev = prev };

                    while (true) {
                        const param_first = it.next();
                        if (param_first.id == .eof) break;
                        if (param_first.id != .identifier) {
                            try pp.comp.addDiagnostic(
                                .{ .tag = .malformed_embed_param, .loc = param_first.loc },
                                param_first.expansionSlice(),
                            );
                            continue;
                        }

                        const char_top = pp.char_buf.items.len;
                        defer pp.char_buf.items.len = char_top;

                        const maybe_colon = it.next();
                        const param = switch (maybe_colon.id) {
                            .colon_colon => blk: {
                                // vendor::param
                                const param = it.next();
                                if (param.id != .identifier) {
                                    try pp.comp.addDiagnostic(
                                        .{ .tag = .malformed_embed_param, .loc = param.loc },
                                        param.expansionSlice(),
                                    );
                                    continue;
                                }
                                const l_paren = it.next();
                                if (l_paren.id != .l_paren) {
                                    try pp.comp.addDiagnostic(
                                        .{ .tag = .malformed_embed_param, .loc = l_paren.loc },
                                        l_paren.expansionSlice(),
                                    );
                                    continue;
                                }
                                break :blk "doesn't exist";
                            },
                            .l_paren => Attribute.normalize(pp.expandedSlice(param_first)),
                            else => {
                                try pp.comp.addDiagnostic(
                                    .{ .tag = .malformed_embed_param, .loc = maybe_colon.loc },
                                    maybe_colon.expansionSlice(),
                                );
                                continue;
                            },
                        };

                        var arg_count: u32 = 0;
                        var first_arg: TokenWithExpansionLocs = undefined;
                        while (true) {
                            const next = it.next();
                            if (next.id == .eof) {
                                try pp.comp.addDiagnostic(
                                    .{ .tag = .malformed_embed_limit, .loc = param_first.loc },
                                    param_first.expansionSlice(),
                                );
                                break;
                            }
                            if (next.id == .r_paren) break;
                            arg_count += 1;
                            if (arg_count == 1) first_arg = next;
                        }

                        if (std.mem.eql(u8, param, "limit")) {
                            if (arg_count != 1) {
                                try pp.comp.addDiagnostic(
                                    .{ .tag = .malformed_embed_limit, .loc = param_first.loc },
                                    param_first.expansionSlice(),
                                );
                                continue;
                            }
                            if (first_arg.id != .pp_num) {
                                try pp.comp.addDiagnostic(
                                    .{ .tag = .malformed_embed_limit, .loc = param_first.loc },
                                    param_first.expansionSlice(),
                                );
                                continue;
                            }
                            _ = std.fmt.parseInt(u32, pp.expandedSlice(first_arg), 10) catch {
                                break :res not_found;
                            };
                        } else if (!std.mem.eql(u8, param, "prefix") and !std.mem.eql(u8, param, "suffix") and
                            !std.mem.eql(u8, param, "if_empty"))
                        {
                            break :res not_found;
                        }
                    }

                    const include_type: Compilation.IncludeType = switch (include_str[0]) {
                        '"' => .quotes,
                        '<' => .angle_brackets,
                        else => unreachable,
                    };
                    const filename = include_str[1 .. include_str.len - 1];
                    const contents = (try pp.comp.findEmbed(filename, arg[0].loc.id, include_type, 1)) orelse
                        break :res not_found;

                    defer pp.comp.gpa.free(contents);
                    break :res if (contents.len != 0) "1\n" else "2\n";
                };
                const start = pp.comp.generated_buf.items.len;
                try pp.comp.generated_buf.appendSlice(pp.comp.gpa, result);
                try buf.append(try pp.makeGeneratedToken(start, .pp_num, tokFromRaw(raw)));
            },
            .macro_param_pragma_operator => {
                const param_toks = expanded_args.items[0];
                // Clang and GCC require exactly one token (so, no parentheses or string pasting)
                // even though their error messages indicate otherwise. Ours is slightly more
                // descriptive.
                var invalid: ?TokenWithExpansionLocs = null;
                var string: ?TokenWithExpansionLocs = null;
                for (param_toks) |tok| switch (tok.id) {
                    .string_literal => {
                        if (string) |_| invalid = tok else string = tok;
                    },
                    .macro_ws => continue,
                    .comment => continue,
                    else => {
                        invalid = tok;
                        break;
                    },
                };
                if (string == null and invalid == null) invalid = .{ .loc = loc, .id = .eof };
                if (invalid) |some| try pp.comp.addDiagnostic(
                    .{ .tag = .pragma_operator_string_literal, .loc = some.loc },
                    some.expansionSlice(),
                ) else try pp.pragmaOperator(string.?, loc);
            },
            .comma => {
                if (tok_i + 2 < func_macro.tokens.len and func_macro.tokens[tok_i + 1].id == .hash_hash) {
                    const hash_hash = func_macro.tokens[tok_i + 1];
                    var maybe_va_args = func_macro.tokens[tok_i + 2];
                    var consumed: usize = 2;
                    if (maybe_va_args.id == .macro_ws and tok_i + 3 < func_macro.tokens.len) {
                        consumed = 3;
                        maybe_va_args = func_macro.tokens[tok_i + 3];
                    }
                    if (maybe_va_args.id == .keyword_va_args) {
                        // GNU extension: `, ##__VA_ARGS__` deletes the comma if __VA_ARGS__ is empty
                        tok_i += consumed;
                        if (func_macro.params.len == expanded_args.items.len) {
                            // Empty __VA_ARGS__, drop the comma
                            try pp.err(hash_hash, .comma_deletion_va_args);
                        } else if (func_macro.params.len == 0 and expanded_args.items.len == 1 and expanded_args.items[0].len == 0) {
                            // Ambiguous whether this is "empty __VA_ARGS__" or "__VA_ARGS__ omitted"
                            if (pp.comp.langopts.standard.isGNU()) {
                                // GNU standard, drop the comma
                                try pp.err(hash_hash, .comma_deletion_va_args);
                            } else {
                                // C standard, retain the comma
                                try buf.append(tokFromRaw(raw));
                            }
                        } else {
                            try buf.append(tokFromRaw(raw));
                            if (expanded_variable_arguments.items.len > 0 or variable_arguments.items.len == func_macro.params.len) {
                                try pp.err(hash_hash, .comma_deletion_va_args);
                            }
                            const raw_loc = Source.Location{
                                .id = maybe_va_args.source,
                                .byte_offset = maybe_va_args.start,
                                .line = maybe_va_args.line,
                            };
                            try bufCopyTokens(&buf, expanded_variable_arguments.items, &.{raw_loc});
                        }
                        continue;
                    }
                }
                // Regular comma, no token pasting with __VA_ARGS__
                try buf.append(tokFromRaw(raw));
            },
            else => try buf.append(tokFromRaw(raw)),
        }
    }
    removePlacemarkers(&buf);

    return buf;
}

fn expandVaOpt(
    pp: *Preprocessor,
    buf: *ExpandBuf,
    raw: RawToken,
    should_expand: bool,
) !void {
    if (!should_expand) return;

    const source = pp.comp.getSource(raw.source);
    var tokenizer: Tokenizer = .{
        .buf = source.buf,
        .index = raw.start,
        .source = raw.source,
        .langopts = pp.comp.langopts,
        .line = raw.line,
    };
    while (tokenizer.index < raw.end) {
        const tok = tokenizer.next();
        try buf.append(tokFromRaw(tok));
    }
}

fn bufCopyTokens(buf: *ExpandBuf, tokens: []const TokenWithExpansionLocs, src: []const Source.Location) !void {
    try buf.ensureUnusedCapacity(tokens.len);
    for (tokens) |tok| {
        var copy = try tok.dupe(buf.allocator);
        errdefer TokenWithExpansionLocs.free(copy.expansion_locs, buf.allocator);
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
) Error!TokenWithExpansionLocs {
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
            return TokenWithExpansionLocs{ .id = .eof, .loc = .{ .id = .generated } };
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
    r_paren: *TokenWithExpansionLocs,
) !MacroArguments {
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
                    try pp.errStr(name_tok, .missing_lparen_after_builtin, pp.expandedSlice(name_tok));
                }
                // Not a macro function call, go over normal identifier, rewind
                tokenizer.* = saved_tokenizer;
                end_idx.* = old_end;
                return error.MissingLParen;
            },
        }
    }

    // collect the arguments.
    var parens: u32 = 0;
    var args = MacroArguments.init(pp.gpa);
    errdefer deinitMacroArguments(pp.gpa, &args);
    var curArgument = std.ArrayList(TokenWithExpansionLocs).init(pp.gpa);
    defer curArgument.deinit();
    while (true) {
        var tok = try nextBufToken(pp, tokenizer, buf, start_idx, end_idx, extend_buf);
        tok.flags.is_macro_arg = true;
        switch (tok.id) {
            .comma => {
                if (parens == 0) {
                    const owned = try curArgument.toOwnedSlice();
                    errdefer pp.gpa.free(owned);
                    try args.append(owned);
                } else {
                    const duped = try tok.dupe(pp.gpa);
                    errdefer TokenWithExpansionLocs.free(duped.expansion_locs, pp.gpa);
                    try curArgument.append(duped);
                }
            },
            .l_paren => {
                const duped = try tok.dupe(pp.gpa);
                errdefer TokenWithExpansionLocs.free(duped.expansion_locs, pp.gpa);
                try curArgument.append(duped);
                parens += 1;
            },
            .r_paren => {
                if (parens == 0) {
                    const owned = try curArgument.toOwnedSlice();
                    errdefer pp.gpa.free(owned);
                    try args.append(owned);
                    r_paren.* = tok;
                    break;
                } else {
                    const duped = try tok.dupe(pp.gpa);
                    errdefer TokenWithExpansionLocs.free(duped.expansion_locs, pp.gpa);
                    try curArgument.append(duped);
                    parens -= 1;
                }
            },
            .eof => {
                {
                    const owned = try curArgument.toOwnedSlice();
                    errdefer pp.gpa.free(owned);
                    try args.append(owned);
                }
                tokenizer.* = saved_tokenizer;
                try pp.comp.addDiagnostic(
                    .{ .tag = .unterminated_macro_arg_list, .loc = name_tok.loc },
                    name_tok.expansionSlice(),
                );
                return error.Unterminated;
            },
            .nl, .whitespace => {
                try curArgument.append(.{ .id = .macro_ws, .loc = tok.loc });
            },
            else => {
                const duped = try tok.dupe(pp.gpa);
                errdefer TokenWithExpansionLocs.free(duped.expansion_locs, pp.gpa);
                try curArgument.append(duped);
            },
        }
    }

    return args;
}

fn removeExpandedTokens(pp: *Preprocessor, buf: *ExpandBuf, start: usize, len: usize, moving_end_idx: *usize) !void {
    for (buf.items[start .. start + len]) |tok| TokenWithExpansionLocs.free(tok.expansion_locs, pp.gpa);
    try buf.replaceRange(start, len, &.{});
    moving_end_idx.* -|= len;
}

/// The behavior of `defined` depends on whether we are in a preprocessor
/// expression context (#if or #elif) or not.
/// In a non-expression context it's just an identifier. Within a preprocessor
/// expression it is a unary operator or one-argument function.
const EvalContext = enum {
    expr,
    non_expr,
};

/// Helper for safely iterating over a slice of tokens while skipping whitespace
const TokenIterator = struct {
    toks: []const TokenWithExpansionLocs,
    i: usize,

    fn init(toks: []const TokenWithExpansionLocs) TokenIterator {
        return .{ .toks = toks, .i = 0 };
    }

    fn nextNoWS(self: *TokenIterator) ?TokenWithExpansionLocs {
        while (self.i < self.toks.len) : (self.i += 1) {
            const tok = self.toks[self.i];
            if (tok.id == .whitespace or tok.id == .macro_ws) continue;

            self.i += 1;
            return tok;
        }
        return null;
    }
};

fn expandMacroExhaustive(
    pp: *Preprocessor,
    tokenizer: *Tokenizer,
    buf: *ExpandBuf,
    start_idx: usize,
    end_idx: usize,
    extend_buf: bool,
    eval_ctx: EvalContext,
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
            if (macro_tok.id == .keyword_defined and eval_ctx == .expr) {
                idx += 1;
                var it = TokenIterator.init(buf.items[idx..moving_end_idx]);
                if (it.nextNoWS()) |tok| {
                    switch (tok.id) {
                        .l_paren => {
                            _ = it.nextNoWS(); // eat (what should be) identifier
                            _ = it.nextNoWS(); // eat (what should be) r paren
                        },
                        .identifier, .extended_identifier => {},
                        else => {},
                    }
                }
                idx += it.i;
                continue;
            }
            if (!macro_tok.id.isMacroIdentifier() or macro_tok.flags.expansion_disabled) {
                idx += 1;
                continue;
            }
            const expanded = pp.expandedSlice(macro_tok);
            const macro = pp.defines.getPtr(expanded) orelse {
                idx += 1;
                continue;
            };
            const macro_hidelist = pp.hideset.get(macro_tok.loc);
            if (pp.hideset.contains(macro_hidelist, expanded)) {
                idx += 1;
                continue;
            }

            macro_handler: {
                if (macro.is_func) {
                    var r_paren: TokenWithExpansionLocs = undefined;
                    var macro_scan_idx = idx;
                    // to be saved in case this doesn't turn out to be a call
                    const args = pp.collectMacroFuncArguments(
                        tokenizer,
                        buf,
                        &macro_scan_idx,
                        &moving_end_idx,
                        extend_buf,
                        macro.is_builtin,
                        &r_paren,
                    ) catch |er| switch (er) {
                        error.MissingLParen => {
                            if (!buf.items[idx].flags.is_macro_arg) buf.items[idx].flags.expansion_disabled = true;
                            idx += 1;
                            break :macro_handler;
                        },
                        error.Unterminated => {
                            if (pp.comp.langopts.emulate == .gcc) idx += 1;
                            try pp.removeExpandedTokens(buf, idx, macro_scan_idx - idx, &moving_end_idx);
                            break :macro_handler;
                        },
                        else => |e| return e,
                    };
                    assert(r_paren.id == .r_paren);
                    defer {
                        for (args.items) |item| {
                            pp.gpa.free(item);
                        }
                        args.deinit();
                    }
                    const r_paren_hidelist = pp.hideset.get(r_paren.loc);
                    var hs = try pp.hideset.intersection(macro_hidelist, r_paren_hidelist);
                    hs = try pp.hideset.prepend(macro_tok.loc, hs);

                    var args_count: u32 = @intCast(args.items.len);
                    // if the macro has zero arguments g() args_count is still 1
                    // an empty token list g() and a whitespace-only token list g(    )
                    // counts as zero arguments for the purposes of argument-count validation
                    if (args_count == 1 and macro.params.len == 0) {
                        for (args.items[0]) |tok| {
                            if (tok.id != .macro_ws) break;
                        } else {
                            args_count = 0;
                        }
                    }

                    // Validate argument count.
                    const extra = Diagnostics.Message.Extra{
                        .arguments = .{ .expected = @intCast(macro.params.len), .actual = args_count },
                    };
                    if (macro.var_args and args_count < macro.params.len) {
                        try pp.comp.addDiagnostic(
                            .{ .tag = .expected_at_least_arguments, .loc = buf.items[idx].loc, .extra = extra },
                            buf.items[idx].expansionSlice(),
                        );
                        idx += 1;
                        try pp.removeExpandedTokens(buf, idx, macro_scan_idx - idx + 1, &moving_end_idx);
                        continue;
                    }
                    if (!macro.var_args and args_count != macro.params.len) {
                        try pp.comp.addDiagnostic(
                            .{ .tag = .expected_arguments, .loc = buf.items[idx].loc, .extra = extra },
                            buf.items[idx].expansionSlice(),
                        );
                        idx += 1;
                        try pp.removeExpandedTokens(buf, idx, macro_scan_idx - idx + 1, &moving_end_idx);
                        continue;
                    }
                    var expanded_args = MacroArguments.init(pp.gpa);
                    defer deinitMacroArguments(pp.gpa, &expanded_args);
                    try expanded_args.ensureTotalCapacity(args.items.len);
                    for (args.items) |arg| {
                        var expand_buf = ExpandBuf.init(pp.gpa);
                        errdefer expand_buf.deinit();
                        try expand_buf.appendSlice(arg);

                        try pp.expandMacroExhaustive(tokenizer, &expand_buf, 0, expand_buf.items.len, false, eval_ctx);

                        expanded_args.appendAssumeCapacity(try expand_buf.toOwnedSlice());
                    }

                    var res = try pp.expandFuncMacro(macro_tok.loc, macro, &args, &expanded_args);
                    defer res.deinit();
                    const tokens_added = res.items.len;

                    const macro_expansion_locs = macro_tok.expansionSlice();
                    for (res.items) |*tok| {
                        try tok.addExpansionLocation(pp.gpa, &.{macro_tok.loc});
                        try tok.addExpansionLocation(pp.gpa, macro_expansion_locs);
                        const tok_hidelist = pp.hideset.get(tok.loc);
                        const new_hidelist = try pp.hideset.@"union"(tok_hidelist, hs);
                        try pp.hideset.put(tok.loc, new_hidelist);
                    }

                    const tokens_removed = macro_scan_idx - idx + 1;
                    for (buf.items[idx .. idx + tokens_removed]) |tok| TokenWithExpansionLocs.free(tok.expansion_locs, pp.gpa);
                    try buf.replaceRange(idx, tokens_removed, res.items);

                    moving_end_idx += tokens_added;
                    // Overflow here means that we encountered an unterminated argument list
                    // while expanding the body of this macro.
                    moving_end_idx -|= tokens_removed;
                    idx += tokens_added;
                    do_rescan = true;
                } else {
                    const res = try pp.expandObjMacro(macro);
                    defer res.deinit();

                    const hs = try pp.hideset.prepend(macro_tok.loc, macro_hidelist);

                    const macro_expansion_locs = macro_tok.expansionSlice();
                    var increment_idx_by = res.items.len;
                    for (res.items, 0..) |*tok, i| {
                        tok.flags.is_macro_arg = macro_tok.flags.is_macro_arg;
                        try tok.addExpansionLocation(pp.gpa, &.{macro_tok.loc});
                        try tok.addExpansionLocation(pp.gpa, macro_expansion_locs);

                        const tok_hidelist = pp.hideset.get(tok.loc);
                        const new_hidelist = try pp.hideset.@"union"(tok_hidelist, hs);
                        try pp.hideset.put(tok.loc, new_hidelist);

                        if (tok.id == .keyword_defined and eval_ctx == .expr) {
                            try pp.comp.addDiagnostic(.{
                                .tag = .expansion_to_defined,
                                .loc = tok.loc,
                            }, tok.expansionSlice());
                        }

                        if (i < increment_idx_by and (tok.id == .keyword_defined or pp.defines.contains(pp.expandedSlice(tok.*)))) {
                            increment_idx_by = i;
                        }
                    }

                    TokenWithExpansionLocs.free(buf.items[idx].expansion_locs, pp.gpa);
                    try buf.replaceRange(idx, 1, res.items);
                    idx += increment_idx_by;
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
        TokenWithExpansionLocs.free(item.expansion_locs, pp.gpa);
    }
    buf.items.len = moving_end_idx;
}

/// Try to expand a macro after a possible candidate has been read from the `tokenizer`
/// into the `raw` token passed as argument
fn expandMacro(pp: *Preprocessor, tokenizer: *Tokenizer, raw: RawToken) MacroError!void {
    var source_tok = tokFromRaw(raw);
    if (!raw.id.isMacroIdentifier()) {
        source_tok.id.simplifyMacroKeyword();
        return pp.addToken(source_tok);
    }
    pp.top_expansion_buf.items.len = 0;
    try pp.top_expansion_buf.append(source_tok);
    pp.expansion_source_loc = source_tok.loc;

    pp.hideset.clearRetainingCapacity();
    try pp.expandMacroExhaustive(tokenizer, &pp.top_expansion_buf, 0, 1, true, .non_expr);
    try pp.ensureUnusedTokenCapacity(pp.top_expansion_buf.items.len);
    for (pp.top_expansion_buf.items) |*tok| {
        if (tok.id == .macro_ws and !pp.preserve_whitespace) {
            TokenWithExpansionLocs.free(tok.expansion_locs, pp.gpa);
            continue;
        }
        if (tok.id == .comment and !pp.comp.langopts.preserve_comments_in_macros) {
            TokenWithExpansionLocs.free(tok.expansion_locs, pp.gpa);
            continue;
        }
        if (tok.id == .placemarker) {
            TokenWithExpansionLocs.free(tok.expansion_locs, pp.gpa);
            continue;
        }
        tok.id.simplifyMacroKeywordExtra(true);
        pp.addTokenAssumeCapacity(tok.*);
    }
    if (pp.preserve_whitespace) {
        try pp.ensureUnusedTokenCapacity(pp.add_expansion_nl);
        while (pp.add_expansion_nl > 0) : (pp.add_expansion_nl -= 1) {
            pp.addTokenAssumeCapacity(.{ .id = .nl, .loc = .{
                .id = tokenizer.source,
                .line = tokenizer.line,
            } });
        }
    }
}

fn expandedSliceExtra(pp: *const Preprocessor, tok: anytype, macro_ws_handling: enum { single_macro_ws, preserve_macro_ws }) []const u8 {
    if (tok.id.lexeme()) |some| {
        if (!tok.id.allowsDigraphs(pp.comp.langopts) and !(tok.id == .macro_ws and macro_ws_handling == .preserve_macro_ws)) return some;
    }
    var tmp_tokenizer = Tokenizer{
        .buf = pp.comp.getSource(tok.loc.id).buf,
        .langopts = pp.comp.langopts,
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

/// Get expanded token source string.
pub fn expandedSlice(pp: *const Preprocessor, tok: anytype) []const u8 {
    return pp.expandedSliceExtra(tok, .single_macro_ws);
}

/// Concat two tokens and add the result to pp.generated
fn pasteTokens(pp: *Preprocessor, lhs_toks: *ExpandBuf, rhs_toks: []const TokenWithExpansionLocs) Error!void {
    const lhs = while (lhs_toks.popOrNull()) |lhs| {
        if ((pp.comp.langopts.preserve_comments_in_macros and lhs.id == .comment) or
            (lhs.id != .macro_ws and lhs.id != .comment))
            break lhs;

        TokenWithExpansionLocs.free(lhs.expansion_locs, pp.gpa);
    } else {
        return bufCopyTokens(lhs_toks, rhs_toks, &.{});
    };

    var rhs_rest: u32 = 1;
    const rhs = for (rhs_toks) |rhs| {
        if ((pp.comp.langopts.preserve_comments_in_macros and rhs.id == .comment) or
            (rhs.id != .macro_ws and rhs.id != .comment))
            break rhs;

        rhs_rest += 1;
    } else {
        return lhs_toks.appendAssumeCapacity(lhs);
    };
    defer TokenWithExpansionLocs.free(lhs.expansion_locs, pp.gpa);

    const start = pp.comp.generated_buf.items.len;
    const end = start + pp.expandedSlice(lhs).len + pp.expandedSlice(rhs).len;
    try pp.comp.generated_buf.ensureTotalCapacity(pp.gpa, end + 1); // +1 for a newline
    // We cannot use the same slices here since they might be invalidated by `ensureCapacity`
    pp.comp.generated_buf.appendSliceAssumeCapacity(pp.expandedSlice(lhs));
    pp.comp.generated_buf.appendSliceAssumeCapacity(pp.expandedSlice(rhs));
    pp.comp.generated_buf.appendAssumeCapacity('\n');

    // Try to tokenize the result.
    var tmp_tokenizer = Tokenizer{
        .buf = pp.comp.generated_buf.items,
        .langopts = pp.comp.langopts,
        .index = @intCast(start),
        .source = .generated,
    };
    const pasted_token = tmp_tokenizer.nextNoWSComments();
    const next = tmp_tokenizer.nextNoWSComments();
    const pasted_id = if (lhs.id == .placemarker and rhs.id == .placemarker)
        .placemarker
    else
        pasted_token.id;
    try lhs_toks.append(try pp.makeGeneratedToken(start, pasted_id, lhs));

    if (next.id != .nl and next.id != .eof) {
        try pp.errStr(
            lhs,
            .pasting_formed_invalid,
            try pp.comp.diagnostics.arena.allocator().dupe(u8, pp.comp.generated_buf.items[start..end]),
        );
        try lhs_toks.append(tokFromRaw(next));
    }

    try bufCopyTokens(lhs_toks, rhs_toks[rhs_rest..], &.{});
}

fn makeGeneratedToken(pp: *Preprocessor, start: usize, id: Token.Id, source: TokenWithExpansionLocs) !TokenWithExpansionLocs {
    var pasted_token = TokenWithExpansionLocs{ .id = id, .loc = .{
        .id = .generated,
        .byte_offset = @intCast(start),
        .line = pp.generated_line,
    } };
    pp.generated_line += 1;
    try pasted_token.addExpansionLocation(pp.gpa, &.{source.loc});
    try pasted_token.addExpansionLocation(pp.gpa, source.expansionSlice());
    return pasted_token;
}

/// Defines a new macro and warns if it is a duplicate
fn defineMacro(pp: *Preprocessor, name_tok: RawToken, macro: Macro) Error!void {
    const name_str = pp.tokSlice(name_tok);
    const gop = try pp.defines.getOrPut(pp.gpa, name_str);
    if (gop.found_existing and !gop.value_ptr.eql(macro, pp)) {
        const tag: Diagnostics.Tag = if (gop.value_ptr.is_builtin) .builtin_macro_redefined else .macro_redefined;
        const start = pp.comp.diagnostics.list.items.len;
        try pp.comp.addDiagnostic(.{
            .tag = tag,
            .loc = .{ .id = name_tok.source, .byte_offset = name_tok.start, .line = name_tok.line },
            .extra = .{ .str = name_str },
        }, &.{});
        if (!gop.value_ptr.is_builtin and pp.comp.diagnostics.list.items.len != start) {
            try pp.comp.addDiagnostic(.{
                .tag = .previous_definition,
                .loc = gop.value_ptr.loc,
            }, &.{});
        }
    }
    if (pp.verbose) {
        pp.verboseLog(name_tok, "macro {s} defined", .{name_str});
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
    var macro_name_token_id = macro_name.id;
    macro_name_token_id.simplifyMacroKeyword();
    switch (macro_name_token_id) {
        .identifier, .extended_identifier => {},
        else => if (macro_name_token_id.isMacroIdentifier()) {
            try pp.err(macro_name, .keyword_macro);
        },
    }

    // Check for function macros and empty defines.
    var first = tokenizer.next();
    switch (first.id) {
        .nl, .eof => return pp.defineMacro(macro_name, .{
            .params = &.{},
            .tokens = &.{},
            .var_args = false,
            .loc = tokFromRaw(macro_name).loc,
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
    while (true) {
        tok.id.simplifyMacroKeyword();
        switch (tok.id) {
            .hash_hash => {
                const next = tokenizer.nextNoWSComments();
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
            .nl, .eof => break,
            .comment => if (pp.comp.langopts.preserve_comments_in_macros) {
                if (need_ws) {
                    need_ws = false;
                    try pp.token_buf.append(.{ .id = .macro_ws, .source = .generated });
                }
                try pp.token_buf.append(tok);
            },
            .whitespace => need_ws = true,
            .unterminated_string_literal, .unterminated_char_literal, .empty_char_literal => |tag| {
                try pp.err(tok, invalidTokenDiagnostic(tag));
                try pp.token_buf.append(tok);
            },
            .unterminated_comment => try pp.err(tok, .unterminated_comment),
            else => {
                if (tok.id != .whitespace and need_ws) {
                    need_ws = false;
                    try pp.token_buf.append(.{ .id = .macro_ws, .source = .generated });
                }
                try pp.token_buf.append(tok);
            },
        }
        tok = tokenizer.next();
    }

    const list = try pp.arena.allocator().dupe(RawToken, pp.token_buf.items);
    try pp.defineMacro(macro_name, .{
        .loc = tokFromRaw(macro_name).loc,
        .tokens = list,
        .params = undefined,
        .is_func = false,
        .var_args = false,
    });
}

/// Handle a function like #define directive.
fn defineFn(pp: *Preprocessor, tokenizer: *Tokenizer, macro_name: RawToken, l_paren: RawToken) Error!void {
    assert(macro_name.id.isMacroIdentifier());
    var params = std.ArrayList([]const u8).init(pp.gpa);
    defer params.deinit();

    // Parse the parameter list.
    var gnu_var_args: []const u8 = "";
    var var_args = false;
    while (true) {
        var tok = tokenizer.nextNoWS();
        if (tok.id == .r_paren) break;
        if (tok.id == .eof) return pp.err(tok, .unterminated_macro_param_list);
        if (tok.id == .ellipsis) {
            var_args = true;
            const r_paren = tokenizer.nextNoWS();
            if (r_paren.id != .r_paren) {
                try pp.err(r_paren, .missing_paren_param_list);
                try pp.err(l_paren, .to_match_paren);
                return skipToNl(tokenizer);
            }
            break;
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
            break;
        } else if (tok.id == .r_paren) {
            break;
        } else if (tok.id != .comma) {
            try pp.err(tok, .expected_comma_param_list);
            return skipToNl(tokenizer);
        }
    }

    var need_ws = false;
    // Collect the body tokens and validate # and ##'s found.
    pp.token_buf.items.len = 0; // Safe to use since we can only be in one directive at a time.
    tok_loop: while (true) {
        var tok = tokenizer.next();
        switch (tok.id) {
            .nl, .eof => break,
            .whitespace => need_ws = pp.token_buf.items.len != 0,
            .comment => if (!pp.comp.langopts.preserve_comments_in_macros) continue else {
                if (need_ws) {
                    need_ws = false;
                    try pp.token_buf.append(.{ .id = .macro_ws, .source = .generated });
                }
                try pp.token_buf.append(tok);
            },
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
                    for (params.items, 0..) |p, i| {
                        if (mem.eql(u8, p, s)) {
                            tok.id = .stringify_param;
                            tok.end = @intCast(i);
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
                const next = tokenizer.nextNoWSComments();
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
            .unterminated_string_literal, .unterminated_char_literal, .empty_char_literal => |tag| {
                try pp.err(tok, invalidTokenDiagnostic(tag));
                try pp.token_buf.append(tok);
            },
            .unterminated_comment => try pp.err(tok, .unterminated_comment),
            else => {
                if (tok.id != .whitespace and need_ws) {
                    need_ws = false;
                    try pp.token_buf.append(.{ .id = .macro_ws, .source = .generated });
                }
                if (var_args and tok.id == .keyword_va_args) {
                    // do nothing
                } else if (var_args and tok.id == .keyword_va_opt) {
                    const opt_l_paren = tokenizer.next();
                    if (opt_l_paren.id != .l_paren) {
                        try pp.err(opt_l_paren, .va_opt_lparen);
                        return skipToNl(tokenizer);
                    }
                    tok.start = opt_l_paren.end;

                    var parens: u32 = 0;
                    while (true) {
                        const opt_tok = tokenizer.next();
                        switch (opt_tok.id) {
                            .l_paren => parens += 1,
                            .r_paren => if (parens == 0) {
                                break;
                            } else {
                                parens -= 1;
                            },
                            .nl, .eof => {
                                try pp.err(opt_tok, .va_opt_rparen);
                                try pp.err(opt_l_paren, .to_match_paren);
                                return skipToNl(tokenizer);
                            },
                            .whitespace => {},
                            else => tok.end = opt_tok.end,
                        }
                    }
                } else if (tok.id.isMacroIdentifier()) {
                    tok.id.simplifyMacroKeyword();
                    const s = pp.tokSlice(tok);
                    if (mem.eql(u8, gnu_var_args, s)) {
                        tok.id = .keyword_va_args;
                    } else for (params.items, 0..) |param, i| {
                        if (mem.eql(u8, param, s)) {
                            // NOTE: it doesn't matter to assign .macro_param_no_expand
                            // here in case a ## was the previous token, because
                            // ## processing will eat this token with the same semantics
                            tok.id = .macro_param;
                            tok.end = @intCast(i);
                            break;
                        }
                    }
                }
                try pp.token_buf.append(tok);
            },
        }
    }

    const param_list = try pp.arena.allocator().dupe([]const u8, params.items);
    const token_list = try pp.arena.allocator().dupe(RawToken, pp.token_buf.items);
    try pp.defineMacro(macro_name, .{
        .is_func = true,
        .params = param_list,
        .var_args = var_args or gnu_var_args.len != 0,
        .tokens = token_list,
        .loc = tokFromRaw(macro_name).loc,
    });
}

/// Handle an #embed directive
/// embedDirective : ("FILENAME" | <FILENAME>) embedParam*
/// embedParam : IDENTIFIER (:: IDENTIFIER)? '(' <tokens> ')'
fn embed(pp: *Preprocessor, tokenizer: *Tokenizer) MacroError!void {
    const first = tokenizer.nextNoWS();
    const filename_tok = pp.findIncludeFilenameToken(first, tokenizer, .ignore_trailing_tokens) catch |er| switch (er) {
        error.InvalidInclude => return,
        else => |e| return e,
    };
    defer TokenWithExpansionLocs.free(filename_tok.expansion_locs, pp.gpa);

    // Check for empty filename.
    const tok_slice = pp.expandedSliceExtra(filename_tok, .single_macro_ws);
    if (tok_slice.len < 3) {
        try pp.err(first, .empty_filename);
        return;
    }
    const filename = tok_slice[1 .. tok_slice.len - 1];
    const include_type: Compilation.IncludeType = switch (filename_tok.id) {
        .string_literal => .quotes,
        .macro_string => .angle_brackets,
        else => unreachable,
    };

    // Index into `token_buf`
    const Range = struct {
        start: u32,
        end: u32,

        fn expand(opt_range: ?@This(), pp_: *Preprocessor, tokenizer_: *Tokenizer) !void {
            const range = opt_range orelse return;
            const slice = pp_.token_buf.items[range.start..range.end];
            for (slice) |tok| {
                try pp_.expandMacro(tokenizer_, tok);
            }
        }
    };
    pp.token_buf.items.len = 0;

    var limit: ?u32 = null;
    var prefix: ?Range = null;
    var suffix: ?Range = null;
    var if_empty: ?Range = null;
    while (true) {
        const param_first = tokenizer.nextNoWS();
        switch (param_first.id) {
            .nl, .eof => break,
            .identifier => {},
            else => {
                try pp.err(param_first, .malformed_embed_param);
                continue;
            },
        }

        const char_top = pp.char_buf.items.len;
        defer pp.char_buf.items.len = char_top;

        const maybe_colon = tokenizer.colonColon();
        const param = switch (maybe_colon.id) {
            .colon_colon => blk: {
                // vendor::param
                const param = tokenizer.nextNoWS();
                if (param.id != .identifier) {
                    try pp.err(param, .malformed_embed_param);
                    continue;
                }
                const l_paren = tokenizer.nextNoWS();
                if (l_paren.id != .l_paren) {
                    try pp.err(l_paren, .malformed_embed_param);
                    continue;
                }
                try pp.char_buf.appendSlice(Attribute.normalize(pp.tokSlice(param_first)));
                try pp.char_buf.appendSlice("::");
                try pp.char_buf.appendSlice(Attribute.normalize(pp.tokSlice(param)));
                break :blk pp.char_buf.items;
            },
            .l_paren => Attribute.normalize(pp.tokSlice(param_first)),
            else => {
                try pp.err(maybe_colon, .malformed_embed_param);
                continue;
            },
        };

        const start: u32 = @intCast(pp.token_buf.items.len);
        while (true) {
            const next = tokenizer.nextNoWS();
            if (next.id == .r_paren) break;
            if (next.id == .eof) {
                try pp.err(maybe_colon, .malformed_embed_param);
                break;
            }
            try pp.token_buf.append(next);
        }
        const end: u32 = @intCast(pp.token_buf.items.len);

        if (std.mem.eql(u8, param, "limit")) {
            if (limit != null) {
                try pp.errStr(tokFromRaw(param_first), .duplicate_embed_param, "limit");
                continue;
            }
            if (start + 1 != end) {
                try pp.err(param_first, .malformed_embed_limit);
                continue;
            }
            const limit_tok = pp.token_buf.items[start];
            if (limit_tok.id != .pp_num) {
                try pp.err(param_first, .malformed_embed_limit);
                continue;
            }
            limit = std.fmt.parseInt(u32, pp.tokSlice(limit_tok), 10) catch {
                try pp.err(limit_tok, .malformed_embed_limit);
                continue;
            };
            pp.token_buf.items.len = start;
        } else if (std.mem.eql(u8, param, "prefix")) {
            if (prefix != null) {
                try pp.errStr(tokFromRaw(param_first), .duplicate_embed_param, "prefix");
                continue;
            }
            prefix = .{ .start = start, .end = end };
        } else if (std.mem.eql(u8, param, "suffix")) {
            if (suffix != null) {
                try pp.errStr(tokFromRaw(param_first), .duplicate_embed_param, "suffix");
                continue;
            }
            suffix = .{ .start = start, .end = end };
        } else if (std.mem.eql(u8, param, "if_empty")) {
            if (if_empty != null) {
                try pp.errStr(tokFromRaw(param_first), .duplicate_embed_param, "if_empty");
                continue;
            }
            if_empty = .{ .start = start, .end = end };
        } else {
            try pp.errStr(
                tokFromRaw(param_first),
                .unsupported_embed_param,
                try pp.comp.diagnostics.arena.allocator().dupe(u8, param),
            );
            pp.token_buf.items.len = start;
        }
    }

    const embed_bytes = (try pp.comp.findEmbed(filename, first.source, include_type, limit)) orelse
        return pp.fatalNotFound(filename_tok, filename);
    defer pp.comp.gpa.free(embed_bytes);

    try Range.expand(prefix, pp, tokenizer);

    if (embed_bytes.len == 0) {
        try Range.expand(if_empty, pp, tokenizer);
        try Range.expand(suffix, pp, tokenizer);
        return;
    }

    try pp.ensureUnusedTokenCapacity(2 * embed_bytes.len - 1); // N bytes and N-1 commas

    // TODO: We currently only support systems with CHAR_BIT == 8
    // If the target's CHAR_BIT is not 8, we need to write out correctly-sized embed_bytes
    // and correctly account for the target's endianness
    const writer = pp.comp.generated_buf.writer(pp.gpa);

    {
        const byte = embed_bytes[0];
        const start = pp.comp.generated_buf.items.len;
        try writer.print("{d}", .{byte});
        pp.addTokenAssumeCapacity(try pp.makeGeneratedToken(start, .embed_byte, filename_tok));
    }

    for (embed_bytes[1..]) |byte| {
        const start = pp.comp.generated_buf.items.len;
        try writer.print(",{d}", .{byte});
        pp.addTokenAssumeCapacity(.{ .id = .comma, .loc = .{ .id = .generated, .byte_offset = @intCast(start) } });
        pp.addTokenAssumeCapacity(try pp.makeGeneratedToken(start + 1, .embed_byte, filename_tok));
    }
    try pp.comp.generated_buf.append(pp.gpa, '\n');

    try Range.expand(suffix, pp, tokenizer);
}

// Handle a #include directive.
fn include(pp: *Preprocessor, tokenizer: *Tokenizer, which: Compilation.WhichInclude) MacroError!void {
    const first = tokenizer.nextNoWS();
    const new_source = findIncludeSource(pp, tokenizer, first, which) catch |er| switch (er) {
        error.InvalidInclude => return,
        else => |e| return e,
    };

    // Prevent stack overflow
    pp.include_depth += 1;
    defer pp.include_depth -= 1;
    if (pp.include_depth > max_include_depth) {
        try pp.comp.addDiagnostic(.{
            .tag = .too_many_includes,
            .loc = .{ .id = first.source, .byte_offset = first.start, .line = first.line },
        }, &.{});
        return error.StopPreprocessing;
    }

    if (pp.include_guards.get(new_source.id)) |guard| {
        if (pp.defines.contains(guard)) return;
    }

    if (pp.verbose) {
        pp.verboseLog(first, "include file {s}", .{new_source.path});
    }

    const token_state = pp.getTokenState();
    try pp.addIncludeStart(new_source);
    const eof = pp.preprocessExtra(new_source) catch |er| switch (er) {
        error.StopPreprocessing => {
            for (pp.expansion_entries.items(.locs)[token_state.expansion_entries_len..]) |loc| TokenWithExpansionLocs.free(loc, pp.gpa);
            pp.restoreTokenState(token_state);
            return;
        },
        else => |e| return e,
    };
    try eof.checkMsEof(new_source, pp.comp);
    if (pp.preserve_whitespace and pp.tokens.items(.id)[pp.tokens.len - 1] != .nl) {
        try pp.addToken(.{ .id = .nl, .loc = .{
            .id = tokenizer.source,
            .line = tokenizer.line,
        } });
    }
    if (pp.linemarkers == .none) return;
    var next = first;
    while (true) {
        var tmp = tokenizer.*;
        next = tmp.nextNoWS();
        if (next.id != .nl) break;
        tokenizer.* = tmp;
    }
    try pp.addIncludeResume(next.source, next.end, next.line);
}

/// tokens that are part of a pragma directive can happen in 3 ways:
///     1. directly in the text via `#pragma ...`
///     2. Via a string literal argument to `_Pragma`
///     3. Via a stringified macro argument which is used as an argument to `_Pragma`
/// operator_loc: Location of `_Pragma`; null if this is from #pragma
/// arg_locs: expansion locations of the argument to _Pragma. empty if #pragma or a raw string literal was used
fn makePragmaToken(pp: *Preprocessor, raw: RawToken, operator_loc: ?Source.Location, arg_locs: []const Source.Location) !TokenWithExpansionLocs {
    var tok = tokFromRaw(raw);
    if (operator_loc) |loc| {
        try tok.addExpansionLocation(pp.gpa, &.{loc});
    }
    try tok.addExpansionLocation(pp.gpa, arg_locs);
    return tok;
}

pub fn addToken(pp: *Preprocessor, tok: TokenWithExpansionLocs) !void {
    if (tok.expansion_locs) |expansion_locs| {
        try pp.expansion_entries.append(pp.gpa, .{ .idx = @intCast(pp.tokens.len), .locs = expansion_locs });
    }
    try pp.tokens.append(pp.gpa, .{ .id = tok.id, .loc = tok.loc });
}

pub fn addTokenAssumeCapacity(pp: *Preprocessor, tok: TokenWithExpansionLocs) void {
    if (tok.expansion_locs) |expansion_locs| {
        pp.expansion_entries.appendAssumeCapacity(.{ .idx = @intCast(pp.tokens.len), .locs = expansion_locs });
    }
    pp.tokens.appendAssumeCapacity(.{ .id = tok.id, .loc = tok.loc });
}

pub fn ensureTotalTokenCapacity(pp: *Preprocessor, capacity: usize) !void {
    try pp.tokens.ensureTotalCapacity(pp.gpa, capacity);
    try pp.expansion_entries.ensureTotalCapacity(pp.gpa, capacity);
}

pub fn ensureUnusedTokenCapacity(pp: *Preprocessor, capacity: usize) !void {
    try pp.tokens.ensureUnusedCapacity(pp.gpa, capacity);
    try pp.expansion_entries.ensureUnusedCapacity(pp.gpa, capacity);
}

/// Handle a pragma directive
fn pragma(pp: *Preprocessor, tokenizer: *Tokenizer, pragma_tok: RawToken, operator_loc: ?Source.Location, arg_locs: []const Source.Location) !void {
    const name_tok = tokenizer.nextNoWS();
    if (name_tok.id == .nl or name_tok.id == .eof) return;

    const name = pp.tokSlice(name_tok);
    try pp.addToken(try pp.makePragmaToken(pragma_tok, operator_loc, arg_locs));
    const pragma_start: u32 = @intCast(pp.tokens.len);

    const pragma_name_tok = try pp.makePragmaToken(name_tok, operator_loc, arg_locs);
    try pp.addToken(pragma_name_tok);
    while (true) {
        const next_tok = tokenizer.next();
        if (next_tok.id == .whitespace) continue;
        if (next_tok.id == .eof) {
            try pp.addToken(.{
                .id = .nl,
                .loc = .{ .id = .generated },
            });
            break;
        }
        try pp.addToken(try pp.makePragmaToken(next_tok, operator_loc, arg_locs));
        if (next_tok.id == .nl) break;
    }
    if (pp.comp.getPragma(name)) |prag| unknown: {
        return prag.preprocessorCB(pp, pragma_start) catch |er| switch (er) {
            error.UnknownPragma => break :unknown,
            else => |e| return e,
        };
    }
    return pp.comp.addDiagnostic(.{
        .tag = .unknown_pragma,
        .loc = pragma_name_tok.loc,
    }, pragma_name_tok.expansionSlice());
}

fn findIncludeFilenameToken(
    pp: *Preprocessor,
    first_token: RawToken,
    tokenizer: *Tokenizer,
    trailing_token_behavior: enum { ignore_trailing_tokens, expect_nl_eof },
) !TokenWithExpansionLocs {
    var first = first_token;

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
        try pp.comp.addDiagnostic(.{
            .tag = .header_str_closing,
            .loc = .{ .id = first.source, .byte_offset = tokenizer.index, .line = first.line },
        }, &.{});
        try pp.err(first, .header_str_match);
    }

    const source_tok = tokFromRaw(first);
    const filename_tok, const expanded_trailing = switch (source_tok.id) {
        .string_literal, .macro_string => .{ source_tok, false },
        else => expanded: {
            // Try to expand if the argument is a macro.
            pp.top_expansion_buf.items.len = 0;
            defer for (pp.top_expansion_buf.items) |tok| TokenWithExpansionLocs.free(tok.expansion_locs, pp.gpa);
            try pp.top_expansion_buf.append(source_tok);
            pp.expansion_source_loc = source_tok.loc;

            try pp.expandMacroExhaustive(tokenizer, &pp.top_expansion_buf, 0, 1, true, .non_expr);
            var trailing_toks: []const TokenWithExpansionLocs = &.{};
            const include_str = (try pp.reconstructIncludeString(pp.top_expansion_buf.items, &trailing_toks, tokFromRaw(first))) orelse {
                try pp.expectNl(tokenizer);
                return error.InvalidInclude;
            };
            const start = pp.comp.generated_buf.items.len;
            try pp.comp.generated_buf.appendSlice(pp.gpa, include_str);

            break :expanded .{ try pp.makeGeneratedToken(start, switch (include_str[0]) {
                '"' => .string_literal,
                '<' => .macro_string,
                else => unreachable,
            }, pp.top_expansion_buf.items[0]), trailing_toks.len != 0 };
        },
    };

    switch (trailing_token_behavior) {
        .expect_nl_eof => {
            // Error on extra tokens.
            const nl = tokenizer.nextNoWS();
            if ((nl.id != .nl and nl.id != .eof) or expanded_trailing) {
                skipToNl(tokenizer);
                try pp.comp.diagnostics.addExtra(pp.comp.langopts, .{
                    .tag = .extra_tokens_directive_end,
                    .loc = filename_tok.loc,
                }, filename_tok.expansionSlice(), false);
            }
        },
        .ignore_trailing_tokens => if (expanded_trailing) {
            try pp.comp.diagnostics.addExtra(pp.comp.langopts, .{
                .tag = .extra_tokens_directive_end,
                .loc = filename_tok.loc,
            }, filename_tok.expansionSlice(), false);
        },
    }
    return filename_tok;
}

fn findIncludeSource(pp: *Preprocessor, tokenizer: *Tokenizer, first: RawToken, which: Compilation.WhichInclude) !Source {
    const filename_tok = try pp.findIncludeFilenameToken(first, tokenizer, .expect_nl_eof);
    defer TokenWithExpansionLocs.free(filename_tok.expansion_locs, pp.gpa);

    // Check for empty filename.
    const tok_slice = pp.expandedSliceExtra(filename_tok, .single_macro_ws);
    if (tok_slice.len < 3) {
        try pp.err(first, .empty_filename);
        return error.InvalidInclude;
    }

    // Find the file.
    const filename = tok_slice[1 .. tok_slice.len - 1];
    const include_type: Compilation.IncludeType = switch (filename_tok.id) {
        .string_literal => .quotes,
        .macro_string => .angle_brackets,
        else => unreachable,
    };

    return (try pp.comp.findInclude(filename, first, include_type, which)) orelse
        return pp.fatalNotFound(filename_tok, filename);
}

fn printLinemarker(
    pp: *Preprocessor,
    w: anytype,
    line_no: u32,
    source: Source,
    start_resume: enum(u8) { start, @"resume", none },
) !void {
    try w.writeByte('#');
    if (pp.linemarkers == .line_directives) try w.writeAll("line");
    try w.print(" {d} \"", .{line_no});
    for (source.path) |byte| switch (byte) {
        '\n' => try w.writeAll("\\n"),
        '\r' => try w.writeAll("\\r"),
        '\t' => try w.writeAll("\\t"),
        '\\' => try w.writeAll("\\\\"),
        '"' => try w.writeAll("\\\""),
        ' ', '!', '#'...'&', '('...'[', ']'...'~' => try w.writeByte(byte),
        // Use hex escapes for any non-ASCII/unprintable characters.
        // This ensures that the parsed version of this string will end up
        // containing the same bytes as the input regardless of encoding.
        else => {
            try w.writeAll("\\x");
            try std.fmt.formatInt(byte, 16, .lower, .{ .width = 2, .fill = '0' }, w);
        },
    };
    try w.writeByte('"');
    if (pp.linemarkers == .numeric_directives) {
        switch (start_resume) {
            .none => {},
            .start => try w.writeAll(" 1"),
            .@"resume" => try w.writeAll(" 2"),
        }
        switch (source.kind) {
            .user => {},
            .system => try w.writeAll(" 3"),
            .extern_c_system => try w.writeAll(" 3 4"),
        }
    }
    try w.writeByte('\n');
}

// After how many empty lines are needed to replace them with linemarkers.
const collapse_newlines = 8;

/// Pretty print tokens and try to preserve whitespace.
pub fn prettyPrintTokens(pp: *Preprocessor, w: anytype) !void {
    const tok_ids = pp.tokens.items(.id);

    var i: u32 = 0;
    var last_nl = true;
    outer: while (true) : (i += 1) {
        var cur: Token = pp.tokens.get(i);
        switch (cur.id) {
            .eof => {
                if (!last_nl) try w.writeByte('\n');
                return;
            },
            .nl => {
                var newlines: u32 = 0;
                for (tok_ids[i..], i..) |id, j| {
                    if (id == .nl) {
                        newlines += 1;
                    } else if (id == .eof) {
                        if (!last_nl) try w.writeByte('\n');
                        return;
                    } else if (id != .whitespace) {
                        if (pp.linemarkers == .none) {
                            if (newlines < 2) break;
                        } else if (newlines < collapse_newlines) {
                            break;
                        }

                        i = @intCast((j - 1) - @intFromBool(tok_ids[j - 1] == .whitespace));
                        if (!last_nl) try w.writeAll("\n");
                        if (pp.linemarkers != .none) {
                            const next = pp.tokens.get(i);
                            const source = pp.comp.getSource(next.loc.id);
                            const line_col = source.lineCol(next.loc);
                            try pp.printLinemarker(w, line_col.line_no, source, .none);
                            last_nl = true;
                        }
                        continue :outer;
                    }
                }
                last_nl = true;
                try w.writeAll("\n");
            },
            .keyword_pragma => {
                const pragma_name = pp.expandedSlice(pp.tokens.get(i + 1));
                const end_idx = mem.indexOfScalarPos(Token.Id, tok_ids, i, .nl) orelse i + 1;
                const pragma_len = @as(u32, @intCast(end_idx)) - i;

                if (pp.comp.getPragma(pragma_name)) |prag| {
                    if (!prag.shouldPreserveTokens(pp, i + 1)) {
                        try w.writeByte('\n');
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
                        last_nl = true;
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
                    if (pp.linemarkers != .none) try w.writeByte('\n');
                    slice = slice[some + 1 ..];
                }
                for (slice) |_| try w.writeByte(' ');
                last_nl = false;
            },
            .include_start => {
                const source = pp.comp.getSource(cur.loc.id);

                try pp.printLinemarker(w, 1, source, .start);
                last_nl = true;
            },
            .include_resume => {
                const source = pp.comp.getSource(cur.loc.id);
                const line_col = source.lineCol(cur.loc);
                if (!last_nl) try w.writeAll("\n");

                try pp.printLinemarker(w, line_col.line_no, source, .@"resume");
                last_nl = true;
            },
            else => {
                const slice = pp.expandedSlice(cur);
                try w.writeAll(slice);
                last_nl = false;
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

            try comp.addDefaultPragmaHandlers();

            var pp = Preprocessor.init(&comp);
            defer pp.deinit();

            pp.preserve_whitespace = true;
            assert(pp.linemarkers == .none);

            const test_runner_macros = try comp.addSourceFromBuffer("<test_runner>", source_text);
            const eof = try pp.preprocess(test_runner_macros);
            try pp.addToken(eof);
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
    // TODO should only be one newline afterwards when emulating clang
    try Test.check(omit_once, "\nint x;\n\n");

    const omit_poison =
        \\#pragma GCC poison foobar
        \\
    ;
    try Test.check(omit_poison, "\n");
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

test "Include guards" {
    const Test = struct {
        /// This is here so that when #elifdef / #elifndef are added we don't forget
        /// to test that they don't accidentally break include guard detection
        fn pairsWithIfndef(tok_id: RawToken.Id) bool {
            return switch (tok_id) {
                .keyword_elif,
                .keyword_elifdef,
                .keyword_elifndef,
                .keyword_else,
                => true,

                .keyword_include,
                .keyword_include_next,
                .keyword_embed,
                .keyword_define,
                .keyword_defined,
                .keyword_undef,
                .keyword_ifdef,
                .keyword_ifndef,
                .keyword_error,
                .keyword_warning,
                .keyword_pragma,
                .keyword_line,
                .keyword_endif,
                => false,
                else => unreachable,
            };
        }

        fn skippable(tok_id: RawToken.Id) bool {
            return switch (tok_id) {
                .keyword_defined, .keyword_va_args, .keyword_va_opt, .keyword_endif => true,
                else => false,
            };
        }

        fn testIncludeGuard(allocator: std.mem.Allocator, comptime template: []const u8, tok_id: RawToken.Id, expected_guards: u32) !void {
            var comp = Compilation.init(allocator);
            defer comp.deinit();
            var pp = Preprocessor.init(&comp);
            defer pp.deinit();

            const path = try std.fs.path.join(allocator, &.{ ".", "bar.h" });
            defer allocator.free(path);

            _ = try comp.addSourceFromBuffer(path, "int bar = 5;\n");

            var buf = std.ArrayList(u8).init(allocator);
            defer buf.deinit();

            var writer = buf.writer();
            switch (tok_id) {
                .keyword_include, .keyword_include_next => try writer.print(template, .{ tok_id.lexeme().?, " \"bar.h\"" }),
                .keyword_define, .keyword_undef => try writer.print(template, .{ tok_id.lexeme().?, " BAR" }),
                .keyword_ifndef,
                .keyword_ifdef,
                .keyword_elifdef,
                .keyword_elifndef,
                => try writer.print(template, .{ tok_id.lexeme().?, " BAR\n#endif" }),
                else => try writer.print(template, .{ tok_id.lexeme().?, "" }),
            }
            const source = try comp.addSourceFromBuffer("test.h", buf.items);
            _ = try pp.preprocess(source);

            try std.testing.expectEqual(expected_guards, pp.include_guards.count());
        }
    };
    const tags = std.meta.tags(RawToken.Id);
    for (tags) |tag| {
        if (Test.skippable(tag)) continue;
        var copy = tag;
        copy.simplifyMacroKeyword();
        if (copy != tag or tag == .keyword_else) {
            const inside_ifndef_template =
                \\//Leading comment (should be ignored)
                \\
                \\#ifndef FOO
                \\#{s}{s}
                \\#endif
            ;
            const expected_guards: u32 = if (Test.pairsWithIfndef(tag)) 0 else 1;
            try Test.testIncludeGuard(std.testing.allocator, inside_ifndef_template, tag, expected_guards);

            const outside_ifndef_template =
                \\#ifndef FOO
                \\#endif
                \\#{s}{s}
            ;
            try Test.testIncludeGuard(std.testing.allocator, outside_ifndef_template, tag, 0);
        }
    }
}
