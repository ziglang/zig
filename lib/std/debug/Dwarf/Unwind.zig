pub const VirtualMachine = @import("Unwind/VirtualMachine.zig");

/// The contents of the `.debug_frame` section as specified by DWARF. This might be a more reliable
/// stack unwind mechanism in some cases, or it may be present when `.eh_frame` is not, but fetching
/// the data requires loading the binary, so it is not a viable approach for fast stack trace
/// capturing within a process.
debug_frame: ?struct {
    data: []const u8,
    /// Offsets into `data` of FDEs, sorted by ascending `pc_begin`.
    sorted_fdes: []SortedFdeEntry,
},

/// Data associated with the `.eh_frame` and `.eh_frame_hdr` sections as defined by LSB Core. The
/// format of `.eh_frame` is an extension of that of DWARF's `.debug_frame` -- in fact it is almost
/// identical, though subtly different in a few places.
eh_frame: ?struct {
    header: EhFrameHeader,
    /// Though this is a slice, it may be longer than the `.eh_frame` section. When unwinding
    /// through the runtime-loaded `.eh_frame_hdr` data, we are not told the size of the `.eh_frame`
    /// section, so construct a slice referring to all of the rest of memory. The end of the section
    /// must be detected through `EntryHeader.terminator`.
    eh_frame_data: []const u8,
    /// Offsets into `eh_frame_data` of FDEs, sorted by ascending `pc_begin`.
    /// Populated only if `header` does not already contain a lookup table.
    sorted_fdes: ?[]SortedFdeEntry,
},

const SortedFdeEntry = struct {
    /// This FDE's value of `pc_begin`.
    pc_begin: u64,
    /// Offset into the section of the corresponding FDE, including the entry header.
    fde_offset: u64,
};

const Section = enum { debug_frame, eh_frame };

