path: []const u8,
cpu_arch: ?std.Target.Cpu.Arch = null,
args: std.ArrayListUnmanaged(Elf.SystemLib) = .{},

pub fn deinit(scr: *LdScript, allocator: Allocator) void {
    scr.args.deinit(allocator);
}

pub const Error = error{
    InvalidLdScript,
    UnexpectedToken,
    UnknownCpuArch,
    OutOfMemory,
};

pub fn parse(scr: *LdScript, data: []const u8, elf_file: *Elf) Error!void {
    const comp = elf_file.base.comp;
    const gpa = comp.gpa;
    var tokenizer = Tokenizer{ .source = data };
    var tokens = std.ArrayList(Token).init(gpa);
    defer tokens.deinit();
    var line_col = std.ArrayList(LineColumn).init(gpa);
    defer line_col.deinit();

    var line: usize = 0;
    var prev_line_last_col: usize = 0;

    while (true) {
        const tok = tokenizer.next();
        try tokens.append(tok);
        const column = tok.start - prev_line_last_col;
        try line_col.append(.{ .line = line, .column = column });
        switch (tok.id) {
            .invalid => {
                try elf_file.reportParseError(scr.path, "invalid token in LD script: '{s}' ({d}:{d})", .{
                    std.fmt.fmtSliceEscapeLower(tok.get(data)),
                    line,
                    column,
                });
                return error.InvalidLdScript;
            },
            .new_line => {
                line += 1;
                prev_line_last_col = tok.end;
            },
            .eof => break,
            else => {},
        }
    }

    var it = TokenIterator{ .tokens = tokens.items };
    var parser = Parser{ .source = data, .it = &it };
    var args = std.ArrayList(Elf.SystemLib).init(gpa);
    scr.doParse(.{
        .parser = &parser,
        .args = &args,
    }) catch |err| switch (err) {
        error.UnexpectedToken => {
            const last_token_id = parser.it.pos - 1;
            const last_token = parser.it.get(last_token_id);
            const lcol = line_col.items[last_token_id];
            try elf_file.reportParseError(scr.path, "unexpected token in LD script: {s}: '{s}' ({d}:{d})", .{
                @tagName(last_token.id),
                last_token.get(data),
                lcol.line,
                lcol.column,
            });
            return error.InvalidLdScript;
        },
        else => |e| return e,
    };
    scr.args = args.moveToUnmanaged();
}

fn doParse(scr: *LdScript, ctx: struct {
    parser: *Parser,
    args: *std.ArrayList(Elf.SystemLib),
}) !void {
    while (true) {
        ctx.parser.skipAny(&.{ .comment, .new_line });

        if (ctx.parser.maybe(.command)) |cmd_id| {
            const cmd = ctx.parser.getCommand(cmd_id);
            switch (cmd) {
                .output_format => scr.cpu_arch = try ctx.parser.outputFormat(),
                // TODO we should verify that group only contains libraries
                .input, .group => try ctx.parser.group(ctx.args),
                else => return error.UnexpectedToken,
            }
        } else break;
    }

    if (ctx.parser.it.next()) |tok| switch (tok.id) {
        .eof => {},
        else => return error.UnexpectedToken,
    };
}

const LineColumn = struct {
    line: usize,
    column: usize,
};

const Command = enum {
    output_format,
    input,
    group,
    as_needed,

    fn fromString(s: []const u8) ?Command {
        inline for (@typeInfo(Command).Enum.fields) |field| {
            const upper_name = n: {
                comptime var buf: [field.name.len]u8 = undefined;
                inline for (field.name, 0..) |c, i| {
                    buf[i] = comptime std.ascii.toUpper(c);
                }
                break :n buf;
            };
            if (std.mem.eql(u8, &upper_name, s)) return @field(Command, field.name);
        }
        return null;
    }
};

