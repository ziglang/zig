const builtin = @import("builtin");
const std = @import("std");
const io = std.io;
const os = std.os;
const warn = std.debug.warn;
const mem = std.mem;
const assert = std.debug.assert;

const max_doc_file_size = 10 * 1024 * 1024;

const exe_ext = std.build.Target(std.build.Target.Native).exeFileExt();
const obj_ext = std.build.Target(std.build.Target.Native).oFileExt();
const tmp_dir_name = "docgen_tmp";
const test_out_path = tmp_dir_name ++ os.path.sep_str ++ "test" ++ exe_ext;

pub fn main() !void {
    var direct_allocator = std.heap.DirectAllocator.init();
    defer direct_allocator.deinit();

    var arena = std.heap.ArenaAllocator.init(&direct_allocator.allocator);
    defer arena.deinit();

    const allocator = &arena.allocator;

    var args_it = os.args();

    if (!args_it.skip()) @panic("expected self arg");

    const zig_exe = try (args_it.next(allocator) orelse @panic("expected zig exe arg"));
    defer allocator.free(zig_exe);

    const in_file_name = try (args_it.next(allocator) orelse @panic("expected input arg"));
    defer allocator.free(in_file_name);

    const out_file_name = try (args_it.next(allocator) orelse @panic("expected output arg"));
    defer allocator.free(out_file_name);

    var in_file = try os.File.openRead(in_file_name);
    defer in_file.close();

    var out_file = try os.File.openWrite(out_file_name);
    defer out_file.close();

    var file_in_stream = io.FileInStream.init(in_file);

    const input_file_bytes = try file_in_stream.stream.readAllAlloc(allocator, max_doc_file_size);

    var file_out_stream = io.FileOutStream.init(out_file);
    var buffered_out_stream = io.BufferedOutStream(io.FileOutStream.Error).init(&file_out_stream.stream);

    var tokenizer = Tokenizer.init(in_file_name, input_file_bytes);
    var toc = try genToc(allocator, &tokenizer);

    try os.makePath(allocator, tmp_dir_name);
    defer os.deleteTree(allocator, tmp_dir_name) catch {};

    try genHtml(allocator, &tokenizer, &toc, &buffered_out_stream.stream, zig_exe);
    try buffered_out_stream.flush();
}

const Token = struct {
    id: Id,
    start: usize,
    end: usize,

    const Id = enum {
        Invalid,
        Content,
        BracketOpen,
        TagContent,
        Separator,
        BracketClose,
        Eof,
    };
};