/// This represents the decoded .eh_frame_hdr header
pub const EhFrameHeader = struct {
    vaddr: u64,
    eh_frame_vaddr: u64,
    search_table: ?struct {
        /// The byte offset of the search table into the `.eh_frame_hdr` section.
        offset: u8,
        encoding: EH.PE,
        fde_count: usize,
        entries: []const u8,
    },

    pub fn entrySize(table_enc: EH.PE, addr_size_bytes: u8) !u8 {
        return switch (table_enc.type) {
            .absptr => 2 * addr_size_bytes,
            .udata2, .sdata2 => 4,
            .udata4, .sdata4 => 8,
            .udata8, .sdata8 => 16,
            .uleb128, .sleb128 => return bad(), // this is a binary search table; all entries must be the same size
            _ => return bad(),
        };
    }

    pub fn parse(
        eh_frame_hdr_vaddr: u64,
        eh_frame_hdr_bytes: []const u8,
        addr_size_bytes: u8,
        endian: Endian,
    ) !EhFrameHeader {
        var r: Reader = .fixed(eh_frame_hdr_bytes);

        const version = try r.takeByte();
        if (version != 1) return bad();

        const eh_frame_ptr_enc: EH.PE = @bitCast(try r.takeByte());
        const fde_count_enc: EH.PE = @bitCast(try r.takeByte());
        const table_enc: EH.PE = @bitCast(try r.takeByte());

        const eh_frame_ptr = try readEhPointer(&r, eh_frame_ptr_enc, addr_size_bytes, .{
            .pc_rel_base = eh_frame_hdr_vaddr + r.seek,
        }, endian);

        return .{
            .vaddr = eh_frame_hdr_vaddr,
            .eh_frame_vaddr = eh_frame_ptr,
            .search_table = table: {
                if (fde_count_enc == EH.PE.omit) break :table null;
                if (table_enc == EH.PE.omit) break :table null;
                const fde_count = try readEhPointer(&r, fde_count_enc, addr_size_bytes, .{
                    .pc_rel_base = eh_frame_hdr_vaddr + r.seek,
                }, endian);
                const entry_size = try entrySize(table_enc, addr_size_bytes);
                const bytes_offset = r.seek;
                const bytes_len = cast(usize, fde_count * entry_size) orelse return error.EndOfStream;
                const bytes = try r.take(bytes_len);
                break :table .{
                    .encoding = table_enc,
                    .fde_count = @intCast(fde_count),
                    .entries = bytes,
                    .offset = @intCast(bytes_offset),
                };
            },
        };
    }

    /// Asserts that `eh_frame_hdr.search_table != null`.
    fn findEntry(
        eh_frame_hdr: *const EhFrameHeader,
        pc: u64,
        addr_size_bytes: u8,
        endian: Endian,
    ) !?u64 {
        const table = &eh_frame_hdr.search_table.?;
        const table_vaddr = eh_frame_hdr.vaddr + table.offset;
        const entry_size = try EhFrameHeader.entrySize(table.encoding, addr_size_bytes);
        var left: usize = 0;
        var len: usize = table.fde_count;
        while (len > 1) {
            const mid = left + len / 2;
            var entry_reader: Reader = .fixed(table.entries[mid * entry_size ..][0..entry_size]);
            const pc_begin = try readEhPointer(&entry_reader, table.encoding, addr_size_bytes, .{
                .pc_rel_base = table_vaddr + left * entry_size,
                .data_rel_base = eh_frame_hdr.vaddr,
            }, endian);
            if (pc < pc_begin) {
                len /= 2;
            } else {
                left = mid;
                len -= len / 2;
            }
        }
        if (len == 0) return null;
        var entry_reader: Reader = .fixed(table.entries[left * entry_size ..][0..entry_size]);
        // Skip past `pc_begin`; we're now interested in the fde offset
        _ = try readEhPointerAbs(&entry_reader, table.encoding.type, addr_size_bytes, endian);
        const fde_ptr = try readEhPointer(&entry_reader, table.encoding, addr_size_bytes, .{
            .pc_rel_base = table_vaddr + left * entry_size,
            .data_rel_base = eh_frame_hdr.vaddr,
        }, endian);
        return std.math.sub(u64, fde_ptr, eh_frame_hdr.eh_frame_vaddr) catch bad(); // offset into .eh_frame
    }
};

pub const EntryHeader = union(enum) {
    cie: struct {
        format: Format,
        /// Remaining bytes in the CIE. These are parseable by `CommonInformationEntry.parse`.
        bytes_len: u64,
    },
    fde: struct {
        format: Format,
        /// Offset into the section of the corresponding CIE, *including* its entry header.
        cie_offset: u64,
        /// Remaining bytes in the FDE. These are parseable by `FrameDescriptionEntry.parse`.
        bytes_len: u64,
    },
    /// The `.eh_frame` format includes terminators which indicate that the last CIE/FDE has been
    /// reached. However, `.debug_frame` does not include such a terminator, so the caller must
    /// keep track of how many section bytes remain when parsing all entries in `.debug_frame`.
    terminator,

    pub fn read(r: *Reader, header_section_offset: u64, section: Section, endian: Endian) !EntryHeader {
        const unit_header = try Dwarf.readUnitHeader(r, endian);
        if (unit_header.unit_length == 0) return .terminator;

        // TODO MLUGG: seriously, just... check the formats of everything in BOTH LSB Core and DWARF. this is a fucking *mess*. maybe add spec references.

        // Next is a value which will disambiguate CIEs and FDEs. Annoyingly, LSB Core makes this
        // value always 4-byte, whereas DWARF makes it depend on the `dwarf.Format`.
        const cie_ptr_or_id_size: u8 = switch (section) {
            .eh_frame => 4,
            .debug_frame => switch (unit_header.format) {
                .@"32" => 4,
                .@"64" => 8,
            },
        };
        const cie_ptr_or_id = switch (cie_ptr_or_id_size) {
            4 => try r.takeInt(u32, endian),
            8 => try r.takeInt(u64, endian),
            else => unreachable,
        };
        const remaining_bytes = unit_header.unit_length - cie_ptr_or_id_size;

        // If this entry is a CIE, then `cie_ptr_or_id` will have this value, which is different
        // between the DWARF `.debug_frame` section and the LSB Core `.eh_frame` section.
        const cie_id: u64 = switch (section) {
            .eh_frame => 0,
            .debug_frame => switch (unit_header.format) {
                .@"32" => maxInt(u32),
                .@"64" => maxInt(u64),
            },
        };
        if (cie_ptr_or_id == cie_id) {
            return .{ .cie = .{
                .format = unit_header.format,
                .bytes_len = remaining_bytes,
            } };
        }

        // This is an FDE -- `cie_ptr_or_id` points to the associated CIE. Unfortunately, the format
        // of that pointer again differs between `.debug_frame` and `.eh_frame`.
        const cie_offset = switch (section) {
            .eh_frame => try std.math.sub(u64, header_section_offset + unit_header.header_length, cie_ptr_or_id),
            .debug_frame => cie_ptr_or_id,
        };
        return .{ .fde = .{
            .format = unit_header.format,
            .cie_offset = cie_offset,
            .bytes_len = remaining_bytes,
        } };
    }
};

