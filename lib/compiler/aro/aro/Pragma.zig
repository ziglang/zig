const std = @import("std");
const Compilation = @import("Compilation.zig");
const Preprocessor = @import("Preprocessor.zig");
const Parser = @import("Parser.zig");
const TokenIndex = @import("Tree.zig").TokenIndex;

pub const Error = Compilation.Error || error{ UnknownPragma, StopPreprocessing };

const Pragma = @This();

/// Called during Preprocessor.init
beforePreprocess: ?*const fn (*Pragma, *Compilation) void = null,

/// Called at the beginning of Parser.parse
beforeParse: ?*const fn (*Pragma, *Compilation) void = null,

/// Called at the end of Parser.parse if a Tree was successfully parsed
afterParse: ?*const fn (*Pragma, *Compilation) void = null,

/// Called during Compilation.deinit
deinit: *const fn (*Pragma, *Compilation) void,

/// Called whenever the preprocessor encounters this pragma. `start_idx` is the index
/// within `pp.tokens` of the pragma name token. The pragma end is indicated by a
/// .nl token (which may be generated if the source ends with a pragma with no newline)
/// As an example, given the following line:
///     #pragma GCC diagnostic error "-Wnewline-eof" \n
/// Then pp.tokens.get(start_idx) will return the `GCC` token.
/// Return error.UnknownPragma to emit an `unknown_pragma` diagnostic
/// Return error.StopPreprocessing to stop preprocessing the current file (see once.zig)
preprocessorHandler: ?*const fn (*Pragma, *Preprocessor, start_idx: TokenIndex) Error!void = null,

/// Called during token pretty-printing (`-E` option). If this returns true, the pragma will
/// be printed; otherwise it will be omitted. start_idx is the index of the pragma name token
preserveTokens: ?*const fn (*Pragma, *Preprocessor, start_idx: TokenIndex) bool = null,

/// Same as preprocessorHandler except called during parsing
/// The parser's `p.tok_i` field must not be changed
parserHandler: ?*const fn (*Pragma, *Parser, start_idx: TokenIndex) Compilation.Error!void = null,

pub fn pasteTokens(pp: *Preprocessor, start_idx: TokenIndex) ![]const u8 {
    if (pp.tokens.get(start_idx).id == .nl) return error.ExpectedStringLiteral;

    const char_top = pp.char_buf.items.len;
    defer pp.char_buf.items.len = char_top;
    var i: usize = 0;
    var lparen_count: u32 = 0;
    var rparen_count: u32 = 0;
    while (true) : (i += 1) {
        const tok = pp.tokens.get(start_idx + i);
        if (tok.id == .nl) break;
        switch (tok.id) {
            .l_paren => {
                if (lparen_count != i) return error.ExpectedStringLiteral;
                lparen_count += 1;
            },
            .r_paren => rparen_count += 1,
            .string_literal => {
                if (rparen_count != 0) return error.ExpectedStringLiteral;
                const str = pp.expandedSlice(tok);
                try pp.char_buf.appendSlice(str[1 .. str.len - 1]);
            },
            else => return error.ExpectedStringLiteral,
        }
    }
    if (lparen_count != rparen_count) return error.ExpectedStringLiteral;
    return pp.char_buf.items[char_top..];
}

pub fn shouldPreserveTokens(self: *Pragma, pp: *Preprocessor, start_idx: TokenIndex) bool {
    if (self.preserveTokens) |func| return func(self, pp, start_idx);
    return false;
}

pub fn preprocessorCB(self: *Pragma, pp: *Preprocessor, start_idx: TokenIndex) Error!void {
    if (self.preprocessorHandler) |func| return func(self, pp, start_idx);
}

pub fn parserCB(self: *Pragma, p: *Parser, start_idx: TokenIndex) Compilation.Error!void {
    const tok_index = p.tok_i;
    defer std.debug.assert(tok_index == p.tok_i);
    if (self.parserHandler) |func| return func(self, p, start_idx);
}
