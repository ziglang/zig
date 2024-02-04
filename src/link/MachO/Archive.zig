objects: std.ArrayListUnmanaged(Object) = .{},

// Archive files start with the ARMAG identifying string.  Then follows a
// `struct ar_hdr', and as many bytes of member file data as its `ar_size'
// member indicates, for each member file.
/// String that begins an archive file.
pub const ARMAG: *const [SARMAG:0]u8 = "!<arch>\n";
/// Size of that string.
pub const SARMAG: u4 = 8;

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

    fn date(self: ar_hdr) !u64 {
        const value = mem.trimRight(u8, &self.ar_date, &[_]u8{@as(u8, 0x20)});
        return std.fmt.parseInt(u64, value, 10);
    }

    fn size(self: ar_hdr) !u32 {
        const value = mem.trimRight(u8, &self.ar_size, &[_]u8{@as(u8, 0x20)});
        return std.fmt.parseInt(u32, value, 10);
    }

    fn name(self: *const ar_hdr) ?[]const u8 {
        const value = &self.ar_name;
        if (mem.startsWith(u8, value, "#1/")) return null;
        const sentinel = mem.indexOfScalar(u8, value, '/') orelse value.len;
        return value[0..sentinel];
    }

    fn nameLength(self: ar_hdr) !?u32 {
        const value = &self.ar_name;
        if (!mem.startsWith(u8, value, "#1/")) return null;
        const trimmed = mem.trimRight(u8, self.ar_name["#1/".len..], &[_]u8{0x20});
        return try std.fmt.parseInt(u32, trimmed, 10);
    }
};

pub fn isArchive(path: []const u8, fat_arch: ?fat.Arch) !bool {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    if (fat_arch) |arch| {
        try file.seekTo(arch.offset);
    }
    const magic = file.reader().readBytesNoEof(SARMAG) catch return false;
    if (!mem.eql(u8, &magic, ARMAG)) return false;
    return true;
}

pub fn deinit(self: *Archive, allocator: Allocator) void {
    self.objects.deinit(allocator);
}

pub fn parse(self: *Archive, macho_file: *MachO, path: []const u8, file: std.fs.File, fat_arch: ?fat.Arch) !void {
    const gpa = macho_file.base.comp.gpa;

    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();

    const offset = if (fat_arch) |ar| ar.offset else 0;
    const size = if (fat_arch) |ar| ar.size else (try file.stat()).size;
    try file.seekTo(offset);

    const reader = file.reader();
    _ = try reader.readBytesNoEof(Archive.SARMAG);

    var pos: usize = Archive.SARMAG;
    while (true) {
        if (pos >= size) break;
        if (!mem.isAligned(pos, 2)) {
            try file.seekBy(1);
            pos += 1;
        }

        const hdr = try reader.readStruct(ar_hdr);
        pos += @sizeOf(ar_hdr);

        if (!mem.eql(u8, &hdr.ar_fmag, ARFMAG)) {
            try macho_file.reportParseError(path, "invalid header delimiter: expected '{s}', found '{s}'", .{
                std.fmt.fmtSliceEscapeLower(ARFMAG), std.fmt.fmtSliceEscapeLower(&hdr.ar_fmag),
            });
            return error.MalformedArchive;
        }

        var hdr_size = try hdr.size();
        const name = name: {
            if (hdr.name()) |n| break :name n;
            if (try hdr.nameLength()) |len| {
                hdr_size -= len;
                const buf = try arena.allocator().alloc(u8, len);
                try reader.readNoEof(buf);
                pos += len;
                const actual_len = mem.indexOfScalar(u8, buf, @as(u8, 0)) orelse len;
                break :name buf[0..actual_len];
            }
            unreachable;
        };
        defer {
            _ = file.seekBy(hdr_size) catch {};
            pos += hdr_size;
        }

        if (mem.eql(u8, name, "__.SYMDEF") or mem.eql(u8, name, "__.SYMDEF SORTED")) continue;

        const object = Object{
            .archive = .{
                .path = try gpa.dupe(u8, path),
                .offset = offset + pos,
            },
            .path = try gpa.dupe(u8, name),
            .file = try std.fs.cwd().openFile(path, .{}),
            .index = undefined,
            .alive = false,
            .mtime = hdr.date() catch 0,
        };

        log.debug("extracting object '{s}' from archive '{s}'", .{ object.path, path });

        try self.objects.append(gpa, object);
    }
}

const fat = @import("fat.zig");
const log = std.log.scoped(.link);
const macho = std.macho;
const mem = std.mem;
const std = @import("std");

const Allocator = mem.Allocator;
const Archive = @This();
const MachO = @import("../MachO.zig");
const Object = @import("Object.zig");