pub const CommonInformationEntry = struct {
    version: u8,

    /// In version 4, CIEs can specify the address size used in the CIE and associated FDEs.
    /// This value must be used *only* to parse associated FDEs in `FrameDescriptionEntry.parse`.
    addr_size_bytes: u8,

    /// Always 0 for versions which do not specify this (currently all versions other than 4).
    segment_selector_size: u8,

    code_alignment_factor: u32,
    data_alignment_factor: i32,
    return_address_register: u8,

    fde_pointer_enc: EH.PE,
    is_signal_frame: bool,

    augmentation_kind: AugmentationKind,

    initial_instructions: []const u8,

    pub const AugmentationKind = enum { none, gcc_eh, lsb_z };

    /// This function expects to read the CIE starting with the version field.
    /// The returned struct references memory backed by `cie_bytes`.
    ///
    /// `length_offset` specifies the offset of this CIE's length field in the
    /// .eh_frame / .debug_frame section.
    pub fn parse(
        cie_bytes: []const u8,
        section: Section,
        default_addr_size_bytes: u8,
    ) !CommonInformationEntry {
        // We only read the data through this reader.
        var r: Reader = .fixed(cie_bytes);

        const version = try r.takeByte();
        switch (section) {
            .eh_frame => if (version != 1 and version != 3) return error.UnsupportedDwarfVersion,
            .debug_frame => if (version != 4) return error.UnsupportedDwarfVersion,
        }

        const aug_str = try r.takeSentinel(0);
        const aug_kind: AugmentationKind = aug: {
            if (aug_str.len == 0) break :aug .none;
            if (aug_str[0] == 'z') break :aug .lsb_z;
            if (std.mem.eql(u8, aug_str, "eh")) break :aug .gcc_eh;
            // We can't finish parsing the CIE if we don't know what its augmentation means.
            return bad();
        };

        switch (aug_kind) {
            .none => {}, // no extra data
            .lsb_z => {}, // no extra data yet, but there is a bit later
            .gcc_eh => try r.discardAll(default_addr_size_bytes), // unsupported data
        }

        const addr_size_bytes = if (version == 4) try r.takeByte() else default_addr_size_bytes;
        const segment_selector_size: u8 = if (version == 4) try r.takeByte() else 0;
        const code_alignment_factor = try r.takeLeb128(u32);
        const data_alignment_factor = try r.takeLeb128(i32);
        const return_address_register = if (version == 1) try r.takeByte() else try r.takeLeb128(u8);

        // This is where LSB's augmentation might add some data.
        const fde_pointer_enc: EH.PE, const is_signal_frame: bool = aug: {
            const default_fde_pointer_enc: EH.PE = .{ .type = .absptr, .rel = .abs };
            if (aug_kind != .lsb_z) break :aug .{ default_fde_pointer_enc, false };
            const aug_data_len = try r.takeLeb128(u32);
            var aug_data: Reader = .fixed(try r.take(aug_data_len));
            var fde_pointer_enc: EH.PE = default_fde_pointer_enc;
            var is_signal_frame = false;
            for (aug_str[1..]) |byte| switch (byte) {
                'L' => _ = try aug_data.takeByte(), // we ignore the LSDA pointer
                'P' => {
                    const enc: EH.PE = @bitCast(try aug_data.takeByte());
                    const endian: Endian = .little; // irrelevant because we're discarding the value anyway
                    _ = try readEhPointerAbs(&r, enc.type, addr_size_bytes, endian); // we ignore the personality routine; endianness is irrelevant since we're discarding
                },
                'R' => fde_pointer_enc = @bitCast(try aug_data.takeByte()),
                'S' => is_signal_frame = true,
                'B', 'G' => {},
                else => return bad(),
            };
            break :aug .{ fde_pointer_enc, is_signal_frame };
        };

        return .{
            .version = version,
            .addr_size_bytes = addr_size_bytes,
            .segment_selector_size = segment_selector_size,
            .code_alignment_factor = code_alignment_factor,
            .data_alignment_factor = data_alignment_factor,
            .return_address_register = return_address_register,
            .fde_pointer_enc = fde_pointer_enc,
            .is_signal_frame = is_signal_frame,
            .augmentation_kind = aug_kind,
            .initial_instructions = r.buffered(),
        };
    }
};

