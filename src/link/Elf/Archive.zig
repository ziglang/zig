objects: []const Object,
/// '\n'-delimited
strtab: []const u8,

pub fn deinit(a: *Archive, gpa: Allocator) void {
    gpa.free(a.objects);
    gpa.free(a.strtab);
    a.* = undefined;
}

pub fn parse(
    gpa: Allocator,
    diags: *Diags,
    file_handles: *const std.ArrayListUnmanaged(File.Handle),
    path: Path,
    handle_index: File.HandleIndex,
) !Archive {
    const handle = file_handles.items[handle_index];
    var pos: usize = 0;
    {
        var magic_buffer: [elf.ARMAG.len]u8 = undefined;
        const n = try handle.preadAll(&magic_buffer, pos);
        if (n != magic_buffer.len) return error.BadMagic;
        if (!mem.eql(u8, &magic_buffer, elf.ARMAG)) return error.BadMagic;
        pos += magic_buffer.len;
    }

    const size = (try handle.stat()).size;

    var objects: std.ArrayListUnmanaged(Object) = .empty;
    defer objects.deinit(gpa);

    var strtab: std.ArrayListUnmanaged(u8) = .empty;
    defer strtab.deinit(gpa);

    while (pos < size) {
        pos = mem.alignForward(usize, pos, 2);

        var hdr: elf.ar_hdr = undefined;
        {
            const n = try handle.preadAll(mem.asBytes(&hdr), pos);
            if (n != @sizeOf(elf.ar_hdr)) return error.UnexpectedEndOfFile;
        }
        pos += @sizeOf(elf.ar_hdr);

        if (!mem.eql(u8, &hdr.ar_fmag, elf.ARFMAG)) {
            return diags.failParse(path, "invalid archive header delimiter: {f}", .{
                std.ascii.hexEscape(&hdr.ar_fmag, .lower),
            });
        }

        const obj_size = try hdr.size();
        defer pos += obj_size;

        if (hdr.isSymtab() or hdr.isSymtab64()) continue;
        if (hdr.isStrtab()) {
            try strtab.resize(gpa, obj_size);
            const amt = try handle.preadAll(strtab.items, pos);
            if (amt != obj_size) return error.InputOutput;
            continue;
        }
        if (hdr.isSymdef() or hdr.isSymdefSorted()) continue;

        const name = if (hdr.name()) |name|
            name
        else if (try hdr.nameOffset()) |off|
            stringTableLookup(strtab.items, off)
        else
            unreachable;

        const object: Object = .{
            .archive = .{
                .path = .{
                    .root_dir = path.root_dir,
                    .sub_path = try gpa.dupe(u8, path.sub_path),
                },
                .offset = pos,
                .size = obj_size,
            },
            .path = Path.initCwd(try gpa.dupe(u8, name)),
            .file_handle = handle_index,
            .index = undefined,
            .alive = false,
        };

        log.debug("extracting object '{f}' from archive '{f}'", .{
            @as(Path, object.path), @as(Path, path),
        });

        try objects.append(gpa, object);
    }

    return .{
        .objects = try objects.toOwnedSlice(gpa),
        .strtab = try strtab.toOwnedSlice(gpa),
    };
}

pub fn stringTableLookup(strtab: []const u8, off: u32) [:'\n']const u8 {
    const slice = strtab[off..];
    return slice[0..mem.indexOfScalar(u8, slice, '\n').? :'\n'];
}

pub fn setArHdr(opts: struct {
    name: union(enum) {
        symtab: void,
        strtab: void,
        name: []const u8,
        name_off: u32,
    },
    size: usize,
}) elf.ar_hdr {
    var hdr: elf.ar_hdr = .{
        .ar_name = undefined,
        .ar_date = undefined,
        .ar_uid = undefined,
        .ar_gid = undefined,
        .ar_mode = undefined,
        .ar_size = undefined,
        .ar_fmag = undefined,
    };
    @memset(mem.asBytes(&hdr), 0x20);
    @memcpy(&hdr.ar_fmag, elf.ARFMAG);

    {
        var stream = std.io.fixedBufferStream(&hdr.ar_name);
        const writer = stream.writer();
        switch (opts.name) {
            .symtab => writer.print("{s}", .{elf.SYM64NAME}) catch unreachable,
            .strtab => writer.print("//", .{}) catch unreachable,
            .name => |x| writer.print("{s}/", .{x}) catch unreachable,
            .name_off => |x| writer.print("/{d}", .{x}) catch unreachable,
        }
    }
    {
        var stream = std.io.fixedBufferStream(&hdr.ar_size);
        stream.writer().print("{d}", .{opts.size}) catch unreachable;
    }

    return hdr;
}

const strtab_delimiter = '\n';
pub const max_member_name_len = 15;