const Parser = struct {
    source: []const u8,
    it: *TokenIterator,

    fn outputFormat(p: *Parser) !std.Target.Cpu.Arch {
        const value = value: {
            if (p.skip(&.{.lparen})) {
                const value_id = try p.require(.literal);
                const value = p.it.get(value_id);
                _ = try p.require(.rparen);
                break :value value.get(p.source);
            } else if (p.skip(&.{ .new_line, .lbrace })) {
                const value_id = try p.require(.literal);
                const value = p.it.get(value_id);
                _ = p.skip(&.{.new_line});
                _ = try p.require(.rbrace);
                break :value value.get(p.source);
            } else return error.UnexpectedToken;
        };
        if (std.mem.eql(u8, value, "elf64-x86-64")) return .x86_64;
        if (std.mem.eql(u8, value, "elf64-littleaarch64")) return .aarch64;
        return error.UnknownCpuArch;
    }

    fn group(p: *Parser, args: *std.ArrayList(Elf.SystemLib)) !void {
        if (!p.skip(&.{.lparen})) return error.UnexpectedToken;

        while (true) {
            if (p.maybe(.literal)) |tok_id| {
                const tok = p.it.get(tok_id);
                const path = tok.get(p.source);
                try args.append(.{ .path = path, .needed = true });
            } else if (p.maybe(.command)) |cmd_id| {
                const cmd = p.getCommand(cmd_id);
                switch (cmd) {
                    .as_needed => try p.asNeeded(args),
                    else => return error.UnexpectedToken,
                }
            } else break;
        }

        _ = try p.require(.rparen);
    }

    fn asNeeded(p: *Parser, args: *std.ArrayList(Elf.SystemLib)) !void {
        if (!p.skip(&.{.lparen})) return error.UnexpectedToken;

        while (p.maybe(.literal)) |tok_id| {
            const tok = p.it.get(tok_id);
            const path = tok.get(p.source);
            try args.append(.{ .path = path, .needed = false });
        }

        _ = try p.require(.rparen);
    }

    fn skip(p: *Parser, comptime ids: []const Token.Id) bool {
        const pos = p.it.pos;
        inline for (ids) |id| {
            const tok = p.it.next() orelse return false;
            if (tok.id != id) {
                p.it.seekTo(pos);
                return false;
            }
        }
        return true;
    }

    fn skipAny(p: *Parser, comptime ids: []const Token.Id) void {
        outer: while (p.it.next()) |tok| {
            inline for (ids) |id| {
                if (id == tok.id) continue :outer;
            }
            break p.it.seekBy(-1);
        }
    }

    fn maybe(p: *Parser, comptime id: Token.Id) ?Token.Index {
        const pos = p.it.pos;
        const tok = p.it.next() orelse return null;
        if (tok.id == id) return pos;
        p.it.seekBy(-1);
        return null;
    }

    fn require(p: *Parser, comptime id: Token.Id) !Token.Index {
        return p.maybe(id) orelse return error.UnexpectedToken;
    }

    fn getCommand(p: *Parser, index: Token.Index) Command {
        const tok = p.it.get(index);
        assert(tok.id == .command);
        return Command.fromString(tok.get(p.source)).?;
    }
};

const Token = struct {
    id: Id,
    start: usize,
    end: usize,

    const Id = enum {
        // zig fmt: off
        eof,
        invalid,

        new_line,
        lparen,    // (
        rparen,    // )
        lbrace,    // {
        rbrace,    // }

        comment,   // /* */

        command,   // literal with special meaning, see Command
        literal,
        // zig fmt: on
    };

    const Index = usize;

    inline fn get(tok: Token, source: []const u8) []const u8 {
        return source[tok.start..tok.end];
    }
};

