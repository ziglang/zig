const std = @import("std");
const mem = std.mem;
const os = std.os;
const Token = std.zig.Token;
const ast = std.zig.ast;
const TokenIndex = std.zig.ast.TokenIndex;

pub const Color = enum {
    Auto,
    Off,
    On,
};

pub const Msg = struct {
    path: []const u8,
    text: []u8,
    first_token: TokenIndex,
    last_token: TokenIndex,
    tree: *ast.Tree,
};

/// `path` must outlive the returned Msg
/// `tree` must outlive the returned Msg
/// Caller owns returned Msg and must free with `allocator`
pub fn createFromParseError(
    allocator: *mem.Allocator,
    parse_error: *const ast.Error,
    tree: *ast.Tree,
    path: []const u8,
) !*Msg {
    const loc_token = parse_error.loc();
    var text_buf = try std.Buffer.initSize(allocator, 0);
    defer text_buf.deinit();

    var out_stream = &std.io.BufferOutStream.init(&text_buf).stream;
    try parse_error.render(&tree.tokens, out_stream);

    const msg = try allocator.create(Msg{
        .tree = tree,
        .path = path,
        .text = text_buf.toOwnedSlice(),
        .first_token = loc_token,
        .last_token = loc_token,
    });
    errdefer allocator.destroy(msg);

    return msg;
}

pub fn printToStream(stream: var, msg: *const Msg, color_on: bool) !void {
    const first_token = msg.tree.tokens.at(msg.first_token);
    const last_token = msg.tree.tokens.at(msg.last_token);
    const start_loc = msg.tree.tokenLocationPtr(0, first_token);
    const end_loc = msg.tree.tokenLocationPtr(first_token.end, last_token);
    if (!color_on) {
        try stream.print(
            "{}:{}:{}: error: {}\n",
            msg.path,
            start_loc.line + 1,
            start_loc.column + 1,
            msg.text,
        );
        return;
    }

    try stream.print(
        "{}:{}:{}: error: {}\n{}\n",
        msg.path,
        start_loc.line + 1,
        start_loc.column + 1,
        msg.text,
        msg.tree.source[start_loc.line_start..start_loc.line_end],
    );
    try stream.writeByteNTimes(' ', start_loc.column);
    try stream.writeByteNTimes('~', last_token.end - first_token.start);
    try stream.write("\n");
}

pub fn printToFile(file: *os.File, msg: *const Msg, color: Color) !void {
    const color_on = switch (color) {
        Color.Auto => file.isTty(),
        Color.On => true,
        Color.Off => false,
    };
    var stream = &std.io.FileOutStream.init(file).stream;
    return printToStream(stream, msg, color_on);
}
