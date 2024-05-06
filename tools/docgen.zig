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
const getExternalExecutor = std.zig.system.getExternalExecutor;
const fatal = std.zig.fatal;

const max_doc_file_size = 10 * 1024 * 1024;

const obj_ext = builtin.object_format.fileExt(builtin.cpu.arch);

const usage =
    \\Usage: docgen [options] input output
    \\
    \\   Generates an HTML document from a docgen template.
    \\
    \\Options:
    \\   --code-dir dir         Path to directory containing code example outputs
    \\   -h, --help             Print this help and exit
    \\
;

pub fn main() !void {
    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_instance.deinit();

    const arena = arena_instance.allocator();

    var args_it = try process.argsWithAllocator(arena);
    if (!args_it.skip()) @panic("expected self arg");

    var opt_code_dir: ?[]const u8 = null;
    var opt_input: ?[]const u8 = null;
    var opt_output: ?[]const u8 = null;

    while (args_it.next()) |arg| {
        if (mem.startsWith(u8, arg, "-")) {
            if (mem.eql(u8, arg, "-h") or mem.eql(u8, arg, "--help")) {
                const stdout = io.getStdOut().writer();
                try stdout.writeAll(usage);
                process.exit(0);
            } else if (mem.eql(u8, arg, "--code-dir")) {
                if (args_it.next()) |param| {
                    opt_code_dir = param;
                } else {
                    fatal("expected parameter after --code-dir", .{});
                }
            } else {
                fatal("unrecognized option: '{s}'", .{arg});
            }
        } else if (opt_input == null) {
            opt_input = arg;
        } else if (opt_output == null) {
            opt_output = arg;
        } else {
            fatal("unexpected positional argument: '{s}'", .{arg});
        }
    }
    const input_path = opt_input orelse fatal("missing input file", .{});
    const output_path = opt_output orelse fatal("missing output file", .{});
    const code_dir_path = opt_code_dir orelse fatal("missing --code-dir argument", .{});

    var in_file = try fs.cwd().openFile(input_path, .{});
    defer in_file.close();

    var out_file = try fs.cwd().createFile(output_path, .{});
    defer out_file.close();

    var code_dir = try fs.cwd().openDir(code_dir_path, .{});
    defer code_dir.close();

    const input_file_bytes = try in_file.reader().readAllAlloc(arena, max_doc_file_size);

    var buffered_writer = io.bufferedWriter(out_file.writer());

    var tokenizer = Tokenizer.init(input_path, input_file_bytes);
    var toc = try genToc(arena, &tokenizer);

    try genHtml(arena, &tokenizer, &toc, code_dir, buffered_writer.writer());
    try buffered_writer.flush();
}

const Token = struct {
    id: Id,
    start: usize,
    end: usize,

    const Id = enum {
        invalid,
        content,
        bracket_open,
        tag_content,
        separator,
        bracket_close,
        eof,
    };
};

const Tokenizer = struct {
    buffer: []const u8,
    index: usize,
    state: State,
    source_file_name: []const u8,

    const State = enum {
        start,
        l_bracket,
        hash,
        tag_name,
        eof,
    };

    fn init(source_file_name: []const u8, buffer: []const u8) Tokenizer {
        return Tokenizer{
            .buffer = buffer,
            .index = 0,
            .state = .start,
            .source_file_name = source_file_name,
        };
    }

    fn next(self: *Tokenizer) Token {
        var result = Token{
            .id = .eof,
            .start = self.index,
            .end = undefined,
        };
        while (self.index < self.buffer.len) : (self.index += 1) {
            const c = self.buffer[self.index];
            switch (self.state) {
                .start => switch (c) {
                    '{' => {
                        self.state = .l_bracket;
                    },
                    else => {
                        result.id = .content;
                    },
                },
                .l_bracket => switch (c) {
                    '#' => {
                        if (result.id != .eof) {
                            self.index -= 1;
                            self.state = .start;
                            break;
                        } else {
                            result.id = .bracket_open;
                            self.index += 1;
                            self.state = .tag_name;
                            break;
                        }
                    },
                    else => {
                        result.id = .content;
                        self.state = .start;
                    },
                },
                .tag_name => switch (c) {
                    '|' => {
                        if (result.id != .eof) {
                            break;
                        } else {
                            result.id = .separator;
                            self.index += 1;
                            break;
                        }
                    },
                    '#' => {
                        self.state = .hash;
                    },
                    else => {
                        result.id = .tag_content;
                    },
                },
                .hash => switch (c) {
                    '}' => {
                        if (result.id != .eof) {
                            self.index -= 1;
                            self.state = .tag_name;
                            break;
                        } else {
                            result.id = .bracket_close;
                            self.index += 1;
                            self.state = .start;
                            break;
                        }
                    },
                    else => {
                        result.id = .tag_content;
                        self.state = .tag_name;
                    },
                },
                .eof => unreachable,
            }
        } else {
            switch (self.state) {
                .start, .l_bracket, .eof => {},
                else => {
                    result.id = .invalid;
                },
            }
            self.state = .eof;
        }
        result.end = self.index;
        return result;
    }

    const Location = struct {
        line: usize,
        column: usize,
        line_start: usize,
        line_end: usize,
    };

    fn getTokenLocation(self: *Tokenizer, token: Token) Location {
        var loc = Location{
            .line = 0,
            .column = 0,
            .line_start = 0,
            .line_end = 0,
        };
        for (self.buffer, 0..) |c, i| {
            if (i == token.start) {
                loc.line_end = i;
                while (loc.line_end < self.buffer.len and self.buffer[loc.line_end] != '\n') : (loc.line_end += 1) {}
                return loc;
            }
            if (c == '\n') {
                loc.line += 1;
                loc.column = 0;
                loc.line_start = i + 1;
            } else {
                loc.column += 1;
            }
        }
        return loc;
    }
};

