objects: std.ArrayListUnmanaged(Object) = .empty,
strtab: std.ArrayListUnmanaged(u8) = .empty,

pub fn deinit(self: *Archive, allocator: Allocator) void {
    self.objects.deinit(allocator);
    self.strtab.deinit(allocator);
}

pub fn parse(self: *Archive, elf_file: *Elf, path: Path, handle_index: File.HandleIndex) !void {
    const comp = elf_file.base.comp;
    const gpa = comp.gpa;
    const diags = &comp.link_diags;
    const handle = elf_file.fileHandle(handle_index);
    const size = (try handle.stat()).size;

    var pos: usize = elf.ARMAG.len;
    while (true) {
        if (pos >= size) break;
        if (!mem.isAligned(pos, 2)) pos += 1;

        var hdr_buffer: [@sizeOf(elf.ar_hdr)]u8 = undefined;
        {
            const amt = try handle.preadAll(&hdr_buffer, pos);
            if (amt != @sizeOf(elf.ar_hdr)) return error.InputOutput;
        }
        const hdr = @as(*align(1) const elf.ar_hdr, @ptrCast(&hdr_buffer)).*;
        pos += @sizeOf(elf.ar_hdr);

        if (!mem.eql(u8, &hdr.ar_fmag, elf.ARFMAG)) {
            return diags.failParse(path, "invalid archive header delimiter: {s}", .{
                std.fmt.fmtSliceEscapeLower(&hdr.ar_fmag),
            });
        }

        const obj_size = try hdr.size();
        defer pos += obj_size;

        if (hdr.isSymtab() or hdr.isSymtab64()) continue;
        if (hdr.isStrtab()) {
            try self.strtab.resize(gpa, obj_size);
            const amt = try handle.preadAll(self.strtab.items, pos);
            if (amt != obj_size) return error.InputOutput;
            continue;
        }
        if (hdr.isSymdef() or hdr.isSymdefSorted()) continue;

        const name = if (hdr.name()) |name|
            name
        else if (try hdr.nameOffset()) |off|
            self.getString(off)
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

        log.debug("extracting object '{}' from archive '{}'", .{
            @as(Path, object.path), @as(Path, path),
        });

        try self.objects.append(gpa, object);
    }
}

fn getString(self: Archive, off: u32) []const u8 {
    assert(off < self.strtab.items.len);
    const name = mem.sliceTo(@as([*:'\n']const u8, @ptrCast(self.strtab.items.ptr + off)), 0);
    return name[0 .. name.len - 1];
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

    pub fn format(
        ar: ArSymtab,
        comptime unused_fmt_string: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = ar;
        _ = unused_fmt_string;
        _ = options;
        _ = writer;
        @compileError("do not format ar symtab directly; use fmt instead");
    }

    const FormatContext = struct {
        ar: ArSymtab,
        elf_file: *Elf,
    };

    pub fn fmt(ar: ArSymtab, elf_file: *Elf) std.fmt.Formatter(format2) {
        return .{ .data = .{
            .ar = ar,
            .elf_file = elf_file,
        } };
    }

    fn format2(
        ctx: FormatContext,
        comptime unused_fmt_string: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = unused_fmt_string;
        _ = options;
        const ar = ctx.ar;
        const elf_file = ctx.elf_file;
        for (ar.symtab.items, 0..) |entry, i| {
            const name = ar.strtab.getAssumeExists(entry.off);
            const file = elf_file.file(entry.file_index).?;
            try writer.print("  {d}: {s} in file({d})({})\n", .{ i, name, entry.file_index, file.fmtPath() });
        }
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

    pub fn format(
        ar: ArStrtab,
        comptime unused_fmt_string: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = unused_fmt_string;
        _ = options;
        try writer.print("{s}", .{std.fmt.fmtSliceEscapeLower(ar.buffer.items)});
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

const Allocator = mem.Allocator;
const Archive = @This();
const Elf = @import("../Elf.zig");
const File = @import("file.zig").File;
const Object = @import("Object.zig");
const StringTable = @import("../StringTable.zig");
