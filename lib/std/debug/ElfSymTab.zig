//! Similar to std.debug.Dwarf, but only using symbol info from an ELF file.

const ElfSymTab = @This();

endian: std.builtin.Endian,

base_address: usize,
mapped_memory: []align(std.heap.page_size_min) const u8,
sections: SectionArray,

/// Populated by `scanAllSymbols`.
symbol_list: std.ArrayListUnmanaged(Symbol) = .empty,

eh_frame_hdr: ?Dwarf.ExceptionFrameHeader = null,

pub const Symbol = struct {
    name: []const u8,
    start: u64,
    end: u64,
};

pub const OpenError = ScanError;

/// Initialize DWARF info. The caller has the responsibility to initialize most
/// the `Dwarf` fields before calling. `binary_mem` is the raw bytes of the
/// main binary file (not the secondary debug info file).
pub fn open(d: *ElfSymTab, gpa: Allocator) OpenError!void {
    try d.scanAllSymbols(gpa);
}

pub const ScanError = error{
    InvalidDebugInfo,
    MissingDebugInfo,
} || Allocator.Error || std.debug.FixedBufferReader.Error;

fn scanAllSymbols(ei: *ElfSymTab, allocator: Allocator) OpenError!void {
    const symtab: Section = ei.sections[@intFromEnum(Section.Id.symtab)].?;
    const strtab: Section = ei.sections[@intFromEnum(Section.Id.strtab)].?;

    const num_symbols = symtab.data.len / symtab.entry_size;
    const symbols = @as([*]const elf.Sym, @ptrCast(@alignCast(symtab.data.ptr)))[0..num_symbols];
    for (symbols) |symbol| {
        if (symbol.st_name == 0) continue;
        if (symbol.st_shndx == elf.SHN_UNDEF) continue;

        const symbol_name = getStringFromTable(strtab.data, symbol.st_name) orelse {
            // If it doesn't have a symbol name, we can't really use it for debugging purposes
            continue;
        };

        // TODO: Does SHN_ABS make a difference for this use case?
        // if (symbol.st_shndx == elf.SHN_ABS) {
        //     continue;
        // }

        // TODO: handle relocatable symbols in DYN type binaries
        try ei.symbol_list.append(allocator, .{
            .name = symbol_name,
            .start = symbol.st_value,
            .end = symbol.st_value + symbol.st_size,
        });
    }
}

pub const LoadError = error{
    InvalidDebugInfo,
    MissingDebugInfo,
    InvalidElfMagic,
    InvalidElfVersion,
    InvalidElfEndian,
    /// TODO: implement this and then remove this error code
    UnimplementedElfForeignEndian,
    /// TODO: implement this and then remove this error code
    UnimplementedElfType,
    /// The debug info may be valid but this implementation uses memory
    /// mapping which limits things to usize. If the target debug info is
    /// 64-bit and host is 32-bit, there may be debug info that is not
    /// supportable using this method.
    Overflow,

    PermissionDenied,
    LockedMemoryLimitExceeded,
    MemoryMappingNotSupported,
} || Allocator.Error || std.fs.File.OpenError || OpenError;

