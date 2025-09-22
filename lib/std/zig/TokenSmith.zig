//! Generates a list of tokens and a valid corresponding source.
//! Smithed intertoken content is a non-goal of this.

const std = @import("../std.zig");
const Smith = std.testing.Smith;
const Token = std.zig.Token;
const TokenList = std.zig.Ast.TokenList;
const TokenSmith = @This();

source_buf: [4096]u8,
source_len: u32,
tag_buf: [512]Token.Tag,
start_buf: [512]std.zig.Ast.ByteOffset,
tags_len: u16,

fn symbolLenWeights(t: *TokenSmith, min: u32, reserve: u32) [2]Smith.Weight {
    @disableInstrumentation();
    const space = @as(u32, t.source_buf.len - 1) - t.source_len - reserve;
    std.debug.assert(space >= 15);
    return .{
        .rangeAtMost(u32, min, space, 1),
        .rangeAtMost(u32, min, 15, space),
    };
}

pub fn gen(smith: *Smith) TokenSmith {
    @disableInstrumentation();
    var t: TokenSmith = .{
        .source_buf = undefined,
        .source_len = 0,
        .tag_buf = undefined,
        .start_buf = undefined,
        .tags_len = 0,
    };

    const max_lexeme_len = comptime max: {
        var max: usize = 0;
        for (std.meta.tags(Token.Tag)) |tag| {
            max = @max(max, if (tag.lexeme()) |s| s.len else 0);
        }
        break :max max;
    } + 1; // + space
    const symbol_reserved = 15 + 4; // 4 = doc comment: "///\n"
    const max_output_bytes = @max(symbol_reserved, max_lexeme_len);

    while (t.tags_len + 2 < t.tag_buf.len - 1 and
        t.source_len + max_output_bytes < t.source_buf.len - 1 and
        !smith.eosWeightedSimple(7, 1))
    {
        const tag = smith.value(Token.Tag);
        if (tag == .eof) continue;
        t.tag_buf[t.tags_len] = tag;
        t.start_buf[t.tags_len] = t.source_len;
        t.tags_len += 1;

        if (tag.lexeme()) |lexeme| {
            @memcpy(t.source_buf[t.source_len..][0..lexeme.len], lexeme);
            t.source_len += @intCast(lexeme.len);

            if (tag == .invalid_periodasterisks) {
                t.tag_buf[t.tags_len] = .asterisk;
                t.start_buf[t.tags_len] = t.source_len - 1;
                t.tags_len += 1;
            }

            t.source_buf[t.source_len] = '\n';
            t.source_len += 1;
        } else sw: switch (tag) {
            .invalid => {
                // While their are multiple ways invalid may be hit,
                // it is unlikely the source will be inspected.
                t.source_buf[t.source_len] = 0;
                t.source_len += 1;
            },
            .identifier => {
                const start = smith.valueWeighted(u8, &.{
                    .rangeAtMost(u8, 'a', 'z', 1),
                    .rangeAtMost(u8, '@', 'Z', 1), // @, A...Z
                    .value(u8, '_', 1),
                });
                t.source_buf[t.source_len] = start;
                t.source_len += 1;
                if (start == '@') continue :sw .string_literal;

                const len_weights = t.symbolLenWeights(0, 1);
                const len = smith.sliceWeighted(
                    t.source_buf[t.source_len..],
                    &len_weights,
                    &.{
                        .rangeAtMost(u8, 'a', 'z', 1),
                        .rangeAtMost(u8, 'A', 'Z', 1),
                        .rangeAtMost(u8, '0', '9', 1),
                        .value(u8, '_', 1),
                    },
                );
                if (Token.getKeyword(t.source_buf[t.source_len - 1 ..][0 .. len + 1]) != null) {
                    t.source_buf[t.source_len - 1] = '_';
                }
                t.source_len += len;

                t.source_buf[t.source_len] = '\n';
                t.source_len += 1;
            },
            .char_literal, .string_literal => |kind| {
                const end: u8 = switch (kind) {
                    .char_literal => '\'',
                    .string_literal => '"',
                    else => unreachable,
                };

                t.source_buf[t.source_len] = end;
                t.source_len += 1;

                const len_weights = t.symbolLenWeights(0, 2);
                const len = smith.sliceWeighted(
                    t.source_buf[t.source_len..],
                    &len_weights,
                    &.{
                        .rangeAtMost(u8, 0x20, 0x7e, 1),
                        .value(u8, '\\', 15),
                    },
                );
                var start_escape = false;
                for (t.source_buf[t.source_len..][0..len]) |*c| {
                    if (!start_escape and c.* == end) c.* = ' ';
                    start_escape = !start_escape and c.* == '\\';
                }
                if (start_escape) t.source_buf[t.source_len..][len - 1] = ' ';
                t.source_len += len;

                t.source_buf[t.source_len] = end;
                t.source_buf[t.source_len + 1] = '\n';
                t.source_len += 2;
            },
            .multiline_string_literal_line => {
                t.source_buf[t.source_len..][0..2].* = @splat('\\');
                t.source_len += 2;

                const len_weights = t.symbolLenWeights(0, 1);
                t.source_len += smith.sliceWeighted(
                    t.source_buf[t.source_len..],
                    &len_weights,
                    &.{.rangeAtMost(u8, 0x20, 0x7e, 1)},
                );

                t.source_buf[t.source_len] = '\n';
                t.source_len += 1;
            },
            .number_literal => {
                t.source_buf[t.source_len] = smith.valueRangeAtMost(u8, '0', '9');
                t.source_len += 1;

                const len_weights = t.symbolLenWeights(0, 1);
                const len = smith.sliceWeighted(
                    t.source_buf[t.source_len..],
                    &len_weights,
                    &.{
                        .rangeAtMost(u8, '0', '9', 8),
                        .rangeAtMost(u8, 'a', 'z', 1),
                        .rangeAtMost(u8, 'A', 'Z', 1),
                        .value(u8, '+', 1),
                        .rangeAtMost(u8, '-', '.', 1), // -, .
                    },
                );

                var no_period = false;
                var not_exponent = true;
                for (t.source_buf[t.source_len..][0..len], 0..) |*c, i| {
                    const invalid_period = no_period and c.* == '.' or i + 1 == len;
                    const is_exponent = c.* == '-' or c.* == '+';
                    const invalid_exponent = not_exponent and is_exponent;
                    const valid_exponent = !not_exponent and is_exponent;
                    if (invalid_period or invalid_exponent) c.* = '0';
                    no_period |= c.* == '.' or valid_exponent;
                    not_exponent = switch (c.*) {
                        'e', 'E', 'p', 'P' => false,
                        else => true,
                    };
                }

                t.source_len += len;
                t.source_buf[t.source_len] = '\n';
                t.source_len += 1;
            },
            .builtin => {
                t.source_buf[t.source_len] = '@';
                t.source_len += 1;

                const len_weights = t.symbolLenWeights(1, 1);
                const len = smith.sliceWeighted(
                    t.source_buf[t.source_len..],
                    &len_weights,
                    &.{
                        .rangeAtMost(u8, 'a', 'z', 1),
                        .rangeAtMost(u8, 'A', 'Z', 1),
                        .rangeAtMost(u8, '0', '9', 1),
                        .value(u8, '_', 1),
                    },
                );
                if (t.source_buf[t.source_len] >= '0' and t.source_buf[t.source_len] <= '9') {
                    t.source_buf[t.source_len] = '_';
                }
                t.source_len += len;

                t.source_buf[t.source_len] = '\n';
                t.source_len += 1;
            },
            .doc_comment, .container_doc_comment => |kind| {
                t.source_buf[t.source_len..][0..2].* = "//".*;
                t.source_buf[t.source_len..][2] = switch (kind) {
                    .doc_comment => '/',
                    .container_doc_comment => '!',
                    else => unreachable,
                };
                t.source_len += 3;

                const len_weights = t.symbolLenWeights(0, 1);
                const len = smith.sliceWeighted(
                    t.source_buf[t.source_len..],
                    &len_weights,
                    &.{
                        .rangeAtMost(u8, 0x20, 0x7e, 1),
                        .rangeAtMost(u8, 0x80, 0xff, 1),
                    },
                );
                if (kind == .doc_comment and len != 0 and t.source_buf[t.source_len] == '/') {
                    t.source_buf[t.source_len] = ' ';
                }
                t.source_len += len;

                t.source_buf[t.source_len] = '\n';
                t.source_len += 1;
            },
            else => unreachable,
        }
    }

    t.tag_buf[t.tags_len] = .eof;
    t.start_buf[t.tags_len] = t.source_len;
    t.tags_len += 1;
    t.source_buf[t.source_len] = 0;
    return t;
}

