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

const max_doc_file_size = 10 * 1024 * 1024;

const exe_ext = @as(std.zig.CrossTarget, .{}).exeFileExt();
const obj_ext = builtin.object_format.fileExt(builtin.cpu.arch);
const tmp_dir_name = "docgen_tmp";
const test_out_path = tmp_dir_name ++ fs.path.sep_str ++ "test" ++ exe_ext;

const usage =
    \\Usage: docgen [--zig] [--skip-code-test] input output"
    \\
    \\   Generates an HTML document from a docgen template.
    \\
    \\Options:
    \\   -h, --help             Print this help and exit
    \\   --skip-code-test       Skip the doctests
    \\
;

fn errorf(comptime format: []const u8, args: anytype) noreturn {
    const stderr = io.getStdErr().writer();

    stderr.print("error: " ++ format, args) catch {};
    process.exit(1);
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var args_it = try process.argsWithAllocator(allocator);
    if (!args_it.skip()) @panic("expected self arg");

    var zig_exe: []const u8 = "zig";
    var do_code_tests = true;
    var files = [_][]const u8{ "", "" };

    var i: usize = 0;
    while (args_it.next()) |arg| {
        if (mem.startsWith(u8, arg, "-")) {
            if (mem.eql(u8, arg, "-h") or mem.eql(u8, arg, "--help")) {
                const stdout = io.getStdOut().writer();
                try stdout.writeAll(usage);
                process.exit(0);
            } else if (mem.eql(u8, arg, "--zig")) {
                if (args_it.next()) |param| {
                    zig_exe = param;
                } else {
                    errorf("expected parameter after --zig\n", .{});
                }
            } else if (mem.eql(u8, arg, "--skip-code-tests")) {
                do_code_tests = false;
            } else {
                errorf("unrecognized option: '{s}'\n", .{arg});
            }
        } else {
            if (i > 1) {
                errorf("too many arguments\n", .{});
            }
            files[i] = arg;
            i += 1;
        }
    }
    if (i < 2) {
        errorf("not enough arguments\n", .{});
        process.exit(1);
    }

    var in_file = try fs.cwd().openFile(files[0], .{ .mode = .read_only });
    defer in_file.close();

    var out_file = try fs.cwd().createFile(files[1], .{});
    defer out_file.close();

    const input_file_bytes = try in_file.reader().readAllAlloc(allocator, max_doc_file_size);

    var buffered_writer = io.bufferedWriter(out_file.writer());

    var tokenizer = Tokenizer.init(files[0], input_file_bytes);
    var toc = try genToc(allocator, &tokenizer);

    try fs.cwd().makePath(tmp_dir_name);
    defer fs.cwd().deleteTree(tmp_dir_name) catch {};

    try genHtml(allocator, &tokenizer, &toc, buffered_writer.writer(), zig_exe, do_code_tests);
    try buffered_writer.flush();
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
            const caret_count = std.math.min(token.end, loc.line_end) - token.start;
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

const ExpectedOutcome = enum {
    Succeed,
    Fail,
    BuildFail,
};

const Code = struct {
    id: Id,
    name: []const u8,
    source_token: Token,
    just_check_syntax: bool,
    mode: std.builtin.Mode,
    link_objects: []const []const u8,
    target_str: ?[]const u8,
    link_libc: bool,
    backend_stage1: bool,
    link_mode: ?std.builtin.LinkMode,
    disable_cache: bool,
    verbose_cimport: bool,

    const Id = union(enum) {
        Test,
        TestError: []const u8,
        TestSafety: []const u8,
        Exe: ExpectedOutcome,
        Obj: ?[]const u8,
        Lib,
    };
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
    Open,
    Close,
};

fn genToc(allocator: Allocator, tokenizer: *Tokenizer) !Toc {
    var urls = std.StringHashMap(Token).init(allocator);
    errdefer urls.deinit();

    var header_stack_size: usize = 0;
    var last_action = Action.Open;
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
            Token.Id.Eof => {
                if (header_stack_size != 0) {
                    return parseError(tokenizer, token, "unbalanced headers", .{});
                }
                try toc.writeAll("    </ul>\n");
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
                    var columns: ?u8 = null;
                    while (true) {
                        const bracket_tok = tokenizer.next();
                        switch (bracket_tok.id) {
                            .BracketClose => break,
                            .Separator => continue,
                            .TagContent => {
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
                    if (last_action == Action.Open) {
                        try toc.writeByte('\n');
                        try toc.writeByteNTimes(' ', header_stack_size * 4);
                        if (last_columns) |n| {
                            try toc.print("<ul style=\"columns: {}\">\n", .{n});
                        } else {
                            try toc.writeAll("<ul>\n");
                        }
                    } else {
                        last_action = Action.Open;
                    }
                    last_columns = columns;
                    try toc.writeByteNTimes(' ', 4 + header_stack_size * 4);
                    try toc.print("<li><a id=\"toc-{s}\" href=\"#{s}\">{s}</a>", .{ urlized, urlized, content });
                } else if (mem.eql(u8, tag_name, "header_close")) {
                    if (header_stack_size == 0) {
                        return parseError(tokenizer, tag_token, "unbalanced close header", .{});
                    }
                    header_stack_size -= 1;
                    _ = try eatToken(tokenizer, Token.Id.BracketClose);

                    if (last_action == Action.Close) {
                        try toc.writeByteNTimes(' ', 8 + header_stack_size * 4);
                        try toc.writeAll("</ul></li>\n");
                    } else {
                        try toc.writeAll("</li>\n");
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
                                try nodes.append(Node{ .SeeAlso = try list.toOwnedSlice() });
                                break;
                            },
                            else => return parseError(tokenizer, see_also_tok, "invalid see_also token", .{}),
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
                } else if (mem.eql(u8, tag_name, "code_begin")) {
                    _ = try eatToken(tokenizer, Token.Id.Separator);
                    const code_kind_tok = try eatToken(tokenizer, Token.Id.TagContent);
                    _ = try eatToken(tokenizer, Token.Id.Separator);
                    const name_tok = try eatToken(tokenizer, Token.Id.TagContent);
                    const name = tokenizer.buffer[name_tok.start..name_tok.end];
                    var error_str: []const u8 = "";
                    const maybe_sep = tokenizer.next();
                    switch (maybe_sep.id) {
                        Token.Id.Separator => {
                            const error_tok = try eatToken(tokenizer, Token.Id.TagContent);
                            error_str = tokenizer.buffer[error_tok.start..error_tok.end];
                            _ = try eatToken(tokenizer, Token.Id.BracketClose);
                        },
                        Token.Id.BracketClose => {},
                        else => return parseError(tokenizer, token, "invalid token", .{}),
                    }
                    const code_kind_str = tokenizer.buffer[code_kind_tok.start..code_kind_tok.end];
                    var code_kind_id: Code.Id = undefined;
                    var just_check_syntax = false;
                    if (mem.eql(u8, code_kind_str, "exe")) {
                        code_kind_id = Code.Id{ .Exe = ExpectedOutcome.Succeed };
                    } else if (mem.eql(u8, code_kind_str, "exe_err")) {
                        code_kind_id = Code.Id{ .Exe = ExpectedOutcome.Fail };
                    } else if (mem.eql(u8, code_kind_str, "exe_build_err")) {
                        code_kind_id = Code.Id{ .Exe = ExpectedOutcome.BuildFail };
                    } else if (mem.eql(u8, code_kind_str, "test")) {
                        code_kind_id = Code.Id.Test;
                    } else if (mem.eql(u8, code_kind_str, "test_err")) {
                        code_kind_id = Code.Id{ .TestError = error_str };
                    } else if (mem.eql(u8, code_kind_str, "test_safety")) {
                        code_kind_id = Code.Id{ .TestSafety = error_str };
                    } else if (mem.eql(u8, code_kind_str, "obj")) {
                        code_kind_id = Code.Id{ .Obj = null };
                    } else if (mem.eql(u8, code_kind_str, "obj_err")) {
                        code_kind_id = Code.Id{ .Obj = error_str };
                    } else if (mem.eql(u8, code_kind_str, "lib")) {
                        code_kind_id = Code.Id.Lib;
                    } else if (mem.eql(u8, code_kind_str, "syntax")) {
                        code_kind_id = Code.Id{ .Obj = null };
                        just_check_syntax = true;
                    } else {
                        return parseError(tokenizer, code_kind_tok, "unrecognized code kind: {s}", .{code_kind_str});
                    }

                    var mode: std.builtin.Mode = .Debug;
                    var link_objects = std.ArrayList([]const u8).init(allocator);
                    defer link_objects.deinit();
                    var target_str: ?[]const u8 = null;
                    var link_libc = false;
                    var link_mode: ?std.builtin.LinkMode = null;
                    var disable_cache = false;
                    var verbose_cimport = false;
                    var backend_stage1 = false;

                    const source_token = while (true) {
                        const content_tok = try eatToken(tokenizer, Token.Id.Content);
                        _ = try eatToken(tokenizer, Token.Id.BracketOpen);
                        const end_code_tag = try eatToken(tokenizer, Token.Id.TagContent);
                        const end_tag_name = tokenizer.buffer[end_code_tag.start..end_code_tag.end];
                        if (mem.eql(u8, end_tag_name, "code_release_fast")) {
                            mode = .ReleaseFast;
                        } else if (mem.eql(u8, end_tag_name, "code_release_safe")) {
                            mode = .ReleaseSafe;
                        } else if (mem.eql(u8, end_tag_name, "code_disable_cache")) {
                            disable_cache = true;
                        } else if (mem.eql(u8, end_tag_name, "code_verbose_cimport")) {
                            verbose_cimport = true;
                        } else if (mem.eql(u8, end_tag_name, "code_link_object")) {
                            _ = try eatToken(tokenizer, Token.Id.Separator);
                            const obj_tok = try eatToken(tokenizer, Token.Id.TagContent);
                            try link_objects.append(tokenizer.buffer[obj_tok.start..obj_tok.end]);
                        } else if (mem.eql(u8, end_tag_name, "target_windows")) {
                            target_str = "x86_64-windows";
                        } else if (mem.eql(u8, end_tag_name, "target_linux_x86_64")) {
                            target_str = "x86_64-linux";
                        } else if (mem.eql(u8, end_tag_name, "target_linux_riscv64")) {
                            target_str = "riscv64-linux";
                        } else if (mem.eql(u8, end_tag_name, "target_wasm")) {
                            target_str = "wasm32-freestanding";
                        } else if (mem.eql(u8, end_tag_name, "target_wasi")) {
                            target_str = "wasm32-wasi";
                        } else if (mem.eql(u8, end_tag_name, "link_libc")) {
                            link_libc = true;
                        } else if (mem.eql(u8, end_tag_name, "link_mode_dynamic")) {
                            link_mode = .Dynamic;
                        } else if (mem.eql(u8, end_tag_name, "backend_stage1")) {
                            backend_stage1 = true;
                        } else if (mem.eql(u8, end_tag_name, "code_end")) {
                            _ = try eatToken(tokenizer, Token.Id.BracketClose);
                            break content_tok;
                        } else {
                            return parseError(
                                tokenizer,
                                end_code_tag,
                                "invalid token inside code_begin: {s}",
                                .{end_tag_name},
                            );
                        }
                        _ = try eatToken(tokenizer, Token.Id.BracketClose);
                    } else unreachable; // TODO issue #707
                    try nodes.append(Node{
                        .Code = Code{
                            .id = code_kind_id,
                            .name = name,
                            .source_token = source_token,
                            .just_check_syntax = just_check_syntax,
                            .mode = mode,
                            .link_objects = try link_objects.toOwnedSlice(),
                            .target_str = target_str,
                            .link_libc = link_libc,
                            .backend_stage1 = backend_stage1,
                            .link_mode = link_mode,
                            .disable_cache = disable_cache,
                            .verbose_cimport = verbose_cimport,
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
                        return parseError(
                            tokenizer,
                            end_syntax_tag,
                            "invalid token inside syntax: {s}",
                            .{end_tag_name},
                        );
                    }
                    _ = try eatToken(tokenizer, Token.Id.BracketClose);
                    try nodes.append(Node{ .InlineSyntax = content_tok });
                } else if (mem.eql(u8, tag_name, "shell_samp")) {
                    _ = try eatToken(tokenizer, Token.Id.BracketClose);
                    const content_tok = try eatToken(tokenizer, Token.Id.Content);
                    _ = try eatToken(tokenizer, Token.Id.BracketOpen);
                    const end_syntax_tag = try eatToken(tokenizer, Token.Id.TagContent);
                    const end_tag_name = tokenizer.buffer[end_syntax_tag.start..end_syntax_tag.end];
                    if (!mem.eql(u8, end_tag_name, "end_shell_samp")) {
                        return parseError(
                            tokenizer,
                            end_syntax_tag,
                            "invalid token inside syntax: {s}",
                            .{end_tag_name},
                        );
                    }
                    _ = try eatToken(tokenizer, Token.Id.BracketClose);
                    try nodes.append(Node{ .Shell = content_tok });
                } else if (mem.eql(u8, tag_name, "syntax_block")) {
                    _ = try eatToken(tokenizer, Token.Id.Separator);
                    const source_type_tok = try eatToken(tokenizer, Token.Id.TagContent);
                    var name: []const u8 = "sample_code";
                    const maybe_sep = tokenizer.next();
                    switch (maybe_sep.id) {
                        Token.Id.Separator => {
                            const name_tok = try eatToken(tokenizer, Token.Id.TagContent);
                            name = tokenizer.buffer[name_tok.start..name_tok.end];
                            _ = try eatToken(tokenizer, Token.Id.BracketClose);
                        },
                        Token.Id.BracketClose => {},
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
                        const content_tok = try eatToken(tokenizer, Token.Id.Content);
                        _ = try eatToken(tokenizer, Token.Id.BracketOpen);
                        const end_code_tag = try eatToken(tokenizer, Token.Id.TagContent);
                        const end_tag_name = tokenizer.buffer[end_code_tag.start..end_code_tag.end];
                        if (mem.eql(u8, end_tag_name, "end_syntax_block")) {
                            _ = try eatToken(tokenizer, Token.Id.BracketClose);
                            break content_tok;
                        } else {
                            return parseError(
                                tokenizer,
                                end_code_tag,
                                "invalid token inside code_begin: {s}",
                                .{end_tag_name},
                            );
                        }
                        _ = try eatToken(tokenizer, Token.Id.BracketClose);
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

//#define VT_RED "\x1b[31;1m"
//#define VT_GREEN "\x1b[32;1m"
//#define VT_CYAN "\x1b[36;1m"
//#define VT_WHITE "\x1b[37;1m"
//#define VT_BOLD "\x1b[0;1m"
//#define VT_RESET "\x1b[0m"

test "term color" {
    const input_bytes = "A\x1b[32;1mgreen\x1b[0mB";
    const result = try termColor(std.testing.allocator, input_bytes);
    defer std.testing.allocator.free(result);
    try testing.expectEqualSlices(u8, "A<span class=\"t32_1\">green</span>B", result);
}

fn termColor(allocator: Allocator, input: []const u8) ![]u8 {
    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();

    var out = buf.writer();
    var number_start_index: usize = undefined;
    var first_number: usize = undefined;
    var second_number: usize = undefined;
    var i: usize = 0;
    var state: enum {
        start,
        escape,
        lbracket,
        number,
        after_number,
        arg,
        arg_number,
        expect_end,
    } = .start;
    var last_new_line: usize = 0;
    var open_span_count: usize = 0;
    while (i < input.len) : (i += 1) {
        const c = input[i];
        switch (state) {
            .start => switch (c) {
                '\x1b' => state = .escape,
                '\n' => {
                    try out.writeByte(c);
                    last_new_line = buf.items.len;
                },
                else => try out.writeByte(c),
            },
            .escape => switch (c) {
                '[' => state = .lbracket,
                else => return error.UnsupportedEscape,
            },
            .lbracket => switch (c) {
                '0'...'9' => {
                    number_start_index = i;
                    state = .number;
                },
                else => return error.UnsupportedEscape,
            },
            .number => switch (c) {
                '0'...'9' => {},
                else => {
                    first_number = std.fmt.parseInt(usize, input[number_start_index..i], 10) catch unreachable;
                    second_number = 0;
                    state = .after_number;
                    i -= 1;
                },
            },

            .after_number => switch (c) {
                ';' => state = .arg,
                'D' => state = .start,
                'K' => {
                    buf.items.len = last_new_line;
                    state = .start;
                },
                else => {
                    state = .expect_end;
                    i -= 1;
                },
            },
            .arg => switch (c) {
                '0'...'9' => {
                    number_start_index = i;
                    state = .arg_number;
                },
                else => return error.UnsupportedEscape,
            },
            .arg_number => switch (c) {
                '0'...'9' => {},
                else => {
                    second_number = std.fmt.parseInt(usize, input[number_start_index..i], 10) catch unreachable;
                    state = .expect_end;
                    i -= 1;
                },
            },
            .expect_end => switch (c) {
                'm' => {
                    state = .start;
                    while (open_span_count != 0) : (open_span_count -= 1) {
                        try out.writeAll("</span>");
                    }
                    if (first_number != 0 or second_number != 0) {
                        try out.print("<span class=\"t{d}_{d}\">", .{ first_number, second_number });
                        open_span_count += 1;
                    }
                },
                else => return error.UnsupportedEscape,
            },
        }
    }
    return try buf.toOwnedSlice();
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

const start_line = "<span class=\"line\">";
const end_line = "</span>";

fn writeEscapedLines(out: anytype, text: []const u8) !void {
    for (text) |char| {
        if (char == '\n') {
            try out.writeAll(end_line);
            try out.writeAll("\n");
            try out.writeAll(start_line);
        } else {
            try writeEscaped(out, &[_]u8{char});
        }
    }
}

fn tokenizeAndPrintRaw(
    allocator: Allocator,
    docgen_tokenizer: *Tokenizer,
    out: anytype,
    source_token: Token,
    raw_src: []const u8,
) !void {
    const src_non_terminated = mem.trim(u8, raw_src, " \n");
    const src = try allocator.dupeZ(u8, src_non_terminated);

    try out.writeAll("<code>" ++ start_line);
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
                    try out.writeAll("</span>" ++ end_line ++ "\n" ++ start_line);
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

            .invalid, .invalid_periodasterisks => return parseError(
                docgen_tokenizer,
                source_token,
                "syntax error",
                .{},
            ),
        }
        index = token.loc.end;
    }
    try out.writeAll(end_line ++ "</code>");
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
            const trimmed_raw_source = mem.trim(u8, raw_source, " \n");

            try out.writeAll("<code>" ++ start_line);
            try writeEscapedLines(out, trimmed_raw_source);
            try out.writeAll(end_line ++ "</code>");
        },
    }
    try out.writeAll("</pre></figure>");
}

fn printShell(out: anytype, shell_content: []const u8, escape: bool) !void {
    const trimmed_shell_content = mem.trim(u8, shell_content, " \n");
    try out.writeAll("<figure><figcaption class=\"shell-cap\">Shell</figcaption><pre><samp>");
    var cmd_cont: bool = false;
    var iter = std.mem.split(u8, trimmed_shell_content, "\n");
    while (iter.next()) |orig_line| {
        const line = mem.trimRight(u8, orig_line, " ");
        if (!cmd_cont and line.len > 1 and mem.eql(u8, line[0..2], "$ ") and line[line.len - 1] != '\\') {
            try out.writeAll(start_line ++ "$ <kbd>");
            const s = std.mem.trimLeft(u8, line[1..], " ");
            if (escape) {
                try writeEscaped(out, s);
            } else {
                try out.writeAll(s);
            }
            try out.writeAll("</kbd>" ++ end_line ++ "\n");
        } else if (!cmd_cont and line.len > 1 and mem.eql(u8, line[0..2], "$ ") and line[line.len - 1] == '\\') {
            try out.writeAll(start_line ++ "$ <kbd>");
            const s = std.mem.trimLeft(u8, line[1..], " ");
            if (escape) {
                try writeEscaped(out, s);
            } else {
                try out.writeAll(s);
            }
            try out.writeAll(end_line ++ "\n");
            cmd_cont = true;
        } else if (line.len > 0 and line[line.len - 1] != '\\' and cmd_cont) {
            try out.writeAll(start_line);
            if (escape) {
                try writeEscaped(out, line);
            } else {
                try out.writeAll(line);
            }
            try out.writeAll("</kbd>" ++ end_line ++ "\n");
            cmd_cont = false;
        } else {
            try out.writeAll(start_line);
            if (escape) {
                try writeEscaped(out, line);
            } else {
                try out.writeAll(line);
            }
            try out.writeAll(end_line ++ "\n");
        }
    }

    try out.writeAll("</samp></pre></figure>");
}

// Override this to skip to later tests
const debug_start_line = 0;

fn genHtml(
    allocator: Allocator,
    tokenizer: *Tokenizer,
    toc: *Toc,
    out: anytype,
    zig_exe: []const u8,
    do_code_tests: bool,
) !void {
    var progress = Progress{};
    const root_node = progress.start("Generating docgen examples", toc.nodes.len);
    defer root_node.end();

    var env_map = try process.getEnvMap(allocator);
    try env_map.put("ZIG_DEBUG_COLOR", "1");

    const host = try std.zig.system.NativeTargetInfo.detect(.{});
    const builtin_code = try getBuiltinCode(allocator, &env_map, zig_exe);

    for (toc.nodes) |node| {
        defer root_node.completeOne();
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
                const name_plus_ext = try std.fmt.allocPrint(allocator, "{s}.zig", .{code.name});
                const syntax_block = SyntaxBlock{
                    .source_type = .zig,
                    .name = name_plus_ext,
                    .source_token = code.source_token,
                };

                try printSourceBlock(allocator, tokenizer, out, syntax_block);

                if (!do_code_tests) {
                    continue;
                }

                if (debug_start_line > 0) {
                    const loc = tokenizer.getTokenLocation(code.source_token);
                    if (debug_start_line > loc.line) {
                        continue;
                    }
                }

                const raw_source = tokenizer.buffer[code.source_token.start..code.source_token.end];
                const trimmed_raw_source = mem.trim(u8, raw_source, " \n");
                const tmp_source_file_name = try fs.path.join(
                    allocator,
                    &[_][]const u8{ tmp_dir_name, name_plus_ext },
                );
                try fs.cwd().writeFile(tmp_source_file_name, trimmed_raw_source);

                var shell_buffer = std.ArrayList(u8).init(allocator);
                defer shell_buffer.deinit();
                var shell_out = shell_buffer.writer();

                switch (code.id) {
                    Code.Id.Exe => |expected_outcome| code_block: {
                        var build_args = std.ArrayList([]const u8).init(allocator);
                        defer build_args.deinit();
                        try build_args.appendSlice(&[_][]const u8{
                            zig_exe,          "build-exe",
                            "--name",         code.name,
                            "--color",        "on",
                            "--enable-cache", tmp_source_file_name,
                        });

                        try shell_out.print("$ zig build-exe {s} ", .{name_plus_ext});

                        switch (code.mode) {
                            .Debug => {},
                            else => {
                                try build_args.appendSlice(&[_][]const u8{ "-O", @tagName(code.mode) });
                                try shell_out.print("-O {s} ", .{@tagName(code.mode)});
                            },
                        }
                        for (code.link_objects) |link_object| {
                            const name_with_ext = try std.fmt.allocPrint(allocator, "{s}{s}", .{ link_object, obj_ext });
                            const full_path_object = try fs.path.join(
                                allocator,
                                &[_][]const u8{ tmp_dir_name, name_with_ext },
                            );
                            try build_args.append(full_path_object);
                            try shell_out.print("{s} ", .{name_with_ext});
                        }
                        if (code.link_libc) {
                            try build_args.append("-lc");
                            try shell_out.print("-lc ", .{});
                        }
                        if (code.backend_stage1) {
                            try build_args.append("-fstage1");
                            try shell_out.print("-fstage1", .{});
                        }
                        const target = try std.zig.CrossTarget.parse(.{
                            .arch_os_abi = code.target_str orelse "native",
                        });
                        if (code.target_str) |triple| {
                            try build_args.appendSlice(&[_][]const u8{ "-target", triple });
                            try shell_out.print("-target {s} ", .{triple});
                        }
                        if (code.verbose_cimport) {
                            try build_args.append("--verbose-cimport");
                            try shell_out.print("--verbose-cimport ", .{});
                        }

                        try shell_out.print("\n", .{});

                        if (expected_outcome == .BuildFail) {
                            const result = try ChildProcess.exec(.{
                                .allocator = allocator,
                                .argv = build_args.items,
                                .env_map = &env_map,
                                .max_output_bytes = max_doc_file_size,
                            });
                            switch (result.term) {
                                .Exited => |exit_code| {
                                    if (exit_code == 0) {
                                        progress.log("", .{});
                                        print("{s}\nThe following command incorrectly succeeded:\n", .{result.stderr});
                                        dumpArgs(build_args.items);
                                        return parseError(tokenizer, code.source_token, "example incorrectly compiled", .{});
                                    }
                                },
                                else => {
                                    progress.log("", .{});
                                    print("{s}\nThe following command crashed:\n", .{result.stderr});
                                    dumpArgs(build_args.items);
                                    return parseError(tokenizer, code.source_token, "example compile crashed", .{});
                                },
                            }
                            const escaped_stderr = try escapeHtml(allocator, result.stderr);
                            const colored_stderr = try termColor(allocator, escaped_stderr);
                            try shell_out.writeAll(colored_stderr);
                            break :code_block;
                        }
                        const exec_result = exec(allocator, &env_map, build_args.items) catch
                            return parseError(tokenizer, code.source_token, "example failed to compile", .{});

                        if (code.verbose_cimport) {
                            const escaped_build_stderr = try escapeHtml(allocator, exec_result.stderr);
                            try shell_out.writeAll(escaped_build_stderr);
                        }

                        if (code.target_str) |triple| {
                            if (mem.startsWith(u8, triple, "wasm32") or
                                mem.startsWith(u8, triple, "riscv64-linux") or
                                (mem.startsWith(u8, triple, "x86_64-linux") and
                                builtin.os.tag != .linux or builtin.cpu.arch != .x86_64))
                            {
                                // skip execution
                                break :code_block;
                            }
                        }

                        const path_to_exe_dir = mem.trim(u8, exec_result.stdout, " \r\n");
                        const path_to_exe_basename = try std.fmt.allocPrint(allocator, "{s}{s}", .{
                            code.name,
                            target.exeFileExt(),
                        });
                        const path_to_exe = try fs.path.join(allocator, &[_][]const u8{
                            path_to_exe_dir,
                            path_to_exe_basename,
                        });
                        const run_args = &[_][]const u8{path_to_exe};

                        var exited_with_signal = false;

                        const result = if (expected_outcome == ExpectedOutcome.Fail) blk: {
                            const result = try ChildProcess.exec(.{
                                .allocator = allocator,
                                .argv = run_args,
                                .env_map = &env_map,
                                .max_output_bytes = max_doc_file_size,
                            });
                            switch (result.term) {
                                .Exited => |exit_code| {
                                    if (exit_code == 0) {
                                        progress.log("", .{});
                                        print("{s}\nThe following command incorrectly succeeded:\n", .{result.stderr});
                                        dumpArgs(run_args);
                                        return parseError(tokenizer, code.source_token, "example incorrectly compiled", .{});
                                    }
                                },
                                .Signal => exited_with_signal = true,
                                else => {},
                            }
                            break :blk result;
                        } else blk: {
                            break :blk exec(allocator, &env_map, run_args) catch return parseError(tokenizer, code.source_token, "example crashed", .{});
                        };

                        const escaped_stderr = try escapeHtml(allocator, result.stderr);
                        const escaped_stdout = try escapeHtml(allocator, result.stdout);

                        const colored_stderr = try termColor(allocator, escaped_stderr);
                        const colored_stdout = try termColor(allocator, escaped_stdout);

                        try shell_out.print("\n$ ./{s}\n{s}{s}", .{ code.name, colored_stdout, colored_stderr });
                        if (exited_with_signal) {
                            try shell_out.print("(process terminated by signal)", .{});
                        }
                        try shell_out.writeAll("\n");
                    },
                    Code.Id.Test => {
                        var test_args = std.ArrayList([]const u8).init(allocator);
                        defer test_args.deinit();

                        try test_args.appendSlice(&[_][]const u8{
                            zig_exe, "test", tmp_source_file_name,
                        });
                        try shell_out.print("$ zig test {s}.zig ", .{code.name});

                        switch (code.mode) {
                            .Debug => {},
                            else => {
                                try test_args.appendSlice(&[_][]const u8{
                                    "-O", @tagName(code.mode),
                                });
                                try shell_out.print("-O {s} ", .{@tagName(code.mode)});
                            },
                        }
                        if (code.link_libc) {
                            try test_args.append("-lc");
                            try shell_out.print("-lc ", .{});
                        }
                        if (code.backend_stage1) {
                            try test_args.append("-fstage1");
                            try shell_out.print("-fstage1", .{});
                        }
                        if (code.target_str) |triple| {
                            try test_args.appendSlice(&[_][]const u8{ "-target", triple });
                            try shell_out.print("-target {s} ", .{triple});

                            const cross_target = try std.zig.CrossTarget.parse(.{
                                .arch_os_abi = triple,
                            });
                            const target_info = try std.zig.system.NativeTargetInfo.detect(
                                cross_target,
                            );
                            switch (host.getExternalExecutor(target_info, .{
                                .link_libc = code.link_libc,
                            })) {
                                .native => {},
                                else => {
                                    try test_args.appendSlice(&[_][]const u8{"--test-no-exec"});
                                    try shell_out.writeAll("--test-no-exec");
                                },
                            }
                        }
                        const result = exec(allocator, &env_map, test_args.items) catch
                            return parseError(tokenizer, code.source_token, "test failed", .{});
                        const escaped_stderr = try escapeHtml(allocator, result.stderr);
                        const escaped_stdout = try escapeHtml(allocator, result.stdout);
                        try shell_out.print("\n{s}{s}\n", .{ escaped_stderr, escaped_stdout });
                    },
                    Code.Id.TestError => |error_match| {
                        var test_args = std.ArrayList([]const u8).init(allocator);
                        defer test_args.deinit();

                        try test_args.appendSlice(&[_][]const u8{
                            zig_exe,
                            "test",
                            "--color",
                            "on",
                            tmp_source_file_name,
                        });
                        try shell_out.print("$ zig test {s}.zig ", .{code.name});

                        switch (code.mode) {
                            .Debug => {},
                            else => {
                                try test_args.appendSlice(&[_][]const u8{ "-O", @tagName(code.mode) });
                                try shell_out.print("-O {s} ", .{@tagName(code.mode)});
                            },
                        }
                        if (code.link_libc) {
                            try test_args.append("-lc");
                            try shell_out.print("-lc ", .{});
                        }
                        if (code.backend_stage1) {
                            try test_args.append("-fstage1");
                            try shell_out.print("-fstage1", .{});
                        }
                        const result = try ChildProcess.exec(.{
                            .allocator = allocator,
                            .argv = test_args.items,
                            .env_map = &env_map,
                            .max_output_bytes = max_doc_file_size,
                        });
                        switch (result.term) {
                            .Exited => |exit_code| {
                                if (exit_code == 0) {
                                    progress.log("", .{});
                                    print("{s}\nThe following command incorrectly succeeded:\n", .{result.stderr});
                                    dumpArgs(test_args.items);
                                    return parseError(tokenizer, code.source_token, "example incorrectly compiled", .{});
                                }
                            },
                            else => {
                                progress.log("", .{});
                                print("{s}\nThe following command crashed:\n", .{result.stderr});
                                dumpArgs(test_args.items);
                                return parseError(tokenizer, code.source_token, "example compile crashed", .{});
                            },
                        }
                        if (mem.indexOf(u8, result.stderr, error_match) == null) {
                            progress.log("", .{});
                            print("{s}\nExpected to find '{s}' in stderr\n", .{ result.stderr, error_match });
                            return parseError(tokenizer, code.source_token, "example did not have expected compile error", .{});
                        }
                        const escaped_stderr = try escapeHtml(allocator, result.stderr);
                        const colored_stderr = try termColor(allocator, escaped_stderr);
                        try shell_out.print("\n{s}\n", .{colored_stderr});
                    },

                    Code.Id.TestSafety => |error_match| {
                        var test_args = std.ArrayList([]const u8).init(allocator);
                        defer test_args.deinit();

                        try test_args.appendSlice(&[_][]const u8{
                            zig_exe, "test", tmp_source_file_name,
                        });
                        var mode_arg: []const u8 = "";
                        switch (code.mode) {
                            .Debug => {},
                            .ReleaseSafe => {
                                try test_args.append("-OReleaseSafe");
                                mode_arg = "-OReleaseSafe";
                            },
                            .ReleaseFast => {
                                try test_args.append("-OReleaseFast");
                                mode_arg = "-OReleaseFast";
                            },
                            .ReleaseSmall => {
                                try test_args.append("-OReleaseSmall");
                                mode_arg = "-OReleaseSmall";
                            },
                        }

                        const result = try ChildProcess.exec(.{
                            .allocator = allocator,
                            .argv = test_args.items,
                            .env_map = &env_map,
                            .max_output_bytes = max_doc_file_size,
                        });
                        switch (result.term) {
                            .Exited => |exit_code| {
                                if (exit_code == 0) {
                                    progress.log("", .{});
                                    print("{s}\nThe following command incorrectly succeeded:\n", .{result.stderr});
                                    dumpArgs(test_args.items);
                                    return parseError(tokenizer, code.source_token, "example test incorrectly succeeded", .{});
                                }
                            },
                            else => {
                                progress.log("", .{});
                                print("{s}\nThe following command crashed:\n", .{result.stderr});
                                dumpArgs(test_args.items);
                                return parseError(tokenizer, code.source_token, "example compile crashed", .{});
                            },
                        }
                        if (mem.indexOf(u8, result.stderr, error_match) == null) {
                            progress.log("", .{});
                            print("{s}\nExpected to find '{s}' in stderr\n", .{ result.stderr, error_match });
                            return parseError(tokenizer, code.source_token, "example did not have expected runtime safety error message", .{});
                        }
                        const escaped_stderr = try escapeHtml(allocator, result.stderr);
                        const colored_stderr = try termColor(allocator, escaped_stderr);
                        try shell_out.print("$ zig test {s}.zig {s}\n{s}\n", .{
                            code.name,
                            mode_arg,
                            colored_stderr,
                        });
                    },
                    Code.Id.Obj => |maybe_error_match| {
                        const name_plus_obj_ext = try std.fmt.allocPrint(allocator, "{s}{s}", .{ code.name, obj_ext });
                        var build_args = std.ArrayList([]const u8).init(allocator);
                        defer build_args.deinit();

                        try build_args.appendSlice(&[_][]const u8{
                            zig_exe,
                            "build-obj",
                            tmp_source_file_name,
                            "--color",
                            "on",
                            "--name",
                            code.name,
                            try std.fmt.allocPrint(allocator, "-femit-bin={s}{c}{s}", .{
                                tmp_dir_name, fs.path.sep, name_plus_obj_ext,
                            }),
                        });

                        try shell_out.print("$ zig build-obj {s}.zig ", .{code.name});

                        switch (code.mode) {
                            .Debug => {},
                            else => {
                                try build_args.appendSlice(&[_][]const u8{ "-O", @tagName(code.mode) });
                                try shell_out.print("-O {s} ", .{@tagName(code.mode)});
                            },
                        }

                        if (code.target_str) |triple| {
                            try build_args.appendSlice(&[_][]const u8{ "-target", triple });
                            try shell_out.print("-target {s} ", .{triple});
                        }

                        if (maybe_error_match) |error_match| {
                            const result = try ChildProcess.exec(.{
                                .allocator = allocator,
                                .argv = build_args.items,
                                .env_map = &env_map,
                                .max_output_bytes = max_doc_file_size,
                            });
                            switch (result.term) {
                                .Exited => |exit_code| {
                                    if (exit_code == 0) {
                                        progress.log("", .{});
                                        print("{s}\nThe following command incorrectly succeeded:\n", .{result.stderr});
                                        dumpArgs(build_args.items);
                                        return parseError(tokenizer, code.source_token, "example build incorrectly succeeded", .{});
                                    }
                                },
                                else => {
                                    progress.log("", .{});
                                    print("{s}\nThe following command crashed:\n", .{result.stderr});
                                    dumpArgs(build_args.items);
                                    return parseError(tokenizer, code.source_token, "example compile crashed", .{});
                                },
                            }
                            if (mem.indexOf(u8, result.stderr, error_match) == null) {
                                progress.log("", .{});
                                print("{s}\nExpected to find '{s}' in stderr\n", .{ result.stderr, error_match });
                                return parseError(tokenizer, code.source_token, "example did not have expected compile error message", .{});
                            }
                            const escaped_stderr = try escapeHtml(allocator, result.stderr);
                            const colored_stderr = try termColor(allocator, escaped_stderr);
                            try shell_out.print("\n{s} ", .{colored_stderr});
                        } else {
                            _ = exec(allocator, &env_map, build_args.items) catch return parseError(tokenizer, code.source_token, "example failed to compile", .{});
                        }
                        try shell_out.writeAll("\n");
                    },
                    Code.Id.Lib => {
                        const bin_basename = try std.zig.binNameAlloc(allocator, .{
                            .root_name = code.name,
                            .target = builtin.target,
                            .output_mode = .Lib,
                        });

                        var test_args = std.ArrayList([]const u8).init(allocator);
                        defer test_args.deinit();

                        try test_args.appendSlice(&[_][]const u8{
                            zig_exe,
                            "build-lib",
                            tmp_source_file_name,
                            try std.fmt.allocPrint(allocator, "-femit-bin={s}{s}{s}", .{
                                tmp_dir_name, fs.path.sep_str, bin_basename,
                            }),
                        });
                        try shell_out.print("$ zig build-lib {s}.zig ", .{code.name});

                        switch (code.mode) {
                            .Debug => {},
                            else => {
                                try test_args.appendSlice(&[_][]const u8{ "-O", @tagName(code.mode) });
                                try shell_out.print("-O {s} ", .{@tagName(code.mode)});
                            },
                        }
                        if (code.target_str) |triple| {
                            try test_args.appendSlice(&[_][]const u8{ "-target", triple });
                            try shell_out.print("-target {s} ", .{triple});
                        }
                        if (code.link_mode) |link_mode| {
                            switch (link_mode) {
                                .Static => {
                                    try test_args.append("-static");
                                    try shell_out.print("-static ", .{});
                                },
                                .Dynamic => {
                                    try test_args.append("-dynamic");
                                    try shell_out.print("-dynamic ", .{});
                                },
                            }
                        }
                        const result = exec(allocator, &env_map, test_args.items) catch return parseError(tokenizer, code.source_token, "test failed", .{});
                        const escaped_stderr = try escapeHtml(allocator, result.stderr);
                        const escaped_stdout = try escapeHtml(allocator, result.stdout);
                        try shell_out.print("\n{s}{s}\n", .{ escaped_stderr, escaped_stdout });
                    },
                }

                if (!code.just_check_syntax) {
                    try printShell(out, shell_buffer.items, false);
                }
            },
        }
    }
}

fn exec(allocator: Allocator, env_map: *process.EnvMap, args: []const []const u8) !ChildProcess.ExecResult {
    const result = try ChildProcess.exec(.{
        .allocator = allocator,
        .argv = args,
        .env_map = env_map,
        .max_output_bytes = max_doc_file_size,
    });
    switch (result.term) {
        .Exited => |exit_code| {
            if (exit_code != 0) {
                print("{s}\nThe following command exited with code {}:\n", .{ result.stderr, exit_code });
                dumpArgs(args);
                return error.ChildExitError;
            }
        },
        else => {
            print("{s}\nThe following command crashed:\n", .{result.stderr});
            dumpArgs(args);
            return error.ChildCrashed;
        },
    }
    return result;
}

fn getBuiltinCode(allocator: Allocator, env_map: *process.EnvMap, zig_exe: []const u8) ![]const u8 {
    const result = try exec(allocator, env_map, &[_][]const u8{ zig_exe, "build-obj", "--show-builtin" });
    return result.stdout;
}

fn dumpArgs(args: []const []const u8) void {
    for (args) |arg|
        print("{s} ", .{arg})
    else
        print("\n", .{});
}

test "shell parsed" {
    const test_allocator = std.testing.allocator;

    {
        const shell_out =
            \\$ zig build test.zig
        ;
        const expected =
            \\<figure><figcaption class="shell-cap">Shell</figcaption><pre><samp><span class="line">$ <kbd>zig build test.zig</kbd></span>
            \\</samp></pre></figure>
        ;

        var buffer = std.ArrayList(u8).init(test_allocator);
        defer buffer.deinit();

        try printShell(buffer.writer(), shell_out, false);
        std.log.emerg("{s}", .{buffer.items});
        try testing.expectEqualSlices(u8, expected, buffer.items);
    }
    {
        const shell_out =
            \\$ zig build test.zig
            \\build output
        ;
        const expected =
            \\<figure><figcaption class="shell-cap">Shell</figcaption><pre><samp><span class="line">$ <kbd>zig build test.zig</kbd></span>
            \\<span class="line">build output</span>
            \\</samp></pre></figure>
        ;

        var buffer = std.ArrayList(u8).init(test_allocator);
        defer buffer.deinit();

        try printShell(buffer.writer(), shell_out, false);
        try testing.expectEqualSlices(u8, expected, buffer.items);
    }
    {
        const shell_out =
            \\$ zig build test.zig
            \\build output
            \\$ ./test
        ;
        const expected =
            \\<figure><figcaption class="shell-cap">Shell</figcaption><pre><samp><span class="line">$ <kbd>zig build test.zig</kbd></span>
            \\<span class="line">build output</span>
            \\<span class="line">$ <kbd>./test</kbd></span>
            \\</samp></pre></figure>
        ;

        var buffer = std.ArrayList(u8).init(test_allocator);
        defer buffer.deinit();

        try printShell(buffer.writer(), shell_out, false);
        try testing.expectEqualSlices(u8, expected, buffer.items);
    }
    {
        const shell_out =
            \\$ zig build test.zig
            \\
            \\$ ./test
            \\output
        ;
        const expected =
            \\<figure><figcaption class="shell-cap">Shell</figcaption><pre><samp><span class="line">$ <kbd>zig build test.zig</kbd></span>
            \\<span class="line"></span>
            \\<span class="line">$ <kbd>./test</kbd></span>
            \\<span class="line">output</span>
            \\</samp></pre></figure>
        ;

        var buffer = std.ArrayList(u8).init(test_allocator);
        defer buffer.deinit();

        try printShell(buffer.writer(), shell_out, false);
        try testing.expectEqualSlices(u8, expected, buffer.items);
    }
    {
        const shell_out =
            \\$ zig build test.zig
            \\$ ./test
            \\output
        ;
        const expected =
            \\<figure><figcaption class="shell-cap">Shell</figcaption><pre><samp><span class="line">$ <kbd>zig build test.zig</kbd></span>
            \\<span class="line">$ <kbd>./test</kbd></span>
            \\<span class="line">output</span>
            \\</samp></pre></figure>
        ;

        var buffer = std.ArrayList(u8).init(test_allocator);
        defer buffer.deinit();

        try printShell(buffer.writer(), shell_out, false);
        try testing.expectEqualSlices(u8, expected, buffer.items);
    }
    {
        const shell_out =
            \\$ zig build test.zig \
            \\ --build-option
            \\build output
            \\$ ./test
            \\output
        ;
        const expected =
            \\<figure><figcaption class="shell-cap">Shell</figcaption><pre><samp><span class="line">$ <kbd>zig build test.zig \</span>
            \\<span class="line"> --build-option</kbd></span>
            \\<span class="line">build output</span>
            \\<span class="line">$ <kbd>./test</kbd></span>
            \\<span class="line">output</span>
            \\</samp></pre></figure>
        ;

        var buffer = std.ArrayList(u8).init(test_allocator);
        defer buffer.deinit();

        try printShell(buffer.writer(), shell_out, false);
        try testing.expectEqualSlices(u8, expected, buffer.items);
    }
    {
        // intentional space after "--build-option1 \"
        const shell_out =
            \\$ zig build test.zig \
            \\ --build-option1 \
            \\ --build-option2
            \\$ ./test
        ;
        const expected =
            \\<figure><figcaption class="shell-cap">Shell</figcaption><pre><samp><span class="line">$ <kbd>zig build test.zig \</span>
            \\<span class="line"> --build-option1 \</span>
            \\<span class="line"> --build-option2</kbd></span>
            \\<span class="line">$ <kbd>./test</kbd></span>
            \\</samp></pre></figure>
        ;

        var buffer = std.ArrayList(u8).init(test_allocator);
        defer buffer.deinit();

        try printShell(buffer.writer(), shell_out, false);
        try testing.expectEqualSlices(u8, expected, buffer.items);
    }
    {
        const shell_out =
            \\$ zig build test.zig \
            \\$ ./test
        ;
        const expected =
            \\<figure><figcaption class="shell-cap">Shell</figcaption><pre><samp><span class="line">$ <kbd>zig build test.zig \</span>
            \\<span class="line">$ ./test</kbd></span>
            \\</samp></pre></figure>
        ;

        var buffer = std.ArrayList(u8).init(test_allocator);
        defer buffer.deinit();

        try printShell(buffer.writer(), shell_out, false);
        try testing.expectEqualSlices(u8, expected, buffer.items);
    }
    {
        const shell_out =
            \\$ zig build test.zig
            \\$ ./test
            \\$1
        ;
        const expected =
            \\<figure><figcaption class="shell-cap">Shell</figcaption><pre><samp><span class="line">$ <kbd>zig build test.zig</kbd></span>
            \\<span class="line">$ <kbd>./test</kbd></span>
            \\<span class="line">$1</span>
            \\</samp></pre></figure>
        ;

        var buffer = std.ArrayList(u8).init(test_allocator);
        defer buffer.deinit();

        try printShell(buffer.writer(), shell_out, false);
        try testing.expectEqualSlices(u8, expected, buffer.items);
    }
    {
        const shell_out =
            \\$zig build test.zig
        ;
        const expected =
            \\<figure><figcaption class="shell-cap">Shell</figcaption><pre><samp><span class="line">$zig build test.zig</span>
            \\</samp></pre></figure>
        ;

        var buffer = std.ArrayList(u8).init(test_allocator);
        defer buffer.deinit();

        try printShell(buffer.writer(), shell_out, false);
        try testing.expectEqualSlices(u8, expected, buffer.items);
    }
}