/// Reads symbol info from an already mapped ELF file.
pub fn load(
    gpa: Allocator,
    mapped_mem: []align(std.heap.page_size_min) const u8,
    expected_crc: ?u32,
    gnu_eh_frame: ?[]const u8,
) LoadError!ElfSymTab {
    if (expected_crc) |crc| if (crc != std.hash.crc.Crc32.hash(mapped_mem)) return error.InvalidDebugInfo;

    const hdr: *const elf.Ehdr = @ptrCast(&mapped_mem[0]);
    if (!mem.eql(u8, hdr.e_ident[0..4], elf.MAGIC)) return error.InvalidElfMagic;
    if (hdr.e_ident[elf.EI_VERSION] != 1) return error.InvalidElfVersion;

    const endian: std.builtin.Endian = switch (hdr.e_ident[elf.EI_DATA]) {
        elf.ELFDATA2LSB => .little,
        elf.ELFDATA2MSB => .big,
        else => return error.InvalidElfEndian,
    };
    if (endian != native_endian) return error.UnimplementedElfForeignEndian;
    if (hdr.e_type != .EXEC) return error.UnimplementedElfType;

    const shoff = hdr.e_shoff;
    const str_section_off = shoff + @as(u64, hdr.e_shentsize) * @as(u64, hdr.e_shstrndx);
    const str_shdr: *const elf.Shdr = @ptrCast(@alignCast(&mapped_mem[cast(usize, str_section_off) orelse return error.Overflow]));
    const header_strings = mapped_mem[str_shdr.sh_offset..][0..str_shdr.sh_size];
    const shdrs = @as(
        [*]const elf.Shdr,
        @ptrCast(@alignCast(&mapped_mem[shoff])),
    )[0..hdr.e_shnum];

    var sections: ElfSymTab.SectionArray = ElfSymTab.null_section_array;

    if (gnu_eh_frame) |eh_frame_hdr| {
        // This is a special case - pointer offsets inside .eh_frame_hdr
        // are encoded relative to its base address, so we must use the
        // version that is already memory mapped, and not the one that
        // will be mapped separately from the ELF file.
        sections[@intFromEnum(Section.Id.eh_frame_hdr)] = .{
            .entry_size = undefined,
            .data = eh_frame_hdr,
            .owned = false,
        };
    }

    for (shdrs) |*shdr| {
        if (shdr.sh_type == elf.SHT_NULL or shdr.sh_type == elf.SHT_NOBITS) continue;
        const name = mem.sliceTo(header_strings[shdr.sh_name..], 0);

        var section_index: ?usize = null;
        inline for (@typeInfo(ElfSymTab.Section.Id).@"enum".fields, 0..) |sect, i| {
            if (mem.eql(u8, "." ++ sect.name, name)) section_index = i;
        }
        if (section_index == null) continue;
        if (sections[section_index.?] != null) continue;

        const section_bytes = try chopSlice(mapped_mem, shdr.sh_offset, shdr.sh_size);
        sections[section_index.?] = if ((shdr.sh_flags & elf.SHF_COMPRESSED) > 0) blk: {
            var section_stream = std.io.fixedBufferStream(section_bytes);
            const section_reader = section_stream.reader();
            const chdr = section_reader.readStruct(elf.Chdr) catch continue;
            if (chdr.ch_type != .ZLIB) continue;

            var zlib_stream = std.compress.zlib.decompressor(section_reader);

            const decompressed_section = try gpa.alloc(u8, chdr.ch_size);
            errdefer gpa.free(decompressed_section);

            const read = zlib_stream.reader().readAll(decompressed_section) catch continue;
            assert(read == decompressed_section.len);

            break :blk .{
                .entry_size = shdr.sh_entsize,
                .data = decompressed_section,
                .virtual_address = shdr.sh_addr,
                .owned = true,
            };
        } else .{
            .entry_size = shdr.sh_entsize,
            .data = section_bytes,
            .virtual_address = shdr.sh_addr,
            .owned = false,
        };
    }

    const missing_debug_info =
        sections[@intFromEnum(ElfSymTab.Section.Id.strtab)] == null or
        sections[@intFromEnum(ElfSymTab.Section.Id.symtab)] == null;

    if (missing_debug_info) {
        return error.MissingDebugInfo;
    }

    var ei: ElfSymTab = .{
        .base_address = 0,
        .endian = endian,
        .sections = sections,
        .mapped_memory = mapped_mem,
    };

    try ElfSymTab.open(&ei, gpa);

    return ei;
}

pub fn deinit(self: *ElfSymTab, allocator: std.mem.Allocator) void {
    for (self.sections) |section_opt| {
        const s = section_opt orelse continue;
        allocator.free(s.data);
    }
    self.symbol_list.deinit(allocator);
}

const num_sections = std.enums.directEnumArrayLen(Section.Id, 0);
pub const SectionArray = [num_sections]?Section;
pub const null_section_array = [_]?Section{null} ** num_sections;

