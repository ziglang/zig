const Archive = @This();

const std = @import("std");
const assert = std.debug.assert;
const fs = std.fs;
const log = std.log.scoped(.archive);
const macho = std.macho;
const mem = std.mem;

const Allocator = mem.Allocator;
const Object = @import("Object.zig");

file: fs.File,
name: []const u8,

header: ar_hdr = undefined,

/// Parsed table of contents.
/// Each symbol name points to a list of all definition
/// sites within the current static archive.
toc: std.StringArrayHashMapUnmanaged(std.ArrayListUnmanaged(u32)) = .{},

// Archive files start with the ARMAG identifying string.  Then follows a
// `struct ar_hdr', and as many bytes of member file data as its `ar_size'
// member indicates, for each member file.
/// String that begins an archive file.
const ARMAG: *const [SARMAG:0]u8 = "!<arch>\n";
/// Size of that string.
const SARMAG: u4 = 8;

/// String in ar_fmag at the end of each header.
const ARFMAG: *const [2:0]u8 = "`\n";

const ar_hdr = extern struct {
    /// Member file name, sometimes / terminated.
    ar_name: [16]u8,

    /// File date, decimal seconds since Epoch.
    ar_date: [12]u8,

    /// User ID, in ASCII format.
    ar_uid: [6]u8,

    /// Group ID, in ASCII format.
    ar_gid: [6]u8,

    /// File mode, in ASCII octal.
    ar_mode: [8]u8,

    /// File size, in ASCII decimal.
    ar_size: [10]u8,

    /// Always contains ARFMAG.
    ar_fmag: [2]u8,

    const NameOrLength = union(enum) {
        Name: []const u8,
        Length: u32,
    };
    fn nameOrLength(self: ar_hdr) !NameOrLength {
        const value = getValue(&self.ar_name);
        const slash_index = mem.indexOfScalar(u8, value, '/') orelse return error.MalformedArchive;
        const len = value.len;
        if (slash_index == len - 1) {
            // Name stored directly
            return NameOrLength{ .Name = value };
        } else {
            // Name follows the header directly and its length is encoded in
            // the name field.
            const length = try std.fmt.parseInt(u32, value[slash_index + 1 ..], 10);
            return NameOrLength{ .Length = length };
        }
    }

    fn date(self: ar_hdr) !u64 {
        const value = getValue(&self.ar_date);
        return std.fmt.parseInt(u64, value, 10);
    }

    fn size(self: ar_hdr) !u32 {
        const value = getValue(&self.ar_size);
        return std.fmt.parseInt(u32, value, 10);
    }

    fn getValue(raw: []const u8) []const u8 {
        return mem.trimRight(u8, raw, &[_]u8{@as(u8, 0x20)});
    }
};

pub fn deinit(self: *Archive, allocator: Allocator) void {
    for (self.toc.keys()) |*key| {
        allocator.free(key.*);
    }
    for (self.toc.values()) |*value| {
        value.deinit(allocator);
    }
    self.toc.deinit(allocator);
}

pub fn parse(self: *Archive, allocator: Allocator) !void {
    const reader = self.file.reader();

    const magic = try reader.readBytesNoEof(SARMAG);
    if (!mem.eql(u8, &magic, ARMAG)) {
        log.debug("invalid magic: expected '{s}', found '{s}'", .{ ARMAG, magic });
        return error.NotArchive;
    }

    self.header = try reader.readStruct(ar_hdr);
    if (!mem.eql(u8, &self.header.ar_fmag, ARFMAG)) {
        log.debug("invalid header delimiter: expected '{s}', found '{s}'", .{ ARFMAG, self.header.ar_fmag });
        return error.NotArchive;
    }

    try self.parseTableOfContents(allocator, reader);
}

fn parseName(allocator: Allocator, header: ar_hdr, reader: anytype) ![]u8 {
    const name_or_length = try header.nameOrLength();
    var name: []u8 = undefined;
    switch (name_or_length) {
        .Name => |n| {
            name = try allocator.dupe(u8, n);
        },
        .Length => |len| {
            var n = try allocator.alloc(u8, len);
            defer allocator.free(n);
            try reader.readNoEof(n);
            const actual_len = mem.indexOfScalar(u8, n, @as(u8, 0)) orelse n.len;
            name = try allocator.dupe(u8, n[0..actual_len]);
        },
    }
    return name;
}

fn parseTableOfContents(self: *Archive, allocator: Allocator, reader: anytype) !void {
    log.debug("parsing table of contents for archive file '{s}'", .{self.name});
    // size field can have extra spaces padded in front as well as the end,
    // so we trim those first before parsing the ASCII value.
    const size_trimmed = std.mem.trim(u8, &self.header.ar_size, " ");
    const sym_tab_size = try std.fmt.parseInt(u32, size_trimmed, 10);

    const num_symbols = try reader.readIntBig(u32);
    const symbol_positions = try allocator.alloc(u32, num_symbols);
    defer allocator.free(symbol_positions);
    for (symbol_positions) |*index| {
        index.* = try reader.readIntBig(u32);
    }

    const sym_tab = try allocator.alloc(u8, sym_tab_size - 4 - (4 * num_symbols));
    defer allocator.free(sym_tab);

    reader.readNoEof(sym_tab) catch {
        log.err("incomplete symbol table: expected symbol table of length 0x{x}", .{sym_tab.len});
        return error.MalformedArchive;
    };

    var i: usize = 0;
    while (i < sym_tab.len) {
        const string = std.mem.sliceTo(sym_tab[i..], 0);
        if (string.len == 0) {
            i += 1;
            continue;
        }
        i += string.len;
        const name = try allocator.dupe(u8, string);
        errdefer allocator.free(name);
        const gop = try self.toc.getOrPut(allocator, name);
        if (gop.found_existing) {
            allocator.free(name);
        } else {
            gop.value_ptr.* = .{};
        }
        try gop.value_ptr.append(allocator, symbol_positions[gop.index]);
    }
}

/// From a given file offset, starts reading for a file header.
/// When found, parses the object file into an `Object` and returns it.
pub fn parseObject(self: Archive, allocator: Allocator, file_offset: u32) !Object {
    try self.file.seekTo(file_offset);
    const reader = self.file.reader();
    const header = try reader.readStruct(ar_hdr);
    const current_offset = try self.file.getPos();
    try self.file.seekTo(0);

    if (!mem.eql(u8, &header.ar_fmag, ARFMAG)) {
        log.err("invalid header delimiter: expected '{s}', found '{s}'", .{ ARFMAG, header.ar_fmag });
        return error.MalformedArchive;
    }

    const object_name = try parseName(allocator, header, reader);
    defer allocator.free(object_name);

    const name = name: {
        var buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const path = try std.os.realpath(self.name, &buffer);
        break :name try std.fmt.allocPrint(allocator, "{s}({s})", .{ path, object_name });
    };
    defer allocator.free(name);

    const object_file = try std.fs.cwd().openFile(self.name, .{});
    errdefer object_file.close();

    try object_file.seekTo(current_offset);
    return Object.create(allocator, object_file, name);
}