pub const ArSymtab = struct {
    symtab: std.ArrayListUnmanaged(Entry) = .empty,
    strtab: StringTable = .{},

    pub fn deinit(ar: *ArSymtab, allocator: Allocator) void {
        ar.symtab.deinit(allocator);
        ar.strtab.deinit(allocator);
    }

    pub fn sort(ar: *ArSymtab) void {
        mem.sort(Entry, ar.symtab.items, {}, Entry.lessThan);
    }

    pub fn size(ar: ArSymtab, kind: enum { p32, p64 }) usize {
        const ptr_size: usize = switch (kind) {
            .p32 => 4,
            .p64 => 8,
        };
        var ss: usize = ptr_size + ar.symtab.items.len * ptr_size;
        for (ar.symtab.items) |entry| {
            ss += ar.strtab.getAssumeExists(entry.off).len + 1;
        }
        return ss;
    }

    pub fn write(ar: ArSymtab, kind: enum { p32, p64 }, elf_file: *Elf, writer: anytype) !void {
        assert(kind == .p64); // TODO p32
        const hdr = setArHdr(.{ .name = .symtab, .size = @intCast(ar.size(.p64)) });
        try writer.writeAll(mem.asBytes(&hdr));

        const comp = elf_file.base.comp;
        const gpa = comp.gpa;
        var offsets = std.AutoHashMap(File.Index, u64).init(gpa);
        defer offsets.deinit();
        try offsets.ensureUnusedCapacity(@intCast(elf_file.objects.items.len + 1));

        if (elf_file.zigObjectPtr()) |zig_object| {
            offsets.putAssumeCapacityNoClobber(zig_object.index, zig_object.output_ar_state.file_off);
        }
        for (elf_file.objects.items) |index| {
            offsets.putAssumeCapacityNoClobber(index, elf_file.file(index).?.object.output_ar_state.file_off);
        }

        // Number of symbols
        try writer.writeInt(u64, @as(u64, @intCast(ar.symtab.items.len)), .big);

        // Offsets to files
        for (ar.symtab.items) |entry| {
            const off = offsets.get(entry.file_index).?;
            try writer.writeInt(u64, off, .big);
        }

        // Strings
        for (ar.symtab.items) |entry| {
            try writer.print("{s}\x00", .{ar.strtab.getAssumeExists(entry.off)});
        }
    }

    const Format = struct {
        ar: ArSymtab,
        elf_file: *Elf,

        fn default(f: Format, writer: *std.io.Writer) std.io.Writer.Error!void {
            const ar = f.ar;
            const elf_file = f.elf_file;
            for (ar.symtab.items, 0..) |entry, i| {
                const name = ar.strtab.getAssumeExists(entry.off);
                const file = elf_file.file(entry.file_index).?;
                try writer.print("  {d}: {s} in file({d})({f})\n", .{ i, name, entry.file_index, file.fmtPath() });
            }
        }
    };

    pub fn fmt(ar: ArSymtab, elf_file: *Elf) std.fmt.Formatter(Format, Format.default) {
        return .{ .data = .{
            .ar = ar,
            .elf_file = elf_file,
        } };
    }

    const Entry = struct {
        /// Offset into the string table.
        off: u32,
        /// Index of the file defining the global.
        file_index: File.Index,

        pub fn lessThan(ctx: void, lhs: Entry, rhs: Entry) bool {
            _ = ctx;
            if (lhs.off == rhs.off) return lhs.file_index < rhs.file_index;
            return lhs.off < rhs.off;
        }
    };
};

pub const ArStrtab = struct {
    buffer: std.ArrayListUnmanaged(u8) = .empty,

    pub fn deinit(ar: *ArStrtab, allocator: Allocator) void {
        ar.buffer.deinit(allocator);
    }

    pub fn insert(ar: *ArStrtab, allocator: Allocator, name: []const u8) error{OutOfMemory}!u32 {
        const off = @as(u32, @intCast(ar.buffer.items.len));
        try ar.buffer.writer(allocator).print("{s}/{c}", .{ name, strtab_delimiter });
        return off;
    }

    pub fn size(ar: ArStrtab) usize {
        return ar.buffer.items.len;
    }

    pub fn write(ar: ArStrtab, writer: anytype) !void {
        const hdr = setArHdr(.{ .name = .strtab, .size = @intCast(ar.size()) });
        try writer.writeAll(mem.asBytes(&hdr));
        try writer.writeAll(ar.buffer.items);
    }

    pub fn format(ar: ArStrtab, writer: *std.io.Writer) std.io.Writer.Error!void {
        try writer.print("{f}", .{std.ascii.hexEscape(ar.buffer.items, .lower)});
    }
};

pub const ArState = struct {
    /// Name offset in the string table.
    name_off: u32 = 0,

    /// File offset of the ar_hdr describing the contributing
    /// object in the archive.
    file_off: u64 = 0,

    /// Total size of the contributing object (excludes ar_hdr).
    size: u64 = 0,
};

const std = @import("std");
const assert = std.debug.assert;
const elf = std.elf;
const fs = std.fs;
const log = std.log.scoped(.link);
const mem = std.mem;
const Path = std.Build.Cache.Path;
const Allocator = std.mem.Allocator;

const Diags = @import("../../link.zig").Diags;
const Archive = @This();
const Elf = @import("../Elf.zig");
const File = @import("file.zig").File;
const Object = @import("Object.zig");
const StringTable = @import("../StringTable.zig");
