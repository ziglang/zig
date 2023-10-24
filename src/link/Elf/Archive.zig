path: []const u8,
data: []const u8,

objects: std.ArrayListUnmanaged(Object) = .{},
strtab: []const u8 = &[0]u8{},

// Archive files start with the ARMAG identifying string.  Then follows a
// `struct ar_hdr', and as many bytes of member file data as its `ar_size'
// member indicates, for each member file.
/// String that begins an archive file.
pub const ARMAG: *const [SARMAG:0]u8 = "!<arch>\n";
/// Size of that string.
pub const SARMAG: u4 = 8;

/// String in ar_fmag at the end of each header.
const ARFMAG: *const [2:0]u8 = "`\n";

const SYM64NAME: *const [7:0]u8 = "/SYM64/";

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

    fn isStrtab(self: ar_hdr) bool {
        return mem.eql(u8, getValue(&self.ar_name), "//");
    }

    fn isSymtab(self: ar_hdr) bool {
        return mem.eql(u8, getValue(&self.ar_name), "/");
    }
};

pub fn isArchive(path: []const u8) !bool {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const reader = file.reader();
    const magic = reader.readBytesNoEof(Archive.SARMAG) catch return false;
    if (!mem.eql(u8, &magic, ARMAG)) return false;
    return true;
}

pub fn deinit(self: *Archive, allocator: Allocator) void {
    allocator.free(self.path);
    allocator.free(self.data);
    self.objects.deinit(allocator);
}

pub fn parse(self: *Archive, elf_file: *Elf) !void {
    const gpa = elf_file.base.allocator;

    var stream = std.io.fixedBufferStream(self.data);
    const reader = stream.reader();
    _ = try reader.readBytesNoEof(SARMAG);

    while (true) {
        if (stream.pos % 2 != 0) {
            stream.pos += 1;
        }

        const hdr = reader.readStruct(ar_hdr) catch break;

        if (!mem.eql(u8, &hdr.ar_fmag, ARFMAG)) {
            // TODO convert into an error
            log.debug(
                "{s}: invalid header delimiter: expected '{s}', found '{s}'",
                .{ self.path, std.fmt.fmtSliceEscapeLower(ARFMAG), std.fmt.fmtSliceEscapeLower(&hdr.ar_fmag) },
            );
            return;
        }

        const size = try hdr.size();
        defer {
            _ = stream.seekBy(size) catch {};
        }

        if (hdr.isSymtab()) continue;
        if (hdr.isStrtab()) {
            self.strtab = self.data[stream.pos..][0..size];
            continue;
        }

        const name = ar_hdr.getValue(&hdr.ar_name);

        if (mem.eql(u8, name, "__.SYMDEF") or mem.eql(u8, name, "__.SYMDEF SORTED")) continue;

        const object_name = blk: {
            if (name[0] == '/') {
                const off = try std.fmt.parseInt(u32, name[1..], 10);
                break :blk self.getString(off);
            }
            break :blk name;
        };

        const object = Object{
            .archive = try gpa.dupe(u8, self.path),
            .path = try gpa.dupe(u8, object_name[0 .. object_name.len - 1]), // To account for trailing '/'
            .data = try gpa.dupe(u8, self.data[stream.pos..][0..size]),
            .index = undefined,
            .alive = false,
        };

        log.debug("extracting object '{s}' from archive '{s}'", .{ object.path, self.path });

        try self.objects.append(gpa, object);
    }
}

fn getString(self: Archive, off: u32) []const u8 {
    assert(off < self.strtab.len);
    return mem.sliceTo(@as([*:'\n']const u8, @ptrCast(self.strtab.ptr + off)), 0);
}

const std = @import("std");
const assert = std.debug.assert;
const elf = std.elf;
const fs = std.fs;
const log = std.log.scoped(.link);
const mem = std.mem;

const Allocator = mem.Allocator;
const Archive = @This();
const Elf = @import("../Elf.zig");
const Object = @import("Object.zig");
