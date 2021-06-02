const Archive = @This();

const std = @import("std");
const assert = std.debug.assert;
const fs = std.fs;
const log = std.log.scoped(.archive);
const macho = std.macho;
const mem = std.mem;

const Allocator = mem.Allocator;
const Object = @import("Object.zig");

usingnamespace @import("commands.zig");

allocator: *Allocator,
arch: ?std.Target.Cpu.Arch = null,
file: ?fs.File = null,
header: ?ar_hdr = null,
name: ?[]const u8 = null,

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

    fn size(self: ar_hdr) !u32 {
        const value = getValue(&self.ar_size);
        return std.fmt.parseInt(u32, value, 10);
    }

    fn getValue(raw: []const u8) []const u8 {
        return mem.trimRight(u8, raw, &[_]u8{@as(u8, 0x20)});
    }
};

pub fn init(allocator: *Allocator) Archive {
    return .{
        .allocator = allocator,
    };
}

pub fn deinit(self: *Archive) void {
    for (self.toc.items()) |*entry| {
        self.allocator.free(entry.key);
        entry.value.deinit(self.allocator);
    }
    self.toc.deinit(self.allocator);

    if (self.name) |n| {
        self.allocator.free(n);
    }
}

pub fn closeFile(self: Archive) void {
    if (self.file) |f| {
        f.close();
    }
}

pub fn parse(self: *Archive) !void {
    var reader = self.file.?.reader();
    const magic = try reader.readBytesNoEof(SARMAG);

    if (!mem.eql(u8, &magic, ARMAG)) {
        log.err("invalid magic: expected '{s}', found '{s}'", .{ ARMAG, magic });
        return error.MalformedArchive;
    }

    self.header = try reader.readStruct(ar_hdr);

    if (!mem.eql(u8, &self.header.?.ar_fmag, ARFMAG)) {
        log.err("invalid header delimiter: expected '{s}', found '{s}'", .{ ARFMAG, self.header.?.ar_fmag });
        return error.MalformedArchive;
    }

    var embedded_name = try parseName(self.allocator, self.header.?, reader);
    log.debug("parsing archive '{s}' at '{s}'", .{ embedded_name, self.name.? });
    defer self.allocator.free(embedded_name);

    try self.parseTableOfContents(reader);

    try reader.context.seekTo(0);
}

fn parseName(allocator: *Allocator, header: ar_hdr, reader: anytype) ![]u8 {
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

fn parseTableOfContents(self: *Archive, reader: anytype) !void {
    const symtab_size = try reader.readIntLittle(u32);
    var symtab = try self.allocator.alloc(u8, symtab_size);
    defer self.allocator.free(symtab);

    reader.readNoEof(symtab) catch {
        log.err("incomplete symbol table: expected symbol table of length 0x{x}", .{symtab_size});
        return error.MalformedArchive;
    };

    const strtab_size = try reader.readIntLittle(u32);
    var strtab = try self.allocator.alloc(u8, strtab_size);
    defer self.allocator.free(strtab);

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

        const sym_name = mem.spanZ(@ptrCast([*:0]const u8, strtab.ptr + n_strx));
        const owned_name = try self.allocator.dupe(u8, sym_name);
        const res = try self.toc.getOrPut(self.allocator, owned_name);
        defer if (res.found_existing) self.allocator.free(owned_name);

        if (!res.found_existing) {
            res.entry.value = .{};
        }

        try res.entry.value.append(self.allocator, object_offset);
    }
}

/// Caller owns the Object instance.
pub fn parseObject(self: Archive, offset: u32) !*Object {
    var reader = self.file.?.reader();
    try reader.context.seekTo(offset);

    const object_header = try reader.readStruct(ar_hdr);

    if (!mem.eql(u8, &object_header.ar_fmag, ARFMAG)) {
        log.err("invalid header delimiter: expected '{s}', found '{s}'", .{ ARFMAG, object_header.ar_fmag });
        return error.MalformedArchive;
    }

    const object_name = try parseName(self.allocator, object_header, reader);
    defer self.allocator.free(object_name);

    log.debug("extracting object '{s}' from archive '{s}'", .{ object_name, self.name.? });

    const name = name: {
        var buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const path = try std.os.realpath(self.name.?, &buffer);
        break :name try std.fmt.allocPrint(self.allocator, "{s}({s})", .{ path, object_name });
    };

    var object = try self.allocator.create(Object);
    errdefer self.allocator.destroy(object);

    object.* = Object.init(self.allocator);
    object.arch = self.arch.?;
    object.file = try fs.cwd().openFile(self.name.?, .{});
    object.name = name;
    object.file_offset = @intCast(u32, try reader.context.getPos());
    try object.parse();

    try reader.context.seekTo(0);

    return object;
}

pub fn isArchive(file: fs.File) !bool {
    const magic = try file.reader().readBytesNoEof(Archive.SARMAG);
    try file.seekTo(0);
    return mem.eql(u8, &magic, Archive.ARMAG);
}
