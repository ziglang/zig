const std = @import("std");
const builtin = @import("builtin");
const io = std.io;
const fs = std.fs;
const print = std.debug.print;
const mem = std.mem;
const testing = std.testing;
const Allocator = std.mem.Allocator;
const max_doc_file_size = 10 * 1024 * 1024;
const fatal = std.zig.fatal;

pub fn main() !void {
    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    const args = try std.process.argsAlloc(arena);
    const input_file = args[1];
    const output_file = args[2];

    var in_file = try fs.cwd().openFile(input_file, .{ .mode = .read_only });
    defer in_file.close();

    var out_file = try fs.cwd().createFile(output_file, .{});
    defer out_file.close();

    var out_dir = try fs.cwd().openDir(fs.path.dirname(output_file).?, .{});
    defer out_dir.close();

    const input_file_bytes = try in_file.reader().readAllAlloc(arena, std.math.maxInt(u32));

    var buffered_writer = io.bufferedWriter(out_file.writer());

    var tokenizer = Tokenizer.init(input_file, input_file_bytes);

    try walk(arena, &tokenizer, out_dir, buffered_writer.writer());

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

fn walk(arena: Allocator, tokenizer: *Tokenizer, out_dir: std.fs.Dir, w: anytype) !void {
    while (true) {
        const token = tokenizer.next();
        switch (token.id) {
            .eof => break,
            .content,
            => {
                try w.writeAll(tokenizer.buffer[token.start..token.end]);
            },
            .bracket_open => {
                const tag_token = try eatToken(tokenizer, .tag_content);
                const tag_name = tokenizer.buffer[tag_token.start..tag_token.end];

                if (mem.eql(u8, tag_name, "code_begin")) {
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
                    var link_objects = std.ArrayList([]const u8).init(arena);
                    var target_str: ?[]const u8 = null;
                    var link_libc = false;
                    var link_mode: ?std.builtin.LinkMode = null;
                    var disable_cache = false;
                    var verbose_cimport = false;
                    var additional_options = std.ArrayList([]const u8).init(arena);

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
                            link_mode = .dynamic;
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

                    const basename = try std.fmt.allocPrint(arena, "{s}.zig", .{name});

                    var file = out_dir.createFile(basename, .{ .exclusive = true }) catch |err| {
                        fatal("unable to create file '{s}': {s}", .{ name, @errorName(err) });
                    };
                    defer file.close();

                    const source = tokenizer.buffer[source_token.start..source_token.end];
                    try file.writeAll(std.mem.trim(u8, source[1..], " \t\r\n"));
                    try file.writeAll("\n\n");

                    if (just_check_syntax) {
                        try file.writer().print("// syntax\n", .{});
                    } else switch (code_kind_id) {
                        .@"test" => try file.writer().print("// test\n", .{}),
                        .lib => try file.writer().print("// lib\n", .{}),
                        .test_error => |s| try file.writer().print("// test_error={s}\n", .{s}),
                        .test_safety => |s| try file.writer().print("// test_safety={s}\n", .{s}),
                        .exe => |s| try file.writer().print("// exe={s}\n", .{@tagName(s)}),
                        .obj => |opt| if (opt) |s| {
                            try file.writer().print("// obj={s}\n", .{s});
                        } else {
                            try file.writer().print("// obj\n", .{});
                        },
                    }

                    if (mode != .Debug)
                        try file.writer().print("// optimize={s}\n", .{@tagName(mode)});

                    for (link_objects.items) |link_object| {
                        try file.writer().print("// link_object={s}\n", .{link_object});
                    }

                    if (target_str) |s|
                        try file.writer().print("// target={s}\n", .{s});

                    if (link_libc) try file.writer().print("// link_libc\n", .{});
                    if (disable_cache) try file.writer().print("// disable_cache\n", .{});
                    if (verbose_cimport) try file.writer().print("// verbose_cimport\n", .{});

                    if (link_mode) |m|
                        try file.writer().print("// link_mode={s}\n", .{@tagName(m)});

                    for (additional_options.items) |o| {
                        try file.writer().print("// additional_option={s}\n", .{o});
                    }
                    try w.print("{{#code|{s}#}}\n", .{basename});
                } else {
                    const close_bracket = while (true) {
                        const next = tokenizer.next();
                        if (next.id == .bracket_close) break next;
                    };
                    try w.writeAll(tokenizer.buffer[token.start..close_bracket.end]);
                }
            },
            else => return parseError(tokenizer, token, "invalid token", .{}),
        }
    }
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
