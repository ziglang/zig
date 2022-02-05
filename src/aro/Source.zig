const std = @import("std");
const Source = @This();

pub const Id = enum(u32) {
    unused = 0,
    generated = 1,
    _,
};

pub const Location = struct {
    id: Id = .unused,
    byte_offset: u32 = 0,
    line: u32 = 0,

    pub fn eql(a: Location, b: Location) bool {
        return a.id == b.id and a.byte_offset == b.byte_offset and a.line == b.line;
    }
};

path: []const u8,
buf: []const u8,
id: Id,
invalid_utf8_loc: ?Location = null,
/// each entry represents a byte position within `buf` where a backslash+newline was deleted
/// from the original raw buffer. The same position can appear multiple times if multiple
/// consecutive splices happened. Guaranteed to be non-decreasing
splice_locs: []const u32,

/// Todo: binary search instead of scanning entire `splice_locs`.
pub fn numSplicesBefore(source: Source, byte_offset: u32) u32 {
    for (source.splice_locs) |splice_offset, i| {
        if (splice_offset > byte_offset) return @intCast(u32, i);
    }
    return @intCast(u32, source.splice_locs.len);
}

/// Returns the actual line number (before newline splicing) of a Location
/// This corresponds to what the user would actually see in their text editor
pub fn physicalLine(source: Source, loc: Location) u32 {
    return loc.line + source.numSplicesBefore(loc.byte_offset);
}

const LineCol = struct { line: []const u8, line_no: u32, col: u32, width: u32, end_with_splice: bool };

pub fn lineCol(source: Source, loc: Location) LineCol {
    var start: usize = 0;
    // find the start of the line which is either a newline or a splice
    if (std.mem.lastIndexOfScalar(u8, source.buf[0..loc.byte_offset], '\n')) |some| start = some + 1;
    const splice_index = for (source.splice_locs) |splice_offset, i| {
        if (splice_offset > start) {
            if (splice_offset < loc.byte_offset) {
                start = splice_offset;
                break @intCast(u32, i) + 1;
            }
            break @intCast(u32, i);
        }
    } else @intCast(u32, source.splice_locs.len);
    var i: usize = start;
    var col: u32 = 1;
    var width: u32 = 0;

    while (i < loc.byte_offset) : (col += 1) { // TODO this is still incorrect, but better
        const len = std.unicode.utf8ByteSequenceLength(source.buf[i]) catch unreachable;
        const cp = std.unicode.utf8Decode(source.buf[i..][0..len]) catch unreachable;
        width += codepointWidth(cp);
        i += len;
    }

    // find the end of the line which is either a newline, EOF or a splice
    var nl = source.buf.len;
    var end_with_splice = false;
    if (std.mem.indexOfScalar(u8, source.buf[start..], '\n')) |some| nl = some + start;
    if (source.splice_locs.len > splice_index and nl > source.splice_locs[splice_index] and source.splice_locs[splice_index] > start) {
        end_with_splice = true;
        nl = source.splice_locs[splice_index];
    }
    return .{
        .line = source.buf[start..nl],
        .line_no = loc.line + splice_index,
        .col = col,
        .width = width,
        .end_with_splice = end_with_splice,
    };
}

fn codepointWidth(cp: u32) u32 {
    return switch (cp) {
        0x1100...0x115F,
        0x2329,
        0x232A,
        0x2E80...0x303F,
        0x3040...0x3247,
        0x3250...0x4DBF,
        0x4E00...0xA4C6,
        0xA960...0xA97C,
        0xAC00...0xD7A3,
        0xF900...0xFAFF,
        0xFE10...0xFE19,
        0xFE30...0xFE6B,
        0xFF01...0xFF60,
        0xFFE0...0xFFE6,
        0x1B000...0x1B001,
        0x1F200...0x1F251,
        0x20000...0x3FFFD,
        0x1F300...0x1F5FF,
        0x1F900...0x1F9FF,
        => 2,
        else => 1,
    };
}

/// Returns the first offset, if any, in buf where an invalid utf8 sequence
/// is found. Code adapted from std.unicode.utf8ValidateSlice
fn offsetOfInvalidUtf8(buf: []const u8) ?u32 {
    std.debug.assert(buf.len <= std.math.maxInt(u32));
    var i: u32 = 0;
    while (i < buf.len) {
        if (std.unicode.utf8ByteSequenceLength(buf[i])) |cp_len| {
            if (i + cp_len > buf.len) return i;
            if (std.meta.isError(std.unicode.utf8Decode(buf[i .. i + cp_len]))) return i;
            i += cp_len;
        } else |_| return i;
    }
    return null;
}

pub fn checkUtf8(source: *Source) void {
    if (offsetOfInvalidUtf8(source.buf)) |offset| {
        source.invalid_utf8_loc = Location{ .id = source.id, .byte_offset = offset };
    }
}