pub const FrameDescriptionEntry = struct {
    pc_begin: u64,
    pc_range: u64,
    instructions: []const u8,

    /// This function expects to read the FDE starting at the PC Begin field.
    /// The returned struct references memory backed by `fde_bytes`.
    pub fn parse(
        /// The virtual address of the FDE we're parsing, *excluding* its entry header (i.e. the
        /// address is after the header). If `fde_bytes` is backed by the memory of a loaded
        /// module's `.eh_frame` section, this will equal `fde_bytes.ptr`.
        fde_vaddr: u64,
        fde_bytes: []const u8,
        cie: CommonInformationEntry,
        endian: Endian,
    ) !FrameDescriptionEntry {
        if (cie.segment_selector_size != 0) return error.UnsupportedAddrSize;

        var r: Reader = .fixed(fde_bytes);

        const pc_begin = try readEhPointer(&r, cie.fde_pointer_enc, cie.addr_size_bytes, .{
            .pc_rel_base = fde_vaddr,
        }, endian);

        // I swear I'm not kidding when I say that PC Range is encoded with `cie.fde_pointer_enc`, but ignoring `rel`.
        const pc_range = switch (try readEhPointerAbs(&r, cie.fde_pointer_enc.type, cie.addr_size_bytes, endian)) {
            .unsigned => |x| x,
            .signed => |x| cast(u64, x) orelse return bad(),
        };

        switch (cie.augmentation_kind) {
            .none, .gcc_eh => {},
            .lsb_z => {
                // There is augmentation data, but it's irrelevant to us -- it
                // only contains the LSDA pointer, which we don't care about.
                const aug_data_len = try r.takeLeb128(u64);
                _ = try r.discardAll(aug_data_len);
            },
        }

        return .{
            .pc_begin = pc_begin,
            .pc_range = pc_range,
            .instructions = r.buffered(),
        };
    }
};