const Tokenizer = struct {
    source: []const u8,
    index: usize = 0,

    fn matchesPattern(comptime pattern: []const u8, slice: []const u8) bool {
        comptime var count: usize = 0;
        inline while (count < pattern.len) : (count += 1) {
            if (count >= slice.len) return false;
            const c = slice[count];
            if (pattern[count] != c) return false;
        }
        return true;
    }

    fn matches(tok: Tokenizer, comptime pattern: []const u8) bool {
        return matchesPattern(pattern, tok.source[tok.index..]);
    }

    fn isCommand(tok: Tokenizer, start: usize, end: usize) bool {
        return if (Command.fromString(tok.source[start..end]) == null) false else true;
    }

    fn next(tok: *Tokenizer) Token {
        var result = Token{
            .id = .eof,
            .start = tok.index,
            .end = undefined,
        };

        var state: enum {
            start,
            comment,
            literal,
        } = .start;

        while (tok.index < tok.source.len) : (tok.index += 1) {
            const c = tok.source[tok.index];
            switch (state) {
                .start => switch (c) {
                    ' ', '\t' => result.start += 1,

                    '\n' => {
                        result.id = .new_line;
                        tok.index += 1;
                        break;
                    },

                    '\r' => {
                        if (tok.matches("\r\n")) {
                            result.id = .new_line;
                            tok.index += "\r\n".len;
                        } else {
                            result.id = .invalid;
                            tok.index += 1;
                        }
                        break;
                    },

                    '/' => if (tok.matches("/*")) {
                        state = .comment;
                        tok.index += "/*".len;
                    } else {
                        state = .literal;
                    },

                    '(' => {
                        result.id = .lparen;
                        tok.index += 1;
                        break;
                    },

                    ')' => {
                        result.id = .rparen;
                        tok.index += 1;
                        break;
                    },

                    '{' => {
                        result.id = .lbrace;
                        tok.index += 1;
                        break;
                    },

                    '}' => {
                        result.id = .rbrace;
                        tok.index += 1;
                        break;
                    },

                    else => state = .literal,
                },

                .comment => switch (c) {
                    '*' => if (tok.matches("*/")) {
                        result.id = .comment;
                        tok.index += "*/".len;
                        break;
                    },
                    else => {},
                },

                .literal => switch (c) {
                    ' ', '(', '\n' => {
                        if (tok.isCommand(result.start, tok.index)) {
                            result.id = .command;
                        } else {
                            result.id = .literal;
                        }
                        break;
                    },

                    ')' => {
                        result.id = .literal;
                        break;
                    },

                    '\r' => {
                        if (tok.matches("\r\n")) {
                            if (tok.isCommand(result.start, tok.index)) {
                                result.id = .command;
                            } else {
                                result.id = .literal;
                            }
                        } else {
                            result.id = .invalid;
                            tok.index += 1;
                        }
                        break;
                    },

                    else => {},
                },
            }
        }

        result.end = tok.index;
        return result;
    }
};

const TokenIterator = struct {
    tokens: []const Token,
    pos: Token.Index = 0,

    fn next(it: *TokenIterator) ?Token {
        const token = it.peek() orelse return null;
        it.pos += 1;
        return token;
    }

    fn peek(it: TokenIterator) ?Token {
        if (it.pos >= it.tokens.len) return null;
        return it.tokens[it.pos];
    }

    inline fn reset(it: *TokenIterator) void {
        it.pos = 0;
    }

    inline fn seekTo(it: *TokenIterator, pos: Token.Index) void {
        it.pos = pos;
    }

    fn seekBy(it: *TokenIterator, offset: isize) void {
        const new_pos = @as(isize, @bitCast(it.pos)) + offset;
        if (new_pos < 0) {
            it.pos = 0;
        } else {
            it.pos = @as(usize, @intCast(new_pos));
        }
    }

    inline fn get(it: *TokenIterator, pos: Token.Index) Token {
        assert(pos < it.tokens.len);
        return it.tokens[pos];
    }
};

const LdScript = @This();

const std = @import("std");
const assert = std.debug.assert;

const Allocator = std.mem.Allocator;
const Elf = @import("../Elf.zig");
