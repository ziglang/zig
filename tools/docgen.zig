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

const max_doc_file_size = 10 * 1024 * 1024;

const obj_ext = builtin.object_format.fileExt(builtin.cpu.arch);
const tmp_dir_name = "docgen_tmp";

const usage =
    \\Usage: docgen [--zig] [--skip-code-tests] input output"
    \\
    \\   Generates an HTML document from a docgen template.
    \\
    \\Options:
    \\   -h, --help             Print this help and exit
    \\   --skip-code-tests      Skip the doctests
    \\
;

fn fatal(comptime format: []const u8, args: anytype) noreturn {
    const stderr = io.getStdErr().writer();

    stderr.print("error: " ++ format ++ "\n", args) catch {};
    process.exit(1);
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var args_it = try process.argsWithAllocator(allocator);
    if (!args_it.skip()) @panic("expected self arg");

    var zig_exe: []const u8 = "zig";
    var opt_zig_lib_dir: ?[]const u8 = null;
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
                    fatal("expected parameter after --zig", .{});
                }
            } else if (mem.eql(u8, arg, "--zig-lib-dir")) {
                if (args_it.next()) |param| {
                    // Convert relative to absolute because this will be passed
                    // to a child process with a different cwd.
                    opt_zig_lib_dir = try fs.realpathAlloc(allocator, param);
                } else {
                    fatal("expected parameter after --zig-lib-dir", .{});
                }
            } else if (mem.eql(u8, arg, "--skip-code-tests")) {
                do_code_tests = false;
            } else {
                fatal("unrecognized option: '{s}'", .{arg});
            }
        } else {
            if (i > 1) {
                fatal("too many arguments", .{});
            }
            files[i] = arg;
            i += 1;
        }
    }
    if (i < 2) {
        fatal("not enough arguments", .{});
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

    try genHtml(allocator, &tokenizer, &toc, buffered_writer.writer(), zig_exe, opt_zig_lib_dir, do_code_tests);
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
    code_node_count: usize,

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
            .code_node_count = 0,
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

const ExpectedOutcome = enum {
    succeed,
    fail,
    build_fail,
};

const Code = struct {
    id: Id,
    name: []const u8,
    source_token: Token,
    just_check_syntax: bool,
    mode: std.builtin.OptimizeMode,
    link_objects: []const []const u8,
    target_str: ?[]const u8,
    link_libc: bool,
    link_mode: ?std.builtin.LinkMode,
    disable_cache: bool,
    verbose_cimport: bool,
    additional_options: []const []const u8,

    const Id = union(enum) {
        @"test",
        test_error: []const u8,
        test_safety: []const u8,
        exe: ExpectedOutcome,
        obj: ?[]const u8,
        lib,
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
                } else if (mem.eql(u8, tag_name, "code_begin")) {
                    _ = try eatToken(tokenizer, .separator);
                    const code_kind_tok = try eatToken(tokenizer, .tag_content);
                    _ = try eatToken(tokenizer, .separator);
                    const name_tok = try eatToken(tokenizer, .tag_content);
                    const name = tokenizer.buffer[name_tok.start..name_tok.end];
                    var error_str: []const u8 = "";
                    const maybe_sep = tokenizer.next();
                    switch (maybe_sep.id) {
                        .separator => {
                            const error_tok = try eatToken(tokenizer, .tag_content);
                            error_str = tokenizer.buffer[error_tok.start..error_tok.end];
                            _ = try eatToken(tokenizer, .bracket_close);
                        },
                        .bracket_close => {},
                        else => return parseError(tokenizer, token, "invalid token", .{}),
                    }
                    const code_kind_str = tokenizer.buffer[code_kind_tok.start..code_kind_tok.end];
                    var code_kind_id: Code.Id = undefined;
                    var just_check_syntax = false;
                    if (mem.eql(u8, code_kind_str, "exe")) {
                        code_kind_id = Code.Id{ .exe = .succeed };
                    } else if (mem.eql(u8, code_kind_str, "exe_err")) {
                        code_kind_id = Code.Id{ .exe = .fail };
                    } else if (mem.eql(u8, code_kind_str, "exe_build_err")) {
                        code_kind_id = Code.Id{ .exe = .build_fail };
                    } else if (mem.eql(u8, code_kind_str, "test")) {
                        code_kind_id = .@"test";
                    } else if (mem.eql(u8, code_kind_str, "test_err")) {
                        code_kind_id = Code.Id{ .test_error = error_str };
                    } else if (mem.eql(u8, code_kind_str, "test_safety")) {
                        code_kind_id = Code.Id{ .test_safety = error_str };
                    } else if (mem.eql(u8, code_kind_str, "obj")) {
                        code_kind_id = Code.Id{ .obj = null };
                    } else if (mem.eql(u8, code_kind_str, "obj_err")) {
                        code_kind_id = Code.Id{ .obj = error_str };
                    } else if (mem.eql(u8, code_kind_str, "lib")) {
                        code_kind_id = Code.Id.lib;
                    } else if (mem.eql(u8, code_kind_str, "syntax")) {
                        code_kind_id = Code.Id{ .obj = null };
                        just_check_syntax = true;
                    } else {
                        return parseError(tokenizer, code_kind_tok, "unrecognized code kind: {s}", .{code_kind_str});
                    }

                    var mode: std.builtin.OptimizeMode = .Debug;
                    var link_objects = std.ArrayList([]const u8).init(allocator);
                    defer link_objects.deinit();
                    var target_str: ?[]const u8 = null;
                    var link_libc = false;
                    var link_mode: ?std.builtin.LinkMode = null;
                    var disable_cache = false;
                    var verbose_cimport = false;
                    var additional_options = std.ArrayList([]const u8).init(allocator);
                    defer additional_options.deinit();

                    const source_token = while (true) {
                        const content_tok = try eatToken(tokenizer, .content);
                        _ = try eatToken(tokenizer, .bracket_open);
                        const end_code_tag = try eatToken(tokenizer, .tag_content);
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
                            _ = try eatToken(tokenizer, .separator);
                            const obj_tok = try eatToken(tokenizer, .tag_content);
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
                        } else if (mem.eql(u8, end_tag_name, "additonal_option")) {
                            _ = try eatToken(tokenizer, .separator);
                            const option = try eatToken(tokenizer, .tag_content);
                            try additional_options.append(tokenizer.buffer[option.start..option.end]);
                        } else if (mem.eql(u8, end_tag_name, "code_end")) {
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
                            .link_mode = link_mode,
                            .disable_cache = disable_cache,
                            .verbose_cimport = verbose_cimport,
                            .additional_options = try additional_options.toOwnedSlice(),
                        },
                    });
                    tokenizer.code_node_count += 1;
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

fn termColor(allocator: Allocator, input: []const u8) ![]u8 {
    // The SRG sequences generates by the Zig compiler are in the format:
    //   ESC [ <foreground-color> ; <n> m
    // or
    //   ESC [ <n> m
    //
    // where
    //   foreground-color is 31 (red), 32 (green), 36 (cyan)
    //   n is 0 (reset), 1 (bold), 2 (dim)
    //
    //   Note that 37 (white) is currently not used by the compiler.
    //
    // See std.debug.TTY.Color.
    const supported_sgr_colors = [_]u8{ 31, 32, 36 };
    const supported_sgr_numbers = [_]u8{ 0, 1, 2 };

    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();

    var out = buf.writer();
    var sgr_param_start_index: usize = undefined;
    var sgr_num: u8 = undefined;
    var sgr_color: u8 = undefined;
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
                    sgr_param_start_index = i;
                    state = .number;
                },
                else => return error.UnsupportedEscape,
            },
            .number => switch (c) {
                '0'...'9' => {},
                else => {
                    sgr_num = try std.fmt.parseInt(u8, input[sgr_param_start_index..i], 10);
                    sgr_color = 0;
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
                    sgr_param_start_index = i;
                    state = .arg_number;
                },
                else => return error.UnsupportedEscape,
            },
            .arg_number => switch (c) {
                '0'...'9' => {},
                else => {
                    // Keep the sequence consistent, foreground color first.
                    // 32;1m is equivalent to 1;32m, but the latter will
                    // generate an incorrect HTML class without notice.
                    sgr_color = sgr_num;
                    if (!in(&supported_sgr_colors, sgr_color)) return error.UnsupportedForegroundColor;

                    sgr_num = try std.fmt.parseInt(u8, input[sgr_param_start_index..i], 10);
                    if (!in(&supported_sgr_numbers, sgr_num)) return error.UnsupportedNumber;

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
                    if (sgr_num == 0) {
                        if (sgr_color != 0) return error.UnsupportedColor;
                        continue;
                    }
                    if (sgr_color != 0) {
                        try out.print("<span class=\"sgr-{d}_{d}m\">", .{ sgr_color, sgr_num });
                    } else {
                        try out.print("<span class=\"sgr-{d}m\">", .{sgr_num});
                    }
                    open_span_count += 1;
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

// Override this to skip to later tests
const debug_start_line = 0;

fn genHtml(
    allocator: Allocator,
    tokenizer: *Tokenizer,
    toc: *Toc,
    out: anytype,
    zig_exe: []const u8,
    opt_zig_lib_dir: ?[]const u8,
    do_code_tests: bool,
) !void {
    var progress = Progress{ .dont_print_on_dumb = true };
    const root_node = progress.start("Generating docgen examples", toc.nodes.len);
    defer root_node.end();

    var env_map = try process.getEnvMap(allocator);
    try env_map.put("YES_COLOR", "1");

    const host = try std.zig.system.resolveTargetQuery(.{});
    const builtin_code = try getBuiltinCode(allocator, &env_map, zig_exe, opt_zig_lib_dir);

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
                const trimmed_raw_source = mem.trim(u8, raw_source, " \r\n");
                const tmp_source_file_name = try fs.path.join(
                    allocator,
                    &[_][]const u8{ tmp_dir_name, name_plus_ext },
                );
                try fs.cwd().writeFile(tmp_source_file_name, trimmed_raw_source);

                var shell_buffer = std.ArrayList(u8).init(allocator);
                defer shell_buffer.deinit();
                var shell_out = shell_buffer.writer();

                switch (code.id) {
                    .exe => |expected_outcome| code_block: {
                        var build_args = std.ArrayList([]const u8).init(allocator);
                        defer build_args.deinit();
                        try build_args.appendSlice(&[_][]const u8{
                            zig_exe,       "build-exe",
                            "--name",      code.name,
                            "--color",     "on",
                            name_plus_ext,
                        });
                        if (opt_zig_lib_dir) |zig_lib_dir| {
                            try build_args.appendSlice(&.{ "--zig-lib-dir", zig_lib_dir });
                        }

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
                            try build_args.append(name_with_ext);
                            try shell_out.print("{s} ", .{name_with_ext});
                        }
                        if (code.link_libc) {
                            try build_args.append("-lc");
                            try shell_out.print("-lc ", .{});
                        }

                        if (code.target_str) |triple| {
                            try build_args.appendSlice(&[_][]const u8{ "-target", triple });
                            try shell_out.print("-target {s} ", .{triple});
                        }
                        if (code.verbose_cimport) {
                            try build_args.append("--verbose-cimport");
                            try shell_out.print("--verbose-cimport ", .{});
                        }
                        for (code.additional_options) |option| {
                            try build_args.append(option);
                            try shell_out.print("{s} ", .{option});
                        }

                        try shell_out.print("\n", .{});

                        if (expected_outcome == .build_fail) {
                            const result = try ChildProcess.run(.{
                                .allocator = allocator,
                                .argv = build_args.items,
                                .cwd = tmp_dir_name,
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
                        const exec_result = run(allocator, &env_map, tmp_dir_name, build_args.items) catch
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

                        const target_query = try std.Target.Query.parse(.{
                            .arch_os_abi = code.target_str orelse "native",
                        });
                        const target = try std.zig.system.resolveTargetQuery(target_query);

                        const path_to_exe = try std.fmt.allocPrint(allocator, "./{s}{s}", .{
                            code.name, target.exeFileExt(),
                        });
                        const run_args = &[_][]const u8{path_to_exe};

                        var exited_with_signal = false;

                        const result = if (expected_outcome == .fail) blk: {
                            const result = try ChildProcess.run(.{
                                .allocator = allocator,
                                .argv = run_args,
                                .env_map = &env_map,
                                .cwd = tmp_dir_name,
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
                            break :blk run(allocator, &env_map, tmp_dir_name, run_args) catch return parseError(tokenizer, code.source_token, "example crashed", .{});
                        };

                        const escaped_stderr = try escapeHtml(allocator, result.stderr);
                        const escaped_stdout = try escapeHtml(allocator, result.stdout);

                        const colored_stderr = try termColor(allocator, escaped_stderr);
                        const colored_stdout = try termColor(allocator, escaped_stdout);

                        try shell_out.print("$ ./{s}\n{s}{s}", .{ code.name, colored_stdout, colored_stderr });
                        if (exited_with_signal) {
                            try shell_out.print("(process terminated by signal)", .{});
                        }
                        try shell_out.writeAll("\n");
                    },
                    .@"test" => {
                        var test_args = std.ArrayList([]const u8).init(allocator);
                        defer test_args.deinit();

                        try test_args.appendSlice(&[_][]const u8{
                            zig_exe,              "test",
                            tmp_source_file_name,
                        });
                        if (opt_zig_lib_dir) |zig_lib_dir| {
                            try test_args.appendSlice(&.{ "--zig-lib-dir", zig_lib_dir });
                        }
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
                        if (code.target_str) |triple| {
                            try test_args.appendSlice(&[_][]const u8{ "-target", triple });
                            try shell_out.print("-target {s} ", .{triple});

                            const target_query = try std.Target.Query.parse(.{
                                .arch_os_abi = triple,
                            });
                            const target = try std.zig.system.resolveTargetQuery(
                                target_query,
                            );
                            switch (getExternalExecutor(host, &target, .{
                                .link_libc = code.link_libc,
                            })) {
                                .native => {},
                                else => {
                                    try test_args.appendSlice(&[_][]const u8{"--test-no-exec"});
                                    try shell_out.writeAll("--test-no-exec");
                                },
                            }
                        }
                        const result = run(allocator, &env_map, null, test_args.items) catch
                            return parseError(tokenizer, code.source_token, "test failed", .{});
                        const escaped_stderr = try escapeHtml(allocator, result.stderr);
                        const escaped_stdout = try escapeHtml(allocator, result.stdout);
                        try shell_out.print("\n{s}{s}\n", .{ escaped_stderr, escaped_stdout });
                    },
                    .test_error => |error_match| {
                        var test_args = std.ArrayList([]const u8).init(allocator);
                        defer test_args.deinit();

                        try test_args.appendSlice(&[_][]const u8{
                            zig_exe,              "test",
                            "--color",            "on",
                            tmp_source_file_name,
                        });
                        if (opt_zig_lib_dir) |zig_lib_dir| {
                            try test_args.appendSlice(&.{ "--zig-lib-dir", zig_lib_dir });
                        }
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
                        const result = try ChildProcess.run(.{
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
                    .test_safety => |error_match| {
                        var test_args = std.ArrayList([]const u8).init(allocator);
                        defer test_args.deinit();

                        try test_args.appendSlice(&[_][]const u8{
                            zig_exe,              "test",
                            tmp_source_file_name,
                        });
                        if (opt_zig_lib_dir) |zig_lib_dir| {
                            try test_args.appendSlice(&.{ "--zig-lib-dir", zig_lib_dir });
                        }
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

                        const result = try ChildProcess.run(.{
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
                    .obj => |maybe_error_match| {
                        const name_plus_obj_ext = try std.fmt.allocPrint(allocator, "{s}{s}", .{ code.name, obj_ext });
                        var build_args = std.ArrayList([]const u8).init(allocator);
                        defer build_args.deinit();

                        try build_args.appendSlice(&[_][]const u8{
                            zig_exe,              "build-obj",
                            "--color",            "on",
                            "--name",             code.name,
                            tmp_source_file_name,
                            try std.fmt.allocPrint(allocator, "-femit-bin={s}{c}{s}", .{
                                tmp_dir_name, fs.path.sep, name_plus_obj_ext,
                            }),
                        });
                        if (opt_zig_lib_dir) |zig_lib_dir| {
                            try build_args.appendSlice(&.{ "--zig-lib-dir", zig_lib_dir });
                        }

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
                        for (code.additional_options) |option| {
                            try build_args.append(option);
                            try shell_out.print("{s} ", .{option});
                        }

                        if (maybe_error_match) |error_match| {
                            const result = try ChildProcess.run(.{
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
                            _ = run(allocator, &env_map, null, build_args.items) catch return parseError(tokenizer, code.source_token, "example failed to compile", .{});
                        }
                        try shell_out.writeAll("\n");
                    },
                    .lib => {
                        const bin_basename = try std.zig.binNameAlloc(allocator, .{
                            .root_name = code.name,
                            .target = builtin.target,
                            .output_mode = .Lib,
                        });

                        var test_args = std.ArrayList([]const u8).init(allocator);
                        defer test_args.deinit();

                        try test_args.appendSlice(&[_][]const u8{
                            zig_exe,              "build-lib",
                            tmp_source_file_name,
                            try std.fmt.allocPrint(allocator, "-femit-bin={s}{s}{s}", .{
                                tmp_dir_name, fs.path.sep_str, bin_basename,
                            }),
                        });
                        if (opt_zig_lib_dir) |zig_lib_dir| {
                            try test_args.appendSlice(&.{ "--zig-lib-dir", zig_lib_dir });
                        }
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
                        for (code.additional_options) |option| {
                            try test_args.append(option);
                            try shell_out.print("{s} ", .{option});
                        }
                        const result = run(allocator, &env_map, null, test_args.items) catch return parseError(tokenizer, code.source_token, "test failed", .{});
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

fn run(
    allocator: Allocator,
    env_map: *process.EnvMap,
    cwd: ?[]const u8,
    args: []const []const u8,
) !ChildProcess.RunResult {
    const result = try ChildProcess.run(.{
        .allocator = allocator,
        .argv = args,
        .env_map = env_map,
        .cwd = cwd,
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

fn getBuiltinCode(
    allocator: Allocator,
    env_map: *process.EnvMap,
    zig_exe: []const u8,
    opt_zig_lib_dir: ?[]const u8,
) ![]const u8 {
    if (opt_zig_lib_dir) |zig_lib_dir| {
        const result = try run(allocator, env_map, null, &.{
            zig_exe, "build-obj", "--show-builtin", "--zig-lib-dir", zig_lib_dir,
        });
        return result.stdout;
    } else {
        const result = try run(allocator, env_map, null, &.{
            zig_exe, "build-obj", "--show-builtin",
        });
        return result.stdout;
    }
}

fn dumpArgs(args: []const []const u8) void {
    for (args) |arg|
        print("{s} ", .{arg})
    else
        print("\n", .{});
}

test "term supported colors" {
    const test_allocator = testing.allocator;

    {
        const input = "A\x1b[31;1mred\x1b[0mB";
        const expect = "A<span class=\"sgr-31_1m\">red</span>B";

        const result = try termColor(test_allocator, input);
        defer test_allocator.free(result);
        try testing.expectEqualSlices(u8, expect, result);
    }

    {
        const input = "A\x1b[32;1mgreen\x1b[0mB";
        const expect = "A<span class=\"sgr-32_1m\">green</span>B";

        const result = try termColor(test_allocator, input);
        defer test_allocator.free(result);
        try testing.expectEqualSlices(u8, expect, result);
    }

    {
        const input = "A\x1b[36;1mcyan\x1b[0mB";
        const expect = "A<span class=\"sgr-36_1m\">cyan</span>B";

        const result = try termColor(test_allocator, input);
        defer test_allocator.free(result);
        try testing.expectEqualSlices(u8, expect, result);
    }

    {
        const input = "A\x1b[1mbold\x1b[0mB";
        const expect = "A<span class=\"sgr-1m\">bold</span>B";

        const result = try termColor(test_allocator, input);
        defer test_allocator.free(result);
        try testing.expectEqualSlices(u8, expect, result);
    }

    {
        const input = "A\x1b[2mdim\x1b[0mB";
        const expect = "A<span class=\"sgr-2m\">dim</span>B";

        const result = try termColor(test_allocator, input);
        defer test_allocator.free(result);
        try testing.expectEqualSlices(u8, expect, result);
    }
}

test "term output from zig" {
    // Use data generated by https://github.com/perillo/zig-tty-test-data,
    // with zig version 0.11.0-dev.1898+36d47dd19.
    const test_allocator = testing.allocator;

    {
        // 1.1-with-build-progress.out
        const input = "Semantic Analysis [1324] \x1b[25D\x1b[0KLLVM Emit Object... \x1b[20D\x1b[0KLLVM Emit Object... \x1b[20D\x1b[0KLLD Link... \x1b[12D\x1b[0K";
        const expect = "";

        const result = try termColor(test_allocator, input);
        defer test_allocator.free(result);
        try testing.expectEqualSlices(u8, expect, result);
    }

    {
        // 2.1-with-reference-traces.out
        const input = "\x1b[1msrc/2.1-with-reference-traces.zig:3:7: \x1b[31;1merror: \x1b[0m\x1b[1mcannot assign to constant\n\x1b[0m    x += 1;\n    \x1b[32;1m~~^~~~\n\x1b[0m\x1b[0m\x1b[2mreferenced by:\n    main: src/2.1-with-reference-traces.zig:7:5\n    callMain: /usr/local/lib/zig/lib/std/start.zig:607:17\n    remaining reference traces hidden; use '-freference-trace' to see all reference traces\n\n\x1b[0m";
        const expect =
            \\<span class="sgr-1m">src/2.1-with-reference-traces.zig:3:7: </span><span class="sgr-31_1m">error: </span><span class="sgr-1m">cannot assign to constant
            \\</span>    x += 1;
            \\    <span class="sgr-32_1m">~~^~~~
            \\</span><span class="sgr-2m">referenced by:
            \\    main: src/2.1-with-reference-traces.zig:7:5
            \\    callMain: /usr/local/lib/zig/lib/std/start.zig:607:17
            \\    remaining reference traces hidden; use '-freference-trace' to see all reference traces
            \\
            \\</span>
        ;

        const result = try termColor(test_allocator, input);
        defer test_allocator.free(result);
        try testing.expectEqualSlices(u8, expect, result);
    }

    {
        // 2.2-without-reference-traces.out
        const input = "\x1b[1m/usr/local/lib/zig/lib/std/io/fixed_buffer_stream.zig:128:29: \x1b[31;1merror: \x1b[0m\x1b[1minvalid type given to fixedBufferStream\n\x1b[0m                    else => @compileError(\"invalid type given to fixedBufferStream\"),\n                            \x1b[32;1m^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n\x1b[0m\x1b[1m/usr/local/lib/zig/lib/std/io/fixed_buffer_stream.zig:116:66: \x1b[36;1mnote: \x1b[0m\x1b[1mcalled from here\n\x1b[0mpub fn fixedBufferStream(buffer: anytype) FixedBufferStream(Slice(@TypeOf(buffer))) {\n;                                                            \x1b[32;1m~~~~~^~~~~~~~~~~~~~~~~\n\x1b[0m";
        const expect =
            \\<span class="sgr-1m">/usr/local/lib/zig/lib/std/io/fixed_buffer_stream.zig:128:29: </span><span class="sgr-31_1m">error: </span><span class="sgr-1m">invalid type given to fixedBufferStream
            \\</span>                    else => @compileError("invalid type given to fixedBufferStream"),
            \\                            <span class="sgr-32_1m">^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            \\</span><span class="sgr-1m">/usr/local/lib/zig/lib/std/io/fixed_buffer_stream.zig:116:66: </span><span class="sgr-36_1m">note: </span><span class="sgr-1m">called from here
            \\</span>pub fn fixedBufferStream(buffer: anytype) FixedBufferStream(Slice(@TypeOf(buffer))) {
            \\;                                                            <span class="sgr-32_1m">~~~~~^~~~~~~~~~~~~~~~~
            \\</span>
        ;

        const result = try termColor(test_allocator, input);
        defer test_allocator.free(result);
        try testing.expectEqualSlices(u8, expect, result);
    }

    {
        // 2.3-with-notes.out
        const input = "\x1b[1msrc/2.3-with-notes.zig:6:9: \x1b[31;1merror: \x1b[0m\x1b[1mexpected type '*2.3-with-notes.Derp', found '*2.3-with-notes.Wat'\n\x1b[0m    bar(w);\n        \x1b[32;1m^\n\x1b[0m\x1b[1msrc/2.3-with-notes.zig:6:9: \x1b[36;1mnote: \x1b[0m\x1b[1mpointer type child '2.3-with-notes.Wat' cannot cast into pointer type child '2.3-with-notes.Derp'\n\x1b[0m\x1b[1msrc/2.3-with-notes.zig:2:13: \x1b[36;1mnote: \x1b[0m\x1b[1mopaque declared here\n\x1b[0mconst Wat = opaque {};\n            \x1b[32;1m^~~~~~~~~\n\x1b[0m\x1b[1msrc/2.3-with-notes.zig:1:14: \x1b[36;1mnote: \x1b[0m\x1b[1mopaque declared here\n\x1b[0mconst Derp = opaque {};\n             \x1b[32;1m^~~~~~~~~\n\x1b[0m\x1b[1msrc/2.3-with-notes.zig:4:18: \x1b[36;1mnote: \x1b[0m\x1b[1mparameter type declared here\n\x1b[0mextern fn bar(d: *Derp) void;\n                 \x1b[32;1m^~~~~\n\x1b[0m\x1b[0m\x1b[2mreferenced by:\n    main: src/2.3-with-notes.zig:10:5\n    callMain: /usr/local/lib/zig/lib/std/start.zig:607:17\n    remaining reference traces hidden; use '-freference-trace' to see all reference traces\n\n\x1b[0m";
        const expect =
            \\<span class="sgr-1m">src/2.3-with-notes.zig:6:9: </span><span class="sgr-31_1m">error: </span><span class="sgr-1m">expected type '*2.3-with-notes.Derp', found '*2.3-with-notes.Wat'
            \\</span>    bar(w);
            \\        <span class="sgr-32_1m">^
            \\</span><span class="sgr-1m">src/2.3-with-notes.zig:6:9: </span><span class="sgr-36_1m">note: </span><span class="sgr-1m">pointer type child '2.3-with-notes.Wat' cannot cast into pointer type child '2.3-with-notes.Derp'
            \\</span><span class="sgr-1m">src/2.3-with-notes.zig:2:13: </span><span class="sgr-36_1m">note: </span><span class="sgr-1m">opaque declared here
            \\</span>const Wat = opaque {};
            \\            <span class="sgr-32_1m">^~~~~~~~~
            \\</span><span class="sgr-1m">src/2.3-with-notes.zig:1:14: </span><span class="sgr-36_1m">note: </span><span class="sgr-1m">opaque declared here
            \\</span>const Derp = opaque {};
            \\             <span class="sgr-32_1m">^~~~~~~~~
            \\</span><span class="sgr-1m">src/2.3-with-notes.zig:4:18: </span><span class="sgr-36_1m">note: </span><span class="sgr-1m">parameter type declared here
            \\</span>extern fn bar(d: *Derp) void;
            \\                 <span class="sgr-32_1m">^~~~~
            \\</span><span class="sgr-2m">referenced by:
            \\    main: src/2.3-with-notes.zig:10:5
            \\    callMain: /usr/local/lib/zig/lib/std/start.zig:607:17
            \\    remaining reference traces hidden; use '-freference-trace' to see all reference traces
            \\
            \\</span>
        ;

        const result = try termColor(test_allocator, input);
        defer test_allocator.free(result);
        try testing.expectEqualSlices(u8, expect, result);
    }

    {
        // 3.1-with-error-return-traces.out

        const input = "error: Error\n\x1b[1m/home/zig/src/3.1-with-error-return-traces.zig:5:5\x1b[0m: \x1b[2m0x20b008 in callee (3.1-with-error-return-traces)\x1b[0m\n    return error.Error;\n    \x1b[32;1m^\x1b[0m\n\x1b[1m/home/zig/src/3.1-with-error-return-traces.zig:9:5\x1b[0m: \x1b[2m0x20b113 in caller (3.1-with-error-return-traces)\x1b[0m\n    try callee();\n    \x1b[32;1m^\x1b[0m\n\x1b[1m/home/zig/src/3.1-with-error-return-traces.zig:13:5\x1b[0m: \x1b[2m0x20b153 in main (3.1-with-error-return-traces)\x1b[0m\n    try caller();\n    \x1b[32;1m^\x1b[0m\n";
        const expect =
            \\error: Error
            \\<span class="sgr-1m">/home/zig/src/3.1-with-error-return-traces.zig:5:5</span>: <span class="sgr-2m">0x20b008 in callee (3.1-with-error-return-traces)</span>
            \\    return error.Error;
            \\    <span class="sgr-32_1m">^</span>
            \\<span class="sgr-1m">/home/zig/src/3.1-with-error-return-traces.zig:9:5</span>: <span class="sgr-2m">0x20b113 in caller (3.1-with-error-return-traces)</span>
            \\    try callee();
            \\    <span class="sgr-32_1m">^</span>
            \\<span class="sgr-1m">/home/zig/src/3.1-with-error-return-traces.zig:13:5</span>: <span class="sgr-2m">0x20b153 in main (3.1-with-error-return-traces)</span>
            \\    try caller();
            \\    <span class="sgr-32_1m">^</span>
            \\
        ;

        const result = try termColor(test_allocator, input);
        defer test_allocator.free(result);
        try testing.expectEqualSlices(u8, expect, result);
    }

    {
        // 3.2-with-stack-trace.out
        const input = "\x1b[1m/usr/local/lib/zig/lib/std/debug.zig:561:19\x1b[0m: \x1b[2m0x22a107 in writeCurrentStackTrace__anon_5898 (3.2-with-stack-trace)\x1b[0m\n    while (it.next()) |return_address| {\n                  \x1b[32;1m^\x1b[0m\n\x1b[1m/usr/local/lib/zig/lib/std/debug.zig:157:80\x1b[0m: \x1b[2m0x20bb23 in dumpCurrentStackTrace (3.2-with-stack-trace)\x1b[0m\n        writeCurrentStackTrace(stderr, debug_info, detectTTYConfig(io.getStdErr()), start_addr) catch |err| {\n                                                                               \x1b[32;1m^\x1b[0m\n\x1b[1m/home/zig/src/3.2-with-stack-trace.zig:5:36\x1b[0m: \x1b[2m0x20d3b2 in foo (3.2-with-stack-trace)\x1b[0m\n    std.debug.dumpCurrentStackTrace(null);\n                                   \x1b[32;1m^\x1b[0m\n\x1b[1m/home/zig/src/3.2-with-stack-trace.zig:9:8\x1b[0m: \x1b[2m0x20b458 in main (3.2-with-stack-trace)\x1b[0m\n    foo();\n       \x1b[32;1m^\x1b[0m\n\x1b[1m/usr/local/lib/zig/lib/std/start.zig:607:22\x1b[0m: \x1b[2m0x20a965 in posixCallMainAndExit (3.2-with-stack-trace)\x1b[0m\n            root.main();\n                     \x1b[32;1m^\x1b[0m\n\x1b[1m/usr/local/lib/zig/lib/std/start.zig:376:5\x1b[0m: \x1b[2m0x20a411 in _start (3.2-with-stack-trace)\x1b[0m\n    @call(.never_inline, posixCallMainAndExit, .{});\n    \x1b[32;1m^\x1b[0m\n";
        const expect =
            \\<span class="sgr-1m">/usr/local/lib/zig/lib/std/debug.zig:561:19</span>: <span class="sgr-2m">0x22a107 in writeCurrentStackTrace__anon_5898 (3.2-with-stack-trace)</span>
            \\    while (it.next()) |return_address| {
            \\                  <span class="sgr-32_1m">^</span>
            \\<span class="sgr-1m">/usr/local/lib/zig/lib/std/debug.zig:157:80</span>: <span class="sgr-2m">0x20bb23 in dumpCurrentStackTrace (3.2-with-stack-trace)</span>
            \\        writeCurrentStackTrace(stderr, debug_info, detectTTYConfig(io.getStdErr()), start_addr) catch |err| {
            \\                                                                               <span class="sgr-32_1m">^</span>
            \\<span class="sgr-1m">/home/zig/src/3.2-with-stack-trace.zig:5:36</span>: <span class="sgr-2m">0x20d3b2 in foo (3.2-with-stack-trace)</span>
            \\    std.debug.dumpCurrentStackTrace(null);
            \\                                   <span class="sgr-32_1m">^</span>
            \\<span class="sgr-1m">/home/zig/src/3.2-with-stack-trace.zig:9:8</span>: <span class="sgr-2m">0x20b458 in main (3.2-with-stack-trace)</span>
            \\    foo();
            \\       <span class="sgr-32_1m">^</span>
            \\<span class="sgr-1m">/usr/local/lib/zig/lib/std/start.zig:607:22</span>: <span class="sgr-2m">0x20a965 in posixCallMainAndExit (3.2-with-stack-trace)</span>
            \\            root.main();
            \\                     <span class="sgr-32_1m">^</span>
            \\<span class="sgr-1m">/usr/local/lib/zig/lib/std/start.zig:376:5</span>: <span class="sgr-2m">0x20a411 in _start (3.2-with-stack-trace)</span>
            \\    @call(.never_inline, posixCallMainAndExit, .{});
            \\    <span class="sgr-32_1m">^</span>
            \\
        ;

        const result = try termColor(test_allocator, input);
        defer test_allocator.free(result);
        try testing.expectEqualSlices(u8, expect, result);
    }
}

test "printShell" {
    const test_allocator = std.testing.allocator;

    {
        const shell_out =
            \\$ zig build test.zig
        ;
        const expected =
            \\<figure><figcaption class="shell-cap">Shell</figcaption><pre><samp>$ <kbd>zig build test.zig</kbd>
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
        ;
        const expected =
            \\<figure><figcaption class="shell-cap">Shell</figcaption><pre><samp>$ <kbd>zig build test.zig</kbd>
            \\build output
            \\</samp></pre></figure>
        ;

        var buffer = std.ArrayList(u8).init(test_allocator);
        defer buffer.deinit();

        try printShell(buffer.writer(), shell_out, false);
        try testing.expectEqualSlices(u8, expected, buffer.items);
    }
    {
        const shell_out = "$ zig build test.zig\r\nbuild output\r\n";
        const expected =
            \\<figure><figcaption class="shell-cap">Shell</figcaption><pre><samp>$ <kbd>zig build test.zig</kbd>
            \\build output
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
            \\<figure><figcaption class="shell-cap">Shell</figcaption><pre><samp>$ <kbd>zig build test.zig</kbd>
            \\build output
            \\$ <kbd>./test</kbd>
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
            \\<figure><figcaption class="shell-cap">Shell</figcaption><pre><samp>$ <kbd>zig build test.zig</kbd>
            \\
            \\$ <kbd>./test</kbd>
            \\output
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
            \\<figure><figcaption class="shell-cap">Shell</figcaption><pre><samp>$ <kbd>zig build test.zig</kbd>
            \\$ <kbd>./test</kbd>
            \\output
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
            \\<figure><figcaption class="shell-cap">Shell</figcaption><pre><samp>$ <kbd>zig build test.zig \
            \\ --build-option</kbd>
            \\build output
            \\$ <kbd>./test</kbd>
            \\output
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
            \\<figure><figcaption class="shell-cap">Shell</figcaption><pre><samp>$ <kbd>zig build test.zig \
            \\ --build-option1 \
            \\ --build-option2</kbd>
            \\$ <kbd>./test</kbd>
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
            \\<figure><figcaption class="shell-cap">Shell</figcaption><pre><samp>$ <kbd>zig build test.zig \
            \\$ ./test</kbd>
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
            \\<figure><figcaption class="shell-cap">Shell</figcaption><pre><samp>$ <kbd>zig build test.zig</kbd>
            \\$ <kbd>./test</kbd>
            \\$1
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
            \\<figure><figcaption class="shell-cap">Shell</figcaption><pre><samp>$zig build test.zig
            \\</samp></pre></figure>
        ;

        var buffer = std.ArrayList(u8).init(test_allocator);
        defer buffer.deinit();

        try printShell(buffer.writer(), shell_out, false);
        try testing.expectEqualSlices(u8, expected, buffer.items);
    }
}
