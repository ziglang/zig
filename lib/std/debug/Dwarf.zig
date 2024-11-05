//! Implements parsing, decoding, and caching of DWARF information.
//!
//! This API does not assume the current executable is itself the thing being
//! debugged, however, it does assume the debug info has the same CPU
//! architecture and OS as the current executable. It is planned to remove this
//! limitation.
//!
//! For unopinionated types and bits, see `std.dwarf`.

const builtin = @import("builtin");
const native_endian = builtin.cpu.arch.endian();

const std = @import("../std.zig");
const Allocator = std.mem.Allocator;
const elf = std.elf;
const mem = std.mem;
const DW = std.dwarf;
const AT = DW.AT;
const EH = DW.EH;
const FORM = DW.FORM;
const Format = DW.Format;
const RLE = DW.RLE;
const UT = DW.UT;
const assert = std.debug.assert;
const cast = std.math.cast;
const maxInt = std.math.maxInt;
const MemoryAccessor = std.debug.MemoryAccessor;
const Path = std.Build.Cache.Path;
const FixedBufferReader = std.debug.FixedBufferReader;

const Dwarf = @This();

pub const expression = @import("Dwarf/expression.zig");
pub const abi = @import("Dwarf/abi.zig");
pub const call_frame = @import("Dwarf/call_frame.zig");

/// Useful to temporarily enable while working on this file.
const debug_debug_mode = false;

endian: std.builtin.Endian,
sections: SectionArray = null_section_array,
is_macho: bool,

/// Filled later by the initializer
abbrev_table_list: std.ArrayListUnmanaged(Abbrev.Table) = .empty,
/// Filled later by the initializer
compile_unit_list: std.ArrayListUnmanaged(CompileUnit) = .empty,
/// Filled later by the initializer
func_list: std.ArrayListUnmanaged(Func) = .empty,

eh_frame_hdr: ?ExceptionFrameHeader = null,
/// These lookup tables are only used if `eh_frame_hdr` is null
cie_map: std.AutoArrayHashMapUnmanaged(u64, CommonInformationEntry) = .empty,
/// Sorted by start_pc
fde_list: std.ArrayListUnmanaged(FrameDescriptionEntry) = .empty,

/// Populated by `populateRanges`.
ranges: std.ArrayListUnmanaged(Range) = .empty,

pub const Range = struct {
    start: u64,
    end: u64,
    /// Index into `compile_unit_list`.
    compile_unit_index: usize,
};

