const std = @import("../std.zig");
const assert = std.debug.assert;

const State = enum {
    Start,
    Backslash,
};

pub const ParseStringLiteralError = error{
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
    const first_index = 1;
    assert(bytes.len != 0 and bytes[bytes.len - 1] == '"');

    var list = std.ArrayList(u8).init(allocator);
    errdefer list.deinit();

    const slice = bytes[first_index..];
    try list.ensureCapacity(slice.len - 1);

    var state = State.Start;
    var index: usize = 0;
    while (index < slice.len) : (index += 1) {
        const b = slice[index];

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
                '\'' => {
                    try list.append('\'');
                    state = State.Start;
                },
                '"' => {
                    try list.append('"');
                    state = State.Start;
                },
                'x' => {
                    const index_continue = index + 3;
                    if (slice.len >= index_continue)
                        if (std.fmt.parseUnsigned(u8, slice[index + 1 .. index_continue], 16)) |char| {
                            try list.append(char);
                            state = State.Start;
                            index = index_continue - 1; // loop-header increments again
                            continue;
                        } else |_| {};

                    bad_index.* = index;
                    return error.InvalidCharacter;
                },
                'u' => {
                    if (slice.len > index + 2 and slice[index + 1] == '{')
                        if (std.mem.indexOfScalarPos(u8, slice[0..std.math.min(index + 9, slice.len)], index + 3, '}')) |index_end| {
                            const hex_str = slice[index + 2 .. index_end];
                            if (std.fmt.parseUnsigned(u32, hex_str, 16)) |uint| {
                                if (uint <= 0x10ffff) {
                                    try list.appendSlice(std.mem.toBytes(uint)[0..]);
                                    state = State.Start;
                                    index = index_end; // loop-header increments
                                    continue;
                                }
                            } else |_| {}
                        };

                    bad_index.* = index;
                    return error.InvalidCharacter;
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