fn parseError(tokenizer: *Tokenizer, token: Token, comptime fmt: []const u8, args: anytype) anyerror {
    const loc = tokenizer.getTokenLocation(token);
    const args_prefix = .{ tokenizer.source_file_name, loc.line + 1, loc.column + 1 };
    print("{s}:{d}:{d}: error: " ++ fmt ++ "\n", args_prefix ++ args);
    if (loc.line_start <= loc.line_end) {
        print("{s}\n", .{tokenizer.buffer[loc.line_start..loc.line_end]});
        {
            var i: usize = 0;
            while (i < loc.column) : (i += 1) {
                print(" ", .{});
            }
        }
        {
            const caret_count = @min(token.end, loc.line_end) - token.start;
            var i: usize = 0;
            while (i < caret_count) : (i += 1) {
                print("~", .{});
            }
        }
        print("\n", .{});
    }
    return error.ParseError;
}

fn assertToken(tokenizer: *Tokenizer, token: Token, id: Token.Id) !void {
    if (token.id != id) {
        return parseError(tokenizer, token, "expected {s}, found {s}", .{ @tagName(id), @tagName(token.id) });
    }
}

fn eatToken(tokenizer: *Tokenizer, id: Token.Id) !Token {
    const token = tokenizer.next();
    try assertToken(tokenizer, token, id);
    return token;
}

const HeaderOpen = struct {
    name: []const u8,
    url: []const u8,
    n: usize,
};

const SeeAlsoItem = struct {
    name: []const u8,
    token: Token,
};

const Code = struct {
    name: []const u8,
    token: Token,
};

const Link = struct {
    url: []const u8,
    name: []const u8,
    token: Token,
};

const SyntaxBlock = struct {
    source_type: SourceType,
    name: []const u8,
    source_token: Token,

    const SourceType = enum {
        zig,
        c,
        peg,
        javascript,
    };
};

const Node = union(enum) {
    Content: []const u8,
    Nav,
    Builtin: Token,
    HeaderOpen: HeaderOpen,
    SeeAlso: []const SeeAlsoItem,
    Code: Code,
    Link: Link,
    InlineSyntax: Token,
    Shell: Token,
    SyntaxBlock: SyntaxBlock,
};

const Toc = struct {
    nodes: []Node,
    toc: []u8,
    urls: std.StringHashMap(Token),
};

const Action = enum {
    open,
    close,
};

