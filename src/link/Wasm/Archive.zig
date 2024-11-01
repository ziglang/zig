/// A list of long file names, delimited by a LF character (0x0a).
/// This is stored as a single slice of bytes, as the header-names
/// point to the character index of a file name, rather than the index
/// in the list.
long_file_names: []const u8,

/// Parsed table of contents.
/// Each symbol name points to a list of all definition
/// sites within the current static archive.
toc: Toc,

const Toc = std.StringArrayHashMapUnmanaged(std.ArrayListUnmanaged(u32));

// Archive files start with the ARMAG identifying string.  Then follows a
// `struct Header', and as many bytes of member file data as its `size'
// member indicates, for each member file.
/// String that begins an archive file.
const ARMAG: *const [SARMAG:0]u8 = "!<arch>\n";
/// Size of that string.
const SARMAG: u4 = 8;

/// String in fmag at the end of each header.
const ARFMAG: *const [2:0]u8 = "`\n";

const Header = extern struct {
    /// Member file name, sometimes / terminated.
    name: [16]u8,
    /// File date, decimal seconds since Epoch.
    date: [12]u8,
    /// User ID, in ASCII format.
    uid: [6]u8,
    /// Group ID, in ASCII format.
    gid: [6]u8,
    /// File mode, in ASCII octal.
    mode: [8]u8,
    /// File size, in ASCII decimal.
    size: [10]u8,
    /// Always contains ARFMAG.
    fmag: [2]u8,

    const NameOrIndex = union(enum) {
        name: []const u8,
        index: u32,
    };

    fn nameOrIndex(archive: Header) !NameOrIndex {
        const value = getValue(&archive.name);
        const slash_index = mem.indexOfScalar(u8, value, '/') orelse return error.MalformedArchive;
        const len = value.len;
        if (slash_index == len - 1) {
            // Name stored directly
            return .{ .name = value };
        } else {
            // Name follows the header directly and its length is encoded in
            // the name field.
            const index = try std.fmt.parseInt(u32, value[slash_index + 1 ..], 10);
            return .{ .index = index };
        }
    }

    fn parsedSize(archive: Header) !u32 {
        const value = getValue(&archive.size);
        return std.fmt.parseInt(u32, value, 10);
    }

    fn getValue(raw: []const u8) []const u8 {
        return mem.trimRight(u8, raw, &[_]u8{@as(u8, 0x20)});
    }
};

pub fn deinit(archive: *Archive, gpa: Allocator) void {
    deinitToc(gpa, &archive.toc);
    gpa.free(archive.long_file_names);
    archive.* = undefined;
}

fn deinitToc(gpa: Allocator, toc: *Toc) void {
    for (toc.keys()) |key| gpa.free(key);
    for (toc.values()) |*value| value.deinit(gpa);
    toc.deinit(gpa);
}

pub fn parse(gpa: Allocator, file_contents: []const u8) !Archive {
    var fbs = std.io.fixedBufferStream(file_contents);
    const reader = fbs.reader();

    const magic = try reader.readBytesNoEof(SARMAG);
    if (!mem.eql(u8, &magic, ARMAG)) return error.BadArchiveMagic;

    const header = try reader.readStruct(Header);
    if (!mem.eql(u8, &header.fmag, ARFMAG)) return error.BadHeaderDelimiter;

    var toc = try parseTableOfContents(gpa, header, reader);
    errdefer deinitToc(gpa, &toc);

    const long_file_names = try parseNameTable(gpa, reader);
    errdefer gpa.free(long_file_names);

    return .{
        .toc = toc,
        .long_file_names = long_file_names,
    };
}

fn parseName(archive: *const Archive, header: Header) ![]const u8 {
    const name_or_index = try header.nameOrIndex();
    switch (name_or_index) {
        .name => |name| return name,
        .index => |index| {
            const name = mem.sliceTo(archive.long_file_names[index..], 0x0a);
            return mem.trimRight(u8, name, "/");
        },
    }
}

fn parseTableOfContents(gpa: Allocator, header: Header, reader: anytype) !Toc {
    // size field can have extra spaces padded in front as well as the end,
    // so we trim those first before parsing the ASCII value.
    const size_trimmed = mem.trim(u8, &header.size, " ");
    const sym_tab_size = try std.fmt.parseInt(u32, size_trimmed, 10);

    const num_symbols = try reader.readInt(u32, .big);
    const symbol_positions = try gpa.alloc(u32, num_symbols);
    defer gpa.free(symbol_positions);
    for (symbol_positions) |*index| {
        index.* = try reader.readInt(u32, .big);
    }

    const sym_tab = try gpa.alloc(u8, sym_tab_size - 4 - (4 * num_symbols));
    defer gpa.free(sym_tab);

    reader.readNoEof(sym_tab) catch return error.IncompleteSymbolTable;

    var toc: Toc = .empty;
    errdefer deinitToc(gpa, &toc);

    var i: usize = 0;
    var pos: usize = 0;
    while (i < num_symbols) : (i += 1) {
        const string = mem.sliceTo(sym_tab[pos..], 0);
        pos += string.len + 1;
        if (string.len == 0) continue;

        const name = try gpa.dupe(u8, string);
        errdefer gpa.free(name);
        const gop = try toc.getOrPut(gpa, name);
        if (gop.found_existing) {
            gpa.free(name);
        } else {
            gop.value_ptr.* = .{};
        }
        try gop.value_ptr.append(gpa, symbol_positions[i]);
    }

    return toc;
}

fn parseNameTable(gpa: Allocator, reader: anytype) ![]const u8 {
    const header: Header = try reader.readStruct(Header);
    if (!mem.eql(u8, &header.fmag, ARFMAG)) {
        return error.InvalidHeaderDelimiter;
    }
    if (!mem.eql(u8, header.name[0..2], "//")) {
        return error.MissingTableName;
    }
    const table_size = try header.parsedSize();
    const long_file_names = try gpa.alloc(u8, table_size);
    errdefer gpa.free(long_file_names);
    try reader.readNoEof(long_file_names);

    return long_file_names;
}

/// From a given file offset, starts reading for a file header.
/// When found, parses the object file into an `Object` and returns it.
pub fn parseObject(archive: Archive, wasm: *Wasm, file_contents: []const u8, path: Path) !Object {
    var fbs = std.io.fixedBufferStream(file_contents);
    const header = try fbs.reader().readStruct(Header);

    if (!mem.eql(u8, &header.fmag, ARFMAG)) return error.BadArchiveHeaderDelimiter;

    const object_name = try archive.parseName(header);
    const object_file_size = try header.parsedSize();

    return Object.create(wasm, file_contents[@sizeOf(Header)..][0..object_file_size], path, object_name);
}

const std = @import("std");
const assert = std.debug.assert;
const fs = std.fs;
const log = std.log.scoped(.archive);
const mem = std.mem;
const Path = std.Build.Cache.Path;

const Allocator = mem.Allocator;
const Object = @import("Object.zig");
const Wasm = @import("../Wasm.zig");

const Archive = @This();
