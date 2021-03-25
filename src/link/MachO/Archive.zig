const Archive = @This();

const std = @import("std");
const assert = std.debug.assert;
const fs = std.fs;
const log = std.log.scoped(.archive);
const macho = std.macho;
const mem = std.mem;

const Allocator = mem.Allocator;
const Object = @import("Object.zig");
const parseName = @import("Zld.zig").parseName;

usingnamespace @import("commands.zig");

allocator: *Allocator,
file: fs.File,
header: ar_hdr,
name: []u8,

objects: std.ArrayListUnmanaged(Object) = .{},

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
        Length: u64,
    };
    pub fn nameOrLength(self: ar_hdr) !NameOrLength {
        const value = getValue(&self.ar_name);
        const slash_index = mem.indexOf(u8, value, "/") orelse return error.MalformedArchive;
        const len = value.len;
        if (slash_index == len - 1) {
            // Name stored directly
            return NameOrLength{ .Name = value };
        } else {
            // Name follows the header directly and its length is encoded in
            // the name field.
            const length = try std.fmt.parseInt(u64, value[slash_index + 1 ..], 10);
            return NameOrLength{ .Length = length };
        }
    }

    pub fn size(self: ar_hdr) !u64 {
        const value = getValue(&self.ar_size);
        return std.fmt.parseInt(u64, value, 10);
    }

    fn getValue(raw: []const u8) []const u8 {
        return mem.trimRight(u8, raw, &[_]u8{@as(u8, 0x20)});
    }
};

pub fn deinit(self: *Archive) void {
    self.allocator.free(self.name);
    for (self.objects.items) |*object| {
        object.deinit();
    }
    self.objects.deinit(self.allocator);
    for (self.toc.items()) |*entry| {
        self.allocator.free(entry.key);
        entry.value.deinit(self.allocator);
    }
    self.toc.deinit(self.allocator);
    self.file.close();
}

/// Caller owns the returned Archive instance and is responsible for calling
/// `deinit` to free allocated memory.
pub fn initFromFile(allocator: *Allocator, arch: std.Target.Cpu.Arch, ar_name: []const u8, file: fs.File) !Archive {
    var reader = file.reader();
    var magic = try readMagic(allocator, reader);
    defer allocator.free(magic);

    if (!mem.eql(u8, magic, ARMAG)) {
        // Reset file cursor.
        try file.seekTo(0);
        return error.NotArchive;
    }

    const header = try reader.readStruct(ar_hdr);

    if (!mem.eql(u8, &header.ar_fmag, ARFMAG))
        return error.MalformedArchive;

    var embedded_name = try getName(allocator, header, reader);
    log.debug("parsing archive '{s}' at '{s}'", .{ embedded_name, ar_name });
    defer allocator.free(embedded_name);

    var name = try allocator.dupe(u8, ar_name);
    var self = Archive{
        .allocator = allocator,
        .file = file,
        .header = header,
        .name = name,
    };

    var object_offsets = try self.readTableOfContents(reader);
    defer self.allocator.free(object_offsets);

    var i: usize = 1;
    while (i < object_offsets.len) : (i += 1) {
        const offset = object_offsets[i];
        try reader.context.seekTo(offset);
        try self.readObject(arch, ar_name, reader);
    }

    return self;
}

fn readTableOfContents(self: *Archive, reader: anytype) ![]u32 {
    const symtab_size = try reader.readIntLittle(u32);
    var symtab = try self.allocator.alloc(u8, symtab_size);
    defer self.allocator.free(symtab);
    try reader.readNoEof(symtab);

    const strtab_size = try reader.readIntLittle(u32);
    var strtab = try self.allocator.alloc(u8, strtab_size);
    defer self.allocator.free(strtab);
    try reader.readNoEof(strtab);

    var symtab_stream = std.io.fixedBufferStream(symtab);
    var symtab_reader = symtab_stream.reader();

    var object_offsets = std.ArrayList(u32).init(self.allocator);
    try object_offsets.append(0);
    var last: usize = 0;

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

        // TODO This will go once we properly use archive's TOC to pick
        // an object which defines a missing symbol rather than pasting in
        // all of the objects always.
        // Here, we assume that symbols are NOT sorted in any way, and
        // they point to objects in sequence.
        if (object_offsets.items[last] != object_offset) {
            try object_offsets.append(object_offset);
            last += 1;
        }
    }

    return object_offsets.toOwnedSlice();
}

fn readObject(self: *Archive, arch: std.Target.Cpu.Arch, ar_name: []const u8, reader: anytype) !void {
    const object_header = try reader.readStruct(ar_hdr);

    if (!mem.eql(u8, &object_header.ar_fmag, ARFMAG))
        return error.MalformedArchive;

    var object_name = try getName(self.allocator, object_header, reader);
    log.debug("extracting object '{s}' from archive '{s}'", .{ object_name, self.name });

    const offset = @intCast(u32, try reader.context.getPos());
    const header = try reader.readStruct(macho.mach_header_64);

    const this_arch: std.Target.Cpu.Arch = switch (header.cputype) {
        macho.CPU_TYPE_ARM64 => .aarch64,
        macho.CPU_TYPE_X86_64 => .x86_64,
        else => |value| {
            log.err("unsupported cpu architecture 0x{x}", .{value});
            return error.UnsupportedCpuArchitecture;
        },
    };
    if (this_arch != arch) {
        log.err("mismatched cpu architecture: found {s}, expected {s}", .{ this_arch, arch });
        return error.MismatchedCpuArchitecture;
    }

    // TODO Implement std.fs.File.clone() or similar.
    var new_file = try fs.cwd().openFile(ar_name, .{});
    var object = Object{
        .allocator = self.allocator,
        .name = object_name,
        .ar_name = try mem.dupe(self.allocator, u8, ar_name),
        .file = new_file,
        .header = header,
    };

    try object.readLoadCommands(reader, .{ .offset = offset });

    if (object.symtab_cmd_index != null) {
        try object.readSymtab();
        try object.readStrtab();
    }

    if (object.data_in_code_cmd_index != null) try object.readDataInCode();

    log.debug("\n\n", .{});
    log.debug("{s} defines symbols", .{object.name});
    for (object.symtab.items) |sym| {
        const symname = object.getString(sym.n_strx);
        log.debug("'{s}': {}", .{ symname, sym });
    }

    try self.objects.append(self.allocator, object);
}

fn readMagic(allocator: *Allocator, reader: anytype) ![]u8 {
    var magic = std.ArrayList(u8).init(allocator);
    try magic.ensureCapacity(SARMAG);
    var i: usize = 0;
    while (i < SARMAG) : (i += 1) {
        const next = try reader.readByte();
        magic.appendAssumeCapacity(next);
    }
    return magic.toOwnedSlice();
}

fn getName(allocator: *Allocator, header: ar_hdr, reader: anytype) ![]u8 {
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