pub fn scanDebugFrame(
    unwind: *Unwind,
    gpa: Allocator,
    section_vaddr: u64,
    section_bytes: []const u8,
    addr_size_bytes: u8,
    endian: Endian,
) void {
    assert(unwind.debug_frame == null);

    var fbr: Reader = .fixed(section_bytes);
    var fde_list: std.ArrayList(SortedFdeEntry) = .empty;
    defer fde_list.deinit(gpa);
    while (fbr.seek < fbr.buffer.len) {
        const entry_offset = fbr.seek;
        switch (try EntryHeader.read(&fbr, fbr.seek, .debug_frame, endian)) {
            // Ignore CIEs; we only need them to parse the FDEs!
            .cie => |info| {
                try fbr.discardAll(info.bytes_len);
                continue;
            },
            .fde => |info| {
                const cie: CommonInformationEntry = cie: {
                    var cie_reader: Reader = .fixed(section_bytes[info.cie_offset..]);
                    const cie_info = switch (try EntryHeader.read(&cie_reader, info.cie_offset, .debug_frame, endian)) {
                        .cie => |cie_info| cie_info,
                        .fde, .terminator => return bad(), // This is meant to be a CIE
                    };
                    break :cie try .parse(try cie_reader.take(cie_info.bytes_len), .debug_frame, addr_size_bytes);
                };
                const fde: FrameDescriptionEntry = try .parse(
                    section_vaddr + fbr.seek,
                    try fbr.take(info.bytes_len),
                    cie,
                    endian,
                );
                try fde_list.append(.{
                    .pc_begin = fde.pc_begin,
                    .fde_offset = entry_offset, // *not* `fde_offset`, because we need to include the entry header
                });
            },
            .terminator => return bad(), // DWARF `.debug_frame` isn't meant to have terminators
        }
    }
    const fde_slice = try fde_list.toOwnedSlice(gpa);
    errdefer comptime unreachable;
    std.mem.sortUnstable(SortedFdeEntry, fde_slice, {}, struct {
        fn lessThan(ctx: void, a: SortedFdeEntry, b: SortedFdeEntry) bool {
            ctx;
            return a.pc_begin < b.pc_begin;
        }
    }.lessThan);
    unwind.debug_frame = .{ .data = section_bytes, .sorted_fdes = fde_slice };
}

pub fn scanEhFrame(
    unwind: *Unwind,
    gpa: Allocator,
    header: EhFrameHeader,
    section_bytes_ptr: [*]const u8,
    /// This is separate from `section_bytes_ptr` because it is unknown when `.eh_frame` is accessed
    /// through the pointer in the `.eh_frame_hdr` section. If this is non-`null`, we avoid reading
    /// past this number of bytes, but if `null`, we must assume that the `.eh_frame` data has a
    /// valid terminator.
    section_bytes_len: ?usize,
    addr_size_bytes: u8,
    endian: Endian,
) !void {
    assert(unwind.eh_frame == null);

    const section_bytes: []const u8 = bytes: {
        // If the length is unknown, let the slice span from `section_bytes_ptr` to the end of memory.
        const len = section_bytes_len orelse (std.math.maxInt(usize) - @intFromPtr(section_bytes_ptr));
        break :bytes section_bytes_ptr[0..len];
    };

    if (header.search_table != null) {
        // No need to populate `sorted_fdes`, the header contains a search table.
        unwind.eh_frame = .{
            .header = header,
            .eh_frame_data = section_bytes,
            .sorted_fdes = null,
        };
        return;
    }

    // We aren't told the length of this section. Luckily, we don't need it, because there will be
    // an `EntryHeader.terminator` after the last CIE/FDE. Just make a `Reader` which will give us
    // alllll of the bytes!
    var fbr: Reader = .fixed(section_bytes);

    var fde_list: std.ArrayList(SortedFdeEntry) = .empty;
    defer fde_list.deinit(gpa);

    while (true) {
        const entry_offset = fbr.seek;
        switch (try EntryHeader.read(&fbr, fbr.seek, .eh_frame, endian)) {
            // Ignore CIEs; we only need them to parse the FDEs!
            .cie => |info| {
                try fbr.discardAll(info.bytes_len);
                continue;
            },
            .fde => |info| {
                const cie: CommonInformationEntry = cie: {
                    var cie_reader: Reader = .fixed(section_bytes[info.cie_offset..]);
                    const cie_info = switch (try EntryHeader.read(&cie_reader, info.cie_offset, .eh_frame, endian)) {
                        .cie => |cie_info| cie_info,
                        .fde, .terminator => return bad(), // This is meant to be a CIE
                    };
                    break :cie try .parse(try cie_reader.take(cie_info.bytes_len), .eh_frame, addr_size_bytes);
                };
                const fde: FrameDescriptionEntry = try .parse(
                    header.eh_frame_vaddr + fbr.seek,
                    try fbr.take(info.bytes_len),
                    cie,
                    endian,
                );
                try fde_list.append(gpa, .{
                    .pc_begin = fde.pc_begin,
                    .fde_offset = entry_offset, // *not* `fde_offset`, because we need to include the entry header
                });
            },
            // Unlike `.debug_frame`, the `.eh_frame` section does have a terminator CIE -- this is
            // necessary because `header` doesn't include the length of the `.eh_frame` section
            .terminator => break,
        }
    }
    const fde_slice = try fde_list.toOwnedSlice(gpa);
    errdefer comptime unreachable;
    std.mem.sortUnstable(SortedFdeEntry, fde_slice, {}, struct {
        fn lessThan(ctx: void, a: SortedFdeEntry, b: SortedFdeEntry) bool {
            ctx;
            return a.pc_begin < b.pc_begin;
        }
    }.lessThan);
    unwind.eh_frame = .{
        .header = header,
        .eh_frame_data = section_bytes,
        .sorted_fdes = fde_slice,
    };
}