fn genToc(allocator: Allocator, tokenizer: *Tokenizer) !Toc {
    var urls = std.StringHashMap(Token).init(allocator);
    errdefer urls.deinit();

    var header_stack_size: usize = 0;
    var last_action: Action = .open;
    var last_columns: ?u8 = null;

    var toc_buf = std.ArrayList(u8).init(allocator);
    defer toc_buf.deinit();

    var toc = toc_buf.writer();

    var nodes = std.ArrayList(Node).init(allocator);
    defer nodes.deinit();

    try toc.writeByte('\n');

    while (true) {
        const token = tokenizer.next();
        switch (token.id) {
            .eof => {
                if (header_stack_size != 0) {
                    return parseError(tokenizer, token, "unbalanced headers", .{});
                }
                try toc.writeAll("    </ul>\n");
                break;
            },
            .content => {
                try nodes.append(Node{ .Content = tokenizer.buffer[token.start..token.end] });
            },
            .bracket_open => {
                const tag_token = try eatToken(tokenizer, .tag_content);
                const tag_name = tokenizer.buffer[tag_token.start..tag_token.end];

                if (mem.eql(u8, tag_name, "nav")) {
                    _ = try eatToken(tokenizer, .bracket_close);

                    try nodes.append(Node.Nav);
                } else if (mem.eql(u8, tag_name, "builtin")) {
                    _ = try eatToken(tokenizer, .bracket_close);
                    try nodes.append(Node{ .Builtin = tag_token });
                } else if (mem.eql(u8, tag_name, "header_open")) {
                    _ = try eatToken(tokenizer, .separator);
                    const content_token = try eatToken(tokenizer, .tag_content);
                    const content = tokenizer.buffer[content_token.start..content_token.end];
                    var columns: ?u8 = null;
                    while (true) {
                        const bracket_tok = tokenizer.next();
                        switch (bracket_tok.id) {
                            .bracket_close => break,
                            .separator => continue,
                            .tag_content => {
                                const param = tokenizer.buffer[bracket_tok.start..bracket_tok.end];
                                if (mem.eql(u8, param, "2col")) {
                                    columns = 2;
                                } else {
                                    return parseError(
                                        tokenizer,
                                        bracket_tok,
                                        "unrecognized header_open param: {s}",
                                        .{param},
                                    );
                                }
                            },
                            else => return parseError(tokenizer, bracket_tok, "invalid header_open token", .{}),
                        }
                    }

                    header_stack_size += 1;

                    const urlized = try urlize(allocator, content);
                    try nodes.append(Node{
                        .HeaderOpen = HeaderOpen{
                            .name = content,
                            .url = urlized,
                            .n = header_stack_size + 1, // highest-level section headers start at h2
                        },
                    });
                    if (try urls.fetchPut(urlized, tag_token)) |kv| {
                        parseError(tokenizer, tag_token, "duplicate header url: #{s}", .{urlized}) catch {};
                        parseError(tokenizer, kv.value, "other tag here", .{}) catch {};
                        return error.ParseError;
                    }
                    if (last_action == .open) {
                        try toc.writeByte('\n');
                        try toc.writeByteNTimes(' ', header_stack_size * 4);
                        if (last_columns) |n| {
                            try toc.print("<ul style=\"columns: {}\">\n", .{n});
                        } else {
                            try toc.writeAll("<ul>\n");
                        }
                    } else {
                        last_action = .open;
                    }
                    last_columns = columns;
                    try toc.writeByteNTimes(' ', 4 + header_stack_size * 4);
                    try toc.print("<li><a id=\"toc-{s}\" href=\"#{s}\">{s}</a>", .{ urlized, urlized, content });
                } else if (mem.eql(u8, tag_name, "header_close")) {
                    if (header_stack_size == 0) {
                        return parseError(tokenizer, tag_token, "unbalanced close header", .{});
                    }
                    header_stack_size -= 1;
                    _ = try eatToken(tokenizer, .bracket_close);

                    if (last_action == .close) {
                        try toc.writeByteNTimes(' ', 8 + header_stack_size * 4);
                        try toc.writeAll("</ul></li>\n");
                    } else {
                        try toc.writeAll("</li>\n");
                        last_action = .close;
                    }
                } else if (mem.eql(u8, tag_name, "see_also")) {
                    var list = std.ArrayList(SeeAlsoItem).init(allocator);
                    errdefer list.deinit();

                    while (true) {
                        const see_also_tok = tokenizer.next();
                        switch (see_also_tok.id) {
                            .tag_content => {
                                const content = tokenizer.buffer[see_also_tok.start..see_also_tok.end];
                                try list.append(SeeAlsoItem{
                                    .name = content,
                                    .token = see_also_tok,
                                });
                            },
                            .separator => {},
                            .bracket_close => {
                                try nodes.append(Node{ .SeeAlso = try list.toOwnedSlice() });
                                break;
                            },
                            else => return parseError(tokenizer, see_also_tok, "invalid see_also token", .{}),
                        }
                    }
                } else if (mem.eql(u8, tag_name, "link")) {
                    _ = try eatToken(tokenizer, .separator);
                    const name_tok = try eatToken(tokenizer, .tag_content);
                    const name = tokenizer.buffer[name_tok.start..name_tok.end];

                    const url_name = blk: {
                        const tok = tokenizer.next();
                        switch (tok.id) {
                            .bracket_close => break :blk name,
                            .separator => {
                                const explicit_text = try eatToken(tokenizer, .tag_content);
                                _ = try eatToken(tokenizer, .bracket_close);
                                break :blk tokenizer.buffer[explicit_text.start..explicit_text.end];
                            },
                            else => return parseError(tokenizer, tok, "invalid link token", .{}),
                        }
                    };

                    try nodes.append(Node{
                        .Link = Link{
                            .url = try urlize(allocator, url_name),
                            .name = name,
                            .token = name_tok,
                        },
                    });
                } else if (mem.eql(u8, tag_name, "code")) {
                    _ = try eatToken(tokenizer, .separator);
                    const name_tok = try eatToken(tokenizer, .tag_content);
                    _ = try eatToken(tokenizer, .bracket_close);
                    try nodes.append(.{
                        .Code = .{
                            .name = tokenizer.buffer[name_tok.start..name_tok.end],
                            .token = name_tok,
                        },
                    });
                } else if (mem.eql(u8, tag_name, "syntax")) {
                    _ = try eatToken(tokenizer, .bracket_close);
                    const content_tok = try eatToken(tokenizer, .content);
                    _ = try eatToken(tokenizer, .bracket_open);
                    const end_syntax_tag = try eatToken(tokenizer, .tag_content);
                    const end_tag_name = tokenizer.buffer[end_syntax_tag.start..end_syntax_tag.end];
                    if (!mem.eql(u8, end_tag_name, "endsyntax")) {
                        return parseError(
                            tokenizer,
                            end_syntax_tag,
                            "invalid token inside syntax: {s}",
                            .{end_tag_name},
                        );
                    }
                    _ = try eatToken(tokenizer, .bracket_close);
                    try nodes.append(Node{ .InlineSyntax = content_tok });
                } else if (mem.eql(u8, tag_name, "shell_samp")) {
                    _ = try eatToken(tokenizer, .bracket_close);
                    const content_tok = try eatToken(tokenizer, .content);
                    _ = try eatToken(tokenizer, .bracket_open);
                    const end_syntax_tag = try eatToken(tokenizer, .tag_content);
                    const end_tag_name = tokenizer.buffer[end_syntax_tag.start..end_syntax_tag.end];
                    if (!mem.eql(u8, end_tag_name, "end_shell_samp")) {
                        return parseError(
                            tokenizer,
                            end_syntax_tag,
                            "invalid token inside syntax: {s}",
                            .{end_tag_name},
                        );
                    }
                    _ = try eatToken(tokenizer, .bracket_close);
                    try nodes.append(Node{ .Shell = content_tok });
                } else if (mem.eql(u8, tag_name, "syntax_block")) {
                    _ = try eatToken(tokenizer, .separator);
                    const source_type_tok = try eatToken(tokenizer, .tag_content);
                    var name: []const u8 = "sample_code";
                    const maybe_sep = tokenizer.next();
                    switch (maybe_sep.id) {
                        .separator => {
                            const name_tok = try eatToken(tokenizer, .tag_content);
                            name = tokenizer.buffer[name_tok.start..name_tok.end];
                            _ = try eatToken(tokenizer, .bracket_close);
                        },
                        .bracket_close => {},
                        else => return parseError(tokenizer, token, "invalid token", .{}),
                    }
                    const source_type_str = tokenizer.buffer[source_type_tok.start..source_type_tok.end];
                    var source_type: SyntaxBlock.SourceType = undefined;
                    if (mem.eql(u8, source_type_str, "zig")) {
                        source_type = SyntaxBlock.SourceType.zig;
                    } else if (mem.eql(u8, source_type_str, "c")) {
                        source_type = SyntaxBlock.SourceType.c;
                    } else if (mem.eql(u8, source_type_str, "peg")) {
                        source_type = SyntaxBlock.SourceType.peg;
                    } else if (mem.eql(u8, source_type_str, "javascript")) {
                        source_type = SyntaxBlock.SourceType.javascript;
                    } else {
                        return parseError(tokenizer, source_type_tok, "unrecognized code kind: {s}", .{source_type_str});
                    }
                    const source_token = while (true) {
                        const content_tok = try eatToken(tokenizer, .content);
                        _ = try eatToken(tokenizer, .bracket_open);
                        const end_code_tag = try eatToken(tokenizer, .tag_content);
                        const end_tag_name = tokenizer.buffer[end_code_tag.start..end_code_tag.end];
                        if (mem.eql(u8, end_tag_name, "end_syntax_block")) {
                            _ = try eatToken(tokenizer, .bracket_close);
                            break content_tok;
                        } else {
                            return parseError(
                                tokenizer,
                                end_code_tag,
                                "invalid token inside code_begin: {s}",
                                .{end_tag_name},
                            );
                        }
                        _ = try eatToken(tokenizer, .bracket_close);
                    };
                    try nodes.append(Node{ .SyntaxBlock = SyntaxBlock{ .source_type = source_type, .name = name, .source_token = source_token } });
                } else {
                    return parseError(tokenizer, tag_token, "unrecognized tag name: {s}", .{tag_name});
                }
            },
            else => return parseError(tokenizer, token, "invalid token", .{}),
        }
    }

    return Toc{
        .nodes = try nodes.toOwnedSlice(),
        .toc = try toc_buf.toOwnedSlice(),
        .urls = urls,
    };
}

