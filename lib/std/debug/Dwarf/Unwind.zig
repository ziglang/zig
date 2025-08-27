sections: SectionArray = @splat(null),

/// Starts out non-`null` if the `.eh_frame_hdr` section is present. May become `null` later if we
/// find that `.eh_frame_hdr` is incomplete.
eh_frame_hdr: ?ExceptionFrameHeader = null,
/// These lookup tables are only used if `eh_frame_hdr` is null
cie_map: std.AutoArrayHashMapUnmanaged(u64, CommonInformationEntry) = .empty,
/// Sorted by start_pc
fde_list: std.ArrayList(FrameDescriptionEntry) = .empty,

pub const Section = struct {
    data: []const u8,

    pub const Id = enum {
        debug_frame,
        eh_frame,
        eh_frame_hdr,
    };
};

const num_sections = std.enums.directEnumArrayLen(Section.Id, 0);
pub const SectionArray = [num_sections]?Section;

pub fn section(unwind: Unwind, dwarf_section: Section.Id) ?[]const u8 {
    return if (unwind.sections[@intFromEnum(dwarf_section)]) |s| s.data else null;
}

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

    pub fn findEntry(
        self: ExceptionFrameHeader,
        eh_frame_len: usize,
        eh_frame_hdr_ptr: usize,
        pc: usize,
        cie: *CommonInformationEntry,
        fde: *FrameDescriptionEntry,
        endian: Endian,
    ) !void {
        const entry_size = try entrySize(self.table_enc);

        var left: usize = 0;
        var len: usize = self.fde_count;
        var fbr: Reader = .fixed(self.entries);

        while (len > 1) {
            const mid = left + len / 2;

            fbr.seek = mid * entry_size;
            const pc_begin = try readEhPointer(&fbr, self.table_enc, @sizeOf(usize), .{
                .pc_rel_base = @intFromPtr(&self.entries[fbr.seek]),
                .follow_indirect = true,
                .data_rel_base = eh_frame_hdr_ptr,
            }, endian) orelse return bad();

            if (pc < pc_begin) {
                len /= 2;
            } else {
                left = mid;
                if (pc == pc_begin) break;
                len -= len / 2;
            }
        }

        if (len == 0) return missing();
        fbr.seek = left * entry_size;

        // Read past the pc_begin field of the entry
        _ = try readEhPointer(&fbr, self.table_enc, @sizeOf(usize), .{
            .pc_rel_base = @intFromPtr(&self.entries[fbr.seek]),
            .follow_indirect = true,
            .data_rel_base = eh_frame_hdr_ptr,
        }, endian) orelse return bad();

        const fde_ptr = cast(usize, try readEhPointer(&fbr, self.table_enc, @sizeOf(usize), .{
            .pc_rel_base = @intFromPtr(&self.entries[fbr.seek]),
            .follow_indirect = true,
            .data_rel_base = eh_frame_hdr_ptr,
        }, endian) orelse return bad()) orelse return bad();

        if (fde_ptr < self.eh_frame_ptr) return bad();

        const eh_frame = @as([*]const u8, @ptrFromInt(self.eh_frame_ptr))[0..eh_frame_len];

        const fde_offset = fde_ptr - self.eh_frame_ptr;
        var eh_frame_fbr: Reader = .fixed(eh_frame);
        eh_frame_fbr.seek = fde_offset;

        const fde_entry_header = try EntryHeader.read(&eh_frame_fbr, .eh_frame, endian);
        if (fde_entry_header.type != .fde) return bad();

        // CIEs always come before FDEs (the offset is a subtraction), so we can assume this memory is readable
        const cie_offset = fde_entry_header.type.fde;
        eh_frame_fbr.seek = @intCast(cie_offset);
        const cie_entry_header = try EntryHeader.read(&eh_frame_fbr, .eh_frame, endian);
        if (cie_entry_header.type != .cie) return bad();

        cie.* = try CommonInformationEntry.parse(
            cie_entry_header.entry_bytes,
            0,
            true,
            cie_entry_header.format,
            .eh_frame,
            cie_entry_header.length_offset,
            @sizeOf(usize),
            endian,
        );

        fde.* = try FrameDescriptionEntry.parse(
            fde_entry_header.entry_bytes,
            0,
            true,
            cie.*,
            @sizeOf(usize),
            endian,
        );

        if (pc < fde.pc_begin or pc >= fde.pc_begin + fde.pc_range) return missing();
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

    /// Reads a header for either an FDE or a CIE, then advances the fbr to the
    /// position after the trailing structure.
    ///
    /// `fbr` must be backed by either the .eh_frame or .debug_frame sections.
    ///
    /// TODO that's a bad API, don't do that. this function should neither require
    /// a fixed reader nor depend on seeking.
    pub fn read(fbr: *Reader, dwarf_section: Section.Id, endian: Endian) !EntryHeader {
        assert(dwarf_section == .eh_frame or dwarf_section == .debug_frame);

        const length_offset = fbr.seek;
        const unit_header = try Dwarf.readUnitHeader(fbr, endian);
        const unit_length = cast(usize, unit_header.unit_length) orelse return bad();
        if (unit_length == 0) return .{
            .length_offset = length_offset,
            .format = unit_header.format,
            .type = .terminator,
            .entry_bytes = &.{},
        };
        const start_offset = fbr.seek;
        const end_offset = start_offset + unit_length;
        defer fbr.seek = end_offset;

        const id = try Dwarf.readAddress(fbr, unit_header.format, endian);
        const entry_bytes = fbr.buffer[fbr.seek..end_offset];
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
        endian: Endian,
    ) !CommonInformationEntry {
        if (addr_size_bytes > 8) return error.UnsupportedAddrSize;

        var fbr: Reader = .fixed(cie_bytes);

        const version = try fbr.takeByte();
        switch (dwarf_section) {
            .eh_frame => if (version != 1 and version != 3) return error.UnsupportedDwarfVersion,
            .debug_frame => if (version != 4) return error.UnsupportedDwarfVersion,
            else => return error.UnsupportedDwarfSection,
        }

        var has_eh_data = false;
        var has_aug_data = false;

        var aug_str_len: usize = 0;
        const aug_str_start = fbr.seek;
        var aug_byte = try fbr.takeByte();
        while (aug_byte != 0) : (aug_byte = try fbr.takeByte()) {
            switch (aug_byte) {
                'z' => {
                    if (aug_str_len != 0) return bad();
                    has_aug_data = true;
                },
                'e' => {
                    if (has_aug_data or aug_str_len != 0) return bad();
                    if (try fbr.takeByte() != 'h') return bad();
                    has_eh_data = true;
                },
                else => if (has_eh_data) return bad(),
            }

            aug_str_len += 1;
        }

        if (has_eh_data) {
            // legacy data created by older versions of gcc - unsupported here
            for (0..addr_size_bytes) |_| _ = try fbr.takeByte();
        }

        const address_size = if (version == 4) try fbr.takeByte() else addr_size_bytes;
        const segment_selector_size = if (version == 4) try fbr.takeByte() else null;

        const code_alignment_factor = try fbr.takeLeb128(u32);
        const data_alignment_factor = try fbr.takeLeb128(i32);
        const return_address_register = if (version == 1) try fbr.takeByte() else try fbr.takeLeb128(u8);

        var lsda_pointer_enc: u8 = EH.PE.omit;
        var personality_enc: ?u8 = null;
        var personality_routine_pointer: ?u64 = null;
        var fde_pointer_enc: u8 = EH.PE.absptr;

        var aug_data: []const u8 = &[_]u8{};
        const aug_str = if (has_aug_data) blk: {
            const aug_data_len = try fbr.takeLeb128(usize);
            const aug_data_start = fbr.seek;
            aug_data = cie_bytes[aug_data_start..][0..aug_data_len];

            const aug_str = cie_bytes[aug_str_start..][0..aug_str_len];
            for (aug_str[1..]) |byte| {
                switch (byte) {
                    'L' => {
                        lsda_pointer_enc = try fbr.takeByte();
                    },
                    'P' => {
                        personality_enc = try fbr.takeByte();
                        personality_routine_pointer = try readEhPointer(&fbr, personality_enc.?, addr_size_bytes, .{
                            .pc_rel_base = try pcRelBase(@intFromPtr(&cie_bytes[fbr.seek]), pc_rel_offset),
                            .follow_indirect = is_runtime,
                        }, endian);
                    },
                    'R' => {
                        fde_pointer_enc = try fbr.takeByte();
                    },
                    'S', 'B', 'G' => {},
                    else => return bad(),
                }
            }

            // aug_data_len can include padding so the CIE ends on an address boundary
            fbr.seek = aug_data_start + aug_data_len;
            break :blk aug_str;
        } else &[_]u8{};

        const initial_instructions = cie_bytes[fbr.seek..];
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
        endian: Endian,
    ) !FrameDescriptionEntry {
        if (addr_size_bytes > 8) return error.InvalidAddrSize;

        var fbr: Reader = .fixed(fde_bytes);

        const pc_begin = try readEhPointer(&fbr, cie.fde_pointer_enc, addr_size_bytes, .{
            .pc_rel_base = try pcRelBase(@intFromPtr(&fde_bytes[fbr.seek]), pc_rel_offset),
            .follow_indirect = is_runtime,
        }, endian) orelse return bad();

        const pc_range = try readEhPointer(&fbr, cie.fde_pointer_enc, addr_size_bytes, .{
            .pc_rel_base = 0,
            .follow_indirect = false,
        }, endian) orelse return bad();

        var aug_data: []const u8 = &[_]u8{};
        const lsda_pointer = if (cie.aug_str.len > 0) blk: {
            const aug_data_len = try fbr.takeLeb128(usize);
            const aug_data_start = fbr.seek;
            aug_data = fde_bytes[aug_data_start..][0..aug_data_len];

            const lsda_pointer = if (cie.lsda_pointer_enc != EH.PE.omit)
                try readEhPointer(&fbr, cie.lsda_pointer_enc, addr_size_bytes, .{
                    .pc_rel_base = try pcRelBase(@intFromPtr(&fde_bytes[fbr.seek]), pc_rel_offset),
                    .follow_indirect = is_runtime,
                }, endian)
            else
                null;

            fbr.seek = aug_data_start + aug_data_len;
            break :blk lsda_pointer;
        } else null;

        const instructions = fde_bytes[fbr.seek..];
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

/// If `.eh_frame_hdr` is present, then only the header needs to be parsed. Otherwise, `.eh_frame`
/// and `.debug_frame` are scanned and a sorted list of FDEs is built for binary searching during
/// unwinding. Even if `.eh_frame_hdr` is used, we may find during unwinding that it's incomplete,
/// in which case we build the sorted list of FDEs at that point.
///
/// See also `scanCieFdeInfo`.
pub fn scanAllUnwindInfo(di: *Dwarf, allocator: Allocator, base_address: usize) !void {
    const endian = di.endian;

    if (di.section(.eh_frame_hdr)) |eh_frame_hdr| blk: {
        var fbr: Reader = .fixed(eh_frame_hdr);

        const version = try fbr.takeByte();
        if (version != 1) break :blk;

        const eh_frame_ptr_enc = try fbr.takeByte();
        if (eh_frame_ptr_enc == EH.PE.omit) break :blk;
        const fde_count_enc = try fbr.takeByte();
        if (fde_count_enc == EH.PE.omit) break :blk;
        const table_enc = try fbr.takeByte();
        if (table_enc == EH.PE.omit) break :blk;

        const eh_frame_ptr = cast(usize, try readEhPointer(&fbr, eh_frame_ptr_enc, @sizeOf(usize), .{
            .pc_rel_base = @intFromPtr(&eh_frame_hdr[fbr.seek]),
            .follow_indirect = true,
        }, endian) orelse return bad()) orelse return bad();

        const fde_count = cast(usize, try readEhPointer(&fbr, fde_count_enc, @sizeOf(usize), .{
            .pc_rel_base = @intFromPtr(&eh_frame_hdr[fbr.seek]),
            .follow_indirect = true,
        }, endian) orelse return bad()) orelse return bad();

        const entry_size = try ExceptionFrameHeader.entrySize(table_enc);
        const entries_len = fde_count * entry_size;
        if (entries_len > eh_frame_hdr.len - fbr.seek) return bad();

        di.eh_frame_hdr = .{
            .eh_frame_ptr = eh_frame_ptr,
            .table_enc = table_enc,
            .fde_count = fde_count,
            .entries = eh_frame_hdr[fbr.seek..][0..entries_len],
        };

        // No need to scan .eh_frame, we have a binary search table already
        return;
    }

    try di.scanCieFdeInfo(allocator, base_address);
}

/// Scan `.eh_frame` and `.debug_frame` and build a sorted list of FDEs for binary searching during
/// unwinding.
pub fn scanCieFdeInfo(unwind: *Unwind, allocator: Allocator, endian: Endian, base_address: usize) !void {
    const frame_sections = [2]Section.Id{ .eh_frame, .debug_frame };
    for (frame_sections) |frame_section| {
        if (unwind.section(frame_section)) |section_data| {
            var fbr: Reader = .fixed(section_data);
            while (fbr.seek < fbr.buffer.len) {
                const entry_header = try EntryHeader.read(&fbr, frame_section, endian);
                switch (entry_header.type) {
                    .cie => {
                        const cie = try CommonInformationEntry.parse(
                            entry_header.entry_bytes,
                            unwind.sectionVirtualOffset(frame_section, base_address).?,
                            true,
                            entry_header.format,
                            frame_section,
                            entry_header.length_offset,
                            @sizeOf(usize),
                            endian,
                        );
                        try unwind.cie_map.put(allocator, entry_header.length_offset, cie);
                    },
                    .fde => |cie_offset| {
                        const cie = unwind.cie_map.get(cie_offset) orelse return bad();
                        const fde = try FrameDescriptionEntry.parse(
                            entry_header.entry_bytes,
                            unwind.sectionVirtualOffset(frame_section, base_address).?,
                            true,
                            cie,
                            @sizeOf(usize),
                            endian,
                        );
                        try unwind.fde_list.append(allocator, fde);
                    },
                    .terminator => break,
                }
            }

            std.mem.sortUnstable(FrameDescriptionEntry, unwind.fde_list.items, {}, struct {
                fn lessThan(ctx: void, a: FrameDescriptionEntry, b: FrameDescriptionEntry) bool {
                    _ = ctx;
                    return a.pc_begin < b.pc_begin;
                }
            }.lessThan);
        }
    }
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

fn readEhPointer(fbr: *Reader, enc: u8, addr_size_bytes: u8, ctx: EhPointerContext, endian: Endian) !?u64 {
    if (enc == EH.PE.omit) return null;

    const value: union(enum) {
        signed: i64,
        unsigned: u64,
    } = switch (enc & EH.PE.type_mask) {
        EH.PE.absptr => .{
            .unsigned = switch (addr_size_bytes) {
                2 => try fbr.takeInt(u16, endian),
                4 => try fbr.takeInt(u32, endian),
                8 => try fbr.takeInt(u64, endian),
                else => return error.InvalidAddrSize,
            },
        },
        EH.PE.uleb128 => .{ .unsigned = try fbr.takeLeb128(u64) },
        EH.PE.udata2 => .{ .unsigned = try fbr.takeInt(u16, endian) },
        EH.PE.udata4 => .{ .unsigned = try fbr.takeInt(u32, endian) },
        EH.PE.udata8 => .{ .unsigned = try fbr.takeInt(u64, endian) },
        EH.PE.sleb128 => .{ .signed = try fbr.takeLeb128(i64) },
        EH.PE.sdata2 => .{ .signed = try fbr.takeInt(i16, endian) },
        EH.PE.sdata4 => .{ .signed = try fbr.takeInt(i32, endian) },
        EH.PE.sdata8 => .{ .signed = try fbr.takeInt(i64, endian) },
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

const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const bad = Dwarf.bad;
const cast = std.math.cast;
const DW = std.dwarf;
const Dwarf = std.debug.Dwarf;
const EH = DW.EH;
const Endian = std.builtin.Endian;
const Format = DW.Format;
const maxInt = std.math.maxInt;
const missing = Dwarf.missing;
const Reader = std.Io.Reader;
const std = @import("std");
const Unwind = @This();