/// The return value may be a false positive. After loading the FDE with `loadFde`, the caller must
/// validate that `pc` is indeed in its range -- if it is not, then no FDE matches `pc`.
pub fn findFdeOffset(unwind: *const Unwind, pc: u64, addr_size_bytes: u8, endian: Endian) !?u64 {
    // We'll break from this block only if we have a manually-constructed search table.
    const sorted_fdes: []const SortedFdeEntry = fdes: {
        if (unwind.debug_frame) |df| break :fdes df.sorted_fdes;
        if (unwind.eh_frame) |eh_frame| {
            if (eh_frame.sorted_fdes) |fdes| break :fdes fdes;
            // Use the search table from the `.eh_frame_hdr` section rather than one of our own
            return eh_frame.header.findEntry(pc, addr_size_bytes, endian);
        }
        // We have no available unwind info
        return null;
    };
    const first_bad_idx = std.sort.partitionPoint(SortedFdeEntry, sorted_fdes, pc, struct {
        fn canIncludePc(target_pc: u64, entry: SortedFdeEntry) bool {
            return target_pc >= entry.pc_begin; // i.e. does 'entry_pc..<last pc>' include 'target_pc'
        }
    }.canIncludePc);
    // `first_bad_idx` is the index of the first FDE whose `pc_begin` is too high to include `pc`.
    // So if any FDE matches, it'll be the one at `first_bad_idx - 1` (maybe false positive).
    if (first_bad_idx == 0) return null;
    return sorted_fdes[first_bad_idx - 1].fde_offset;
}

