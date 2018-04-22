const std = @import("../index.zig");
const debug = std.debug;
const mem = std.mem;
const assert = debug.assert;

pub const utf8 = @import("utf8.zig");
pub const ascii = @import("ascii.zig");
pub const utils = @import("string_utils.zig");

/// Returns a hash for a string
pub fn hashStr(k: []const u8) u32 {
    // FNV 32-bit hash
    var h: u32 = 2166136261;
    for (k) |b| {
        h = (h ^ b) *% 16777619;
    }
    return h;
}

/// Returns if two strings are equal.
/// Note: just maps to mem.eql, this is mainly
///       for use in structures like in buf_map.
pub fn strEql(a: []const u8, b: []const u8)bool {
    return mem.eql(u8, a, b);
}

const AsciiSplitIt = utils.SplitIt(ascii.View, ascii.Iterator, u8, u8);

/// Splits a string (ascii set).
/// It will split it at ANY of the split bytes.
/// i.e. splitting at "\n " means '\n' AND/OR ' '.
pub fn asciiSplit(a: []const u8, splitBytes: []const u8) !AsciiSplitIt {
    return try AsciiSplitIt.init(a, splitBytes);
}

const Utf8SplitIt = utils.SplitIt(utf8.View, utf8.Iterator, u8, u32);

/// Splits a string (utf8 set).
/// It will split it at ANY of the split bytes.
/// i.e. splitting at "\n " means '\n' AND/OR ' '.
pub fn utf8Split(a: []const u8, splitBytes: []const u8) !Utf8SplitIt {
    return try Utf8SplitIt.init(a, splitBytes);
}

fn calculateLength(comptime BaseType: type,  sep: []const BaseType, views: [][]const BaseType, strings: ...) usize {
    var totalLength: usize = 0;
    comptime var string_i = 0;
    inline while (string_i < strings.len) : (string_i += 1) {
        const arg = ([]const BaseType)(strings[string_i]);
        totalLength += arg.len;
        if (string_i < strings.len - 1 and (arg.len < sep.len or !mem.eql(BaseType, arg[arg.len - sep.len..], sep))) {
            totalLength += sep.len;
        }
        views[string_i] = arg;
    }
    return totalLength;
}

/// Joins strings together with a seperator.
/// Error: The allocator could fail.
pub fn join(comptime BaseType: type, allocator: &mem.Allocator, sep: []const BaseType, strings: ...) ![]BaseType {
    var views: [strings.len][]const u8 = undefined;
    const totalLength = calculateLength(BaseType, sep, views[0..], strings);
    const buf = try allocator.alloc(BaseType, totalLength);
    return utils.joinViewsBuffer(BaseType, sep, views[0..], totalLength, buf);
}

/// Similar version as join but uses a buffer instead of an allocator.
pub fn joinBuffer(comptime BaseType: type,  buffer: []BaseType, sep: []const BaseType, strings: ...) []BaseType {
    var views: [strings.len][]const u8 = undefined;
    const totalLength = calculateLength(BaseType, sep, views[0..], strings);
    return utils.joinViewsBuffer(BaseType, sep, views[0..], totalLength, buffer);
}

pub fn joinCharSep(comptime BaseType: type, allocator: &mem.Allocator, sep: BaseType, strings: ...) ![]BaseType {
    return join(BaseType, allocator, []BaseType{ sep }, strings);
}

pub fn joinBufferCharSep(comptime BaseType: type, buffer: []BaseType, sep: BaseType, strings: ...) ![]BaseType {
    return joinBuffer(BaseType, buffer, []BaseType{ sep }, strings);
}

/// To choose what sides.
pub const Side = enum { LEFT = 1, RIGHT = 2, BOTH = 3, };

/// Trim an ascii string from either/both sides.
pub fn asciiTrim(string: []const u8, trimChars: []const u8, side: Side)[]const u8 {
    return utils.trim(ascii.View, u8, &ascii.View.initUnchecked(string), &ascii.View.initUnchecked(trimChars), side);
}

/// Trim an utf8 string from either/both sides.
pub fn utf8Trim(string: []const u8, trimChars: []const u8, side: Side)[]const u8 {
    return utils.trim(utf8.View, u8, &utf8.View.initUnchecked(string), &utf8.View.initUnchecked(trimChars), side);
}

test "string.ascii.joinBuffer" {
    var buf: [100]u8 = undefined;
    assert(mem.eql(u8, joinBuffer(u8, buf[0..], ", ", "a", "߶", "۩", "°"), "a, ߶, ۩, °"));
    assert(mem.eql(u8, joinBuffer(u8, buf[0..], ",", "۩"), "۩"));
}

test "string.utf8.joinBuffer" {
    var buf: [100]u8 = undefined;
    assert(mem.eql(u8, joinBuffer(u8, buf[0..], ", ", "a", "b", "c"), "a, b, c"));
    assert(mem.eql(u8, joinBuffer(u8, buf[0..], ",", "a"), "a"));
}

test "string.ascii.trim" {
    // Copied from mem.trim
    assert(mem.eql(u8, asciiTrim(" foo\n ", " \n", Side.BOTH), "foo"));
    assert(mem.eql(u8, asciiTrim("foo", " \n", Side.BOTH), "foo"));
    assert(mem.eql(u8, asciiTrim(" foo ", " ", Side.LEFT), "foo "));
}

test "string.split.ascii" {
    var it = try asciiSplit("   abc def   ghi k ", " ");
    assert(mem.eql(u8, ?? it.nextBytes(), "abc"));
    assert(mem.eql(u8, ?? it.nextBytes(), "def"));
    assert(mem.eql(u8, ?? it.restBytes(), "ghi k "));
    assert(mem.eql(u8, ?? it.nextBytes(), "ghi"));
    assert(mem.eql(u8, ?? it.nextBytes(), "k"));
    assert(it.nextBytes() == null);
}

test "string.split.unicode" {
    var it = try utf8Split("   abc ۩   g߶hi  ", " ");
    assert(mem.eql(u8, ?? it.nextBytes(), "abc"));
    assert(mem.eql(u8, ?? it.nextBytes(), "۩"));
    assert(mem.eql(u8, ?? it.restBytes(), "g߶hi  "));
    assert(mem.eql(u8, ?? it.nextBytes(), "g߶hi"));
    assert(it.nextBytes() == null);
}

test "Strings" {
    _ = @import("utf8.zig");
    _ = @import("ascii.zig");
}