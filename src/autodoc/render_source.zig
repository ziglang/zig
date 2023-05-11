const std = @import("std");
const builtin = @import("builtin");
const io = std.io;
const fs = std.fs;
const process = std.process;
const ChildProcess = std.ChildProcess;
const Progress = std.Progress;
const print = std.debug.print;
const mem = std.mem;
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Module = @import("../Module.zig");

pub fn genHtml(
    allocator: Allocator,
    src: *Module.File,
    out: anytype,
) !void {
    try out.writeAll(
        \\<!doctype html>
        \\<html lang="en">
        \\<head>
        \\    <meta charset="utf-8">
        \\    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    );
    try out.print("    <title>{s} - source view</title>\n", .{src.sub_file_path});
    try out.writeAll(
        \\    <link rel="icon" href="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAAPNJREFUeNpi/P//PwMlgOXHUjly9E0G4hwgZmQiQZMqEK8H4v9QzUEgQSaoADK+zhH9iAGL+C0gDoAaNg9mGLoLfgA1awK9hS9gzgJxA9RQBmQDrgMxJzRMGKE4HYj/Ial5A8QmQLwCJoBsgBYW2+TR1ChDaWt4LOBxKsi/VUh8XiD+gq4IVyzwQAMJBoKwacZlAB8Qf0bi96IZhtOAe1D6LpqaEiz6rmEzQAeIzwGxCJpieFqApo/vQKyJboAaEBsAsSEupwI1MwKjGBTVHOhegMX5UajYRqiBjMgYmj400cVh0XgTiKdC0zhJgJHS7AwQYABm9EAdCKrEfAAAAABJRU5ErkJggg=="/>
        \\    <style>
        \\      body{
        \\        font-family: system-ui, -apple-system, Roboto, "Segoe UI", sans-serif;
        \\        margin: 0;
        \\        line-height: 1.5;
        \\      }
        \\
        \\      pre > code {
        \\        display: block;
        \\        overflow: auto;
        \\        line-height: normal;
        \\        margin: 0em;
        \\      }
        \\      .tok-kw {
        \\          color: #333;
        \\          font-weight: bold;
        \\      }
        \\      .tok-str {
        \\          color: #d14;
        \\      }
        \\      .tok-builtin {
        \\          color: #005C7A;
        \\      }
        \\      .tok-comment {
        \\          color: #545454;
        \\          font-style: italic;
        \\      }
        \\      .tok-fn {
        \\          color: #900;
        \\          font-weight: bold;
        \\      }
        \\      .tok-null {
        \\          color: #005C5C;
        \\      }
        \\      .tok-number {
        \\          color: #005C5C;
        \\      }
        \\      .tok-type {
        \\          color: #458;
        \\          font-weight: bold;
        \\      }
        \\      pre {
        \\        counter-reset: line;
        \\      }
        \\      pre .line:before {
        \\        counter-increment: line;
        \\        content: counter(line);
        \\        display: inline-block;
        \\        padding-right: 1em;
        \\        width: 2em;
        \\        text-align: right;
        \\        color: #999;
        \\      }
        \\      
        \\      .line {
        \\        width: 100%;
        \\        display: inline-block;
        \\      }
        \\      .line:target {
        \\        border-top: 1px solid #ccc;
        \\        border-bottom: 1px solid #ccc;
        \\        background: #fafafa;
        \\      }
        \\
        \\      @media (prefers-color-scheme: dark) {
        \\        body{
        \\            background:#222;
        \\            color: #ccc;
        \\        }
        \\        pre > code {
        \\            color: #ccc;
        \\            background: #222;
        \\            border: unset;
        \\        }
        \\        .line:target {
        \\            border-top: 1px solid #444;
        \\            border-bottom: 1px solid #444;
        \\            background: #333;
        \\        }
        \\        .tok-kw {
        \\            color: #eee;
        \\        }
        \\        .tok-str {
        \\            color: #2e5;
        \\        }
        \\        .tok-builtin {
        \\            color: #ff894c;
        \\        }
        \\        .tok-comment {
        \\            color: #aa7;
        \\        }
        \\        .tok-fn {
        \\            color: #B1A0F8;
        \\        }
        \\        .tok-null {
        \\            color: #ff8080;
        \\        }
        \\        .tok-number {
        \\            color: #ff8080;
        \\        }
        \\        .tok-type {
        \\            color: #68f;
        \\        }
        \\      }
        \\    </style>
        \\</head>
        \\<body>
        \\
    );

    const source = try src.getSource(allocator);
    try tokenizeAndPrintRaw(out, source.bytes);
    try out.writeAll(
        \\</body>
        \\</html>
    );
}

