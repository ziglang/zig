const std = @import("../index.zig");
const assert = std.debug.assert;

const State = enum.{
    Start,
    Backslash,
};

pub const ParseStringLiteralError = error.{
    OutOfMemory,

    /// When this is returned, index will be the position of the character.
    InvalidCharacter,
};

/// caller owns returned memory
pub fn parseStringLiteral(
    allocator: *std.mem.Allocator,
    bytes: []const u8,
    bad_index: *usize, // populated if error.InvalidCharacter is returned
) ParseStringLiteralError![]u8 {
    const first_index = if (bytes[0] == 'c') usize(2) else usize(1);
    assert(bytes[bytes.len - 1] == '"');

    var list = std.ArrayList(u8).init(allocator);
    errdefer list.deinit();

    const slice = bytes[first_index..];
    try list.ensureCapacity(slice.len - 1);

    var state = State.Start;
    for (slice) |b, index| {
        switch (state) {
            State.Start => switch (b) {
                '\\' => state = State.Backslash,
                '\n' => {
                    bad_index.* = index;
                    return error.InvalidCharacter;
                },
                '"' => return list.toOwnedSlice(),
                else => try list.append(b),
            },
            State.Backslash => switch (b) {
                'x' => @panic("TODO"),
                'u' => @panic("TODO"),
                'U' => @panic("TODO"),
                'n' => {
                    try list.append('\n');
                    state = State.Start;
                },
                'r' => {
                    try list.append('\r');
                    state = State.Start;
                },
                '\\' => {
                    try list.append('\\');
                    state = State.Start;
                },
                't' => {
                    try list.append('\t');
                    state = State.Start;
                },
                '"' => {
                    try list.append('"');
                    state = State.Start;
                },
                else => {
                    bad_index.* = index;
                    return error.InvalidCharacter;
                },
            },
            else => unreachable,
        }
    }
    unreachable;
}
