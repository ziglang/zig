const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;

const aro = @import("aro");
const CToken = aro.Tokenizer.Token;

const helpers = @import("helpers.zig");
const Translator = @import("Translator.zig");
const Error = Translator.Error;
pub const MacroProcessingError = Error || error{UnexpectedMacroToken};

const Impl = std.meta.DeclEnum(std.zig.c_translation.helpers);
const Template = struct { []const u8, Impl };

/// Templates must be function-like macros
/// first element is macro source, second element is the name of the function
/// in __helpers which implements it
const templates = [_]Template{
    .{ "f_SUFFIX(X) (X ## f)", .F_SUFFIX },
    .{ "F_SUFFIX(X) (X ## F)", .F_SUFFIX },

    .{ "u_SUFFIX(X) (X ## u)", .U_SUFFIX },
    .{ "U_SUFFIX(X) (X ## U)", .U_SUFFIX },

    .{ "l_SUFFIX(X) (X ## l)", .L_SUFFIX },
    .{ "L_SUFFIX(X) (X ## L)", .L_SUFFIX },

    .{ "ul_SUFFIX(X) (X ## ul)", .UL_SUFFIX },
    .{ "uL_SUFFIX(X) (X ## uL)", .UL_SUFFIX },
    .{ "Ul_SUFFIX(X) (X ## Ul)", .UL_SUFFIX },
    .{ "UL_SUFFIX(X) (X ## UL)", .UL_SUFFIX },

    .{ "ll_SUFFIX(X) (X ## ll)", .LL_SUFFIX },
    .{ "LL_SUFFIX(X) (X ## LL)", .LL_SUFFIX },

    .{ "ull_SUFFIX(X) (X ## ull)", .ULL_SUFFIX },
    .{ "uLL_SUFFIX(X) (X ## uLL)", .ULL_SUFFIX },
    .{ "Ull_SUFFIX(X) (X ## Ull)", .ULL_SUFFIX },
    .{ "ULL_SUFFIX(X) (X ## ULL)", .ULL_SUFFIX },

    .{ "f_SUFFIX(X) X ## f", .F_SUFFIX },
    .{ "F_SUFFIX(X) X ## F", .F_SUFFIX },

    .{ "u_SUFFIX(X) X ## u", .U_SUFFIX },
    .{ "U_SUFFIX(X) X ## U", .U_SUFFIX },

    .{ "l_SUFFIX(X) X ## l", .L_SUFFIX },
    .{ "L_SUFFIX(X) X ## L", .L_SUFFIX },

    .{ "ul_SUFFIX(X) X ## ul", .UL_SUFFIX },
    .{ "uL_SUFFIX(X) X ## uL", .UL_SUFFIX },
    .{ "Ul_SUFFIX(X) X ## Ul", .UL_SUFFIX },
    .{ "UL_SUFFIX(X) X ## UL", .UL_SUFFIX },

    .{ "ll_SUFFIX(X) X ## ll", .LL_SUFFIX },
    .{ "LL_SUFFIX(X) X ## LL", .LL_SUFFIX },

    .{ "ull_SUFFIX(X) X ## ull", .ULL_SUFFIX },
    .{ "uLL_SUFFIX(X) X ## uLL", .ULL_SUFFIX },
    .{ "Ull_SUFFIX(X) X ## Ull", .ULL_SUFFIX },
    .{ "ULL_SUFFIX(X) X ## ULL", .ULL_SUFFIX },

    .{ "CAST_OR_CALL(X, Y) (X)(Y)", .CAST_OR_CALL },
    .{ "CAST_OR_CALL(X, Y) ((X)(Y))", .CAST_OR_CALL },

    .{
        \\wl_container_of(ptr, sample, member)                     \
        \\(__typeof__(sample))((char *)(ptr) -                     \
        \\     offsetof(__typeof__(*sample), member))
        ,
        .WL_CONTAINER_OF,
    },

    .{ "IGNORE_ME(X) ((void)(X))", .DISCARD },
    .{ "IGNORE_ME(X) (void)(X)", .DISCARD },
    .{ "IGNORE_ME(X) ((const void)(X))", .DISCARD },
    .{ "IGNORE_ME(X) (const void)(X)", .DISCARD },
    .{ "IGNORE_ME(X) ((volatile void)(X))", .DISCARD },
    .{ "IGNORE_ME(X) (volatile void)(X)", .DISCARD },
    .{ "IGNORE_ME(X) ((const volatile void)(X))", .DISCARD },
    .{ "IGNORE_ME(X) (const volatile void)(X)", .DISCARD },
    .{ "IGNORE_ME(X) ((volatile const void)(X))", .DISCARD },
    .{ "IGNORE_ME(X) (volatile const void)(X)", .DISCARD },
};