pub fn loadFde(unwind: *const Unwind, fde_offset: u64, addr_size_bytes: u8, endian: Endian) !struct { Format, CommonInformationEntry, FrameDescriptionEntry } {
    const section_bytes: []const u8, const section_vaddr: u64, const section: Section = s: {
        if (unwind.debug_frame) |df| break :s .{ df.data, if (true) @panic("MLUGG TODO"), .debug_frame };
        if (unwind.eh_frame) |ef| break :s .{ ef.eh_frame_data, ef.header.eh_frame_vaddr, .eh_frame };
        unreachable; // how did you get `fde_offset`?!
    };

    var fde_reader: Reader = .fixed(section_bytes[fde_offset..]);
    const fde_info = switch (try EntryHeader.read(&fde_reader, fde_offset, section, endian)) {
        .fde => |info| info,
        .cie, .terminator => return bad(), // This is meant to be an FDE
    };

    const cie_offset = fde_info.cie_offset;
    var cie_reader: Reader = .fixed(section_bytes[cie_offset..]);
    const cie_info = switch (try EntryHeader.read(&cie_reader, cie_offset, section, endian)) {
        .cie => |info| info,
        .fde, .terminator => return bad(), // This is meant to be a CIE
    };

    const cie: CommonInformationEntry = try .parse(
        try cie_reader.take(cie_info.bytes_len),
        section,
        addr_size_bytes,
    );
    const fde: FrameDescriptionEntry = try .parse(
        section_vaddr + fde_offset + fde_reader.seek,
        try fde_reader.take(fde_info.bytes_len),
        cie,
        endian,
    );

    return .{ cie_info.format, cie, fde };
}

const EhPointerContext = struct {
    // The address of the pointer field itself
    pc_rel_base: u64,

    // These relative addressing modes are only used in specific cases, and
    // might not be available / required in all parsing contexts
    data_rel_base: ?u64 = null,
    text_rel_base: ?u64 = null,
    function_rel_base: ?u64 = null,
};
/// Returns `error.InvalidDebugInfo` if the encoding is `EH.PE.omit`.
fn readEhPointerAbs(r: *Reader, enc_ty: EH.PE.Type, addr_size_bytes: u8, endian: Endian) !union(enum) {
    signed: i64,
    unsigned: u64,
} {
    return switch (enc_ty) {
        .absptr => .{
            .unsigned = switch (addr_size_bytes) {
                2 => try r.takeInt(u16, endian),
                4 => try r.takeInt(u32, endian),
                8 => try r.takeInt(u64, endian),
                else => return error.UnsupportedAddrSize,
            },
        },
        .uleb128 => .{ .unsigned = try r.takeLeb128(u64) },
        .udata2 => .{ .unsigned = try r.takeInt(u16, endian) },
        .udata4 => .{ .unsigned = try r.takeInt(u32, endian) },
        .udata8 => .{ .unsigned = try r.takeInt(u64, endian) },
        .sleb128 => .{ .signed = try r.takeLeb128(i64) },
        .sdata2 => .{ .signed = try r.takeInt(i16, endian) },
        .sdata4 => .{ .signed = try r.takeInt(i32, endian) },
        .sdata8 => .{ .signed = try r.takeInt(i64, endian) },
        else => return bad(),
    };
}
/// Returns `error.InvalidDebugInfo` if the encoding is `EH.PE.omit`.
fn readEhPointer(fbr: *Reader, enc: EH.PE, addr_size_bytes: u8, ctx: EhPointerContext, endian: Endian) !u64 {
    const offset = try readEhPointerAbs(fbr, enc.type, addr_size_bytes, endian);
    const base = switch (enc.rel) {
        .abs, .aligned => 0,
        .pcrel => ctx.pc_rel_base,
        .textrel => ctx.text_rel_base orelse return bad(),
        .datarel => ctx.data_rel_base orelse return bad(),
        .funcrel => ctx.function_rel_base orelse return bad(),
        .indirect => return bad(), // GCC extension; not supported
        _ => return bad(),
    };
    return switch (offset) {
        .signed => |s| @intCast(try std.math.add(i64, s, @as(i64, @intCast(base)))),
        // absptr can actually contain signed values in some cases (aarch64 MachO)
        .unsigned => |u| u +% base,
    };
}

/// Like `Reader.fixed`, but when the length of the data is unknown and we just want to allow
/// reading indefinitely.
fn maxSlice(ptr: [*]const u8) []const u8 {
    const len = std.math.maxInt(usize) - @intFromPtr(ptr);
    return ptr[0..len];
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
