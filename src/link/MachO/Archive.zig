const Archive = @This();

const std = @import("std");
const assert = std.debug.assert;
const fs = std.fs;
const log = std.log.scoped(.link);
const macho = std.macho;
const mem = std.mem;

const Allocator = mem.Allocator;
const Object = @import("Object.zig");

file: fs.File,
fat_offset: u64,
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
        const slash_index = mem.indexOf(u8, value, "/") orelse return error.MalformedArchive;
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

pub fn isArchive(file: fs.File, fat_offset: u64) bool {
    const reader = file.reader();
    const magic = reader.readBytesNoEof(SARMAG) catch return false;
    defer file.seekTo(fat_offset) catch {};
    return mem.eql(u8, &magic, ARMAG);
}

pub fn deinit(self: *Archive, allocator: Allocator) void {
    self.file.close();
    for (self.toc.keys()) |*key| {
        allocator.free(key.*);
    }
    for (self.toc.values()) |*value| {
        value.deinit(allocator);
    }
    self.toc.deinit(allocator);
    allocator.free(self.name);
}

pub fn parse(self: *Archive, allocator: Allocator, reader: anytype) !void {
    _ = try reader.readBytesNoEof(SARMAG);
    self.header = try reader.readStruct(ar_hdr);
    const name_or_length = try self.header.nameOrLength();
    var embedded_name = try parseName(allocator, name_or_length, reader);
    log.debug("parsing archive '{s}' at '{s}'", .{ embedded_name, self.name });
    defer allocator.free(embedded_name);

    try self.parseTableOfContents(allocator, reader);
}

fn parseName(allocator: Allocator, name_or_length: ar_hdr.NameOrLength, reader: anytype) ![]u8 {
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
    const symtab_size = try reader.readIntLittle(u32);
    var symtab = try allocator.alloc(u8, symtab_size);
    defer allocator.free(symtab);

    reader.readNoEof(symtab) catch {
        log.err("incomplete symbol table: expected symbol table of length 0x{x}", .{symtab_size});
        return error.MalformedArchive;
    };

    const strtab_size = try reader.readIntLittle(u32);
    var strtab = try allocator.alloc(u8, strtab_size);
    defer allocator.free(strtab);

    reader.readNoEof(strtab) catch {
        log.err("incomplete symbol table: expected string table of length 0x{x}", .{strtab_size});
        return error.MalformedArchive;
    };

    var symtab_stream = std.io.fixedBufferStream(symtab);
    var symtab_reader = symtab_stream.reader();

    while (true) {
        const n_strx = symtab_reader.readIntLittle(u32) catch |err| switch (err) {
            error.EndOfStream => break,
            else => |e| return e,
        };
        const object_offset = try symtab_reader.readIntLittle(u32);

        const sym_name = mem.sliceTo(@as([*:0]const u8, @ptrCast(strtab.ptr + n_strx)), 0);
        const owned_name = try allocator.dupe(u8, sym_name);
        const res = try self.toc.getOrPut(allocator, owned_name);
        defer if (res.found_existing) allocator.free(owned_name);

        if (!res.found_existing) {
            res.value_ptr.* = .{};
        }

        try res.value_ptr.append(allocator, object_offset);
    }
}

pub fn parseObject(self: Archive, gpa: Allocator, offset: u32) !Object {
    const reader = self.file.reader();
    try reader.context.seekTo(self.fat_offset + offset);

    const object_header = try reader.readStruct(ar_hdr);

    const name_or_length = try object_header.nameOrLength();
    const object_name = try parseName(gpa, name_or_length, reader);
    defer gpa.free(object_name);

    log.debug("extracting object '{s}' from archive '{s}'", .{ object_name, self.name });

    const name = name: {
        var buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const path = try std.os.realpath(self.name, &buffer);
        break :name try std.fmt.allocPrint(gpa, "{s}({s})", .{ path, object_name });
    };

    const object_name_len = switch (name_or_length) {
        .Name => 0,
        .Length => |len| len,
    };
    const object_size = (try object_header.size()) - object_name_len;
    const contents = try gpa.allocWithOptions(u8, object_size, @alignOf(u64), null);
    const amt = try reader.readAll(contents);
    if (amt != object_size) {
        return error.InputOutput;
    }

    var object = Object{
        .name = name,
        .mtime = object_header.date() catch 0,
        .contents = contents,
    };

    try object.parse(gpa);

    return object;
}