const Pattern = struct {
    slicer: MacroSlicer,
    impl: Impl,

    fn init(pl: *Pattern, allocator: mem.Allocator, template: Template) Error!void {
        const source = template[0];
        const impl = template[1];
        var tok_list: std.ArrayList(CToken) = .empty;
        defer tok_list.deinit(allocator);

        pl.* = .{
            .slicer = try tokenizeMacro(allocator, source, &tok_list),
            .impl = impl,
        };
    }

    fn deinit(pl: *Pattern, allocator: mem.Allocator) void {
        allocator.free(pl.slicer.tokens);
        pl.* = undefined;
    }

    /// This function assumes that `ms` has already been validated to contain a function-like
    /// macro, and that the parsed template macro in `pl` also contains a function-like
    /// macro. Please review this logic carefully if changing that assumption. Two
    /// function-like macros are considered equivalent if and only if they contain the same
    /// list of tokens, modulo parameter names.
    fn matches(pat: Pattern, ms: MacroSlicer) bool {
        if (ms.params != pat.slicer.params) return false;
        if (ms.tokens.len != pat.slicer.tokens.len) return false;

        for (ms.tokens, pat.slicer.tokens) |macro_tok, pat_tok| {
            if (macro_tok.id != pat_tok.id) return false;
            switch (macro_tok.id) {
                .macro_param, .macro_param_no_expand => {
                    // `.end` is the parameter index.
                    if (macro_tok.end != pat_tok.end) return false;
                },
                .identifier, .extended_identifier, .string_literal, .char_literal, .pp_num => {
                    const macro_bytes = ms.slice(macro_tok);
                    const pattern_bytes = pat.slicer.slice(pat_tok);

                    if (!mem.eql(u8, pattern_bytes, macro_bytes)) return false;
                },
                else => {
                    // other tags correspond to keywords and operators that do not contain a "payload"
                    // that can vary
                },
            }
        }
        return true;
    }
};

const PatternList = @This();

patterns: []Pattern,

pub const MacroSlicer = struct {
    source: []const u8,
    tokens: []const CToken,
    params: u32,

    fn slice(pl: MacroSlicer, token: CToken) []const u8 {
        return pl.source[token.start..token.end];
    }
};

pub fn init(allocator: mem.Allocator) Error!PatternList {
    const patterns = try allocator.alloc(Pattern, templates.len);
    for (patterns, templates) |*pattern, template| {
        try pattern.init(allocator, template);
    }
    return .{ .patterns = patterns };
}

pub fn deinit(pl: *PatternList, allocator: mem.Allocator) void {
    for (pl.patterns) |*pattern| pattern.deinit(allocator);
    allocator.free(pl.patterns);
    pl.* = undefined;
}

pub fn match(pl: PatternList, ms: MacroSlicer) Error!?Impl {
    for (pl.patterns) |pattern| if (pattern.matches(ms)) return pattern.impl;
    return null;
}

fn tokenizeMacro(allocator: mem.Allocator, source: []const u8, tok_list: *std.ArrayList(CToken)) Error!MacroSlicer {
    var param_count: u32 = 0;
    var param_buf: [8][]const u8 = undefined;

    var tokenizer: aro.Tokenizer = .{
        .buf = source,
        .source = .unused,
        .langopts = .{},
    };
    {
        const name_tok = tokenizer.nextNoWS();
        assert(name_tok.id == .identifier);
        const l_paren = tokenizer.nextNoWS();
        assert(l_paren.id == .l_paren);
    }

    while (true) {
        const param = tokenizer.nextNoWS();
        if (param.id == .r_paren) break;
        assert(param.id == .identifier);
        const slice = source[param.start..param.end];
        param_buf[param_count] = slice;
        param_count += 1;

        const comma = tokenizer.nextNoWS();
        if (comma.id == .r_paren) break;
        assert(comma.id == .comma);
    }

    outer: while (true) {
        const tok = tokenizer.next();
        switch (tok.id) {
            .whitespace, .comment => continue,
            .identifier => {
                const slice = source[tok.start..tok.end];
                for (param_buf[0..param_count], 0..) |param, i| {
                    if (std.mem.eql(u8, param, slice)) {
                        try tok_list.append(allocator, .{
                            .id = .macro_param,
                            .source = .unused,
                            .end = @intCast(i),
                        });
                        continue :outer;
                    }
                }
            },
            .hash_hash => {
                if (tok_list.items[tok_list.items.len - 1].id == .macro_param) {
                    tok_list.items[tok_list.items.len - 1].id = .macro_param_no_expand;
                }
            },
            .nl, .eof => break,
            else => {},
        }
        try tok_list.append(allocator, tok);
    }

    return .{
        .source = source,
        .tokens = try tok_list.toOwnedSlice(allocator),
        .params = param_count,
    };
}