pub const Section = struct {
    entry_size: usize,
    data: []const u8,
    // Module-relative virtual address.
    // Only set if the section data was loaded from disk.
    virtual_address: ?usize = null,
    // If `data` is owned by this Dwarf.
    owned: bool,

    pub const Id = enum {
        strtab,
        symtab,
        eh_frame_hdr,
        eh_frame,
    };

    // For sections that are not memory mapped by the loader, this is an offset
    // from `data.ptr` to where the section would have been mapped. Otherwise,
    // `data` is directly backed by the section and the offset is zero.
    pub fn virtualOffset(self: Section, base_address: usize) i64 {
        return if (self.virtual_address) |va|
            @as(i64, @intCast(base_address + va)) -
                @as(i64, @intCast(@intFromPtr(self.data.ptr)))
        else
            0;
    }
};

pub fn section(ei: ElfSymTab, elf_section: Section.Id) ?[]const u8 {
    return if (ei.sections[@intFromEnum(elf_section)]) |s| s.data else null;
}

pub fn getSymbolAtAddress(self: *@This(), allocator: Allocator, address: usize) !std.debug.Symbol {
    _ = allocator;
    // Translate the VA into an address into this object
    const relocated_address = address - self.base_address;
    for (self.symbol_list.items) |symbol| {
        if (symbol.start <= relocated_address and relocated_address <= symbol.end) {
            return .{
                .name = symbol.name,
            };
        }
    }
    return .{};
}

pub fn scanAllUnwindInfo(this: *@This()) !void {
    const eh_frame_hdr = this.section(.eh_frame_hdr) orelse return;

    var fbr: FixedBufferReader = .{ .buf = eh_frame_hdr, .endian = native_endian };

    const version = try fbr.readByte();
    if (version != 1) return;

    const eh_frame_ptr_enc = try fbr.readByte();
    if (eh_frame_ptr_enc == EH.PE.omit) return;
    const fde_count_enc = try fbr.readByte();
    if (fde_count_enc == EH.PE.omit) return;
    const table_enc = try fbr.readByte();
    if (table_enc == EH.PE.omit) return;

    const eh_frame_ptr = cast(usize, try Dwarf.readEhPointer(&fbr, eh_frame_ptr_enc, @sizeOf(usize), .{
        .pc_rel_base = @intFromPtr(&eh_frame_hdr[fbr.pos]),
        .follow_indirect = true,
    }) orelse return Dwarf.bad()) orelse return Dwarf.bad();

    const fde_count = cast(usize, try Dwarf.readEhPointer(&fbr, fde_count_enc, @sizeOf(usize), .{
        .pc_rel_base = @intFromPtr(&eh_frame_hdr[fbr.pos]),
        .follow_indirect = true,
    }) orelse return Dwarf.bad()) orelse return Dwarf.bad();

    const entry_size = try Dwarf.ExceptionFrameHeader.entrySize(table_enc);
    const entries_len = fde_count * entry_size;
    if (entries_len > eh_frame_hdr.len - fbr.pos) return Dwarf.bad();

    this.eh_frame_hdr = .{
        .eh_frame_ptr = eh_frame_ptr,
        .table_enc = table_enc,
        .fde_count = fde_count,
        .entries = eh_frame_hdr[fbr.pos..][0..entries_len],
    };
}

fn getStringFromTable(string_table: []const u8, pos: usize) ?[]const u8 {
    if (pos == 0) return null;
    const section_name_end = std.mem.indexOfScalarPos(u8, string_table, pos, '\x00') orelse return null;
    return string_table[pos..section_name_end];
}

pub fn chopSlice(ptr: []const u8, offset: u64, size: u64) error{Overflow}![]const u8 {
    const start = cast(usize, offset) orelse return error.Overflow;
    const end = start + (cast(usize, size) orelse return error.Overflow);
    return ptr[start..end];
}

const builtin = @import("builtin");
const native_endian = builtin.cpu.arch.endian();

const std = @import("../std.zig");
const Allocator = std.mem.Allocator;
const elf = std.elf;
const mem = std.mem;
const assert = std.debug.assert;
const cast = std.math.cast;
const maxInt = std.math.maxInt;
const MemoryAccessor = std.debug.MemoryAccessor;
const FixedBufferReader = std.debug.FixedBufferReader;
const Dwarf = std.debug.Dwarf;
const DW = std.dwarf;
const EH = DW.EH;