fn urlize(allocator: Allocator, input: []const u8) ![]u8 {
    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();

    const out = buf.writer();
    for (input) |c| {
        switch (c) {
            'a'...'z', 'A'...'Z', '_', '-', '0'...'9' => {
                try out.writeByte(c);
            },
            ' ' => {
                try out.writeByte('-');
            },
            else => {},
        }
    }
    return try buf.toOwnedSlice();
}

fn escapeHtml(allocator: Allocator, input: []const u8) ![]u8 {
    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();

    const out = buf.writer();
    try writeEscaped(out, input);
    return try buf.toOwnedSlice();
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

// Returns true if number is in slice.
fn in(slice: []const u8, number: u8) bool {
    for (slice) |n| {
        if (number == n) return true;
    }
    return false;
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

fn writeEscapedLines(out: anytype, text: []const u8) !void {
    return writeEscaped(out, text);
}

fn tokenizeAndPrintRaw(
    allocator: Allocator,
    docgen_tokenizer: *Tokenizer,
    out: anytype,
    source_token: Token,
    raw_src: []const u8,
) !void {
    const src_non_terminated = mem.trim(u8, raw_src, " \r\n");
    const src = try allocator.dupeZ(u8, src_non_terminated);

    try out.writeAll("<code>");
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
            try out.writeAll("</span>");
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
            .multiline_string_literal_line,
            .char_literal,
            => {
                try out.writeAll("<span class=\"tok-str\">");
                try writeEscaped(out, src[token.loc.start..token.loc.end]);
                try out.writeAll("</span>");
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

            .invalid, .invalid_periodasterisks => return parseError(
                docgen_tokenizer,
                source_token,
                "syntax error",
                .{},
            ),
        }
        index = token.loc.end;
    }
    try out.writeAll("</code>");
}

fn tokenizeAndPrint(
    allocator: Allocator,
    docgen_tokenizer: *Tokenizer,
    out: anytype,
    source_token: Token,
) !void {
    const raw_src = docgen_tokenizer.buffer[source_token.start..source_token.end];
    return tokenizeAndPrintRaw(allocator, docgen_tokenizer, out, source_token, raw_src);
}

fn printSourceBlock(allocator: Allocator, docgen_tokenizer: *Tokenizer, out: anytype, syntax_block: SyntaxBlock) !void {
    const source_type = @tagName(syntax_block.source_type);

    try out.print("<figure><figcaption class=\"{s}-cap\"><cite class=\"file\">{s}</cite></figcaption><pre>", .{ source_type, syntax_block.name });
    switch (syntax_block.source_type) {
        .zig => try tokenizeAndPrint(allocator, docgen_tokenizer, out, syntax_block.source_token),
        else => {
            const raw_source = docgen_tokenizer.buffer[syntax_block.source_token.start..syntax_block.source_token.end];
            const trimmed_raw_source = mem.trim(u8, raw_source, " \r\n");

            try out.writeAll("<code>");
            try writeEscapedLines(out, trimmed_raw_source);
            try out.writeAll("</code>");
        },
    }
    try out.writeAll("</pre></figure>");
}

fn printShell(out: anytype, shell_content: []const u8, escape: bool) !void {
    const trimmed_shell_content = mem.trim(u8, shell_content, " \r\n");
    try out.writeAll("<figure><figcaption class=\"shell-cap\">Shell</figcaption><pre><samp>");
    var cmd_cont: bool = false;
    var iter = std.mem.splitScalar(u8, trimmed_shell_content, '\n');
    while (iter.next()) |orig_line| {
        const line = mem.trimRight(u8, orig_line, " \r");
        if (!cmd_cont and line.len > 1 and mem.eql(u8, line[0..2], "$ ") and line[line.len - 1] != '\\') {
            try out.writeAll("$ <kbd>");
            const s = std.mem.trimLeft(u8, line[1..], " ");
            if (escape) {
                try writeEscaped(out, s);
            } else {
                try out.writeAll(s);
            }
            try out.writeAll("</kbd>" ++ "\n");
        } else if (!cmd_cont and line.len > 1 and mem.eql(u8, line[0..2], "$ ") and line[line.len - 1] == '\\') {
            try out.writeAll("$ <kbd>");
            const s = std.mem.trimLeft(u8, line[1..], " ");
            if (escape) {
                try writeEscaped(out, s);
            } else {
                try out.writeAll(s);
            }
            try out.writeAll("\n");
            cmd_cont = true;
        } else if (line.len > 0 and line[line.len - 1] != '\\' and cmd_cont) {
            if (escape) {
                try writeEscaped(out, line);
            } else {
                try out.writeAll(line);
            }
            try out.writeAll("</kbd>" ++ "\n");
            cmd_cont = false;
        } else {
            if (escape) {
                try writeEscaped(out, line);
            } else {
                try out.writeAll(line);
            }
            try out.writeAll("\n");
        }
    }

    try out.writeAll("</samp></pre></figure>");
}

fn genHtml(
    allocator: Allocator,
    tokenizer: *Tokenizer,
    toc: *Toc,
    code_dir: std.fs.Dir,
    out: anytype,
) !void {
    for (toc.nodes) |node| {
        switch (node) {
            .Content => |data| {
                try out.writeAll(data);
            },
            .Link => |info| {
                if (!toc.urls.contains(info.url)) {
                    return parseError(tokenizer, info.token, "url not found: {s}", .{info.url});
                }
                try out.print("<a href=\"#{s}\">{s}</a>", .{ info.url, info.name });
            },
            .Nav => {
                try out.writeAll(toc.toc);
            },
            .Builtin => |tok| {
                try out.writeAll("<figure><figcaption class=\"zig-cap\"><cite>@import(\"builtin\")</cite></figcaption><pre>");
                const builtin_code = @embedFile("builtin"); // 😎
                try tokenizeAndPrintRaw(allocator, tokenizer, out, tok, builtin_code);
                try out.writeAll("</pre></figure>");
            },
            .HeaderOpen => |info| {
                try out.print(
                    "<h{d} id=\"{s}\"><a href=\"#toc-{s}\">{s}</a> <a class=\"hdr\" href=\"#{s}\">§</a></h{d}>\n",
                    .{ info.n, info.url, info.url, info.name, info.url, info.n },
                );
            },
            .SeeAlso => |items| {
                try out.writeAll("<p>See also:</p><ul>\n");
                for (items) |item| {
                    const url = try urlize(allocator, item.name);
                    if (!toc.urls.contains(url)) {
                        return parseError(tokenizer, item.token, "url not found: {s}", .{url});
                    }
                    try out.print("<li><a href=\"#{s}\">{s}</a></li>\n", .{ url, item.name });
                }
                try out.writeAll("</ul>\n");
            },
            .InlineSyntax => |content_tok| {
                try tokenizeAndPrint(allocator, tokenizer, out, content_tok);
            },
            .Shell => |content_tok| {
                const raw_shell_content = tokenizer.buffer[content_tok.start..content_tok.end];
                try printShell(out, raw_shell_content, true);
            },
            .SyntaxBlock => |syntax_block| {
                try printSourceBlock(allocator, tokenizer, out, syntax_block);
            },
            .Code => |code| {
                const out_basename = try std.fmt.allocPrint(allocator, "{s}.out", .{
                    fs.path.stem(code.name),
                });
                defer allocator.free(out_basename);

                const contents = code_dir.readFileAlloc(allocator, out_basename, std.math.maxInt(u32)) catch |err| {
                    return parseError(tokenizer, code.token, "unable to open '{s}': {s}", .{
                        out_basename, @errorName(err),
                    });
                };
                defer allocator.free(contents);

                try out.writeAll(contents);
            },
        }
    }
}