pub fn source(t: *TokenSmith) [:0]u8 {
    return t.source_buf[0..t.source_len :0];
}

/// The Slice is not backed by a MultiArrayList, so calling deinit or toMultiArrayList is illegal.
pub fn list(t: *TokenSmith) TokenList.Slice {
    var slice: TokenList.Slice = .{
        .ptrs = undefined,
        .len = t.tags_len,
        .capacity = t.tags_len,
    };
    comptime std.debug.assert(slice.ptrs.len == 2);
    slice.ptrs[@intFromEnum(TokenList.Field.tag)] = @ptrCast(&t.tag_buf);
    slice.ptrs[@intFromEnum(TokenList.Field.start)] = @ptrCast(&t.start_buf);
    return slice;
}

test TokenSmith {
    try std.testing.fuzz({}, checkSource, .{});
}

fn checkSource(_: void, smith: *Smith) !void {
    var t: TokenSmith = .gen(smith);
    try std.testing.expectEqual(Token.Tag.eof, t.tag_buf[t.tags_len - 1]);

    var tokenizer: std.zig.Tokenizer = .init(t.source());
    for (t.tag_buf[0..t.tags_len], t.start_buf[0..t.tags_len]) |tag, start| {
        const tok = tokenizer.next();
        try std.testing.expectEqual(tok.tag, tag);
        try std.testing.expectEqual(tok.loc.start, start);
        if (tag == .invalid) break;
    }
}