const start_line = "<span class=\"line\" id=\"L{d}\">";
const end_line = "</span>\n";

var line_counter: usize = 1;

pub fn tokenizeAndPrintRaw(
    out: anytype,
    src: [:0]const u8,
) !void {
    line_counter = 1;

    try out.print("<pre><code>" ++ start_line, .{line_counter});
    var tokenizer = std.zig.Tokenizer.init(src);
    var index: usize = 0;
    var next_tok_is_fn = false;
    while (true) {
        const prev_tok_was_fn = next_tok_is_fn;
        next_tok_is_fn = false;

        const token = tokenizer.next();
        if (mem.indexOf(u8, src[index..token.loc.start], "//")) |comment_start_off| {
            // render one comment
            const comment_start = index + comment_start_off;
            const comment_end_off = mem.indexOf(u8, src[comment_start..token.loc.start], "\n");
            const comment_end = if (comment_end_off) |o| comment_start + o else token.loc.start;

            try writeEscapedLines(out, src[index..comment_start]);
            try out.writeAll("<span class=\"tok-comment\">");
            try writeEscaped(out, src[comment_start..comment_end]);
            try out.writeAll("</span>\n");
            index = comment_end;
            tokenizer.index = index;
            continue;
        }

        try writeEscapedLines(out, src[index..token.loc.start]);
        switch (token.tag) {
            .eof => break,

            .keyword_addrspace,
            .keyword_align,
            .keyword_and,
            .keyword_asm,
            .keyword_async,
            .keyword_await,
            .keyword_break,
            .keyword_catch,
            .keyword_comptime,
            .keyword_const,
            .keyword_continue,
            .keyword_defer,
            .keyword_else,
            .keyword_enum,
            .keyword_errdefer,
            .keyword_error,
            .keyword_export,
            .keyword_extern,
            .keyword_for,
            .keyword_if,
            .keyword_inline,
            .keyword_noalias,
            .keyword_noinline,
            .keyword_nosuspend,
            .keyword_opaque,
            .keyword_or,
            .keyword_orelse,
            .keyword_packed,
            .keyword_anyframe,
            .keyword_pub,
            .keyword_resume,
            .keyword_return,
            .keyword_linksection,
            .keyword_callconv,
            .keyword_struct,
            .keyword_suspend,
            .keyword_switch,
            .keyword_test,
            .keyword_threadlocal,
            .keyword_try,
            .keyword_union,
            .keyword_unreachable,
            .keyword_usingnamespace,
            .keyword_var,
            .keyword_volatile,
            .keyword_allowzero,
            .keyword_while,
            .keyword_anytype,
            => {
                try out.writeAll("<span class=\"tok-kw\">");
                try writeEscaped(out, src[token.loc.start..token.loc.end]);
                try out.writeAll("</span>");
            },

            .keyword_fn => {
                try out.writeAll("<span class=\"tok-kw\">");
                try writeEscaped(out, src[token.loc.start..token.loc.end]);
                try out.writeAll("</span>");
                next_tok_is_fn = true;
            },

            .string_literal,
            .char_literal,
            => {
                try out.writeAll("<span class=\"tok-str\">");
                try writeEscaped(out, src[token.loc.start..token.loc.end]);
                try out.writeAll("</span>");
            },

            .multiline_string_literal_line => {
                if (src[token.loc.end - 1] == '\n') {
                    try out.writeAll("<span class=\"tok-str\">");
                    try writeEscaped(out, src[token.loc.start .. token.loc.end - 1]);
                    line_counter += 1;
                    try out.print("</span>" ++ end_line ++ "\n" ++ start_line, .{line_counter});
                } else {
                    try out.writeAll("<span class=\"tok-str\">");
                    try writeEscaped(out, src[token.loc.start..token.loc.end]);
                    try out.writeAll("</span>");
                }
            },

            .builtin => {
                try out.writeAll("<span class=\"tok-builtin\">");
                try writeEscaped(out, src[token.loc.start..token.loc.end]);
                try out.writeAll("</span>");
            },

            .doc_comment,
            .container_doc_comment,
            => {
                try out.writeAll("<span class=\"tok-comment\">");
                try writeEscaped(out, src[token.loc.start..token.loc.end]);
                try out.writeAll("</span>");
            },

            .identifier => {
                const tok_bytes = src[token.loc.start..token.loc.end];
                if (mem.eql(u8, tok_bytes, "undefined") or
                    mem.eql(u8, tok_bytes, "null") or
                    mem.eql(u8, tok_bytes, "true") or
                    mem.eql(u8, tok_bytes, "false"))
                {
                    try out.writeAll("<span class=\"tok-null\">");
                    try writeEscaped(out, tok_bytes);
                    try out.writeAll("</span>");
                } else if (prev_tok_was_fn) {
                    try out.writeAll("<span class=\"tok-fn\">");
                    try writeEscaped(out, tok_bytes);
                    try out.writeAll("</span>");
                } else {
                    const is_int = blk: {
                        if (src[token.loc.start] != 'i' and src[token.loc.start] != 'u')
                            break :blk false;
                        var i = token.loc.start + 1;
                        if (i == token.loc.end)
                            break :blk false;
                        while (i != token.loc.end) : (i += 1) {
                            if (src[i] < '0' or src[i] > '9')
                                break :blk false;
                        }
                        break :blk true;
                    };
                    if (is_int or isType(tok_bytes)) {
                        try out.writeAll("<span class=\"tok-type\">");
                        try writeEscaped(out, tok_bytes);
                        try out.writeAll("</span>");
                    } else {
                        try writeEscaped(out, tok_bytes);
                    }
                }
            },

            .number_literal => {
                try out.writeAll("<span class=\"tok-number\">");
                try writeEscaped(out, src[token.loc.start..token.loc.end]);
                try out.writeAll("</span>");
            },

            .bang,
            .pipe,
            .pipe_pipe,
            .pipe_equal,
            .equal,
            .equal_equal,
            .equal_angle_bracket_right,
            .bang_equal,
            .l_paren,
            .r_paren,
            .semicolon,
            .percent,
            .percent_equal,
            .l_brace,
            .r_brace,
            .l_bracket,
            .r_bracket,
            .period,
            .period_asterisk,
            .ellipsis2,
            .ellipsis3,
            .caret,
            .caret_equal,
            .plus,
            .plus_plus,
            .plus_equal,
            .plus_percent,
            .plus_percent_equal,
            .plus_pipe,
            .plus_pipe_equal,
            .minus,
            .minus_equal,
            .minus_percent,
            .minus_percent_equal,
            .minus_pipe,
            .minus_pipe_equal,
            .asterisk,
            .asterisk_equal,
            .asterisk_asterisk,
            .asterisk_percent,
            .asterisk_percent_equal,
            .asterisk_pipe,
            .asterisk_pipe_equal,
            .arrow,
            .colon,
            .slash,
            .slash_equal,
            .comma,
            .ampersand,
            .ampersand_equal,
            .question_mark,
            .angle_bracket_left,
            .angle_bracket_left_equal,
            .angle_bracket_angle_bracket_left,
            .angle_bracket_angle_bracket_left_equal,
            .angle_bracket_angle_bracket_left_pipe,
            .angle_bracket_angle_bracket_left_pipe_equal,
            .angle_bracket_right,
            .angle_bracket_right_equal,
            .angle_bracket_angle_bracket_right,
            .angle_bracket_angle_bracket_right_equal,
            .tilde,
            => try writeEscaped(out, src[token.loc.start..token.loc.end]),

            .invalid, .invalid_periodasterisks => return error.ParseError,
        }
        index = token.loc.end;
    }
    try out.writeAll(end_line ++ "</code></pre>");
}

fn writeEscapedLines(out: anytype, text: []const u8) !void {
    for (text) |char| {
        if (char == '\n') {
            try out.writeAll(end_line);
            line_counter += 1;
            try out.print(start_line, .{line_counter});
        } else {
            try writeEscaped(out, &[_]u8{char});
        }
    }
}

fn writeEscaped(out: anytype, input: []const u8) !void {
    for (input) |c| {
        try switch (c) {
            '&' => out.writeAll("&amp;"),
            '<' => out.writeAll("&lt;"),
            '>' => out.writeAll("&gt;"),
            '"' => out.writeAll("&quot;"),
            else => out.writeByte(c),
        };
    }
}

const builtin_types = [_][]const u8{
    "f16",          "f32",     "f64",        "f80",          "f128",
    "c_longdouble", "c_short", "c_ushort",   "c_int",        "c_uint",
    "c_long",       "c_ulong", "c_longlong", "c_ulonglong",  "c_char",
    "anyopaque",    "void",    "bool",       "isize",        "usize",
    "noreturn",     "type",    "anyerror",   "comptime_int", "comptime_float",
};

fn isType(name: []const u8) bool {
    for (builtin_types) |t| {
        if (mem.eql(u8, t, name))
            return true;
    }
    return false;
}