test "Macro matching" {
    const testing = std.testing;
    const helper = struct {
        fn checkMacro(
            allocator: mem.Allocator,
            pattern_list: PatternList,
            source: []const u8,
            comptime expected_match: ?Impl,
        ) !void {
            var tok_list: std.ArrayList(CToken) = .empty;
            defer tok_list.deinit(allocator);
            const ms = try tokenizeMacro(allocator, source, &tok_list);
            defer allocator.free(ms.tokens);

            const matched = try pattern_list.match(ms);
            if (expected_match) |expected| {
                try testing.expectEqual(expected, matched);
            } else {
                try testing.expectEqual(@as(@TypeOf(matched), null), matched);
            }
        }
    };
    const allocator = std.testing.allocator;
    var pattern_list = try PatternList.init(allocator);
    defer pattern_list.deinit(allocator);

    try helper.checkMacro(allocator, pattern_list, "BAR(Z) (Z ## F)", .F_SUFFIX);
    try helper.checkMacro(allocator, pattern_list, "BAR(Z) (Z ## U)", .U_SUFFIX);
    try helper.checkMacro(allocator, pattern_list, "BAR(Z) (Z ## L)", .L_SUFFIX);
    try helper.checkMacro(allocator, pattern_list, "BAR(Z) (Z ## LL)", .LL_SUFFIX);
    try helper.checkMacro(allocator, pattern_list, "BAR(Z) (Z ## UL)", .UL_SUFFIX);
    try helper.checkMacro(allocator, pattern_list, "BAR(Z) (Z ## ULL)", .ULL_SUFFIX);
    try helper.checkMacro(allocator, pattern_list,
        \\container_of(a, b, c)                             \
        \\(__typeof__(b))((char *)(a) -                     \
        \\     offsetof(__typeof__(*b), c))
    , .WL_CONTAINER_OF);

    try helper.checkMacro(allocator, pattern_list, "NO_MATCH(X, Y) (X + Y)", null);
    try helper.checkMacro(allocator, pattern_list, "CAST_OR_CALL(X, Y) (X)(Y)", .CAST_OR_CALL);
    try helper.checkMacro(allocator, pattern_list, "CAST_OR_CALL(X, Y) ((X)(Y))", .CAST_OR_CALL);
    try helper.checkMacro(allocator, pattern_list, "IGNORE_ME(X) (void)(X)", .DISCARD);
    try helper.checkMacro(allocator, pattern_list, "IGNORE_ME(X) ((void)(X))", .DISCARD);
    try helper.checkMacro(allocator, pattern_list, "IGNORE_ME(X) (const void)(X)", .DISCARD);
    try helper.checkMacro(allocator, pattern_list, "IGNORE_ME(X) ((const void)(X))", .DISCARD);
    try helper.checkMacro(allocator, pattern_list, "IGNORE_ME(X) (volatile void)(X)", .DISCARD);
    try helper.checkMacro(allocator, pattern_list, "IGNORE_ME(X) ((volatile void)(X))", .DISCARD);
    try helper.checkMacro(allocator, pattern_list, "IGNORE_ME(X) (const volatile void)(X)", .DISCARD);
    try helper.checkMacro(allocator, pattern_list, "IGNORE_ME(X) ((const volatile void)(X))", .DISCARD);
    try helper.checkMacro(allocator, pattern_list, "IGNORE_ME(X) (volatile const void)(X)", .DISCARD);
    try helper.checkMacro(allocator, pattern_list, "IGNORE_ME(X) ((volatile const void)(X))", .DISCARD);
}
