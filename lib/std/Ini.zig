bytes: []const u8,

pub const SectionIterator = struct {
    ini: Ini,
    next_index: ?usize,
    header: []const u8,

    pub fn next(it: *SectionIterator) ?[]const u8 {
        const bytes = it.ini.bytes;
        const start = it.next_index orelse return null;
        const end = mem.indexOfPos(u8, bytes, start, "\n[") orelse bytes.len;
        const result = bytes[start..end];
        if (mem.indexOfPos(u8, bytes, start, it.header)) |next_index| {
            it.next_index = next_index + it.header.len;
        } else {
            it.next_index = null;
        }
        return result;
    }
};

/// Asserts that `header` includes "\n[" at the beginning and "]\n" at the end.
/// `header` must remain valid for the lifetime of the iterator.
pub fn iterateSection(ini: Ini, header: []const u8) SectionIterator {
    assert(mem.startsWith(u8, header, "\n["));
    assert(mem.endsWith(u8, header, "]\n"));
    const first_header = header[1..];
    const next_index = if (mem.indexOf(u8, ini.bytes, first_header)) |i|
        i + first_header.len
    else
        null;
    return .{
        .ini = ini,
        .next_index = next_index,
        .header = header,
    };
}

const std = @import("std.zig");
const mem = std.mem;
const assert = std.debug.assert;
const Ini = @This();
const testing = std.testing;

test iterateSection {
    const example =
        \\[package]
        \\name=libffmpeg
        \\version=5.1.2
        \\
        \\[dependency]
        \\id=libz
        \\url=url1
        \\
        \\[dependency]
        \\id=libmp3lame
        \\url=url2
    ;
    var ini: Ini = .{ .bytes = example };
    var it = ini.iterateSection("\n[dependency]\n");
    const section1 = it.next() orelse return error.TestFailed;
    try testing.expectEqualStrings("id=libz\nurl=url1\n", section1);
    const section2 = it.next() orelse return error.TestFailed;
    try testing.expectEqualStrings("id=libmp3lame\nurl=url2", section2);
    try testing.expect(it.next() == null);
}