const Tokenizer = struct {
    buffer: []const u8,
    index: usize,
    state: State,
    source_file_name: []const u8,
    code_node_count: usize,

    const State = enum {
        Start,
        LBracket,
        Hash,
        TagName,
        Eof,
    };

    fn init(source_file_name: []const u8, buffer: []const u8) Tokenizer {
        return Tokenizer{
            .buffer = buffer,
            .index = 0,
            .state = State.Start,
            .source_file_name = source_file_name,
            .code_node_count = 0,
        };
    }

    fn next(self: *Tokenizer) Token {
        var result = Token{
            .id = Token.Id.Eof,
            .start = self.index,
            .end = undefined,
        };
        while (self.index < self.buffer.len) : (self.index += 1) {
            const c = self.buffer[self.index];
            switch (self.state) {
                State.Start => switch (c) {
                    '{' => {
                        self.state = State.LBracket;
                    },
                    else => {
                        result.id = Token.Id.Content;
                    },
                },
                State.LBracket => switch (c) {
                    '#' => {
                        if (result.id != Token.Id.Eof) {
                            self.index -= 1;
                            self.state = State.Start;
                            break;
                        } else {
                            result.id = Token.Id.BracketOpen;
                            self.index += 1;
                            self.state = State.TagName;
                            break;
                        }
                    },
                    else => {
                        result.id = Token.Id.Content;
                        self.state = State.Start;
                    },
                },
                State.TagName => switch (c) {
                    '|' => {
                        if (result.id != Token.Id.Eof) {
                            break;
                        } else {
                            result.id = Token.Id.Separator;
                            self.index += 1;
                            break;
                        }
                    },
                    '#' => {
                        self.state = State.Hash;
                    },
                    else => {
                        result.id = Token.Id.TagContent;
                    },
                },
                State.Hash => switch (c) {
                    '}' => {
                        if (result.id != Token.Id.Eof) {
                            self.index -= 1;
                            self.state = State.TagName;
                            break;
                        } else {
                            result.id = Token.Id.BracketClose;
                            self.index += 1;
                            self.state = State.Start;
                            break;
                        }
                    },
                    else => {
                        result.id = Token.Id.TagContent;
                        self.state = State.TagName;
                    },
                },
                State.Eof => unreachable,
            }
        } else {
            switch (self.state) {
                State.Start, State.LBracket, State.Eof => {},
                else => {
                    result.id = Token.Id.Invalid;
                },
            }
            self.state = State.Eof;
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

    fn getTokenLocation(self: *Tokenizer, token: *const Token) Location {
        var loc = Location{
            .line = 0,
            .column = 0,
            .line_start = 0,
            .line_end = 0,
        };
        for (self.buffer) |c, i| {
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

fn parseError(tokenizer: *Tokenizer, token: *const Token, comptime fmt: []const u8, args: ...) error {
    const loc = tokenizer.getTokenLocation(token);
    warn("{}:{}:{}: error: " ++ fmt ++ "\n", tokenizer.source_file_name, loc.line + 1, loc.column + 1, args);
    if (loc.line_start <= loc.line_end) {
        warn("{}\n", tokenizer.buffer[loc.line_start..loc.line_end]);
        {
            var i: usize = 0;
            while (i < loc.column) : (i += 1) {
                warn(" ");
            }
        }
        {
            const caret_count = token.end - token.start;
            var i: usize = 0;
            while (i < caret_count) : (i += 1) {
                warn("~");
            }
        }
        warn("\n");
    }
    return error.ParseError;
}

fn assertToken(tokenizer: *Tokenizer, token: *const Token, id: Token.Id) !void {
    if (token.id != id) {
        return parseError(tokenizer, token, "expected {}, found {}", @tagName(id), @tagName(token.id));
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

const ExpectedOutcome = enum {
    Succeed,
    Fail,
};

const Code = struct {
    id: Id,
    name: []const u8,
    source_token: Token,
    is_inline: bool,
    mode: builtin.Mode,
    link_objects: []const []const u8,
    target_windows: bool,
    link_libc: bool,

    const Id = union(enum) {
        Test,
        TestError: []const u8,
        TestSafety: []const u8,
        Exe: ExpectedOutcome,
        Obj: ?[]const u8,
    };
};

const Link = struct {
    url: []const u8,
    name: []const u8,
    token: Token,
};

const Node = union(enum) {
    Content: []const u8,
    Nav,
    Builtin: Token,
    HeaderOpen: HeaderOpen,
    SeeAlso: []const SeeAlsoItem,
    Code: Code,
    Link: Link,
    Syntax: Token,
};

const Toc = struct {
    nodes: []Node,
    toc: []u8,
    urls: std.HashMap([]const u8, Token, mem.hash_slice_u8, mem.eql_slice_u8),
};

const Action = enum {
    Open,
    Close,
};

fn genToc(allocator: *mem.Allocator, tokenizer: *Tokenizer) !Toc {
    var urls = std.HashMap([]const u8, Token, mem.hash_slice_u8, mem.eql_slice_u8).init(allocator);
    errdefer urls.deinit();

    var header_stack_size: usize = 0;
    var last_action = Action.Open;

    var toc_buf = try std.Buffer.initSize(allocator, 0);
    defer toc_buf.deinit();

    var toc_buf_adapter = io.BufferOutStream.init(&toc_buf);
    var toc = &toc_buf_adapter.stream;

    var nodes = std.ArrayList(Node).init(allocator);
    defer nodes.deinit();

    try toc.writeByte('\n');

    while (true) {
        const token = tokenizer.next();
        switch (token.id) {
            Token.Id.Eof => {
                if (header_stack_size != 0) {
                    return parseError(tokenizer, token, "unbalanced headers");
                }
                try toc.write("    </ul>\n");
                break;
            },
            Token.Id.Content => {
                try nodes.append(Node{ .Content = tokenizer.buffer[token.start..token.end] });
            },
            Token.Id.BracketOpen => {
                const tag_token = try eatToken(tokenizer, Token.Id.TagContent);
                const tag_name = tokenizer.buffer[tag_token.start..tag_token.end];

                if (mem.eql(u8, tag_name, "nav")) {
                    _ = try eatToken(tokenizer, Token.Id.BracketClose);

                    try nodes.append(Node.Nav);
                } else if (mem.eql(u8, tag_name, "builtin")) {
                    _ = try eatToken(tokenizer, Token.Id.BracketClose);
                    try nodes.append(Node{ .Builtin = tag_token });
                } else if (mem.eql(u8, tag_name, "header_open")) {
                    _ = try eatToken(tokenizer, Token.Id.Separator);
                    const content_token = try eatToken(tokenizer, Token.Id.TagContent);
                    const content = tokenizer.buffer[content_token.start..content_token.end];
                    _ = try eatToken(tokenizer, Token.Id.BracketClose);

                    header_stack_size += 1;

                    const urlized = try urlize(allocator, content);
                    try nodes.append(Node{
                        .HeaderOpen = HeaderOpen{
                            .name = content,
                            .url = urlized,
                            .n = header_stack_size,
                        },
                    });
                    if (try urls.put(urlized, tag_token)) |entry| {
                        parseError(tokenizer, tag_token, "duplicate header url: #{}", urlized) catch {};
                        parseError(tokenizer, entry.value, "other tag here") catch {};
                        return error.ParseError;
                    }
                    if (last_action == Action.Open) {
                        try toc.writeByte('\n');
                        try toc.writeByteNTimes(' ', header_stack_size * 4);
                        try toc.write("<ul>\n");
                    } else {
                        last_action = Action.Open;
                    }
                    try toc.writeByteNTimes(' ', 4 + header_stack_size * 4);
                    try toc.print("<li><a href=\"#{}\">{}</a>", urlized, content);
                } else if (mem.eql(u8, tag_name, "header_close")) {
                    if (header_stack_size == 0) {
                        return parseError(tokenizer, tag_token, "unbalanced close header");
                    }
                    header_stack_size -= 1;
                    _ = try eatToken(tokenizer, Token.Id.BracketClose);

                    if (last_action == Action.Close) {
                        try toc.writeByteNTimes(' ', 8 + header_stack_size * 4);
                        try toc.write("</ul></li>\n");
                    } else {
                        try toc.write("</li>\n");
                        last_action = Action.Close;
                    }
                } else if (mem.eql(u8, tag_name, "see_also")) {
                    var list = std.ArrayList(SeeAlsoItem).init(allocator);
                    errdefer list.deinit();

                    while (true) {
                        const see_also_tok = tokenizer.next();
                        switch (see_also_tok.id) {
                            Token.Id.TagContent => {
                                const content = tokenizer.buffer[see_also_tok.start..see_also_tok.end];
                                try list.append(SeeAlsoItem{
                                    .name = content,
                                    .token = see_also_tok,
                                });
                            },
                            Token.Id.Separator => {},
                            Token.Id.BracketClose => {
                                try nodes.append(Node{ .SeeAlso = list.toOwnedSlice() });
                                break;
                            },
                            else => return parseError(tokenizer, see_also_tok, "invalid see_also token"),
                        }
                    }
                } else if (mem.eql(u8, tag_name, "link")) {
                    _ = try eatToken(tokenizer, Token.Id.Separator);
                    const name_tok = try eatToken(tokenizer, Token.Id.TagContent);
                    const name = tokenizer.buffer[name_tok.start..name_tok.end];

                    const url_name = blk: {
                        const tok = tokenizer.next();
                        switch (tok.id) {
                            Token.Id.BracketClose => break :blk name,
                            Token.Id.Separator => {
                                const explicit_text = try eatToken(tokenizer, Token.Id.TagContent);
                                _ = try eatToken(tokenizer, Token.Id.BracketClose);
                                break :blk tokenizer.buffer[explicit_text.start..explicit_text.end];
                            },
                            else => return parseError(tokenizer, tok, "invalid link token"),
                        }
                    };

                    try nodes.append(Node{
                        .Link = Link{
                            .url = try urlize(allocator, url_name),
                            .name = name,
                            .token = name_tok,
                        },
                    });
                } else if (mem.eql(u8, tag_name, "code_begin")) {
                    _ = try eatToken(tokenizer, Token.Id.Separator);
                    const code_kind_tok = try eatToken(tokenizer, Token.Id.TagContent);
                    var name: []const u8 = "test";
                    const maybe_sep = tokenizer.next();
                    switch (maybe_sep.id) {
                        Token.Id.Separator => {
                            const name_tok = try eatToken(tokenizer, Token.Id.TagContent);
                            name = tokenizer.buffer[name_tok.start..name_tok.end];
                            _ = try eatToken(tokenizer, Token.Id.BracketClose);
                        },
                        Token.Id.BracketClose => {},
                        else => return parseError(tokenizer, token, "invalid token"),
                    }
                    const code_kind_str = tokenizer.buffer[code_kind_tok.start..code_kind_tok.end];
                    var code_kind_id: Code.Id = undefined;
                    var is_inline = false;
                    if (mem.eql(u8, code_kind_str, "exe")) {
                        code_kind_id = Code.Id{ .Exe = ExpectedOutcome.Succeed };
                    } else if (mem.eql(u8, code_kind_str, "exe_err")) {
                        code_kind_id = Code.Id{ .Exe = ExpectedOutcome.Fail };
                    } else if (mem.eql(u8, code_kind_str, "test")) {
                        code_kind_id = Code.Id.Test;
                    } else if (mem.eql(u8, code_kind_str, "test_err")) {
                        code_kind_id = Code.Id{ .TestError = name };
                        name = "test";
                    } else if (mem.eql(u8, code_kind_str, "test_safety")) {
                        code_kind_id = Code.Id{ .TestSafety = name };
                        name = "test";
                    } else if (mem.eql(u8, code_kind_str, "obj")) {
                        code_kind_id = Code.Id{ .Obj = null };
                    } else if (mem.eql(u8, code_kind_str, "obj_err")) {
                        code_kind_id = Code.Id{ .Obj = name };
                        name = "test";
                    } else if (mem.eql(u8, code_kind_str, "syntax")) {
                        code_kind_id = Code.Id{ .Obj = null };
                        is_inline = true;
                    } else {
                        return parseError(tokenizer, code_kind_tok, "unrecognized code kind: {}", code_kind_str);
                    }

                    var mode = builtin.Mode.Debug;
                    var link_objects = std.ArrayList([]const u8).init(allocator);
                    defer link_objects.deinit();
                    var target_windows = false;
                    var link_libc = false;

                    const source_token = while (true) {
                        const content_tok = try eatToken(tokenizer, Token.Id.Content);
                        _ = try eatToken(tokenizer, Token.Id.BracketOpen);
                        const end_code_tag = try eatToken(tokenizer, Token.Id.TagContent);
                        const end_tag_name = tokenizer.buffer[end_code_tag.start..end_code_tag.end];
                        if (mem.eql(u8, end_tag_name, "code_release_fast")) {
                            mode = builtin.Mode.ReleaseFast;
                        } else if (mem.eql(u8, end_tag_name, "code_link_object")) {
                            _ = try eatToken(tokenizer, Token.Id.Separator);
                            const obj_tok = try eatToken(tokenizer, Token.Id.TagContent);
                            try link_objects.append(tokenizer.buffer[obj_tok.start..obj_tok.end]);
                        } else if (mem.eql(u8, end_tag_name, "target_windows")) {
                            target_windows = true;
                        } else if (mem.eql(u8, end_tag_name, "link_libc")) {
                            link_libc = true;
                        } else if (mem.eql(u8, end_tag_name, "code_end")) {
                            _ = try eatToken(tokenizer, Token.Id.BracketClose);
                            break content_tok;
                        } else {
                            return parseError(tokenizer, end_code_tag, "invalid token inside code_begin: {}", end_tag_name);
                        }
                        _ = try eatToken(tokenizer, Token.Id.BracketClose);
                    } else
                        unreachable; // TODO issue #707
                    try nodes.append(Node{
                        .Code = Code{
                            .id = code_kind_id,
                            .name = name,
                            .source_token = source_token,
                            .is_inline = is_inline,
                            .mode = mode,
                            .link_objects = link_objects.toOwnedSlice(),
                            .target_windows = target_windows,
                            .link_libc = link_libc,
                        },
                    });
                    tokenizer.code_node_count += 1;
                } else if (mem.eql(u8, tag_name, "syntax")) {
                    _ = try eatToken(tokenizer, Token.Id.BracketClose);
                    const content_tok = try eatToken(tokenizer, Token.Id.Content);
                    _ = try eatToken(tokenizer, Token.Id.BracketOpen);
                    const end_syntax_tag = try eatToken(tokenizer, Token.Id.TagContent);
                    const end_tag_name = tokenizer.buffer[end_syntax_tag.start..end_syntax_tag.end];
                    if (!mem.eql(u8, end_tag_name, "endsyntax")) {
                        return parseError(tokenizer, end_syntax_tag, "invalid token inside syntax: {}", end_tag_name);
                    }
                    _ = try eatToken(tokenizer, Token.Id.BracketClose);
                    try nodes.append(Node{ .Syntax = content_tok });
                } else {
                    return parseError(tokenizer, tag_token, "unrecognized tag name: {}", tag_name);
                }
            },
            else => return parseError(tokenizer, token, "invalid token"),
        }
    }

    return Toc{
        .nodes = nodes.toOwnedSlice(),
        .toc = toc_buf.toOwnedSlice(),
        .urls = urls,
    };
}

fn urlize(allocator: *mem.Allocator, input: []const u8) ![]u8 {
    var buf = try std.Buffer.initSize(allocator, 0);
    defer buf.deinit();

    var buf_adapter = io.BufferOutStream.init(&buf);
    var out = &buf_adapter.stream;
    for (input) |c| {
        switch (c) {
            'a'...'z', 'A'...'Z', '_', '-' => {
                try out.writeByte(c);
            },
            ' ' => {
                try out.writeByte('-');
            },
            else => {},
        }
    }
    return buf.toOwnedSlice();
}

fn escapeHtml(allocator: *mem.Allocator, input: []const u8) ![]u8 {
    var buf = try std.Buffer.initSize(allocator, 0);
    defer buf.deinit();

    var buf_adapter = io.BufferOutStream.init(&buf);
    var out = &buf_adapter.stream;
    try writeEscaped(out, input);
    return buf.toOwnedSlice();
}

fn writeEscaped(out: var, input: []const u8) !void {
    for (input) |c| {
        try switch (c) {
            '&' => out.write("&amp;"),
            '<' => out.write("&lt;"),
            '>' => out.write("&gt;"),
            '"' => out.write("&quot;"),
            else => out.writeByte(c),
        };
    }
}

//#define VT_RED "\x1b[31;1m"
//#define VT_GREEN "\x1b[32;1m"
//#define VT_CYAN "\x1b[36;1m"
//#define VT_WHITE "\x1b[37;1m"
//#define VT_BOLD "\x1b[0;1m"
//#define VT_RESET "\x1b[0m"

const TermState = enum {
    Start,
    Escape,
    LBracket,
    Number,
    AfterNumber,
    Arg,
    ArgNumber,
    ExpectEnd,
};

test "term color" {
    const input_bytes = "A\x1b[32;1mgreen\x1b[0mB";
    const result = try termColor(std.debug.global_allocator, input_bytes);
    assert(mem.eql(u8, result, "A<span class=\"t32\">green</span>B"));
}

fn termColor(allocator: *mem.Allocator, input: []const u8) ![]u8 {
    var buf = try std.Buffer.initSize(allocator, 0);
    defer buf.deinit();

    var buf_adapter = io.BufferOutStream.init(&buf);
    var out = &buf_adapter.stream;
    var number_start_index: usize = undefined;
    var first_number: usize = undefined;
    var second_number: usize = undefined;
    var i: usize = 0;
    var state = TermState.Start;
    var open_span_count: usize = 0;
    while (i < input.len) : (i += 1) {
        const c = input[i];
        switch (state) {
            TermState.Start => switch (c) {
                '\x1b' => state = TermState.Escape,
                else => try out.writeByte(c),
            },
            TermState.Escape => switch (c) {
                '[' => state = TermState.LBracket,
                else => return error.UnsupportedEscape,
            },
            TermState.LBracket => switch (c) {
                '0'...'9' => {
                    number_start_index = i;
                    state = TermState.Number;
                },
                else => return error.UnsupportedEscape,
            },
            TermState.Number => switch (c) {
                '0'...'9' => {},
                else => {
                    first_number = std.fmt.parseInt(usize, input[number_start_index..i], 10) catch unreachable;
                    second_number = 0;
                    state = TermState.AfterNumber;
                    i -= 1;
                },
            },

            TermState.AfterNumber => switch (c) {
                ';' => state = TermState.Arg,
                else => {
                    state = TermState.ExpectEnd;
                    i -= 1;
                },
            },
            TermState.Arg => switch (c) {
                '0'...'9' => {
                    number_start_index = i;
                    state = TermState.ArgNumber;
                },
                else => return error.UnsupportedEscape,
            },
            TermState.ArgNumber => switch (c) {
                '0'...'9' => {},
                else => {
                    second_number = std.fmt.parseInt(usize, input[number_start_index..i], 10) catch unreachable;
                    state = TermState.ExpectEnd;
                    i -= 1;
                },
            },
            TermState.ExpectEnd => switch (c) {
                'm' => {
                    state = TermState.Start;
                    while (open_span_count != 0) : (open_span_count -= 1) {
                        try out.write("</span>");
                    }
                    if (first_number != 0 or second_number != 0) {
                        try out.print("<span class=\"t{}_{}\">", first_number, second_number);
                        open_span_count += 1;
                    }
                },
                else => return error.UnsupportedEscape,
            },
        }
    }
    return buf.toOwnedSlice();
}

const builtin_types = [][]const u8{
    "f16", "f32", "f64", "f128", "c_longdouble", "c_short",
    "c_ushort", "c_int", "c_uint", "c_long", "c_ulong", "c_longlong",
    "c_ulonglong", "c_char", "c_void", "void", "bool", "isize",
    "usize", "noreturn", "type", "error", "comptime_int", "comptime_float",
};

fn isType(name: []const u8) bool {
    for (builtin_types) |t| {
        if (mem.eql(u8, t, name))
            return true;
    }
    return false;
}

fn tokenizeAndPrintRaw(docgen_tokenizer: *Tokenizer, out: var, source_token: Token, raw_src: []const u8) !void {
    const src = mem.trim(u8, raw_src, " \n");
    try out.write("<code class=\"zig\">");
    var tokenizer = std.zig.Tokenizer.init(src);
    var index: usize = 0;
    var next_tok_is_fn = false;
    while (true) {
        const prev_tok_was_fn = next_tok_is_fn;
        next_tok_is_fn = false;

        const token = tokenizer.next();
        try writeEscaped(out, src[index..token.start]);
        switch (token.id) {
            std.zig.Token.Id.Eof => break,

            std.zig.Token.Id.Keyword_align,
            std.zig.Token.Id.Keyword_and,
            std.zig.Token.Id.Keyword_asm,
            std.zig.Token.Id.Keyword_async,
            std.zig.Token.Id.Keyword_await,
            std.zig.Token.Id.Keyword_break,
            std.zig.Token.Id.Keyword_cancel,
            std.zig.Token.Id.Keyword_catch,
            std.zig.Token.Id.Keyword_comptime,
            std.zig.Token.Id.Keyword_const,
            std.zig.Token.Id.Keyword_continue,
            std.zig.Token.Id.Keyword_defer,
            std.zig.Token.Id.Keyword_else,
            std.zig.Token.Id.Keyword_enum,
            std.zig.Token.Id.Keyword_errdefer,
            std.zig.Token.Id.Keyword_error,
            std.zig.Token.Id.Keyword_export,
            std.zig.Token.Id.Keyword_extern,
            std.zig.Token.Id.Keyword_for,
            std.zig.Token.Id.Keyword_if,
            std.zig.Token.Id.Keyword_inline,
            std.zig.Token.Id.Keyword_nakedcc,
            std.zig.Token.Id.Keyword_noalias,
            std.zig.Token.Id.Keyword_or,
            std.zig.Token.Id.Keyword_orelse,
            std.zig.Token.Id.Keyword_packed,
            std.zig.Token.Id.Keyword_promise,
            std.zig.Token.Id.Keyword_pub,
            std.zig.Token.Id.Keyword_resume,
            std.zig.Token.Id.Keyword_return,
            std.zig.Token.Id.Keyword_section,
            std.zig.Token.Id.Keyword_stdcallcc,
            std.zig.Token.Id.Keyword_struct,
            std.zig.Token.Id.Keyword_suspend,
            std.zig.Token.Id.Keyword_switch,
            std.zig.Token.Id.Keyword_test,
            std.zig.Token.Id.Keyword_try,
            std.zig.Token.Id.Keyword_union,
            std.zig.Token.Id.Keyword_unreachable,
            std.zig.Token.Id.Keyword_use,
            std.zig.Token.Id.Keyword_var,
            std.zig.Token.Id.Keyword_volatile,
            std.zig.Token.Id.Keyword_while,
            => {
                try out.write("<span class=\"tok-kw\">");
                try writeEscaped(out, src[token.start..token.end]);
                try out.write("</span>");
            },

            std.zig.Token.Id.Keyword_fn => {
                try out.write("<span class=\"tok-kw\">");
                try writeEscaped(out, src[token.start..token.end]);
                try out.write("</span>");
                next_tok_is_fn = true;
            },

            std.zig.Token.Id.Keyword_undefined,
            std.zig.Token.Id.Keyword_null,
            std.zig.Token.Id.Keyword_true,
            std.zig.Token.Id.Keyword_false,
            std.zig.Token.Id.Keyword_this,
            => {
                try out.write("<span class=\"tok-null\">");
                try writeEscaped(out, src[token.start..token.end]);
                try out.write("</span>");
            },

            std.zig.Token.Id.StringLiteral,
            std.zig.Token.Id.MultilineStringLiteralLine,
            std.zig.Token.Id.CharLiteral,
            => {
                try out.write("<span class=\"tok-str\">");
                try writeEscaped(out, src[token.start..token.end]);
                try out.write("</span>");
            },

            std.zig.Token.Id.Builtin => {
                try out.write("<span class=\"tok-builtin\">");
                try writeEscaped(out, src[token.start..token.end]);
                try out.write("</span>");
            },

            std.zig.Token.Id.LineComment,
            std.zig.Token.Id.DocComment,
            std.zig.Token.Id.ShebangLine,
            => {
                try out.write("<span class=\"tok-comment\">");
                try writeEscaped(out, src[token.start..token.end]);
                try out.write("</span>");
            },

            std.zig.Token.Id.Identifier => {
                if (prev_tok_was_fn) {
                    try out.write("<span class=\"tok-fn\">");
                    try writeEscaped(out, src[token.start..token.end]);
                    try out.write("</span>");
                } else {
                    const is_int = blk: {
                        if (src[token.start] != 'i' and src[token.start] != 'u')
                            break :blk false;
                        var i = token.start + 1;
                        if (i == token.end)
                            break :blk false;
                        while (i != token.end) : (i += 1) {
                            if (src[i] < '0' or src[i] > '9')
                                break :blk false;
                        }
                        break :blk true;
                    };
                    if (is_int or isType(src[token.start..token.end])) {
                        try out.write("<span class=\"tok-type\">");
                        try writeEscaped(out, src[token.start..token.end]);
                        try out.write("</span>");
                    } else {
                        try writeEscaped(out, src[token.start..token.end]);
                    }
                }
            },

            std.zig.Token.Id.IntegerLiteral,
            std.zig.Token.Id.FloatLiteral,
            => {
                try out.write("<span class=\"tok-number\">");
                try writeEscaped(out, src[token.start..token.end]);
                try out.write("</span>");
            },

            std.zig.Token.Id.Bang,
            std.zig.Token.Id.Pipe,
            std.zig.Token.Id.PipePipe,
            std.zig.Token.Id.PipeEqual,
            std.zig.Token.Id.Equal,
            std.zig.Token.Id.EqualEqual,
            std.zig.Token.Id.EqualAngleBracketRight,
            std.zig.Token.Id.BangEqual,
            std.zig.Token.Id.LParen,
            std.zig.Token.Id.RParen,
            std.zig.Token.Id.Semicolon,
            std.zig.Token.Id.Percent,
            std.zig.Token.Id.PercentEqual,
            std.zig.Token.Id.LBrace,
            std.zig.Token.Id.RBrace,
            std.zig.Token.Id.LBracket,
            std.zig.Token.Id.RBracket,
            std.zig.Token.Id.Period,
            std.zig.Token.Id.Ellipsis2,
            std.zig.Token.Id.Ellipsis3,
            std.zig.Token.Id.Caret,
            std.zig.Token.Id.CaretEqual,
            std.zig.Token.Id.Plus,
            std.zig.Token.Id.PlusPlus,
            std.zig.Token.Id.PlusEqual,
            std.zig.Token.Id.PlusPercent,
            std.zig.Token.Id.PlusPercentEqual,
            std.zig.Token.Id.Minus,
            std.zig.Token.Id.MinusEqual,
            std.zig.Token.Id.MinusPercent,
            std.zig.Token.Id.MinusPercentEqual,
            std.zig.Token.Id.Asterisk,
            std.zig.Token.Id.AsteriskEqual,
            std.zig.Token.Id.AsteriskAsterisk,
            std.zig.Token.Id.AsteriskPercent,
            std.zig.Token.Id.AsteriskPercentEqual,
            std.zig.Token.Id.Arrow,
            std.zig.Token.Id.Colon,
            std.zig.Token.Id.Slash,
            std.zig.Token.Id.SlashEqual,
            std.zig.Token.Id.Comma,
            std.zig.Token.Id.Ampersand,
            std.zig.Token.Id.AmpersandEqual,
            std.zig.Token.Id.QuestionMark,
            std.zig.Token.Id.AngleBracketLeft,
            std.zig.Token.Id.AngleBracketLeftEqual,
            std.zig.Token.Id.AngleBracketAngleBracketLeft,
            std.zig.Token.Id.AngleBracketAngleBracketLeftEqual,
            std.zig.Token.Id.AngleBracketRight,
            std.zig.Token.Id.AngleBracketRightEqual,
            std.zig.Token.Id.AngleBracketAngleBracketRight,
            std.zig.Token.Id.AngleBracketAngleBracketRightEqual,
            std.zig.Token.Id.Tilde,
            std.zig.Token.Id.BracketStarBracket,
            => try writeEscaped(out, src[token.start..token.end]),

            std.zig.Token.Id.Invalid => return parseError(
                docgen_tokenizer,
                source_token,
                "syntax error",
            ),
        }
        index = token.end;
    }
    try out.write("</code>");
}

fn tokenizeAndPrint(docgen_tokenizer: *Tokenizer, out: var, source_token: Token) !void {
    const raw_src = docgen_tokenizer.buffer[source_token.start..source_token.end];
    return tokenizeAndPrintRaw(docgen_tokenizer, out, source_token, raw_src);
}

fn genHtml(allocator: *mem.Allocator, tokenizer: *Tokenizer, toc: *Toc, out: var, zig_exe: []const u8) !void {
    var code_progress_index: usize = 0;

    var env_map = try os.getEnvMap(allocator);
    try env_map.set("ZIG_DEBUG_COLOR", "1");

    const builtin_code = try getBuiltinCode(allocator, &env_map, zig_exe);

    for (toc.nodes) |node| {
        switch (node) {
            Node.Content => |data| {
                try out.write(data);
            },
            Node.Link => |info| {
                if (!toc.urls.contains(info.url)) {
                    return parseError(tokenizer, info.token, "url not found: {}", info.url);
                }
                try out.print("<a href=\"#{}\">{}</a>", info.url, info.name);
            },
            Node.Nav => {
                try out.write(toc.toc);
            },
            Node.Builtin => |tok| {
                try out.write("<pre>");
                try tokenizeAndPrintRaw(tokenizer, out, tok, builtin_code);
                try out.write("</pre>");
            },
            Node.HeaderOpen => |info| {
                try out.print("<h{} id=\"{}\">{}</h{}>\n", info.n, info.url, info.name, info.n);
            },
            Node.SeeAlso => |items| {
                try out.write("<p>See also:</p><ul>\n");
                for (items) |item| {
                    const url = try urlize(allocator, item.name);
                    if (!toc.urls.contains(url)) {
                        return parseError(tokenizer, item.token, "url not found: {}", url);
                    }
                    try out.print("<li><a href=\"#{}\">{}</a></li>\n", url, item.name);
                }
                try out.write("</ul>\n");
            },
            Node.Syntax => |content_tok| {
                try tokenizeAndPrint(tokenizer, out, content_tok);
            },
            Node.Code => |code| {
                code_progress_index += 1;
                warn("docgen example code {}/{}...", code_progress_index, tokenizer.code_node_count);

                const raw_source = tokenizer.buffer[code.source_token.start..code.source_token.end];
                const trimmed_raw_source = mem.trim(u8, raw_source, " \n");
                if (!code.is_inline) {
                    try out.print("<p class=\"file\">{}.zig</p>", code.name);
                }
                try out.write("<pre>");
                try tokenizeAndPrint(tokenizer, out, code.source_token);
                try out.write("</pre>");
                const name_plus_ext = try std.fmt.allocPrint(allocator, "{}.zig", code.name);
                const tmp_source_file_name = try os.path.join(allocator, tmp_dir_name, name_plus_ext);
                try io.writeFile(tmp_source_file_name, trimmed_raw_source);

                switch (code.id) {
                    Code.Id.Exe => |expected_outcome| {
                        const name_plus_bin_ext = try std.fmt.allocPrint(allocator, "{}{}", code.name, exe_ext);
                        const tmp_bin_file_name = try os.path.join(allocator, tmp_dir_name, name_plus_bin_ext);
                        var build_args = std.ArrayList([]const u8).init(allocator);
                        defer build_args.deinit();
                        try build_args.appendSlice([][]const u8{
                            zig_exe,
                            "build-exe",
                            tmp_source_file_name,
                            "--output",
                            tmp_bin_file_name,
                        });
                        try out.print("<pre><code class=\"shell\">$ zig build-exe {}.zig", code.name);
                        switch (code.mode) {
                            builtin.Mode.Debug => {},
                            builtin.Mode.ReleaseSafe => {
                                try build_args.append("--release-safe");
                                try out.print(" --release-safe");
                            },
                            builtin.Mode.ReleaseFast => {
                                try build_args.append("--release-fast");
                                try out.print(" --release-fast");
                            },
                            builtin.Mode.ReleaseSmall => {
                                try build_args.append("--release-small");
                                try out.print(" --release-small");
                            },
                        }
                        for (code.link_objects) |link_object| {
                            const name_with_ext = try std.fmt.allocPrint(allocator, "{}{}", link_object, obj_ext);
                            const full_path_object = try os.path.join(allocator, tmp_dir_name, name_with_ext);
                            try build_args.append("--object");
                            try build_args.append(full_path_object);
                            try out.print(" --object {}", name_with_ext);
                        }
                        if (code.link_libc) {
                            try build_args.append("--library");
                            try build_args.append("c");
                            try out.print(" --library c");
                        }
                        _ = exec(allocator, &env_map, build_args.toSliceConst()) catch return parseError(tokenizer, code.source_token, "example failed to compile");

                        const run_args = [][]const u8{tmp_bin_file_name};

                        const result = if (expected_outcome == ExpectedOutcome.Fail) blk: {
                            const result = try os.ChildProcess.exec(allocator, run_args, null, &env_map, max_doc_file_size);
                            switch (result.term) {
                                os.ChildProcess.Term.Exited => |exit_code| {
                                    if (exit_code == 0) {
                                        warn("{}\nThe following command incorrectly succeeded:\n", result.stderr);
                                        for (run_args) |arg|
                                            warn("{} ", arg)
                                        else
                                            warn("\n");
                                        return parseError(tokenizer, code.source_token, "example incorrectly compiled");
                                    }
                                },
                                else => {},
                            }
                            break :blk result;
                        } else blk: {
                            break :blk exec(allocator, &env_map, run_args) catch return parseError(tokenizer, code.source_token, "example crashed");
                        };

                        const escaped_stderr = try escapeHtml(allocator, result.stderr);
                        const escaped_stdout = try escapeHtml(allocator, result.stdout);

                        const colored_stderr = try termColor(allocator, escaped_stderr);
                        const colored_stdout = try termColor(allocator, escaped_stdout);

                        try out.print("\n$ ./{}\n{}{}</code></pre>\n", code.name, colored_stdout, colored_stderr);
                    },
                    Code.Id.Test => {
                        var test_args = std.ArrayList([]const u8).init(allocator);
                        defer test_args.deinit();

                        try test_args.appendSlice([][]const u8{
                            zig_exe,
                            "test",
                            tmp_source_file_name,
                            "--output",
                            test_out_path,
                        });
                        try out.print("<pre><code class=\"shell\">$ zig test {}.zig", code.name);
                        switch (code.mode) {
                            builtin.Mode.Debug => {},
                            builtin.Mode.ReleaseSafe => {
                                try test_args.append("--release-safe");
                                try out.print(" --release-safe");
                            },
                            builtin.Mode.ReleaseFast => {
                                try test_args.append("--release-fast");
                                try out.print(" --release-fast");
                            },
                            builtin.Mode.ReleaseSmall => {
                                try test_args.append("--release-small");
                                try out.print(" --release-small");
                            },
                        }
                        if (code.target_windows) {
                            try test_args.appendSlice([][]const u8{
                                "--target-os",
                                "windows",
                                "--target-arch",
                                "x86_64",
                                "--target-environ",
                                "msvc",
                            });
                        }
                        const result = exec(allocator, &env_map, test_args.toSliceConst()) catch return parseError(tokenizer, code.source_token, "test failed");
                        const escaped_stderr = try escapeHtml(allocator, result.stderr);
                        const escaped_stdout = try escapeHtml(allocator, result.stdout);
                        try out.print("\n{}{}</code></pre>\n", escaped_stderr, escaped_stdout);
                    },
                    Code.Id.TestError => |error_match| {
                        var test_args = std.ArrayList([]const u8).init(allocator);
                        defer test_args.deinit();

                        try test_args.appendSlice([][]const u8{
                            zig_exe,
                            "test",
                            "--color",
                            "on",
                            tmp_source_file_name,
                            "--output",
                            test_out_path,
                        });
                        try out.print("<pre><code class=\"shell\">$ zig test {}.zig", code.name);
                        switch (code.mode) {
                            builtin.Mode.Debug => {},
                            builtin.Mode.ReleaseSafe => {
                                try test_args.append("--release-safe");
                                try out.print(" --release-safe");
                            },
                            builtin.Mode.ReleaseFast => {
                                try test_args.append("--release-fast");
                                try out.print(" --release-fast");
                            },
                            builtin.Mode.ReleaseSmall => {
                                try test_args.append("--release-small");
                                try out.print(" --release-small");
                            },
                        }
                        const result = try os.ChildProcess.exec(allocator, test_args.toSliceConst(), null, &env_map, max_doc_file_size);
                        switch (result.term) {
                            os.ChildProcess.Term.Exited => |exit_code| {
                                if (exit_code == 0) {
                                    warn("{}\nThe following command incorrectly succeeded:\n", result.stderr);
                                    for (test_args.toSliceConst()) |arg|
                                        warn("{} ", arg)
                                    else
                                        warn("\n");
                                    return parseError(tokenizer, code.source_token, "example incorrectly compiled");
                                }
                            },
                            else => {
                                warn("{}\nThe following command crashed:\n", result.stderr);
                                for (test_args.toSliceConst()) |arg|
                                    warn("{} ", arg)
                                else
                                    warn("\n");
                                return parseError(tokenizer, code.source_token, "example compile crashed");
                            },
                        }
                        if (mem.indexOf(u8, result.stderr, error_match) == null) {
                            warn("{}\nExpected to find '{}' in stderr", result.stderr, error_match);
                            return parseError(tokenizer, code.source_token, "example did not have expected compile error");
                        }
                        const escaped_stderr = try escapeHtml(allocator, result.stderr);
                        const colored_stderr = try termColor(allocator, escaped_stderr);
                        try out.print("\n{}</code></pre>\n", colored_stderr);
                    },

                    Code.Id.TestSafety => |error_match| {
                        var test_args = std.ArrayList([]const u8).init(allocator);
                        defer test_args.deinit();

                        try test_args.appendSlice([][]const u8{
                            zig_exe,
                            "test",
                            tmp_source_file_name,
                            "--output",
                            test_out_path,
                        });
                        switch (code.mode) {
                            builtin.Mode.Debug => {},
                            builtin.Mode.ReleaseSafe => try test_args.append("--release-safe"),
                            builtin.Mode.ReleaseFast => try test_args.append("--release-fast"),
                            builtin.Mode.ReleaseSmall => try test_args.append("--release-small"),
                        }

                        const result = try os.ChildProcess.exec(allocator, test_args.toSliceConst(), null, &env_map, max_doc_file_size);
                        switch (result.term) {
                            os.ChildProcess.Term.Exited => |exit_code| {
                                if (exit_code == 0) {
                                    warn("{}\nThe following command incorrectly succeeded:\n", result.stderr);
                                    for (test_args.toSliceConst()) |arg|
                                        warn("{} ", arg)
                                    else
                                        warn("\n");
                                    return parseError(tokenizer, code.source_token, "example test incorrectly succeeded");
                                }
                            },
                            else => {
                                warn("{}\nThe following command crashed:\n", result.stderr);
                                for (test_args.toSliceConst()) |arg|
                                    warn("{} ", arg)
                                else
                                    warn("\n");
                                return parseError(tokenizer, code.source_token, "example compile crashed");
                            },
                        }
                        if (mem.indexOf(u8, result.stderr, error_match) == null) {
                            warn("{}\nExpected to find '{}' in stderr", result.stderr, error_match);
                            return parseError(tokenizer, code.source_token, "example did not have expected runtime safety error message");
                        }
                        const escaped_stderr = try escapeHtml(allocator, result.stderr);
                        const colored_stderr = try termColor(allocator, escaped_stderr);
                        try out.print("<pre><code class=\"shell\">$ zig test {}.zig\n{}</code></pre>\n", code.name, colored_stderr);
                    },
                    Code.Id.Obj => |maybe_error_match| {
                        const name_plus_obj_ext = try std.fmt.allocPrint(allocator, "{}{}", code.name, obj_ext);
                        const tmp_obj_file_name = try os.path.join(allocator, tmp_dir_name, name_plus_obj_ext);
                        var build_args = std.ArrayList([]const u8).init(allocator);
                        defer build_args.deinit();

                        const name_plus_h_ext = try std.fmt.allocPrint(allocator, "{}.h", code.name);
                        const output_h_file_name = try os.path.join(allocator, tmp_dir_name, name_plus_h_ext);

                        try build_args.appendSlice([][]const u8{
                            zig_exe,
                            "build-obj",
                            tmp_source_file_name,
                            "--color",
                            "on",
                            "--output",
                            tmp_obj_file_name,
                            "--output-h",
                            output_h_file_name,
                        });

                        if (!code.is_inline) {
                            try out.print("<pre><code class=\"shell\">$ zig build-obj {}.zig", code.name);
                        }

                        switch (code.mode) {
                            builtin.Mode.Debug => {},
                            builtin.Mode.ReleaseSafe => {
                                try build_args.append("--release-safe");
                                if (!code.is_inline) {
                                    try out.print(" --release-safe");
                                }
                            },
                            builtin.Mode.ReleaseFast => {
                                try build_args.append("--release-fast");
                                if (!code.is_inline) {
                                    try out.print(" --release-fast");
                                }
                            },
                            builtin.Mode.ReleaseSmall => {
                                try build_args.append("--release-small");
                                if (!code.is_inline) {
                                    try out.print(" --release-small");
                                }
                            },
                        }

                        if (maybe_error_match) |error_match| {
                            const result = try os.ChildProcess.exec(allocator, build_args.toSliceConst(), null, &env_map, max_doc_file_size);
                            switch (result.term) {
                                os.ChildProcess.Term.Exited => |exit_code| {
                                    if (exit_code == 0) {
                                        warn("{}\nThe following command incorrectly succeeded:\n", result.stderr);
                                        for (build_args.toSliceConst()) |arg|
                                            warn("{} ", arg)
                                        else
                                            warn("\n");
                                        return parseError(tokenizer, code.source_token, "example build incorrectly succeeded");
                                    }
                                },
                                else => {
                                    warn("{}\nThe following command crashed:\n", result.stderr);
                                    for (build_args.toSliceConst()) |arg|
                                        warn("{} ", arg)
                                    else
                                        warn("\n");
                                    return parseError(tokenizer, code.source_token, "example compile crashed");
                                },
                            }
                            if (mem.indexOf(u8, result.stderr, error_match) == null) {
                                warn("{}\nExpected to find '{}' in stderr", result.stderr, error_match);
                                return parseError(tokenizer, code.source_token, "example did not have expected compile error message");
                            }
                            const escaped_stderr = try escapeHtml(allocator, result.stderr);
                            const colored_stderr = try termColor(allocator, escaped_stderr);
                            try out.print("\n{}\n", colored_stderr);
                            if (!code.is_inline) {
                                try out.print("</code></pre>\n");
                            }
                        } else {
                            _ = exec(allocator, &env_map, build_args.toSliceConst()) catch return parseError(tokenizer, code.source_token, "example failed to compile");
                        }
                        if (!code.is_inline) {
                            try out.print("</code></pre>\n");
                        }
                    },
                }
                warn("OK\n");
            },
        }
    }
}

fn exec(allocator: *mem.Allocator, env_map: *std.BufMap, args: []const []const u8) !os.ChildProcess.ExecResult {
    const result = try os.ChildProcess.exec(allocator, args, null, env_map, max_doc_file_size);
    switch (result.term) {
        os.ChildProcess.Term.Exited => |exit_code| {
            if (exit_code != 0) {
                warn("{}\nThe following command exited with code {}:\n", result.stderr, exit_code);
                for (args) |arg|
                    warn("{} ", arg)
                else
                    warn("\n");
                return error.ChildExitError;
            }
        },
        else => {
            warn("{}\nThe following command crashed:\n", result.stderr);
            for (args) |arg|
                warn("{} ", arg)
            else
                warn("\n");
            return error.ChildCrashed;
        },
    }
    return result;
}

fn getBuiltinCode(allocator: *mem.Allocator, env_map: *std.BufMap, zig_exe: []const u8) ![]const u8 {
    const result = try exec(allocator, env_map, []const []const u8{
        zig_exe,
        "builtin",
    });
    return result.stdout;
}