pub const Section = struct {
    data: []const u8,
    // Module-relative virtual address.
    // Only set if the section data was loaded from disk.
    virtual_address: ?usize = null,
    // If `data` is owned by this Dwarf.
    owned: bool,

    pub const Id = enum {
        debug_info,
        debug_abbrev,
        debug_str,
        debug_str_offsets,
        debug_line,
        debug_line_str,
        debug_ranges,
        debug_loclists,
        debug_rnglists,
        debug_addr,
        debug_names,
        debug_frame,
        eh_frame,
        eh_frame_hdr,
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

pub const Abbrev = struct {
    code: u64,
    tag_id: u64,
    has_children: bool,
    attrs: []Attr,

    fn deinit(abbrev: *Abbrev, allocator: Allocator) void {
        allocator.free(abbrev.attrs);
        abbrev.* = undefined;
    }

    const Attr = struct {
        id: u64,
        form_id: u64,
        /// Only valid if form_id is .implicit_const
        payload: i64,
    };

    const Table = struct {
        // offset from .debug_abbrev
        offset: u64,
        abbrevs: []Abbrev,

        fn deinit(table: *Table, allocator: Allocator) void {
            for (table.abbrevs) |*abbrev| {
                abbrev.deinit(allocator);
            }
            allocator.free(table.abbrevs);
            table.* = undefined;
        }

        fn get(table: *const Table, abbrev_code: u64) ?*const Abbrev {
            return for (table.abbrevs) |*abbrev| {
                if (abbrev.code == abbrev_code) break abbrev;
            } else null;
        }
    };
};

pub const CompileUnit = struct {
    version: u16,
    format: Format,
    die: Die,
    pc_range: ?PcRange,

    str_offsets_base: usize,
    addr_base: usize,
    rnglists_base: usize,
    loclists_base: usize,
    frame_base: ?*const FormValue,

    src_loc_cache: ?SrcLocCache,

    pub const SrcLocCache = struct {
        line_table: LineTable,
        directories: []const FileEntry,
        files: []FileEntry,
        version: u16,

        pub const LineTable = std.AutoArrayHashMapUnmanaged(u64, LineEntry);

        pub const LineEntry = struct {
            line: u32,
            column: u32,
            /// Offset by 1 depending on whether Dwarf version is >= 5.
            file: u32,

            pub const invalid: LineEntry = .{
                .line = undefined,
                .column = undefined,
                .file = std.math.maxInt(u32),
            };

            pub fn isInvalid(le: LineEntry) bool {
                return le.file == invalid.file;
            }
        };

        pub fn findSource(slc: *const SrcLocCache, address: u64) !LineEntry {
            const index = std.sort.upperBound(u64, slc.line_table.keys(), address, struct {
                fn order(context: u64, item: u64) std.math.Order {
                    return std.math.order(context, item);
                }
            }.order);
            if (index == 0) return missing();
            return slc.line_table.values()[index - 1];
        }
    };
};

pub const FormValue = union(enum) {
    addr: u64,
    addrx: usize,
    block: []const u8,
    udata: u64,
    data16: *const [16]u8,
    sdata: i64,
    exprloc: []const u8,
    flag: bool,
    sec_offset: u64,
    ref: u64,
    ref_addr: u64,
    string: [:0]const u8,
    strp: u64,
    strx: usize,
    line_strp: u64,
    loclistx: u64,
    rnglistx: u64,

    fn getString(fv: FormValue, di: Dwarf) ![:0]const u8 {
        switch (fv) {
            .string => |s| return s,
            .strp => |off| return di.getString(off),
            .line_strp => |off| return di.getLineString(off),
            else => return bad(),
        }
    }

    fn getUInt(fv: FormValue, comptime U: type) !U {
        return switch (fv) {
            inline .udata,
            .sdata,
            .sec_offset,
            => |c| cast(U, c) orelse bad(),
            else => bad(),
        };
    }
};

pub const Die = struct {
    tag_id: u64,
    has_children: bool,
    attrs: []Attr,

    const Attr = struct {
        id: u64,
        value: FormValue,
    };

    fn deinit(self: *Die, allocator: Allocator) void {
        allocator.free(self.attrs);
        self.* = undefined;
    }

    fn getAttr(self: *const Die, id: u64) ?*const FormValue {
        for (self.attrs) |*attr| {
            if (attr.id == id) return &attr.value;
        }
        return null;
    }

    fn getAttrAddr(
        self: *const Die,
        di: *const Dwarf,
        id: u64,
        compile_unit: CompileUnit,
    ) error{ InvalidDebugInfo, MissingDebugInfo }!u64 {
        const form_value = self.getAttr(id) orelse return error.MissingDebugInfo;
        return switch (form_value.*) {
            .addr => |value| value,
            .addrx => |index| di.readDebugAddr(compile_unit, index),
            else => bad(),
        };
    }

    fn getAttrSecOffset(self: *const Die, id: u64) !u64 {
        const form_value = self.getAttr(id) orelse return error.MissingDebugInfo;
        return form_value.getUInt(u64);
    }

    fn getAttrUnsignedLe(self: *const Die, id: u64) !u64 {
        const form_value = self.getAttr(id) orelse return error.MissingDebugInfo;
        return switch (form_value.*) {
            .Const => |value| value.asUnsignedLe(),
            else => bad(),
        };
    }

    fn getAttrRef(self: *const Die, id: u64, unit_offset: u64, unit_len: u64) !u64 {
        const form_value = self.getAttr(id) orelse return error.MissingDebugInfo;
        return switch (form_value.*) {
            .ref => |offset| if (offset < unit_len) unit_offset + offset else bad(),
            .ref_addr => |addr| addr,
            else => bad(),
        };
    }

    pub fn getAttrString(
        self: *const Die,
        di: *Dwarf,
        id: u64,
        opt_str: ?[]const u8,
        compile_unit: CompileUnit,
    ) error{ InvalidDebugInfo, MissingDebugInfo }![]const u8 {
        const form_value = self.getAttr(id) orelse return error.MissingDebugInfo;
        switch (form_value.*) {
            .string => |value| return value,
            .strp => |offset| return di.getString(offset),
            .strx => |index| {
                const debug_str_offsets = di.section(.debug_str_offsets) orelse return bad();
                if (compile_unit.str_offsets_base == 0) return bad();
                switch (compile_unit.format) {
                    .@"32" => {
                        const byte_offset = compile_unit.str_offsets_base + 4 * index;
                        if (byte_offset + 4 > debug_str_offsets.len) return bad();
                        const offset = mem.readInt(u32, debug_str_offsets[byte_offset..][0..4], di.endian);
                        return getStringGeneric(opt_str, offset);
                    },
                    .@"64" => {
                        const byte_offset = compile_unit.str_offsets_base + 8 * index;
                        if (byte_offset + 8 > debug_str_offsets.len) return bad();
                        const offset = mem.readInt(u64, debug_str_offsets[byte_offset..][0..8], di.endian);
                        return getStringGeneric(opt_str, offset);
                    },
                }
            },
            .line_strp => |offset| return di.getLineString(offset),
            else => return bad(),
        }
    }
};

/// This represents the decoded .eh_frame_hdr header
pub const ExceptionFrameHeader = struct {
    eh_frame_ptr: usize,
    table_enc: u8,
    fde_count: usize,
    entries: []const u8,

    pub fn entrySize(table_enc: u8) !u8 {
        return switch (table_enc & EH.PE.type_mask) {
            EH.PE.udata2,
            EH.PE.sdata2,
            => 4,
            EH.PE.udata4,
            EH.PE.sdata4,
            => 8,
            EH.PE.udata8,
            EH.PE.sdata8,
            => 16,
            // This is a binary search table, so all entries must be the same length
            else => return bad(),
        };
    }

    fn isValidPtr(
        self: ExceptionFrameHeader,
        comptime T: type,
        ptr: usize,
        ma: *MemoryAccessor,
        eh_frame_len: ?usize,
    ) bool {
        if (eh_frame_len) |len| {
            return ptr >= self.eh_frame_ptr and ptr <= self.eh_frame_ptr + len - @sizeOf(T);
        } else {
            return ma.load(T, ptr) != null;
        }
    }

    /// Find an entry by binary searching the eh_frame_hdr section.
    ///
    /// Since the length of the eh_frame section (`eh_frame_len`) may not be known by the caller,
    /// MemoryAccessor will be used to verify readability of the header entries.
    /// If `eh_frame_len` is provided, then these checks can be skipped.
    pub fn findEntry(
        self: ExceptionFrameHeader,
        ma: *MemoryAccessor,
        eh_frame_len: ?usize,
        eh_frame_hdr_ptr: usize,
        pc: usize,
        cie: *CommonInformationEntry,
        fde: *FrameDescriptionEntry,
    ) !void {
        const entry_size = try entrySize(self.table_enc);

        var left: usize = 0;
        var len: usize = self.fde_count;

        var fbr: FixedBufferReader = .{ .buf = self.entries, .endian = native_endian };

        while (len > 1) {
            const mid = left + len / 2;

            fbr.pos = mid * entry_size;
            const pc_begin = try readEhPointer(&fbr, self.table_enc, @sizeOf(usize), .{
                .pc_rel_base = @intFromPtr(&self.entries[fbr.pos]),
                .follow_indirect = true,
                .data_rel_base = eh_frame_hdr_ptr,
            }) orelse return bad();

            if (pc < pc_begin) {
                len /= 2;
            } else {
                left = mid;
                if (pc == pc_begin) break;
                len -= len / 2;
            }
        }

        if (len == 0) return bad();
        fbr.pos = left * entry_size;

        // Read past the pc_begin field of the entry
        _ = try readEhPointer(&fbr, self.table_enc, @sizeOf(usize), .{
            .pc_rel_base = @intFromPtr(&self.entries[fbr.pos]),
            .follow_indirect = true,
            .data_rel_base = eh_frame_hdr_ptr,
        }) orelse return bad();

        const fde_ptr = cast(usize, try readEhPointer(&fbr, self.table_enc, @sizeOf(usize), .{
            .pc_rel_base = @intFromPtr(&self.entries[fbr.pos]),
            .follow_indirect = true,
            .data_rel_base = eh_frame_hdr_ptr,
        }) orelse return bad()) orelse return bad();

        if (fde_ptr < self.eh_frame_ptr) return bad();

        // Even if eh_frame_len is not specified, all ranges accssed are checked via MemoryAccessor
        const eh_frame = @as([*]const u8, @ptrFromInt(self.eh_frame_ptr))[0 .. eh_frame_len orelse maxInt(u32)];

        const fde_offset = fde_ptr - self.eh_frame_ptr;
        var eh_frame_fbr: FixedBufferReader = .{
            .buf = eh_frame,
            .pos = fde_offset,
            .endian = native_endian,
        };

        const fde_entry_header = try EntryHeader.read(&eh_frame_fbr, if (eh_frame_len == null) ma else null, .eh_frame);
        if (fde_entry_header.entry_bytes.len > 0 and !self.isValidPtr(u8, @intFromPtr(&fde_entry_header.entry_bytes[fde_entry_header.entry_bytes.len - 1]), ma, eh_frame_len)) return bad();
        if (fde_entry_header.type != .fde) return bad();

        // CIEs always come before FDEs (the offset is a subtraction), so we can assume this memory is readable
        const cie_offset = fde_entry_header.type.fde;
        try eh_frame_fbr.seekTo(cie_offset);
        const cie_entry_header = try EntryHeader.read(&eh_frame_fbr, if (eh_frame_len == null) ma else null, .eh_frame);
        if (cie_entry_header.entry_bytes.len > 0 and !self.isValidPtr(u8, @intFromPtr(&cie_entry_header.entry_bytes[cie_entry_header.entry_bytes.len - 1]), ma, eh_frame_len)) return bad();
        if (cie_entry_header.type != .cie) return bad();

        cie.* = try CommonInformationEntry.parse(
            cie_entry_header.entry_bytes,
            0,
            true,
            cie_entry_header.format,
            .eh_frame,
            cie_entry_header.length_offset,
            @sizeOf(usize),
            native_endian,
        );

        fde.* = try FrameDescriptionEntry.parse(
            fde_entry_header.entry_bytes,
            0,
            true,
            cie.*,
            @sizeOf(usize),
            native_endian,
        );
    }
};

pub const EntryHeader = struct {
    /// Offset of the length field in the backing buffer
    length_offset: usize,
    format: Format,
    type: union(enum) {
        cie,
        /// Value is the offset of the corresponding CIE
        fde: u64,
        terminator,
    },
    /// The entry's contents, not including the ID field
    entry_bytes: []const u8,

    /// The length of the entry including the ID field, but not the length field itself
    pub fn entryLength(self: EntryHeader) usize {
        return self.entry_bytes.len + @as(u8, if (self.format == .@"64") 8 else 4);
    }

    /// Reads a header for either an FDE or a CIE, then advances the fbr to the position after the trailing structure.
    /// `fbr` must be a FixedBufferReader backed by either the .eh_frame or .debug_frame sections.
    pub fn read(
        fbr: *FixedBufferReader,
        opt_ma: ?*MemoryAccessor,
        dwarf_section: Section.Id,
    ) !EntryHeader {
        assert(dwarf_section == .eh_frame or dwarf_section == .debug_frame);

        const length_offset = fbr.pos;
        const unit_header = try readUnitHeader(fbr, opt_ma);
        const unit_length = cast(usize, unit_header.unit_length) orelse return bad();
        if (unit_length == 0) return .{
            .length_offset = length_offset,
            .format = unit_header.format,
            .type = .terminator,
            .entry_bytes = &.{},
        };
        const start_offset = fbr.pos;
        const end_offset = start_offset + unit_length;
        defer fbr.pos = end_offset;

        const id = try if (opt_ma) |ma|
            fbr.readAddressChecked(unit_header.format, ma)
        else
            fbr.readAddress(unit_header.format);
        const entry_bytes = fbr.buf[fbr.pos..end_offset];
        const cie_id: u64 = switch (dwarf_section) {
            .eh_frame => CommonInformationEntry.eh_id,
            .debug_frame => switch (unit_header.format) {
                .@"32" => CommonInformationEntry.dwarf32_id,
                .@"64" => CommonInformationEntry.dwarf64_id,
            },
            else => unreachable,
        };

        return .{
            .length_offset = length_offset,
            .format = unit_header.format,
            .type = if (id == cie_id) .cie else .{ .fde = switch (dwarf_section) {
                .eh_frame => try std.math.sub(u64, start_offset, id),
                .debug_frame => id,
                else => unreachable,
            } },
            .entry_bytes = entry_bytes,
        };
    }
};

pub const CommonInformationEntry = struct {
    // Used in .eh_frame
    pub const eh_id = 0;

    // Used in .debug_frame (DWARF32)
    pub const dwarf32_id = maxInt(u32);

    // Used in .debug_frame (DWARF64)
    pub const dwarf64_id = maxInt(u64);

    // Offset of the length field of this entry in the eh_frame section.
    // This is the key that FDEs use to reference CIEs.
    length_offset: u64,
    version: u8,
    address_size: u8,
    format: Format,

    // Only present in version 4
    segment_selector_size: ?u8,

    code_alignment_factor: u32,
    data_alignment_factor: i32,
    return_address_register: u8,

    aug_str: []const u8,
    aug_data: []const u8,
    lsda_pointer_enc: u8,
    personality_enc: ?u8,
    personality_routine_pointer: ?u64,
    fde_pointer_enc: u8,
    initial_instructions: []const u8,

    pub fn isSignalFrame(self: CommonInformationEntry) bool {
        for (self.aug_str) |c| if (c == 'S') return true;
        return false;
    }

    pub fn addressesSignedWithBKey(self: CommonInformationEntry) bool {
        for (self.aug_str) |c| if (c == 'B') return true;
        return false;
    }

    pub fn mteTaggedFrame(self: CommonInformationEntry) bool {
        for (self.aug_str) |c| if (c == 'G') return true;
        return false;
    }

    /// This function expects to read the CIE starting with the version field.
    /// The returned struct references memory backed by cie_bytes.
    ///
    /// See the FrameDescriptionEntry.parse documentation for the description
    /// of `pc_rel_offset` and `is_runtime`.
    ///
    /// `length_offset` specifies the offset of this CIE's length field in the
    /// .eh_frame / .debug_frame section.
    pub fn parse(
        cie_bytes: []const u8,
        pc_rel_offset: i64,
        is_runtime: bool,
        format: Format,
        dwarf_section: Section.Id,
        length_offset: u64,
        addr_size_bytes: u8,
        endian: std.builtin.Endian,
    ) !CommonInformationEntry {
        if (addr_size_bytes > 8) return error.UnsupportedAddrSize;

        var fbr: FixedBufferReader = .{ .buf = cie_bytes, .endian = endian };

        const version = try fbr.readByte();
        switch (dwarf_section) {
            .eh_frame => if (version != 1 and version != 3) return error.UnsupportedDwarfVersion,
            .debug_frame => if (version != 4) return error.UnsupportedDwarfVersion,
            else => return error.UnsupportedDwarfSection,
        }

        var has_eh_data = false;
        var has_aug_data = false;

        var aug_str_len: usize = 0;
        const aug_str_start = fbr.pos;
        var aug_byte = try fbr.readByte();
        while (aug_byte != 0) : (aug_byte = try fbr.readByte()) {
            switch (aug_byte) {
                'z' => {
                    if (aug_str_len != 0) return bad();
                    has_aug_data = true;
                },
                'e' => {
                    if (has_aug_data or aug_str_len != 0) return bad();
                    if (try fbr.readByte() != 'h') return bad();
                    has_eh_data = true;
                },
                else => if (has_eh_data) return bad(),
            }

            aug_str_len += 1;
        }

        if (has_eh_data) {
            // legacy data created by older versions of gcc - unsupported here
            for (0..addr_size_bytes) |_| _ = try fbr.readByte();
        }

        const address_size = if (version == 4) try fbr.readByte() else addr_size_bytes;
        const segment_selector_size = if (version == 4) try fbr.readByte() else null;

        const code_alignment_factor = try fbr.readUleb128(u32);
        const data_alignment_factor = try fbr.readIleb128(i32);
        const return_address_register = if (version == 1) try fbr.readByte() else try fbr.readUleb128(u8);

        var lsda_pointer_enc: u8 = EH.PE.omit;
        var personality_enc: ?u8 = null;
        var personality_routine_pointer: ?u64 = null;
        var fde_pointer_enc: u8 = EH.PE.absptr;

        var aug_data: []const u8 = &[_]u8{};
        const aug_str = if (has_aug_data) blk: {
            const aug_data_len = try fbr.readUleb128(usize);
            const aug_data_start = fbr.pos;
            aug_data = cie_bytes[aug_data_start..][0..aug_data_len];

            const aug_str = cie_bytes[aug_str_start..][0..aug_str_len];
            for (aug_str[1..]) |byte| {
                switch (byte) {
                    'L' => {
                        lsda_pointer_enc = try fbr.readByte();
                    },
                    'P' => {
                        personality_enc = try fbr.readByte();
                        personality_routine_pointer = try readEhPointer(&fbr, personality_enc.?, addr_size_bytes, .{
                            .pc_rel_base = try pcRelBase(@intFromPtr(&cie_bytes[fbr.pos]), pc_rel_offset),
                            .follow_indirect = is_runtime,
                        });
                    },
                    'R' => {
                        fde_pointer_enc = try fbr.readByte();
                    },
                    'S', 'B', 'G' => {},
                    else => return bad(),
                }
            }

            // aug_data_len can include padding so the CIE ends on an address boundary
            fbr.pos = aug_data_start + aug_data_len;
            break :blk aug_str;
        } else &[_]u8{};

        const initial_instructions = cie_bytes[fbr.pos..];
        return .{
            .length_offset = length_offset,
            .version = version,
            .address_size = address_size,
            .format = format,
            .segment_selector_size = segment_selector_size,
            .code_alignment_factor = code_alignment_factor,
            .data_alignment_factor = data_alignment_factor,
            .return_address_register = return_address_register,
            .aug_str = aug_str,
            .aug_data = aug_data,
            .lsda_pointer_enc = lsda_pointer_enc,
            .personality_enc = personality_enc,
            .personality_routine_pointer = personality_routine_pointer,
            .fde_pointer_enc = fde_pointer_enc,
            .initial_instructions = initial_instructions,
        };
    }
};

pub const FrameDescriptionEntry = struct {
    // Offset into eh_frame where the CIE for this FDE is stored
    cie_length_offset: u64,

    pc_begin: u64,
    pc_range: u64,
    lsda_pointer: ?u64,
    aug_data: []const u8,
    instructions: []const u8,

    /// This function expects to read the FDE starting at the PC Begin field.
    /// The returned struct references memory backed by `fde_bytes`.
    ///
    /// `pc_rel_offset` specifies an offset to be applied to pc_rel_base values
    /// used when decoding pointers. This should be set to zero if fde_bytes is
    /// backed by the memory of a .eh_frame / .debug_frame section in the running executable.
    /// Otherwise, it should be the relative offset to translate addresses from
    /// where the section is currently stored in memory, to where it *would* be
    /// stored at runtime: section base addr - backing data base ptr.
    ///
    /// Similarly, `is_runtime` specifies this function is being called on a runtime
    /// section, and so indirect pointers can be followed.
    pub fn parse(
        fde_bytes: []const u8,
        pc_rel_offset: i64,
        is_runtime: bool,
        cie: CommonInformationEntry,
        addr_size_bytes: u8,
        endian: std.builtin.Endian,
    ) !FrameDescriptionEntry {
        if (addr_size_bytes > 8) return error.InvalidAddrSize;

        var fbr: FixedBufferReader = .{ .buf = fde_bytes, .endian = endian };

        const pc_begin = try readEhPointer(&fbr, cie.fde_pointer_enc, addr_size_bytes, .{
            .pc_rel_base = try pcRelBase(@intFromPtr(&fde_bytes[fbr.pos]), pc_rel_offset),
            .follow_indirect = is_runtime,
        }) orelse return bad();

        const pc_range = try readEhPointer(&fbr, cie.fde_pointer_enc, addr_size_bytes, .{
            .pc_rel_base = 0,
            .follow_indirect = false,
        }) orelse return bad();

        var aug_data: []const u8 = &[_]u8{};
        const lsda_pointer = if (cie.aug_str.len > 0) blk: {
            const aug_data_len = try fbr.readUleb128(usize);
            const aug_data_start = fbr.pos;
            aug_data = fde_bytes[aug_data_start..][0..aug_data_len];

            const lsda_pointer = if (cie.lsda_pointer_enc != EH.PE.omit)
                try readEhPointer(&fbr, cie.lsda_pointer_enc, addr_size_bytes, .{
                    .pc_rel_base = try pcRelBase(@intFromPtr(&fde_bytes[fbr.pos]), pc_rel_offset),
                    .follow_indirect = is_runtime,
                })
            else
                null;

            fbr.pos = aug_data_start + aug_data_len;
            break :blk lsda_pointer;
        } else null;

        const instructions = fde_bytes[fbr.pos..];
        return .{
            .cie_length_offset = cie.length_offset,
            .pc_begin = pc_begin,
            .pc_range = pc_range,
            .lsda_pointer = lsda_pointer,
            .aug_data = aug_data,
            .instructions = instructions,
        };
    }
};

const num_sections = std.enums.directEnumArrayLen(Section.Id, 0);
pub const SectionArray = [num_sections]?Section;
pub const null_section_array = [_]?Section{null} ** num_sections;

pub const OpenError = ScanError;

/// Initialize DWARF info. The caller has the responsibility to initialize most
/// the `Dwarf` fields before calling. `binary_mem` is the raw bytes of the
/// main binary file (not the secondary debug info file).
pub fn open(d: *Dwarf, gpa: Allocator) OpenError!void {
    try d.scanAllFunctions(gpa);
    try d.scanAllCompileUnits(gpa);
}

const PcRange = struct {
    start: u64,
    end: u64,
};

const Func = struct {
    pc_range: ?PcRange,
    name: ?[]const u8,
};

pub fn section(di: Dwarf, dwarf_section: Section.Id) ?[]const u8 {
    return if (di.sections[@intFromEnum(dwarf_section)]) |s| s.data else null;
}

pub fn sectionVirtualOffset(di: Dwarf, dwarf_section: Section.Id, base_address: usize) ?i64 {
    return if (di.sections[@intFromEnum(dwarf_section)]) |s| s.virtualOffset(base_address) else null;
}

pub fn deinit(di: *Dwarf, gpa: Allocator) void {
    for (di.sections) |opt_section| {
        if (opt_section) |s| if (s.owned) gpa.free(s.data);
    }
    for (di.abbrev_table_list.items) |*abbrev| {
        abbrev.deinit(gpa);
    }
    di.abbrev_table_list.deinit(gpa);
    for (di.compile_unit_list.items) |*cu| {
        if (cu.src_loc_cache) |*slc| {
            slc.line_table.deinit(gpa);
            gpa.free(slc.directories);
            gpa.free(slc.files);
        }
        cu.die.deinit(gpa);
    }
    di.compile_unit_list.deinit(gpa);
    di.func_list.deinit(gpa);
    di.cie_map.deinit(gpa);
    di.fde_list.deinit(gpa);
    di.ranges.deinit(gpa);
    di.* = undefined;
}

pub fn getSymbolName(di: *Dwarf, address: u64) ?[]const u8 {
    for (di.func_list.items) |*func| {
        if (func.pc_range) |range| {
            if (address >= range.start and address < range.end) {
                return func.name;
            }
        }
    }

    return null;
}

pub const ScanError = error{
    InvalidDebugInfo,
    MissingDebugInfo,
} || Allocator.Error || std.debug.FixedBufferReader.Error;

fn scanAllFunctions(di: *Dwarf, allocator: Allocator) ScanError!void {
    var fbr: FixedBufferReader = .{ .buf = di.section(.debug_info).?, .endian = di.endian };
    var this_unit_offset: u64 = 0;

    while (this_unit_offset < fbr.buf.len) {
        try fbr.seekTo(this_unit_offset);

        const unit_header = try readUnitHeader(&fbr, null);
        if (unit_header.unit_length == 0) return;
        const next_offset = unit_header.header_length + unit_header.unit_length;

        const version = try fbr.readInt(u16);
        if (version < 2 or version > 5) return bad();

        var address_size: u8 = undefined;
        var debug_abbrev_offset: u64 = undefined;
        if (version >= 5) {
            const unit_type = try fbr.readInt(u8);
            if (unit_type != DW.UT.compile) return bad();
            address_size = try fbr.readByte();
            debug_abbrev_offset = try fbr.readAddress(unit_header.format);
        } else {
            debug_abbrev_offset = try fbr.readAddress(unit_header.format);
            address_size = try fbr.readByte();
        }
        if (address_size != @sizeOf(usize)) return bad();

        const abbrev_table = try di.getAbbrevTable(allocator, debug_abbrev_offset);

        var max_attrs: usize = 0;
        var zig_padding_abbrev_code: u7 = 0;
        for (abbrev_table.abbrevs) |abbrev| {
            max_attrs = @max(max_attrs, abbrev.attrs.len);
            if (cast(u7, abbrev.code)) |code| {
                if (abbrev.tag_id == DW.TAG.ZIG_padding and
                    !abbrev.has_children and
                    abbrev.attrs.len == 0)
                {
                    zig_padding_abbrev_code = code;
                }
            }
        }
        const attrs_buf = try allocator.alloc(Die.Attr, max_attrs * 3);
        defer allocator.free(attrs_buf);
        var attrs_bufs: [3][]Die.Attr = undefined;
        for (&attrs_bufs, 0..) |*buf, index| buf.* = attrs_buf[index * max_attrs ..][0..max_attrs];

        const next_unit_pos = this_unit_offset + next_offset;

        var compile_unit: CompileUnit = .{
            .version = version,
            .format = unit_header.format,
            .die = undefined,
            .pc_range = null,

            .str_offsets_base = 0,
            .addr_base = 0,
            .rnglists_base = 0,
            .loclists_base = 0,
            .frame_base = null,
            .src_loc_cache = null,
        };

        while (true) {
            fbr.pos = std.mem.indexOfNonePos(u8, fbr.buf, fbr.pos, &.{
                zig_padding_abbrev_code, 0,
            }) orelse fbr.buf.len;
            if (fbr.pos >= next_unit_pos) break;
            var die_obj = (try parseDie(
                &fbr,
                attrs_bufs[0],
                abbrev_table,
                unit_header.format,
            )) orelse continue;

            switch (die_obj.tag_id) {
                DW.TAG.compile_unit => {
                    compile_unit.die = die_obj;
                    compile_unit.die.attrs = attrs_bufs[1][0..die_obj.attrs.len];
                    @memcpy(compile_unit.die.attrs, die_obj.attrs);

                    compile_unit.str_offsets_base = if (die_obj.getAttr(AT.str_offsets_base)) |fv| try fv.getUInt(usize) else 0;
                    compile_unit.addr_base = if (die_obj.getAttr(AT.addr_base)) |fv| try fv.getUInt(usize) else 0;
                    compile_unit.rnglists_base = if (die_obj.getAttr(AT.rnglists_base)) |fv| try fv.getUInt(usize) else 0;
                    compile_unit.loclists_base = if (die_obj.getAttr(AT.loclists_base)) |fv| try fv.getUInt(usize) else 0;
                    compile_unit.frame_base = die_obj.getAttr(AT.frame_base);
                },
                DW.TAG.subprogram, DW.TAG.inlined_subroutine, DW.TAG.subroutine, DW.TAG.entry_point => {
                    const fn_name = x: {
                        var this_die_obj = die_obj;
                        // Prevent endless loops
                        for (0..3) |_| {
                            if (this_die_obj.getAttr(AT.name)) |_| {
                                break :x try this_die_obj.getAttrString(di, AT.name, di.section(.debug_str), compile_unit);
                            } else if (this_die_obj.getAttr(AT.abstract_origin)) |_| {
                                const after_die_offset = fbr.pos;
                                defer fbr.pos = after_die_offset;

                                // Follow the DIE it points to and repeat
                                const ref_offset = try this_die_obj.getAttrRef(AT.abstract_origin, this_unit_offset, next_offset);
                                try fbr.seekTo(ref_offset);
                                this_die_obj = (try parseDie(
                                    &fbr,
                                    attrs_bufs[2],
                                    abbrev_table, // wrong abbrev table for different cu
                                    unit_header.format,
                                )) orelse return bad();
                            } else if (this_die_obj.getAttr(AT.specification)) |_| {
                                const after_die_offset = fbr.pos;
                                defer fbr.pos = after_die_offset;

                                // Follow the DIE it points to and repeat
                                const ref_offset = try this_die_obj.getAttrRef(AT.specification, this_unit_offset, next_offset);
                                try fbr.seekTo(ref_offset);
                                this_die_obj = (try parseDie(
                                    &fbr,
                                    attrs_bufs[2],
                                    abbrev_table, // wrong abbrev table for different cu
                                    unit_header.format,
                                )) orelse return bad();
                            } else {
                                break :x null;
                            }
                        }

                        break :x null;
                    };

                    var range_added = if (die_obj.getAttrAddr(di, AT.low_pc, compile_unit)) |low_pc| blk: {
                        if (die_obj.getAttr(AT.high_pc)) |high_pc_value| {
                            const pc_end = switch (high_pc_value.*) {
                                .addr => |value| value,
                                .udata => |offset| low_pc + offset,
                                else => return bad(),
                            };

                            try di.func_list.append(allocator, .{
                                .name = fn_name,
                                .pc_range = .{
                                    .start = low_pc,
                                    .end = pc_end,
                                },
                            });

                            break :blk true;
                        }

                        break :blk false;
                    } else |err| blk: {
                        if (err != error.MissingDebugInfo) return err;
                        break :blk false;
                    };

                    if (die_obj.getAttr(AT.ranges)) |ranges_value| blk: {
                        var iter = DebugRangeIterator.init(ranges_value, di, &compile_unit) catch |err| {
                            if (err != error.MissingDebugInfo) return err;
                            break :blk;
                        };

                        while (try iter.next()) |range| {
                            range_added = true;
                            try di.func_list.append(allocator, .{
                                .name = fn_name,
                                .pc_range = .{
                                    .start = range.start,
                                    .end = range.end,
                                },
                            });
                        }
                    }

                    if (fn_name != null and !range_added) {
                        try di.func_list.append(allocator, .{
                            .name = fn_name,
                            .pc_range = null,
                        });
                    }
                },
                else => {},
            }
        }

        this_unit_offset += next_offset;
    }
}

fn scanAllCompileUnits(di: *Dwarf, allocator: Allocator) ScanError!void {
    var fbr: FixedBufferReader = .{ .buf = di.section(.debug_info).?, .endian = di.endian };
    var this_unit_offset: u64 = 0;

    var attrs_buf = std.ArrayList(Die.Attr).init(allocator);
    defer attrs_buf.deinit();

    while (this_unit_offset < fbr.buf.len) {
        try fbr.seekTo(this_unit_offset);

        const unit_header = try readUnitHeader(&fbr, null);
        if (unit_header.unit_length == 0) return;
        const next_offset = unit_header.header_length + unit_header.unit_length;

        const version = try fbr.readInt(u16);
        if (version < 2 or version > 5) return bad();

        var address_size: u8 = undefined;
        var debug_abbrev_offset: u64 = undefined;
        if (version >= 5) {
            const unit_type = try fbr.readInt(u8);
            if (unit_type != UT.compile) return bad();
            address_size = try fbr.readByte();
            debug_abbrev_offset = try fbr.readAddress(unit_header.format);
        } else {
            debug_abbrev_offset = try fbr.readAddress(unit_header.format);
            address_size = try fbr.readByte();
        }
        if (address_size != @sizeOf(usize)) return bad();

        const abbrev_table = try di.getAbbrevTable(allocator, debug_abbrev_offset);

        var max_attrs: usize = 0;
        for (abbrev_table.abbrevs) |abbrev| {
            max_attrs = @max(max_attrs, abbrev.attrs.len);
        }
        try attrs_buf.resize(max_attrs);

        var compile_unit_die = (try parseDie(
            &fbr,
            attrs_buf.items,
            abbrev_table,
            unit_header.format,
        )) orelse return bad();

        if (compile_unit_die.tag_id != DW.TAG.compile_unit) return bad();

        compile_unit_die.attrs = try allocator.dupe(Die.Attr, compile_unit_die.attrs);

        var compile_unit: CompileUnit = .{
            .version = version,
            .format = unit_header.format,
            .pc_range = null,
            .die = compile_unit_die,
            .str_offsets_base = if (compile_unit_die.getAttr(AT.str_offsets_base)) |fv| try fv.getUInt(usize) else 0,
            .addr_base = if (compile_unit_die.getAttr(AT.addr_base)) |fv| try fv.getUInt(usize) else 0,
            .rnglists_base = if (compile_unit_die.getAttr(AT.rnglists_base)) |fv| try fv.getUInt(usize) else 0,
            .loclists_base = if (compile_unit_die.getAttr(AT.loclists_base)) |fv| try fv.getUInt(usize) else 0,
            .frame_base = compile_unit_die.getAttr(AT.frame_base),
            .src_loc_cache = null,
        };

        compile_unit.pc_range = x: {
            if (compile_unit_die.getAttrAddr(di, AT.low_pc, compile_unit)) |low_pc| {
                if (compile_unit_die.getAttr(AT.high_pc)) |high_pc_value| {
                    const pc_end = switch (high_pc_value.*) {
                        .addr => |value| value,
                        .udata => |offset| low_pc + offset,
                        else => return bad(),
                    };
                    break :x PcRange{
                        .start = low_pc,
                        .end = pc_end,
                    };
                } else {
                    break :x null;
                }
            } else |err| {
                if (err != error.MissingDebugInfo) return err;
                break :x null;
            }
        };

        try di.compile_unit_list.append(allocator, compile_unit);

        this_unit_offset += next_offset;
    }
}

pub fn populateRanges(d: *Dwarf, gpa: Allocator) ScanError!void {
    assert(d.ranges.items.len == 0);

    for (d.compile_unit_list.items, 0..) |*cu, cu_index| {
        if (cu.pc_range) |range| {
            try d.ranges.append(gpa, .{
                .start = range.start,
                .end = range.end,
                .compile_unit_index = cu_index,
            });
            continue;
        }
        const ranges_value = cu.die.getAttr(AT.ranges) orelse continue;
        var iter = DebugRangeIterator.init(ranges_value, d, cu) catch continue;
        while (try iter.next()) |range| {
            // Not sure why LLVM thinks it's OK to emit these...
            if (range.start == range.end) continue;

            try d.ranges.append(gpa, .{
                .start = range.start,
                .end = range.end,
                .compile_unit_index = cu_index,
            });
        }
    }

    std.mem.sortUnstable(Range, d.ranges.items, {}, struct {
        pub fn lessThan(ctx: void, a: Range, b: Range) bool {
            _ = ctx;
            return a.start < b.start;
        }
    }.lessThan);
}

const DebugRangeIterator = struct {
    base_address: u64,
    section_type: Section.Id,
    di: *const Dwarf,
    compile_unit: *const CompileUnit,
    fbr: FixedBufferReader,

    pub fn init(ranges_value: *const FormValue, di: *const Dwarf, compile_unit: *const CompileUnit) !@This() {
        const section_type = if (compile_unit.version >= 5) Section.Id.debug_rnglists else Section.Id.debug_ranges;
        const debug_ranges = di.section(section_type) orelse return error.MissingDebugInfo;

        const ranges_offset = switch (ranges_value.*) {
            .sec_offset, .udata => |off| off,
            .rnglistx => |idx| off: {
                switch (compile_unit.format) {
                    .@"32" => {
                        const offset_loc = @as(usize, @intCast(compile_unit.rnglists_base + 4 * idx));
                        if (offset_loc + 4 > debug_ranges.len) return bad();
                        const offset = mem.readInt(u32, debug_ranges[offset_loc..][0..4], di.endian);
                        break :off compile_unit.rnglists_base + offset;
                    },
                    .@"64" => {
                        const offset_loc = @as(usize, @intCast(compile_unit.rnglists_base + 8 * idx));
                        if (offset_loc + 8 > debug_ranges.len) return bad();
                        const offset = mem.readInt(u64, debug_ranges[offset_loc..][0..8], di.endian);
                        break :off compile_unit.rnglists_base + offset;
                    },
                }
            },
            else => return bad(),
        };

        // All the addresses in the list are relative to the value
        // specified by DW_AT.low_pc or to some other value encoded
        // in the list itself.
        // If no starting value is specified use zero.
        const base_address = compile_unit.die.getAttrAddr(di, AT.low_pc, compile_unit.*) catch |err| switch (err) {
            error.MissingDebugInfo => 0,
            else => return err,
        };

        return .{
            .base_address = base_address,
            .section_type = section_type,
            .di = di,
            .compile_unit = compile_unit,
            .fbr = .{
                .buf = debug_ranges,
                .pos = cast(usize, ranges_offset) orelse return bad(),
                .endian = di.endian,
            },
        };
    }

    // Returns the next range in the list, or null if the end was reached.
    pub fn next(self: *@This()) !?PcRange {
        switch (self.section_type) {
            .debug_rnglists => {
                const kind = try self.fbr.readByte();
                switch (kind) {
                    RLE.end_of_list => return null,
                    RLE.base_addressx => {
                        const index = try self.fbr.readUleb128(usize);
                        self.base_address = try self.di.readDebugAddr(self.compile_unit.*, index);
                        return try self.next();
                    },
                    RLE.startx_endx => {
                        const start_index = try self.fbr.readUleb128(usize);
                        const start_addr = try self.di.readDebugAddr(self.compile_unit.*, start_index);

                        const end_index = try self.fbr.readUleb128(usize);
                        const end_addr = try self.di.readDebugAddr(self.compile_unit.*, end_index);

                        return .{
                            .start = start_addr,
                            .end = end_addr,
                        };
                    },
                    RLE.startx_length => {
                        const start_index = try self.fbr.readUleb128(usize);
                        const start_addr = try self.di.readDebugAddr(self.compile_unit.*, start_index);

                        const len = try self.fbr.readUleb128(usize);
                        const end_addr = start_addr + len;

                        return .{
                            .start = start_addr,
                            .end = end_addr,
                        };
                    },
                    RLE.offset_pair => {
                        const start_addr = try self.fbr.readUleb128(usize);
                        const end_addr = try self.fbr.readUleb128(usize);

                        // This is the only kind that uses the base address
                        return .{
                            .start = self.base_address + start_addr,
                            .end = self.base_address + end_addr,
                        };
                    },
                    RLE.base_address => {
                        self.base_address = try self.fbr.readInt(usize);
                        return try self.next();
                    },
                    RLE.start_end => {
                        const start_addr = try self.fbr.readInt(usize);
                        const end_addr = try self.fbr.readInt(usize);

                        return .{
                            .start = start_addr,
                            .end = end_addr,
                        };
                    },
                    RLE.start_length => {
                        const start_addr = try self.fbr.readInt(usize);
                        const len = try self.fbr.readUleb128(usize);
                        const end_addr = start_addr + len;

                        return .{
                            .start = start_addr,
                            .end = end_addr,
                        };
                    },
                    else => return bad(),
                }
            },
            .debug_ranges => {
                const start_addr = try self.fbr.readInt(usize);
                const end_addr = try self.fbr.readInt(usize);
                if (start_addr == 0 and end_addr == 0) return null;

                // This entry selects a new value for the base address
                if (start_addr == maxInt(usize)) {
                    self.base_address = end_addr;
                    return try self.next();
                }

                return .{
                    .start = self.base_address + start_addr,
                    .end = self.base_address + end_addr,
                };
            },
            else => unreachable,
        }
    }
};

/// TODO: change this to binary searching the sorted compile unit list
pub fn findCompileUnit(di: *const Dwarf, target_address: u64) !*CompileUnit {
    for (di.compile_unit_list.items) |*compile_unit| {
        if (compile_unit.pc_range) |range| {
            if (target_address >= range.start and target_address < range.end) return compile_unit;
        }

        const ranges_value = compile_unit.die.getAttr(AT.ranges) orelse continue;
        var iter = DebugRangeIterator.init(ranges_value, di, compile_unit) catch continue;
        while (try iter.next()) |range| {
            if (target_address >= range.start and target_address < range.end) return compile_unit;
        }
    }

    return missing();
}

/// Gets an already existing AbbrevTable given the abbrev_offset, or if not found,
/// seeks in the stream and parses it.
fn getAbbrevTable(di: *Dwarf, allocator: Allocator, abbrev_offset: u64) !*const Abbrev.Table {
    for (di.abbrev_table_list.items) |*table| {
        if (table.offset == abbrev_offset) {
            return table;
        }
    }
    try di.abbrev_table_list.append(
        allocator,
        try di.parseAbbrevTable(allocator, abbrev_offset),
    );
    return &di.abbrev_table_list.items[di.abbrev_table_list.items.len - 1];
}

fn parseAbbrevTable(di: *Dwarf, allocator: Allocator, offset: u64) !Abbrev.Table {
    var fbr: FixedBufferReader = .{
        .buf = di.section(.debug_abbrev).?,
        .pos = cast(usize, offset) orelse return bad(),
        .endian = di.endian,
    };

    var abbrevs = std.ArrayList(Abbrev).init(allocator);
    defer {
        for (abbrevs.items) |*abbrev| {
            abbrev.deinit(allocator);
        }
        abbrevs.deinit();
    }

    var attrs = std.ArrayList(Abbrev.Attr).init(allocator);
    defer attrs.deinit();

    while (true) {
        const code = try fbr.readUleb128(u64);
        if (code == 0) break;
        const tag_id = try fbr.readUleb128(u64);
        const has_children = (try fbr.readByte()) == DW.CHILDREN.yes;

        while (true) {
            const attr_id = try fbr.readUleb128(u64);
            const form_id = try fbr.readUleb128(u64);
            if (attr_id == 0 and form_id == 0) break;
            try attrs.append(.{
                .id = attr_id,
                .form_id = form_id,
                .payload = switch (form_id) {
                    FORM.implicit_const => try fbr.readIleb128(i64),
                    else => undefined,
                },
            });
        }

        try abbrevs.append(.{
            .code = code,
            .tag_id = tag_id,
            .has_children = has_children,
            .attrs = try attrs.toOwnedSlice(),
        });
    }

    return .{
        .offset = offset,
        .abbrevs = try abbrevs.toOwnedSlice(),
    };
}

fn parseDie(
    fbr: *FixedBufferReader,
    attrs_buf: []Die.Attr,
    abbrev_table: *const Abbrev.Table,
    format: Format,
) ScanError!?Die {
    const abbrev_code = try fbr.readUleb128(u64);
    if (abbrev_code == 0) return null;
    const table_entry = abbrev_table.get(abbrev_code) orelse return bad();

    const attrs = attrs_buf[0..table_entry.attrs.len];
    for (attrs, table_entry.attrs) |*result_attr, attr| result_attr.* = Die.Attr{
        .id = attr.id,
        .value = try parseFormValue(
            fbr,
            attr.form_id,
            format,
            attr.payload,
        ),
    };
    return .{
        .tag_id = table_entry.tag_id,
        .has_children = table_entry.has_children,
        .attrs = attrs,
    };
}

/// Ensures that addresses in the returned LineTable are monotonically increasing.
fn runLineNumberProgram(d: *Dwarf, gpa: Allocator, compile_unit: *CompileUnit) !CompileUnit.SrcLocCache {
    const compile_unit_cwd = try compile_unit.die.getAttrString(d, AT.comp_dir, d.section(.debug_line_str), compile_unit.*);
    const line_info_offset = try compile_unit.die.getAttrSecOffset(AT.stmt_list);

    var fbr: FixedBufferReader = .{
        .buf = d.section(.debug_line).?,
        .endian = d.endian,
    };
    try fbr.seekTo(line_info_offset);

    const unit_header = try readUnitHeader(&fbr, null);
    if (unit_header.unit_length == 0) return missing();

    const next_offset = unit_header.header_length + unit_header.unit_length;

    const version = try fbr.readInt(u16);
    if (version < 2) return bad();

    const addr_size: u8, const seg_size: u8 = if (version >= 5) .{
        try fbr.readByte(),
        try fbr.readByte(),
    } else .{
        switch (unit_header.format) {
            .@"32" => 4,
            .@"64" => 8,
        },
        0,
    };
    _ = addr_size;
    _ = seg_size;

    const prologue_length = try fbr.readAddress(unit_header.format);
    const prog_start_offset = fbr.pos + prologue_length;

    const minimum_instruction_length = try fbr.readByte();
    if (minimum_instruction_length == 0) return bad();

    if (version >= 4) {
        const maximum_operations_per_instruction = try fbr.readByte();
        _ = maximum_operations_per_instruction;
    }

    const default_is_stmt = (try fbr.readByte()) != 0;
    const line_base = try fbr.readByteSigned();

    const line_range = try fbr.readByte();
    if (line_range == 0) return bad();

    const opcode_base = try fbr.readByte();

    const standard_opcode_lengths = try fbr.readBytes(opcode_base - 1);

    var directories: std.ArrayListUnmanaged(FileEntry) = .empty;
    defer directories.deinit(gpa);
    var file_entries: std.ArrayListUnmanaged(FileEntry) = .empty;
    defer file_entries.deinit(gpa);

    if (version < 5) {
        try directories.append(gpa, .{ .path = compile_unit_cwd });

        while (true) {
            const dir = try fbr.readBytesTo(0);
            if (dir.len == 0) break;
            try directories.append(gpa, .{ .path = dir });
        }

        while (true) {
            const file_name = try fbr.readBytesTo(0);
            if (file_name.len == 0) break;
            const dir_index = try fbr.readUleb128(u32);
            const mtime = try fbr.readUleb128(u64);
            const size = try fbr.readUleb128(u64);
            try file_entries.append(gpa, .{
                .path = file_name,
                .dir_index = dir_index,
                .mtime = mtime,
                .size = size,
            });
        }
    } else {
        const FileEntFmt = struct {
            content_type_code: u16,
            form_code: u16,
        };
        {
            var dir_ent_fmt_buf: [10]FileEntFmt = undefined;
            const directory_entry_format_count = try fbr.readByte();
            if (directory_entry_format_count > dir_ent_fmt_buf.len) return bad();
            for (dir_ent_fmt_buf[0..directory_entry_format_count]) |*ent_fmt| {
                ent_fmt.* = .{
                    .content_type_code = try fbr.readUleb128(u8),
                    .form_code = try fbr.readUleb128(u16),
                };
            }

            const directories_count = try fbr.readUleb128(usize);

            for (try directories.addManyAsSlice(gpa, directories_count)) |*e| {
                e.* = .{ .path = &.{} };
                for (dir_ent_fmt_buf[0..directory_entry_format_count]) |ent_fmt| {
                    const form_value = try parseFormValue(
                        &fbr,
                        ent_fmt.form_code,
                        unit_header.format,
                        null,
                    );
                    switch (ent_fmt.content_type_code) {
                        DW.LNCT.path => e.path = try form_value.getString(d.*),
                        DW.LNCT.directory_index => e.dir_index = try form_value.getUInt(u32),
                        DW.LNCT.timestamp => e.mtime = try form_value.getUInt(u64),
                        DW.LNCT.size => e.size = try form_value.getUInt(u64),
                        DW.LNCT.MD5 => e.md5 = switch (form_value) {
                            .data16 => |data16| data16.*,
                            else => return bad(),
                        },
                        else => continue,
                    }
                }
            }
        }

        var file_ent_fmt_buf: [10]FileEntFmt = undefined;
        const file_name_entry_format_count = try fbr.readByte();
        if (file_name_entry_format_count > file_ent_fmt_buf.len) return bad();
        for (file_ent_fmt_buf[0..file_name_entry_format_count]) |*ent_fmt| {
            ent_fmt.* = .{
                .content_type_code = try fbr.readUleb128(u16),
                .form_code = try fbr.readUleb128(u16),
            };
        }

        const file_names_count = try fbr.readUleb128(usize);
        try file_entries.ensureUnusedCapacity(gpa, file_names_count);

        for (try file_entries.addManyAsSlice(gpa, file_names_count)) |*e| {
            e.* = .{ .path = &.{} };
            for (file_ent_fmt_buf[0..file_name_entry_format_count]) |ent_fmt| {
                const form_value = try parseFormValue(
                    &fbr,
                    ent_fmt.form_code,
                    unit_header.format,
                    null,
                );
                switch (ent_fmt.content_type_code) {
                    DW.LNCT.path => e.path = try form_value.getString(d.*),
                    DW.LNCT.directory_index => e.dir_index = try form_value.getUInt(u32),
                    DW.LNCT.timestamp => e.mtime = try form_value.getUInt(u64),
                    DW.LNCT.size => e.size = try form_value.getUInt(u64),
                    DW.LNCT.MD5 => e.md5 = switch (form_value) {
                        .data16 => |data16| data16.*,
                        else => return bad(),
                    },
                    else => continue,
                }
            }
        }
    }

    var prog = LineNumberProgram.init(default_is_stmt, version);
    var line_table: CompileUnit.SrcLocCache.LineTable = .{};
    errdefer line_table.deinit(gpa);

    try fbr.seekTo(prog_start_offset);

    const next_unit_pos = line_info_offset + next_offset;

    while (fbr.pos < next_unit_pos) {
        const opcode = try fbr.readByte();

        if (opcode == DW.LNS.extended_op) {
            const op_size = try fbr.readUleb128(u64);
            if (op_size < 1) return bad();
            const sub_op = try fbr.readByte();
            switch (sub_op) {
                DW.LNE.end_sequence => {
                    // The row being added here is an "end" address, meaning
                    // that it does not map to the source location here -
                    // rather it marks the previous address as the last address
                    // that maps to this source location.

                    // In this implementation we don't mark end of addresses.
                    // This is a performance optimization based on the fact
                    // that we don't need to know if an address is missing
                    // source location info; we are only interested in being
                    // able to look up source location info for addresses that
                    // are known to have debug info.
                    //if (debug_debug_mode) assert(!line_table.contains(prog.address));
                    //try line_table.put(gpa, prog.address, CompileUnit.SrcLocCache.LineEntry.invalid);
                    prog.reset();
                },
                DW.LNE.set_address => {
                    const addr = try fbr.readInt(usize);
                    prog.address = addr;
                },
                DW.LNE.define_file => {
                    const path = try fbr.readBytesTo(0);
                    const dir_index = try fbr.readUleb128(u32);
                    const mtime = try fbr.readUleb128(u64);
                    const size = try fbr.readUleb128(u64);
                    try file_entries.append(gpa, .{
                        .path = path,
                        .dir_index = dir_index,
                        .mtime = mtime,
                        .size = size,
                    });
                },
                else => try fbr.seekForward(op_size - 1),
            }
        } else if (opcode >= opcode_base) {
            // special opcodes
            const adjusted_opcode = opcode - opcode_base;
            const inc_addr = minimum_instruction_length * (adjusted_opcode / line_range);
            const inc_line = @as(i32, line_base) + @as(i32, adjusted_opcode % line_range);
            prog.line += inc_line;
            prog.address += inc_addr;
            try prog.addRow(gpa, &line_table);
            prog.basic_block = false;
        } else {
            switch (opcode) {
                DW.LNS.copy => {
                    try prog.addRow(gpa, &line_table);
                    prog.basic_block = false;
                },
                DW.LNS.advance_pc => {
                    const arg = try fbr.readUleb128(usize);
                    prog.address += arg * minimum_instruction_length;
                },
                DW.LNS.advance_line => {
                    const arg = try fbr.readIleb128(i64);
                    prog.line += arg;
                },
                DW.LNS.set_file => {
                    const arg = try fbr.readUleb128(usize);
                    prog.file = arg;
                },
                DW.LNS.set_column => {
                    const arg = try fbr.readUleb128(u64);
                    prog.column = arg;
                },
                DW.LNS.negate_stmt => {
                    prog.is_stmt = !prog.is_stmt;
                },
                DW.LNS.set_basic_block => {
                    prog.basic_block = true;
                },
                DW.LNS.const_add_pc => {
                    const inc_addr = minimum_instruction_length * ((255 - opcode_base) / line_range);
                    prog.address += inc_addr;
                },
                DW.LNS.fixed_advance_pc => {
                    const arg = try fbr.readInt(u16);
                    prog.address += arg;
                },
                DW.LNS.set_prologue_end => {},
                else => {
                    if (opcode - 1 >= standard_opcode_lengths.len) return bad();
                    try fbr.seekForward(standard_opcode_lengths[opcode - 1]);
                },
            }
        }
    }

    // Dwarf standard v5, 6.2.5 says
    // > Within a sequence, addresses and operation pointers may only increase.
    // However, this is empirically not the case in reality, so we sort here.
    line_table.sortUnstable(struct {
        keys: []const u64,

        pub fn lessThan(ctx: @This(), a_index: usize, b_index: usize) bool {
            return ctx.keys[a_index] < ctx.keys[b_index];
        }
    }{ .keys = line_table.keys() });

    return .{
        .line_table = line_table,
        .directories = try directories.toOwnedSlice(gpa),
        .files = try file_entries.toOwnedSlice(gpa),
        .version = version,
    };
}

pub fn populateSrcLocCache(d: *Dwarf, gpa: Allocator, cu: *CompileUnit) ScanError!void {
    if (cu.src_loc_cache != null) return;
    cu.src_loc_cache = try runLineNumberProgram(d, gpa, cu);
}

pub fn getLineNumberInfo(
    d: *Dwarf,
    gpa: Allocator,
    compile_unit: *CompileUnit,
    target_address: u64,
) !std.debug.SourceLocation {
    try populateSrcLocCache(d, gpa, compile_unit);
    const slc = &compile_unit.src_loc_cache.?;
    const entry = try slc.findSource(target_address);
    const file_index = entry.file - @intFromBool(slc.version < 5);
    if (file_index >= slc.files.len) return bad();
    const file_entry = &slc.files[file_index];
    if (file_entry.dir_index >= slc.directories.len) return bad();
    const dir_name = slc.directories[file_entry.dir_index].path;
    const file_name = try std.fs.path.join(gpa, &.{ dir_name, file_entry.path });
    return .{
        .line = entry.line,
        .column = entry.column,
        .file_name = file_name,
    };
}

fn getString(di: Dwarf, offset: u64) ![:0]const u8 {
    return getStringGeneric(di.section(.debug_str), offset);
}

fn getLineString(di: Dwarf, offset: u64) ![:0]const u8 {
    return getStringGeneric(di.section(.debug_line_str), offset);
}

fn readDebugAddr(di: Dwarf, compile_unit: CompileUnit, index: u64) !u64 {
    const debug_addr = di.section(.debug_addr) orelse return bad();

    // addr_base points to the first item after the header, however we
    // need to read the header to know the size of each item. Empirically,
    // it may disagree with is_64 on the compile unit.
    // The header is 8 or 12 bytes depending on is_64.
    if (compile_unit.addr_base < 8) return bad();

    const version = mem.readInt(u16, debug_addr[compile_unit.addr_base - 4 ..][0..2], di.endian);
    if (version != 5) return bad();

    const addr_size = debug_addr[compile_unit.addr_base - 2];
    const seg_size = debug_addr[compile_unit.addr_base - 1];

    const byte_offset = @as(usize, @intCast(compile_unit.addr_base + (addr_size + seg_size) * index));
    if (byte_offset + addr_size > debug_addr.len) return bad();
    return switch (addr_size) {
        1 => debug_addr[byte_offset],
        2 => mem.readInt(u16, debug_addr[byte_offset..][0..2], di.endian),
        4 => mem.readInt(u32, debug_addr[byte_offset..][0..4], di.endian),
        8 => mem.readInt(u64, debug_addr[byte_offset..][0..8], di.endian),
        else => bad(),
    };
}

/// If .eh_frame_hdr is present, then only the header needs to be parsed.
///
/// Otherwise, .eh_frame and .debug_frame are scanned and a sorted list
/// of FDEs is built for binary searching during unwinding.
pub fn scanAllUnwindInfo(di: *Dwarf, allocator: Allocator, base_address: usize) !void {
    if (di.section(.eh_frame_hdr)) |eh_frame_hdr| blk: {
        var fbr: FixedBufferReader = .{ .buf = eh_frame_hdr, .endian = native_endian };

        const version = try fbr.readByte();
        if (version != 1) break :blk;

        const eh_frame_ptr_enc = try fbr.readByte();
        if (eh_frame_ptr_enc == EH.PE.omit) break :blk;
        const fde_count_enc = try fbr.readByte();
        if (fde_count_enc == EH.PE.omit) break :blk;
        const table_enc = try fbr.readByte();
        if (table_enc == EH.PE.omit) break :blk;

        const eh_frame_ptr = cast(usize, try readEhPointer(&fbr, eh_frame_ptr_enc, @sizeOf(usize), .{
            .pc_rel_base = @intFromPtr(&eh_frame_hdr[fbr.pos]),
            .follow_indirect = true,
        }) orelse return bad()) orelse return bad();

        const fde_count = cast(usize, try readEhPointer(&fbr, fde_count_enc, @sizeOf(usize), .{
            .pc_rel_base = @intFromPtr(&eh_frame_hdr[fbr.pos]),
            .follow_indirect = true,
        }) orelse return bad()) orelse return bad();

        const entry_size = try ExceptionFrameHeader.entrySize(table_enc);
        const entries_len = fde_count * entry_size;
        if (entries_len > eh_frame_hdr.len - fbr.pos) return bad();

        di.eh_frame_hdr = .{
            .eh_frame_ptr = eh_frame_ptr,
            .table_enc = table_enc,
            .fde_count = fde_count,
            .entries = eh_frame_hdr[fbr.pos..][0..entries_len],
        };

        // No need to scan .eh_frame, we have a binary search table already
        return;
    }

    const frame_sections = [2]Section.Id{ .eh_frame, .debug_frame };
    for (frame_sections) |frame_section| {
        if (di.section(frame_section)) |section_data| {
            var fbr: FixedBufferReader = .{ .buf = section_data, .endian = di.endian };
            while (fbr.pos < fbr.buf.len) {
                const entry_header = try EntryHeader.read(&fbr, null, frame_section);
                switch (entry_header.type) {
                    .cie => {
                        const cie = try CommonInformationEntry.parse(
                            entry_header.entry_bytes,
                            di.sectionVirtualOffset(frame_section, base_address).?,
                            true,
                            entry_header.format,
                            frame_section,
                            entry_header.length_offset,
                            @sizeOf(usize),
                            di.endian,
                        );
                        try di.cie_map.put(allocator, entry_header.length_offset, cie);
                    },
                    .fde => |cie_offset| {
                        const cie = di.cie_map.get(cie_offset) orelse return bad();
                        const fde = try FrameDescriptionEntry.parse(
                            entry_header.entry_bytes,
                            di.sectionVirtualOffset(frame_section, base_address).?,
                            true,
                            cie,
                            @sizeOf(usize),
                            di.endian,
                        );
                        try di.fde_list.append(allocator, fde);
                    },
                    .terminator => break,
                }
            }

            std.mem.sortUnstable(FrameDescriptionEntry, di.fde_list.items, {}, struct {
                fn lessThan(ctx: void, a: FrameDescriptionEntry, b: FrameDescriptionEntry) bool {
                    _ = ctx;
                    return a.pc_begin < b.pc_begin;
                }
            }.lessThan);
        }
    }
}

fn parseFormValue(
    fbr: *FixedBufferReader,
    form_id: u64,
    format: Format,
    implicit_const: ?i64,
) ScanError!FormValue {
    return switch (form_id) {
        FORM.addr => .{ .addr = try fbr.readAddress(switch (@bitSizeOf(usize)) {
            32 => .@"32",
            64 => .@"64",
            else => @compileError("unsupported @sizeOf(usize)"),
        }) },
        FORM.addrx1 => .{ .addrx = try fbr.readInt(u8) },
        FORM.addrx2 => .{ .addrx = try fbr.readInt(u16) },
        FORM.addrx3 => .{ .addrx = try fbr.readInt(u24) },
        FORM.addrx4 => .{ .addrx = try fbr.readInt(u32) },
        FORM.addrx => .{ .addrx = try fbr.readUleb128(usize) },

        FORM.block1,
        FORM.block2,
        FORM.block4,
        FORM.block,
        => .{ .block = try fbr.readBytes(switch (form_id) {
            FORM.block1 => try fbr.readInt(u8),
            FORM.block2 => try fbr.readInt(u16),
            FORM.block4 => try fbr.readInt(u32),
            FORM.block => try fbr.readUleb128(usize),
            else => unreachable,
        }) },

        FORM.data1 => .{ .udata = try fbr.readInt(u8) },
        FORM.data2 => .{ .udata = try fbr.readInt(u16) },
        FORM.data4 => .{ .udata = try fbr.readInt(u32) },
        FORM.data8 => .{ .udata = try fbr.readInt(u64) },
        FORM.data16 => .{ .data16 = (try fbr.readBytes(16))[0..16] },
        FORM.udata => .{ .udata = try fbr.readUleb128(u64) },
        FORM.sdata => .{ .sdata = try fbr.readIleb128(i64) },
        FORM.exprloc => .{ .exprloc = try fbr.readBytes(try fbr.readUleb128(usize)) },
        FORM.flag => .{ .flag = (try fbr.readByte()) != 0 },
        FORM.flag_present => .{ .flag = true },
        FORM.sec_offset => .{ .sec_offset = try fbr.readAddress(format) },

        FORM.ref1 => .{ .ref = try fbr.readInt(u8) },
        FORM.ref2 => .{ .ref = try fbr.readInt(u16) },
        FORM.ref4 => .{ .ref = try fbr.readInt(u32) },
        FORM.ref8 => .{ .ref = try fbr.readInt(u64) },
        FORM.ref_udata => .{ .ref = try fbr.readUleb128(u64) },

        FORM.ref_addr => .{ .ref_addr = try fbr.readAddress(format) },
        FORM.ref_sig8 => .{ .ref = try fbr.readInt(u64) },

        FORM.string => .{ .string = try fbr.readBytesTo(0) },
        FORM.strp => .{ .strp = try fbr.readAddress(format) },
        FORM.strx1 => .{ .strx = try fbr.readInt(u8) },
        FORM.strx2 => .{ .strx = try fbr.readInt(u16) },
        FORM.strx3 => .{ .strx = try fbr.readInt(u24) },
        FORM.strx4 => .{ .strx = try fbr.readInt(u32) },
        FORM.strx => .{ .strx = try fbr.readUleb128(usize) },
        FORM.line_strp => .{ .line_strp = try fbr.readAddress(format) },
        FORM.indirect => parseFormValue(fbr, try fbr.readUleb128(u64), format, implicit_const),
        FORM.implicit_const => .{ .sdata = implicit_const orelse return bad() },
        FORM.loclistx => .{ .loclistx = try fbr.readUleb128(u64) },
        FORM.rnglistx => .{ .rnglistx = try fbr.readUleb128(u64) },
        else => {
            //debug.print("unrecognized form id: {x}\n", .{form_id});
            return bad();
        },
    };
}

const FileEntry = struct {
    path: []const u8,
    dir_index: u32 = 0,
    mtime: u64 = 0,
    size: u64 = 0,
    md5: [16]u8 = [1]u8{0} ** 16,
};

const LineNumberProgram = struct {
    address: u64,
    file: usize,
    line: i64,
    column: u64,
    version: u16,
    is_stmt: bool,
    basic_block: bool,

    default_is_stmt: bool,

    // Reset the state machine following the DWARF specification
    pub fn reset(self: *LineNumberProgram) void {
        self.address = 0;
        self.file = 1;
        self.line = 1;
        self.column = 0;
        self.is_stmt = self.default_is_stmt;
        self.basic_block = false;
    }

    pub fn init(is_stmt: bool, version: u16) LineNumberProgram {
        return .{
            .address = 0,
            .file = 1,
            .line = 1,
            .column = 0,
            .version = version,
            .is_stmt = is_stmt,
            .basic_block = false,
            .default_is_stmt = is_stmt,
        };
    }

    pub fn addRow(prog: *LineNumberProgram, gpa: Allocator, table: *CompileUnit.SrcLocCache.LineTable) !void {
        if (prog.line == 0) {
            //if (debug_debug_mode) @panic("garbage line data");
            return;
        }
        if (debug_debug_mode) assert(!table.contains(prog.address));
        try table.put(gpa, prog.address, .{
            .line = cast(u32, prog.line) orelse maxInt(u32),
            .column = cast(u32, prog.column) orelse maxInt(u32),
            .file = cast(u32, prog.file) orelse return bad(),
        });
    }
};

const UnitHeader = struct {
    format: Format,
    header_length: u4,
    unit_length: u64,
};

fn readUnitHeader(fbr: *FixedBufferReader, opt_ma: ?*MemoryAccessor) ScanError!UnitHeader {
    return switch (try if (opt_ma) |ma| fbr.readIntChecked(u32, ma) else fbr.readInt(u32)) {
        0...0xfffffff0 - 1 => |unit_length| .{
            .format = .@"32",
            .header_length = 4,
            .unit_length = unit_length,
        },
        0xfffffff0...0xffffffff - 1 => bad(),
        0xffffffff => .{
            .format = .@"64",
            .header_length = 12,
            .unit_length = try if (opt_ma) |ma| fbr.readIntChecked(u64, ma) else fbr.readInt(u64),
        },
    };
}

/// Returns the DWARF register number for an x86_64 register number found in compact unwind info
pub fn compactUnwindToDwarfRegNumber(unwind_reg_number: u3) !u8 {
    return switch (unwind_reg_number) {
        1 => 3, // RBX
        2 => 12, // R12
        3 => 13, // R13
        4 => 14, // R14
        5 => 15, // R15
        6 => 6, // RBP
        else => error.InvalidUnwindRegisterNumber,
    };
}

/// This function is to make it handy to comment out the return and make it
/// into a crash when working on this file.
pub fn bad() error{InvalidDebugInfo} {
    if (debug_debug_mode) @panic("bad dwarf");
    return error.InvalidDebugInfo;
}

fn missing() error{MissingDebugInfo} {
    if (debug_debug_mode) @panic("missing dwarf");
    return error.MissingDebugInfo;
}

fn getStringGeneric(opt_str: ?[]const u8, offset: u64) ![:0]const u8 {
    const str = opt_str orelse return bad();
    if (offset > str.len) return bad();
    const casted_offset = cast(usize, offset) orelse return bad();
    // Valid strings always have a terminating zero byte
    const last = std.mem.indexOfScalarPos(u8, str, casted_offset, 0) orelse return bad();
    return str[casted_offset..last :0];
}

const EhPointerContext = struct {
    // The address of the pointer field itself
    pc_rel_base: u64,

    // Whether or not to follow indirect pointers. This should only be
    // used when decoding pointers at runtime using the current process's
    // debug info
    follow_indirect: bool,

    // These relative addressing modes are only used in specific cases, and
    // might not be available / required in all parsing contexts
    data_rel_base: ?u64 = null,
    text_rel_base: ?u64 = null,
    function_rel_base: ?u64 = null,
};
fn readEhPointer(fbr: *FixedBufferReader, enc: u8, addr_size_bytes: u8, ctx: EhPointerContext) !?u64 {
    if (enc == EH.PE.omit) return null;

    const value: union(enum) {
        signed: i64,
        unsigned: u64,
    } = switch (enc & EH.PE.type_mask) {
        EH.PE.absptr => .{
            .unsigned = switch (addr_size_bytes) {
                2 => try fbr.readInt(u16),
                4 => try fbr.readInt(u32),
                8 => try fbr.readInt(u64),
                else => return error.InvalidAddrSize,
            },
        },
        EH.PE.uleb128 => .{ .unsigned = try fbr.readUleb128(u64) },
        EH.PE.udata2 => .{ .unsigned = try fbr.readInt(u16) },
        EH.PE.udata4 => .{ .unsigned = try fbr.readInt(u32) },
        EH.PE.udata8 => .{ .unsigned = try fbr.readInt(u64) },
        EH.PE.sleb128 => .{ .signed = try fbr.readIleb128(i64) },
        EH.PE.sdata2 => .{ .signed = try fbr.readInt(i16) },
        EH.PE.sdata4 => .{ .signed = try fbr.readInt(i32) },
        EH.PE.sdata8 => .{ .signed = try fbr.readInt(i64) },
        else => return bad(),
    };

    const base = switch (enc & EH.PE.rel_mask) {
        EH.PE.pcrel => ctx.pc_rel_base,
        EH.PE.textrel => ctx.text_rel_base orelse return error.PointerBaseNotSpecified,
        EH.PE.datarel => ctx.data_rel_base orelse return error.PointerBaseNotSpecified,
        EH.PE.funcrel => ctx.function_rel_base orelse return error.PointerBaseNotSpecified,
        else => null,
    };

    const ptr: u64 = if (base) |b| switch (value) {
        .signed => |s| @intCast(try std.math.add(i64, s, @as(i64, @intCast(b)))),
        // absptr can actually contain signed values in some cases (aarch64 MachO)
        .unsigned => |u| u +% b,
    } else switch (value) {
        .signed => |s| @as(u64, @intCast(s)),
        .unsigned => |u| u,
    };

    if ((enc & EH.PE.indirect) > 0 and ctx.follow_indirect) {
        if (@sizeOf(usize) != addr_size_bytes) {
            // See the documentation for `follow_indirect`
            return error.NonNativeIndirection;
        }

        const native_ptr = cast(usize, ptr) orelse return error.PointerOverflow;
        return switch (addr_size_bytes) {
            2, 4, 8 => return @as(*const usize, @ptrFromInt(native_ptr)).*,
            else => return error.UnsupportedAddrSize,
        };
    } else {
        return ptr;
    }
}

fn pcRelBase(field_ptr: usize, pc_rel_offset: i64) !usize {
    if (pc_rel_offset < 0) {
        return std.math.sub(usize, field_ptr, @as(usize, @intCast(-pc_rel_offset)));
    } else {
        return std.math.add(usize, field_ptr, @as(usize, @intCast(pc_rel_offset)));
    }
}

pub const ElfModule = struct {
    base_address: usize,
    dwarf: Dwarf,
    mapped_memory: []align(std.mem.page_size) const u8,
    external_mapped_memory: ?[]align(std.mem.page_size) const u8,

    pub fn deinit(self: *@This(), allocator: Allocator) void {
        self.dwarf.deinit(allocator);
        std.posix.munmap(self.mapped_memory);
        if (self.external_mapped_memory) |m| std.posix.munmap(m);
    }

    pub fn getSymbolAtAddress(self: *@This(), allocator: Allocator, address: usize) !std.debug.Symbol {
        // Translate the VA into an address into this object
        const relocated_address = address - self.base_address;
        return self.dwarf.getSymbol(allocator, relocated_address);
    }

    pub fn getDwarfInfoForAddress(self: *@This(), allocator: Allocator, address: usize) !?*const Dwarf {
        _ = allocator;
        _ = address;
        return &self.dwarf;
    }

    pub const LoadError = error{
        InvalidDebugInfo,
        MissingDebugInfo,
        InvalidElfMagic,
        InvalidElfVersion,
        InvalidElfEndian,
        /// TODO: implement this and then remove this error code
        UnimplementedDwarfForeignEndian,
        /// The debug info may be valid but this implementation uses memory
        /// mapping which limits things to usize. If the target debug info is
        /// 64-bit and host is 32-bit, there may be debug info that is not
        /// supportable using this method.
        Overflow,

        PermissionDenied,
        LockedMemoryLimitExceeded,
        MemoryMappingNotSupported,
    } || Allocator.Error || std.fs.File.OpenError || OpenError;

    /// Reads debug info from an already mapped ELF file.
    ///
    /// If the required sections aren't present but a reference to external debug
    /// info is, then this this function will recurse to attempt to load the debug
    /// sections from an external file.
    pub fn load(
        gpa: Allocator,
        mapped_mem: []align(std.mem.page_size) const u8,
        build_id: ?[]const u8,
        expected_crc: ?u32,
        parent_sections: *Dwarf.SectionArray,
        parent_mapped_mem: ?[]align(std.mem.page_size) const u8,
        elf_filename: ?[]const u8,
    ) LoadError!Dwarf.ElfModule {
        if (expected_crc) |crc| if (crc != std.hash.crc.Crc32.hash(mapped_mem)) return error.InvalidDebugInfo;

        const hdr: *const elf.Ehdr = @ptrCast(&mapped_mem[0]);
        if (!mem.eql(u8, hdr.e_ident[0..4], elf.MAGIC)) return error.InvalidElfMagic;
        if (hdr.e_ident[elf.EI_VERSION] != 1) return error.InvalidElfVersion;

        const endian: std.builtin.Endian = switch (hdr.e_ident[elf.EI_DATA]) {
            elf.ELFDATA2LSB => .little,
            elf.ELFDATA2MSB => .big,
            else => return error.InvalidElfEndian,
        };
        if (endian != native_endian) return error.UnimplementedDwarfForeignEndian;

        const shoff = hdr.e_shoff;
        const str_section_off = shoff + @as(u64, hdr.e_shentsize) * @as(u64, hdr.e_shstrndx);
        const str_shdr: *const elf.Shdr = @ptrCast(@alignCast(&mapped_mem[cast(usize, str_section_off) orelse return error.Overflow]));
        const header_strings = mapped_mem[str_shdr.sh_offset..][0..str_shdr.sh_size];
        const shdrs = @as(
            [*]const elf.Shdr,
            @ptrCast(@alignCast(&mapped_mem[shoff])),
        )[0..hdr.e_shnum];

        var sections: Dwarf.SectionArray = Dwarf.null_section_array;

        // Combine section list. This takes ownership over any owned sections from the parent scope.
        for (parent_sections, &sections) |*parent, *section_elem| {
            if (parent.*) |*p| {
                section_elem.* = p.*;
                p.owned = false;
            }
        }
        errdefer for (sections) |opt_section| if (opt_section) |s| if (s.owned) gpa.free(s.data);

        var separate_debug_filename: ?[]const u8 = null;
        var separate_debug_crc: ?u32 = null;

        for (shdrs) |*shdr| {
            if (shdr.sh_type == elf.SHT_NULL or shdr.sh_type == elf.SHT_NOBITS) continue;
            const name = mem.sliceTo(header_strings[shdr.sh_name..], 0);

            if (mem.eql(u8, name, ".gnu_debuglink")) {
                const gnu_debuglink = try chopSlice(mapped_mem, shdr.sh_offset, shdr.sh_size);
                const debug_filename = mem.sliceTo(@as([*:0]const u8, @ptrCast(gnu_debuglink.ptr)), 0);
                const crc_offset = mem.alignForward(usize, debug_filename.len + 1, 4);
                const crc_bytes = gnu_debuglink[crc_offset..][0..4];
                separate_debug_crc = mem.readInt(u32, crc_bytes, native_endian);
                separate_debug_filename = debug_filename;
                continue;
            }

            var section_index: ?usize = null;
            inline for (@typeInfo(Dwarf.Section.Id).@"enum".fields, 0..) |sect, i| {
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
                    .data = decompressed_section,
                    .virtual_address = shdr.sh_addr,
                    .owned = true,
                };
            } else .{
                .data = section_bytes,
                .virtual_address = shdr.sh_addr,
                .owned = false,
            };
        }

        const missing_debug_info =
            sections[@intFromEnum(Dwarf.Section.Id.debug_info)] == null or
            sections[@intFromEnum(Dwarf.Section.Id.debug_abbrev)] == null or
            sections[@intFromEnum(Dwarf.Section.Id.debug_str)] == null or
            sections[@intFromEnum(Dwarf.Section.Id.debug_line)] == null;

        // Attempt to load debug info from an external file
        // See: https://sourceware.org/gdb/onlinedocs/gdb/Separate-Debug-Files.html
        if (missing_debug_info) {

            // Only allow one level of debug info nesting
            if (parent_mapped_mem) |_| {
                return error.MissingDebugInfo;
            }

            // $XDG_CACHE_HOME/debuginfod_client/<buildid>/debuginfo
            // This only opportunisticly tries to load from the debuginfod cache, but doesn't try to populate it.
            // One can manually run `debuginfod-find debuginfo PATH` to download the symbols
            if (build_id) |id| blk: {
                var debuginfod_dir: std.fs.Dir = switch (builtin.os.tag) {
                    .wasi, .windows => break :blk,
                    else => dir: {
                        if (std.posix.getenv("DEBUGINFOD_CACHE_PATH")) |path| {
                            break :dir std.fs.openDirAbsolute(path, .{}) catch break :blk;
                        }
                        if (std.posix.getenv("XDG_CACHE_HOME")) |cache_path| {
                            if (cache_path.len > 0) {
                                const path = std.fs.path.join(gpa, &[_][]const u8{ cache_path, "debuginfod_client" }) catch break :blk;
                                defer gpa.free(path);
                                break :dir std.fs.openDirAbsolute(path, .{}) catch break :blk;
                            }
                        }
                        if (std.posix.getenv("HOME")) |home_path| {
                            const path = std.fs.path.join(gpa, &[_][]const u8{ home_path, ".cache", "debuginfod_client" }) catch break :blk;
                            defer gpa.free(path);
                            break :dir std.fs.openDirAbsolute(path, .{}) catch break :blk;
                        }
                        break :blk;
                    },
                };
                defer debuginfod_dir.close();

                const filename = std.fmt.allocPrint(
                    gpa,
                    "{s}/debuginfo",
                    .{std.fmt.fmtSliceHexLower(id)},
                ) catch break :blk;
                defer gpa.free(filename);

                const path: Path = .{
                    .root_dir = .{ .path = null, .handle = debuginfod_dir },
                    .sub_path = filename,
                };

                return loadPath(gpa, path, null, separate_debug_crc, &sections, mapped_mem) catch break :blk;
            }

            const global_debug_directories = [_][]const u8{
                "/usr/lib/debug",
            };

            // <global debug directory>/.build-id/<2-character id prefix>/<id remainder>.debug
            if (build_id) |id| blk: {
                if (id.len < 3) break :blk;

                // Either md5 (16 bytes) or sha1 (20 bytes) are used here in practice
                const extension = ".debug";
                var id_prefix_buf: [2]u8 = undefined;
                var filename_buf: [38 + extension.len]u8 = undefined;

                _ = std.fmt.bufPrint(&id_prefix_buf, "{s}", .{std.fmt.fmtSliceHexLower(id[0..1])}) catch unreachable;
                const filename = std.fmt.bufPrint(
                    &filename_buf,
                    "{s}" ++ extension,
                    .{std.fmt.fmtSliceHexLower(id[1..])},
                ) catch break :blk;

                for (global_debug_directories) |global_directory| {
                    const path: Path = .{
                        .root_dir = std.Build.Cache.Directory.cwd(),
                        .sub_path = try std.fs.path.join(gpa, &.{
                            global_directory, ".build-id", &id_prefix_buf, filename,
                        }),
                    };
                    defer gpa.free(path.sub_path);

                    return loadPath(gpa, path, null, separate_debug_crc, &sections, mapped_mem) catch continue;
                }
            }

            // use the path from .gnu_debuglink, in the same search order as gdb
            if (separate_debug_filename) |separate_filename| blk: {
                if (elf_filename != null and mem.eql(u8, elf_filename.?, separate_filename))
                    return error.MissingDebugInfo;

                exe_dir: {
                    var exe_dir_buf: [std.fs.max_path_bytes]u8 = undefined;
                    const exe_dir_path = std.fs.selfExeDirPath(&exe_dir_buf) catch break :exe_dir;
                    var exe_dir = std.fs.openDirAbsolute(exe_dir_path, .{}) catch break :exe_dir;
                    defer exe_dir.close();

                    // <exe_dir>/<gnu_debuglink>
                    if (loadPath(
                        gpa,
                        .{
                            .root_dir = .{ .path = null, .handle = exe_dir },
                            .sub_path = separate_filename,
                        },
                        null,
                        separate_debug_crc,
                        &sections,
                        mapped_mem,
                    )) |debug_info| {
                        return debug_info;
                    } else |_| {}

                    // <exe_dir>/.debug/<gnu_debuglink>
                    const path: Path = .{
                        .root_dir = .{ .path = null, .handle = exe_dir },
                        .sub_path = try std.fs.path.join(gpa, &.{ ".debug", separate_filename }),
                    };
                    defer gpa.free(path.sub_path);

                    if (loadPath(gpa, path, null, separate_debug_crc, &sections, mapped_mem)) |debug_info| return debug_info else |_| {}
                }

                var cwd_buf: [std.fs.max_path_bytes]u8 = undefined;
                const cwd_path = std.posix.realpath(".", &cwd_buf) catch break :blk;

                // <global debug directory>/<absolute folder of current binary>/<gnu_debuglink>
                for (global_debug_directories) |global_directory| {
                    const path: Path = .{
                        .root_dir = std.Build.Cache.Directory.cwd(),
                        .sub_path = try std.fs.path.join(gpa, &.{ global_directory, cwd_path, separate_filename }),
                    };
                    defer gpa.free(path.sub_path);
                    if (loadPath(gpa, path, null, separate_debug_crc, &sections, mapped_mem)) |debug_info| return debug_info else |_| {}
                }
            }

            return error.MissingDebugInfo;
        }

        var di: Dwarf = .{
            .endian = endian,
            .sections = sections,
            .is_macho = false,
        };

        try Dwarf.open(&di, gpa);

        return .{
            .base_address = 0,
            .dwarf = di,
            .mapped_memory = parent_mapped_mem orelse mapped_mem,
            .external_mapped_memory = if (parent_mapped_mem != null) mapped_mem else null,
        };
    }

    pub fn loadPath(
        gpa: Allocator,
        elf_file_path: Path,
        build_id: ?[]const u8,
        expected_crc: ?u32,
        parent_sections: *Dwarf.SectionArray,
        parent_mapped_mem: ?[]align(std.mem.page_size) const u8,
    ) LoadError!Dwarf.ElfModule {
        const elf_file = elf_file_path.root_dir.handle.openFile(elf_file_path.sub_path, .{}) catch |err| switch (err) {
            error.FileNotFound => return missing(),
            else => return err,
        };
        defer elf_file.close();

        const end_pos = elf_file.getEndPos() catch return bad();
        const file_len = cast(usize, end_pos) orelse return error.Overflow;

        const mapped_mem = try std.posix.mmap(
            null,
            file_len,
            std.posix.PROT.READ,
            .{ .TYPE = .SHARED },
            elf_file.handle,
            0,
        );
        errdefer std.posix.munmap(mapped_mem);

        return load(
            gpa,
            mapped_mem,
            build_id,
            expected_crc,
            parent_sections,
            parent_mapped_mem,
            elf_file_path.sub_path,
        );
    }
};

pub fn getSymbol(di: *Dwarf, allocator: Allocator, address: u64) !std.debug.Symbol {
    if (di.findCompileUnit(address)) |compile_unit| {
        return .{
            .name = di.getSymbolName(address) orelse "???",
            .compile_unit_name = compile_unit.die.getAttrString(di, std.dwarf.AT.name, di.section(.debug_str), compile_unit.*) catch |err| switch (err) {
                error.MissingDebugInfo, error.InvalidDebugInfo => "???",
            },
            .source_location = di.getLineNumberInfo(allocator, compile_unit, address) catch |err| switch (err) {
                error.MissingDebugInfo, error.InvalidDebugInfo => null,
                else => return err,
            },
        };
    } else |err| switch (err) {
        error.MissingDebugInfo, error.InvalidDebugInfo => return .{},
        else => return err,
    }
}

pub fn chopSlice(ptr: []const u8, offset: u64, size: u64) error{Overflow}![]const u8 {
    const start = cast(usize, offset) orelse return error.Overflow;
    const end = start + (cast(usize, size) orelse return error.Overflow);
    return ptr[start..end];
}
