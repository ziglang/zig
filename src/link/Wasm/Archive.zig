/// A list of long file names, delimited by a LF character (0x0a).
/// This is stored as a single slice of bytes, as the header-names
/// point to the character index of a file name, rather than the index
/// in the list.
/// Points into `file_contents`.
long_file_names: RelativeSlice,

/// Parsed table of contents.
/// Each symbol name points to a list of all definition
/// sites within the current static archive.
toc: Toc,

/// Key points into `LazyArchive` `file_contents`.
/// Value is allocated with gpa.
const Toc = std.StringArrayHashMapUnmanaged(std.ArrayListUnmanaged(u32));

const ARMAG = std.elf.ARMAG;
const ARFMAG = std.elf.ARFMAG;

const RelativeSlice = struct {
    off: u32,
    len: u32,
};

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
    archive.* = undefined;
}

fn deinitToc(gpa: Allocator, toc: *Toc) void {
    for (toc.values()) |*value| value.deinit(gpa);
    toc.deinit(gpa);
}

pub fn parse(gpa: Allocator, file_contents: []const u8) !Archive {
    var pos: usize = 0;

    if (!mem.eql(u8, file_contents[0..ARMAG.len], ARMAG)) return error.BadArchiveMagic;
    pos += ARMAG.len;

    const header = mem.bytesAsValue(Header, file_contents[pos..][0..@sizeOf(Header)]);
    if (!mem.eql(u8, &header.fmag, ARFMAG)) return error.BadHeaderDelimiter;
    pos += @sizeOf(Header);

    // The size field can have extra spaces padded in front as well as
    // the end, so we trim those first before parsing the ASCII value.
    const size_trimmed = mem.trim(u8, &header.size, " ");
    const sym_tab_size = try std.fmt.parseInt(u32, size_trimmed, 10);

    const num_symbols = mem.readInt(u32, file_contents[pos..][0..4], .big);
    pos += 4;

    const symbol_positions_size = @sizeOf(u32) * num_symbols;
    const symbol_positions_be = mem.bytesAsSlice(u32, file_contents[pos..][0..symbol_positions_size]);
    pos += symbol_positions_size;

    const sym_tab = file_contents[pos..][0 .. sym_tab_size - 4 - symbol_positions_size];
    pos += sym_tab.len;

    var toc: Toc = .empty;
    errdefer deinitToc(gpa, &toc);

    var sym_tab_pos: usize = 0;
    for (0..num_symbols) |i| {
        const name = mem.sliceTo(sym_tab[sym_tab_pos..], 0);
        sym_tab_pos += name.len + 1;
        if (name.len == 0) continue;

        const gop = try toc.getOrPut(gpa, name);
        if (!gop.found_existing) gop.value_ptr.* = .empty;
        try gop.value_ptr.append(gpa, std.mem.nativeToBig(u32, symbol_positions_be[i]));
    }

    const long_file_names: RelativeSlice = s: {
        const sub_header = mem.bytesAsValue(Header, file_contents[pos..][0..@sizeOf(Header)]);
        pos += @sizeOf(Header);

        if (!mem.eql(u8, &header.fmag, ARFMAG)) return error.BadHeaderDelimiter;
        if (!mem.eql(u8, sub_header.name[0..2], "//")) return error.MissingTableName;
        const table_size = try sub_header.parsedSize();

        break :s .{
            .off = @intCast(pos),
            .len = table_size,
        };
    };

    return .{
        .toc = toc,
        .long_file_names = long_file_names,
    };
}

/// From a given file offset, starts reading for a file header.
/// When found, parses the object file into an `Object` and returns it.
pub fn parseObject(
    archive: Archive,
    wasm: *Wasm,
    file_contents: []const u8,
    object_offset: u32,
    path: Path,
    host_name: Wasm.OptionalString,
    scratch_space: *Object.ScratchSpace,
    must_link: bool,
    gc_sections: bool,
) !Object {
    const header = mem.bytesAsValue(Header, file_contents[object_offset..][0..@sizeOf(Header)]);
    if (!mem.eql(u8, &header.fmag, ARFMAG)) return error.BadHeaderDelimiter;

    const name_or_index = try header.nameOrIndex();
    const object_name = switch (name_or_index) {
        .name => |name| name,
        .index => |index| n: {
            const long_file_names = file_contents[archive.long_file_names.off..][0..archive.long_file_names.len];
            const name = mem.sliceTo(long_file_names[index..], 0x0a);
            break :n mem.trimRight(u8, name, "/");
        },
    };

    const object_file_size = try header.parsedSize();
    const contents = file_contents[object_offset + @sizeOf(Header) ..][0..object_file_size];

    return Object.parse(wasm, contents, path, object_name, host_name, scratch_space, must_link, gc_sections);
}

const Archive = @This();

const builtin = @import("builtin");

const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const Path = std.Build.Cache.Path;

const Wasm = @import("../Wasm.zig");
const Object = @import("Object.zig");
