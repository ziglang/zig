const std = @import("std");
const lex = @import("lex.zig");
const SourceMappings = @import("source_mapping.zig").SourceMappings;
const SupportedCodePage = @import("code_pages.zig").SupportedCodePage;

pub fn hasDisjointCodePage(source: []const u8, source_mappings: ?*const SourceMappings, default_code_page: SupportedCodePage) bool {
    var line_handler = lex.LineHandler{ .buffer = source };
    var i: usize = 0;
    while (i < source.len) {
        const codepoint = default_code_page.codepointAt(i, source) orelse break;
        const c = codepoint.value;
        switch (c) {
            '\r', '\n' => {
                _ = line_handler.incrementLineNumber(i);
                // Any lines that are not from the root file interrupt the disjoint code page
                if (source_mappings != null and !source_mappings.?.isRootFile(line_handler.line_number)) return false;
            },
            // whitespace is ignored
            ' ',
            '\t',
            // NBSP, this should technically be in the TODO below, but it is treated as whitespace
            // due to a (misguided) special casing in the lexer, see the TODO in lex.zig
            '\u{A0}',
            => {},

            // TODO: All of the below are treated as whitespace by the Win32 RC preprocessor, which also
            //       means they are trimmed from the file during preprocessing. This means that these characters
            //       should be treated like ' ', '\t' above, but since the resinator preprocessor does not treat
            //       them as whitespace *or* trim whitespace, files with these characters are likely going to
            //       error. So, in the future some sort of emulation of/rejection of the Win32 behavior might
            //       make handling these codepoints specially make sense, but for now it doesn't really matter
            //       so they are not handled specially for simplicity's sake.
            //'\u{1680}',
            //'\u{180E}',
            //'\u{2001}',
            //'\u{2002}',
            //'\u{2003}',
            //'\u{2004}',
            //'\u{2005}',
            //'\u{2006}',
            //'\u{2007}',
            //'\u{2008}',
            //'\u{2009}',
            //'\u{200A}',
            //'\u{2028}',
            //'\u{2029}',
            //'\u{202F}',
            //'\u{205F}',
            //'\u{3000}',

            '#' => {
                if (source_mappings != null and !source_mappings.?.isRootFile(line_handler.line_number)) {
                    return false;
                }
                const start_i = i;
                while (i < source.len and source[i] != '\r' and source[i] != '\n') : (i += 1) {}
                const line = source[start_i..i];
                _ = (lex.parsePragmaCodePage(line) catch |err| switch (err) {
                    error.NotPragma => return false,
                    error.NotCodePagePragma => continue,
                    error.CodePagePragmaUnsupportedCodePage => continue,
                    else => continue,
                }) orelse return false; // DEFAULT interrupts disjoint code page

                // If we got a code page, then it is a disjoint code page pragma
                return true;
            },
            else => {
                // Any other character interrupts the disjoint code page
                return false;
            },
        }

        i += codepoint.byte_len;
    }
    return false;
}

test hasDisjointCodePage {
    try std.testing.expect(hasDisjointCodePage("#pragma code_page(65001)\n", null, .windows1252));
    // NBSP is a special case
    try std.testing.expect(hasDisjointCodePage("\xA0\n#pragma code_page(65001)\n", null, .windows1252));
    try std.testing.expect(hasDisjointCodePage("\u{A0}\n#pragma code_page(1252)\n", null, .utf8));
    // other preprocessor commands don't interrupt
    try std.testing.expect(hasDisjointCodePage("#pragma foo\n#pragma code_page(65001)\n", null, .windows1252));
    // invalid code page doesn't interrupt
    try std.testing.expect(hasDisjointCodePage("#pragma code_page(1234567)\n#pragma code_page(65001)\n", null, .windows1252));

    try std.testing.expect(!hasDisjointCodePage("#if 1\n#endif\n#pragma code_page(65001)", null, .windows1252));
    try std.testing.expect(!hasDisjointCodePage("// comment\n#pragma code_page(65001)", null, .windows1252));
    try std.testing.expect(!hasDisjointCodePage("/* comment */\n#pragma code_page(65001)", null, .windows1252));
}

test "multiline comment edge case" {
    // TODO
    if (true) return error.SkipZigTest;

    try std.testing.expect(hasDisjointCodePage("/* comment */#pragma code_page(65001)", null, .windows1252));
}
