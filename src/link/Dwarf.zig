gpa: std.mem.Allocator,
bin_file: *link.File,
format: DW.Format,
endian: std.builtin.Endian,
address_size: AddressSize,

mods: std.AutoArrayHashMapUnmanaged(*Module, ModInfo),
types: std.AutoArrayHashMapUnmanaged(InternPool.Index, Entry.Index),
navs: std.AutoArrayHashMapUnmanaged(InternPool.Nav.Index, Entry.Index),

debug_abbrev: DebugAbbrev,
debug_aranges: DebugAranges,
debug_frame: DebugFrame,
debug_info: DebugInfo,
debug_line: DebugLine,
debug_line_str: StringSection,
debug_loclists: DebugLocLists,
debug_rnglists: DebugRngLists,
debug_str: StringSection,

pub const UpdateError = error{
    ReinterpretDeclRef,
    IllDefinedMemoryLayout,
    Unimplemented,
    OutOfMemory,
    EndOfStream,
    Overflow,
    Underflow,
    UnexpectedEndOfFile,
} ||
    std.fs.File.OpenError ||
    std.fs.File.SetEndPosError ||
    std.fs.File.CopyRangeError ||
    std.fs.File.PReadError ||
    std.fs.File.PWriteError;

pub const FlushError =
    UpdateError ||
    std.process.GetCwdError;

pub const RelocError =
    std.fs.File.PWriteError;

pub const AddressSize = enum(u8) {
    @"32" = 4,
    @"64" = 8,
    _,
};

const ModInfo = struct {
    root_dir_path: Entry.Index,
    dirs: std.AutoArrayHashMapUnmanaged(Unit.Index, void),
    files: Files,

    const Files = std.AutoArrayHashMapUnmanaged(Zcu.File.Index, void);

    fn deinit(mod_info: *ModInfo, gpa: std.mem.Allocator) void {
        mod_info.dirs.deinit(gpa);
        mod_info.files.deinit(gpa);
        mod_info.* = undefined;
    }
};

const DebugAbbrev = struct {
    section: Section,
    const unit: Unit.Index = @enumFromInt(0);

    const header_bytes = 0;

    const trailer_bytes = uleb128Bytes(@intFromEnum(AbbrevCode.null));
};

const DebugAranges = struct {
    section: Section,

    fn headerBytes(dwarf: *Dwarf) u32 {
        return dwarf.unitLengthBytes() + 2 + dwarf.sectionOffsetBytes() + 1 + 1;
    }

    fn trailerBytes(dwarf: *Dwarf) u32 {
        return @intFromEnum(dwarf.address_size) * 2;
    }
};

const DebugFrame = struct {
    header: Header,
    section: Section,

    const Format = enum { none, debug_frame, eh_frame };
    const Header = struct {
        format: Format,
        code_alignment_factor: u32,
        data_alignment_factor: i32,
        return_address_register: u32,
        initial_instructions: []const Cfa,
    };

    fn headerBytes(dwarf: *Dwarf) u32 {
        const target = dwarf.bin_file.comp.root_mod.resolved_target.result;
        return @intCast(switch (dwarf.debug_frame.header.format) {
            .none => return 0,
            .debug_frame => dwarf.unitLengthBytes() + dwarf.sectionOffsetBytes() + 1 + "\x00".len + 1 + 1,
            .eh_frame => dwarf.unitLengthBytes() + 4 + 1 + "zR\x00".len +
                uleb128Bytes(1) + 1,
        } + switch (target.cpu.arch) {
            .x86_64 => len: {
                dev.check(.x86_64_backend);
                const Register = @import("../arch/x86_64/bits.zig").Register;
                break :len uleb128Bytes(1) + sleb128Bytes(-8) + uleb128Bytes(Register.rip.dwarfNum()) +
                    1 + uleb128Bytes(Register.rsp.dwarfNum()) + sleb128Bytes(-1) +
                    1 + uleb128Bytes(1);
            },
            else => unreachable,
        });
    }

    fn trailerBytes(dwarf: *Dwarf) u32 {
        return @intCast(switch (dwarf.debug_frame.header.format) {
            .none => 0,
            .debug_frame => dwarf.unitLengthBytes() + dwarf.sectionOffsetBytes() + 1 + "\x00".len + 1 + 1 + uleb128Bytes(1) + sleb128Bytes(1) + uleb128Bytes(0),
            .eh_frame => dwarf.unitLengthBytes() + 4 + 1 + "\x00".len + uleb128Bytes(1) + sleb128Bytes(1) + uleb128Bytes(0),
        });
    }
};

const DebugInfo = struct {
    section: Section,

    fn headerBytes(dwarf: *Dwarf) u32 {
        return dwarf.unitLengthBytes() + 2 + 1 + 1 + dwarf.sectionOffsetBytes() +
            uleb128Bytes(@intFromEnum(AbbrevCode.compile_unit)) + 1 + dwarf.sectionOffsetBytes() * 6 + uleb128Bytes(0) +
            uleb128Bytes(@intFromEnum(AbbrevCode.module)) + dwarf.sectionOffsetBytes() + uleb128Bytes(0);
    }

    fn declEntryLineOff(dwarf: *Dwarf) u32 {
        return AbbrevCode.decl_bytes + dwarf.sectionOffsetBytes();
    }

    const trailer_bytes = 1 + 1;
};

const DebugLine = struct {
    header: Header,
    section: Section,

    const Header = struct {
        minimum_instruction_length: u8,
        maximum_operations_per_instruction: u8,
        default_is_stmt: bool,
        line_base: i8,
        line_range: u8,
        opcode_base: u8,
    };

    fn dirIndexInfo(dir_count: u32) struct { bytes: u8, form: DeclValEnum(DW.FORM) } {
        return if (dir_count <= 1 << 8)
            .{ .bytes = 1, .form = .data1 }
        else if (dir_count <= 1 << 16)
            .{ .bytes = 2, .form = .data2 }
        else
            unreachable;
    }

    fn headerBytes(dwarf: *Dwarf, dir_count: u32, file_count: u32) u32 {
        const dir_index_info = dirIndexInfo(dir_count);
        return dwarf.unitLengthBytes() + 2 + 1 + 1 + dwarf.sectionOffsetBytes() + 1 + 1 + 1 + 1 + 1 + 1 + 1 * (dwarf.debug_line.header.opcode_base - 1) +
            1 + uleb128Bytes(DW.LNCT.path) + uleb128Bytes(DW.FORM.line_strp) + uleb128Bytes(dir_count) + (dwarf.sectionOffsetBytes()) * dir_count +
            1 + uleb128Bytes(DW.LNCT.path) + uleb128Bytes(DW.FORM.line_strp) + uleb128Bytes(DW.LNCT.directory_index) + uleb128Bytes(@intFromEnum(dir_index_info.form)) + uleb128Bytes(DW.LNCT.LLVM_source) + uleb128Bytes(DW.FORM.line_strp) + uleb128Bytes(file_count) + (dwarf.sectionOffsetBytes() + dir_index_info.bytes + dwarf.sectionOffsetBytes()) * file_count;
    }

    const trailer_bytes = 1 + uleb128Bytes(1) + 1;
};

const DebugLocLists = struct {
    section: Section,

    fn baseOffset(dwarf: *Dwarf) u32 {
        return dwarf.unitLengthBytes() + 2 + 1 + 1 + 4;
    }

    fn headerBytes(dwarf: *Dwarf) u32 {
        return baseOffset(dwarf);
    }

    const trailer_bytes = 0;
};

const DebugRngLists = struct {
    section: Section,

    const baseOffset = DebugLocLists.baseOffset;

    fn headerBytes(dwarf: *Dwarf) u32 {
        return baseOffset(dwarf) + dwarf.sectionOffsetBytes() * 1;
    }

    const trailer_bytes = 1;
};

const StringSection = struct {
    contents: std.ArrayListUnmanaged(u8),
    map: std.AutoArrayHashMapUnmanaged(void, void),
    section: Section,

    const unit: Unit.Index = @enumFromInt(0);

    const init: StringSection = .{
        .contents = .{},
        .map = .{},
        .section = Section.init,
    };

    fn deinit(str_sec: *StringSection, gpa: std.mem.Allocator) void {
        str_sec.contents.deinit(gpa);
        str_sec.map.deinit(gpa);
        str_sec.section.deinit(gpa);
    }

    fn addString(str_sec: *StringSection, dwarf: *Dwarf, str: []const u8) UpdateError!Entry.Index {
        const gop = try str_sec.map.getOrPutAdapted(dwarf.gpa, str, Adapter{ .str_sec = str_sec });
        errdefer _ = str_sec.map.pop();
        const entry: Entry.Index = @enumFromInt(gop.index);
        if (!gop.found_existing) {
            const unit_ptr = str_sec.section.getUnit(unit);
            assert(try str_sec.section.getUnit(unit).addEntry(dwarf.gpa) == entry);
            errdefer _ = unit_ptr.entries.pop();
            const entry_ptr = unit_ptr.getEntry(entry);
            if (unit_ptr.last.unwrap()) |last_entry|
                unit_ptr.getEntry(last_entry).next = entry.toOptional();
            entry_ptr.prev = unit_ptr.last;
            unit_ptr.last = entry.toOptional();
            entry_ptr.off = @intCast(str_sec.contents.items.len);
            entry_ptr.len = @intCast(str.len + 1);
            try str_sec.contents.ensureUnusedCapacity(dwarf.gpa, str.len + 1);
            str_sec.contents.appendSliceAssumeCapacity(str);
            str_sec.contents.appendAssumeCapacity(0);
            str_sec.section.dirty = true;
        }
        return entry;
    }

    const Adapter = struct {
        str_sec: *StringSection,

        pub fn hash(_: Adapter, key: []const u8) u32 {
            return @truncate(std.hash.Wyhash.hash(0, key));
        }

        pub fn eql(adapter: Adapter, key: []const u8, _: void, rhs_index: usize) bool {
            const entry = adapter.str_sec.section.getUnit(unit).getEntry(@enumFromInt(rhs_index));
            return std.mem.eql(u8, key, adapter.str_sec.contents.items[entry.off..][0 .. entry.len - 1 :0]);
        }
    };
};

/// A linker section containing a sequence of `Unit`s.
pub const Section = struct {
    dirty: bool,
    pad_to_ideal: bool,
    alignment: InternPool.Alignment,
    index: u32,
    first: Unit.Index.Optional,
    last: Unit.Index.Optional,
    len: u64,
    units: std.ArrayListUnmanaged(Unit),

    pub const Index = enum {
        debug_abbrev,
        debug_aranges,
        debug_frame,
        debug_info,
        debug_line,
        debug_line_str,
        debug_loclists,
        debug_rnglists,
        debug_str,
    };

    const init: Section = .{
        .dirty = true,
        .pad_to_ideal = true,
        .alignment = .@"1",
        .index = std.math.maxInt(u32),
        .first = .none,
        .last = .none,
        .units = .{},
        .len = 0,
    };

    fn deinit(sec: *Section, gpa: std.mem.Allocator) void {
        for (sec.units.items) |*unit| unit.deinit(gpa);
        sec.units.deinit(gpa);
        sec.* = undefined;
    }

    fn off(sec: Section, dwarf: *Dwarf) u64 {
        if (dwarf.bin_file.cast(.elf)) |elf_file| {
            const zo = elf_file.zigObjectPtr().?;
            const atom = zo.symbol(sec.index).atom(elf_file).?;
            return atom.offset(elf_file);
        } else if (dwarf.bin_file.cast(.macho)) |macho_file| {
            const header = if (macho_file.d_sym) |d_sym|
                d_sym.sections.items[sec.index]
            else
                macho_file.sections.items(.header)[sec.index];
            return header.offset;
        } else unreachable;
    }

    fn addUnit(sec: *Section, header_len: u32, trailer_len: u32, dwarf: *Dwarf) UpdateError!Unit.Index {
        const unit: Unit.Index = @enumFromInt(sec.units.items.len);
        const unit_ptr = try sec.units.addOne(dwarf.gpa);
        errdefer sec.popUnit(dwarf.gpa);
        const aligned_header_len: u32 = @intCast(sec.alignment.forward(header_len));
        const aligned_trailer_len: u32 = @intCast(sec.alignment.forward(trailer_len));
        unit_ptr.* = .{
            .prev = sec.last,
            .next = .none,
            .first = .none,
            .last = .none,
            .header_len = aligned_header_len,
            .trailer_len = aligned_trailer_len,
            .off = 0,
            .len = aligned_header_len + aligned_trailer_len,
            .entries = .{},
            .cross_unit_relocs = .{},
            .cross_section_relocs = .{},
        };
        if (sec.last.unwrap()) |last_unit| {
            const last_unit_ptr = sec.getUnit(last_unit);
            last_unit_ptr.next = unit.toOptional();
            unit_ptr.off = last_unit_ptr.off + sec.padToIdeal(last_unit_ptr.len);
        }
        if (sec.first == .none)
            sec.first = unit.toOptional();
        sec.last = unit.toOptional();
        try sec.resize(dwarf, unit_ptr.off + sec.padToIdeal(unit_ptr.len));
        return unit;
    }

    fn unlinkUnit(sec: *Section, unit: Unit.Index) void {
        const unit_ptr = sec.getUnit(unit);
        if (unit_ptr.prev.unwrap()) |prev_unit| sec.getUnit(prev_unit).next = unit_ptr.next;
        if (unit_ptr.next.unwrap()) |next_unit| sec.getUnit(next_unit).prev = unit_ptr.prev;
        if (sec.first == unit.toOptional()) sec.first = unit_ptr.next;
        if (sec.last == unit.toOptional()) sec.last = unit_ptr.prev;
    }

    fn popUnit(sec: *Section, gpa: std.mem.Allocator) void {
        const unit_index: Unit.Index = @enumFromInt(sec.units.items.len - 1);
        sec.unlinkUnit(unit_index);
        var unit = sec.units.pop();
        unit.deinit(gpa);
    }

    pub fn getUnit(sec: *Section, unit: Unit.Index) *Unit {
        return &sec.units.items[@intFromEnum(unit)];
    }

    fn resizeEntry(sec: *Section, unit: Unit.Index, entry: Entry.Index, dwarf: *Dwarf, len: u32) UpdateError!void {
        const unit_ptr = sec.getUnit(unit);
        const entry_ptr = unit_ptr.getEntry(entry);
        if (len > 0) {
            if (entry_ptr.len == 0) {
                assert(entry_ptr.prev == .none and entry_ptr.next == .none);
                entry_ptr.off = if (unit_ptr.last.unwrap()) |last_entry| off: {
                    const last_entry_ptr = unit_ptr.getEntry(last_entry);
                    last_entry_ptr.next = entry.toOptional();
                    break :off last_entry_ptr.off + sec.padToIdeal(last_entry_ptr.len);
                } else 0;
                entry_ptr.prev = unit_ptr.last;
                unit_ptr.last = entry.toOptional();
                if (unit_ptr.first == .none) unit_ptr.first = unit_ptr.last;
                if (entry_ptr.prev.unwrap()) |prev_entry| try unit_ptr.getEntry(prev_entry).pad(unit_ptr, sec, dwarf);
            }
            try entry_ptr.resize(unit_ptr, sec, dwarf, len);
        }
        assert(entry_ptr.len == len);
    }

    fn replaceEntry(sec: *Section, unit: Unit.Index, entry: Entry.Index, dwarf: *Dwarf, contents: []const u8) UpdateError!void {
        try sec.resizeEntry(unit, entry, dwarf, @intCast(contents.len));
        const unit_ptr = sec.getUnit(unit);
        try unit_ptr.getEntry(entry).replace(unit_ptr, sec, dwarf, contents);
    }

    fn resize(sec: *Section, dwarf: *Dwarf, len: u64) UpdateError!void {
        if (len <= sec.len) return;
        if (dwarf.bin_file.cast(.elf)) |elf_file| {
            const zo = elf_file.zigObjectPtr().?;
            const atom = zo.symbol(sec.index).atom(elf_file).?;
            const shndx = atom.output_section_index;
            if (sec == &dwarf.debug_frame.section)
                try elf_file.growAllocSection(shndx, len, sec.alignment.toByteUnits().?)
            else
                try elf_file.growNonAllocSection(shndx, len, sec.alignment.toByteUnits().?, true);
            const shdr = elf_file.sections.items(.shdr)[shndx];
            atom.size = shdr.sh_size;
            atom.alignment = InternPool.Alignment.fromNonzeroByteUnits(shdr.sh_addralign);
            sec.len = shdr.sh_size;
        } else if (dwarf.bin_file.cast(.macho)) |macho_file| {
            const header = if (macho_file.d_sym) |*d_sym| header: {
                try d_sym.growSection(@intCast(sec.index), len, true, macho_file);
                break :header &d_sym.sections.items[sec.index];
            } else header: {
                try macho_file.growSection(@intCast(sec.index), len);
                break :header &macho_file.sections.items(.header)[sec.index];
            };
            sec.len = header.size;
        }
    }

    fn trim(sec: *Section, dwarf: *Dwarf) void {
        const len = sec.getUnit(sec.first.unwrap() orelse return).off;
        if (len == 0) return;
        for (sec.units.items) |*unit| unit.off -= len;
        sec.len -= len;
        if (dwarf.bin_file.cast(.elf)) |elf_file| {
            const zo = elf_file.zigObjectPtr().?;
            const atom = zo.symbol(sec.index).atom(elf_file).?;
            const shndx = atom.output_section_index;
            const shdr = &elf_file.sections.items(.shdr)[shndx];
            atom.size = sec.len;
            shdr.sh_offset += len;
            shdr.sh_size = sec.len;
        } else if (dwarf.bin_file.cast(.macho)) |macho_file| {
            const header = if (macho_file.d_sym) |*d_sym|
                &d_sym.sections.items[sec.index]
            else
                &macho_file.sections.items(.header)[sec.index];
            header.offset += @intCast(len);
            header.size = sec.len;
        }
    }

    fn resolveRelocs(sec: *Section, dwarf: *Dwarf) RelocError!void {
        for (sec.units.items) |*unit| try unit.resolveRelocs(sec, dwarf);
    }

    fn padToIdeal(sec: *Section, actual_size: anytype) @TypeOf(actual_size) {
        return @intCast(sec.alignment.forward(if (sec.pad_to_ideal) Dwarf.padToIdeal(actual_size) else actual_size));
    }
};

/// A unit within a `Section` containing a sequence of `Entry`s.
const Unit = struct {
    prev: Index.Optional,
    next: Index.Optional,
    first: Entry.Index.Optional,
    last: Entry.Index.Optional,
    /// offset within containing section
    off: u32,
    header_len: u32,
    trailer_len: u32,
    /// data length in bytes
    len: u32,
    entries: std.ArrayListUnmanaged(Entry),
    cross_unit_relocs: std.ArrayListUnmanaged(CrossUnitReloc),
    cross_section_relocs: std.ArrayListUnmanaged(CrossSectionReloc),

    const Index = enum(u32) {
        main,
        _,

        const Optional = enum(u32) {
            none = std.math.maxInt(u32),
            _,

            pub fn unwrap(uio: Optional) ?Index {
                return if (uio != .none) @enumFromInt(@intFromEnum(uio)) else null;
            }
        };

        fn toOptional(ui: Index) Optional {
            return @enumFromInt(@intFromEnum(ui));
        }
    };

    fn clear(unit: *Unit) void {
        unit.cross_unit_relocs.clearRetainingCapacity();
        unit.cross_section_relocs.clearRetainingCapacity();
    }

    fn deinit(unit: *Unit, gpa: std.mem.Allocator) void {
        for (unit.entries.items) |*entry| entry.deinit(gpa);
        unit.entries.deinit(gpa);
        unit.cross_unit_relocs.deinit(gpa);
        unit.cross_section_relocs.deinit(gpa);
        unit.* = undefined;
    }

    fn addEntry(unit: *Unit, gpa: std.mem.Allocator) std.mem.Allocator.Error!Entry.Index {
        const entry: Entry.Index = @enumFromInt(unit.entries.items.len);
        const entry_ptr = try unit.entries.addOne(gpa);
        entry_ptr.* = .{
            .prev = .none,
            .next = .none,
            .off = 0,
            .len = 0,
            .cross_entry_relocs = .{},
            .cross_unit_relocs = .{},
            .cross_section_relocs = .{},
            .external_relocs = .{},
        };
        return entry;
    }

    pub fn getEntry(unit: *Unit, entry: Entry.Index) *Entry {
        return &unit.entries.items[@intFromEnum(entry)];
    }

    fn resize(unit_ptr: *Unit, sec: *Section, dwarf: *Dwarf, extra_header_len: u32, len: u32) UpdateError!void {
        const end = if (unit_ptr.next.unwrap()) |next_unit|
            sec.getUnit(next_unit).off
        else
            sec.len;
        if (extra_header_len > 0 or unit_ptr.off + len > end) {
            unit_ptr.len = @min(unit_ptr.len, len);
            var new_off = unit_ptr.off;
            if (unit_ptr.next.unwrap()) |next_unit| {
                const next_unit_ptr = sec.getUnit(next_unit);
                if (unit_ptr.prev.unwrap()) |prev_unit|
                    sec.getUnit(prev_unit).next = unit_ptr.next
                else
                    sec.first = unit_ptr.next;
                const unit = next_unit_ptr.prev;
                next_unit_ptr.prev = unit_ptr.prev;
                const last_unit_ptr = sec.getUnit(sec.last.unwrap().?);
                last_unit_ptr.next = unit;
                unit_ptr.prev = sec.last;
                unit_ptr.next = .none;
                new_off = last_unit_ptr.off + sec.padToIdeal(last_unit_ptr.len);
                sec.last = unit;
                sec.dirty = true;
            } else if (extra_header_len > 0) {
                // `copyRangeAll` in `move` does not support overlapping ranges
                // so make sure new location is disjoint from current location.
                new_off += unit_ptr.len -| extra_header_len;
            }
            try sec.resize(dwarf, new_off + len);
            try unit_ptr.move(sec, dwarf, new_off + extra_header_len);
            unit_ptr.off -= extra_header_len;
            unit_ptr.header_len += extra_header_len;
            sec.trim(dwarf);
        }
        unit_ptr.len = len;
    }

    fn trim(unit: *Unit) void {
        const len = unit.getEntry(unit.first.unwrap() orelse return).off;
        if (len == 0) return;
        for (unit.entries.items) |*entry| entry.off -= len;
        unit.off += len;
        unit.len -= len;
    }

    fn move(unit: *Unit, sec: *Section, dwarf: *Dwarf, new_off: u32) UpdateError!void {
        if (unit.off == new_off) return;
        if (try dwarf.getFile().?.copyRangeAll(
            sec.off(dwarf) + unit.off,
            dwarf.getFile().?,
            sec.off(dwarf) + new_off,
            unit.len,
        ) != unit.len) return error.InputOutput;
        unit.off = new_off;
    }

    fn resizeHeader(unit: *Unit, sec: *Section, dwarf: *Dwarf, len: u32) UpdateError!void {
        unit.trim();
        if (unit.header_len == len) return;
        const available_len = if (unit.prev.unwrap()) |prev_unit| prev_excess: {
            const prev_unit_ptr = sec.getUnit(prev_unit);
            break :prev_excess unit.off - prev_unit_ptr.off - prev_unit_ptr.len;
        } else 0;
        if (available_len + unit.header_len < len)
            try unit.resize(sec, dwarf, len - unit.header_len, unit.len - unit.header_len + len);
        if (unit.header_len > len) {
            const excess_header_len = unit.header_len - len;
            unit.off += excess_header_len;
            unit.header_len -= excess_header_len;
            unit.len -= excess_header_len;
        } else if (unit.header_len < len) {
            const needed_header_len = len - unit.header_len;
            unit.off -= needed_header_len;
            unit.header_len += needed_header_len;
            unit.len += needed_header_len;
        }
        assert(unit.header_len == len);
        sec.trim(dwarf);
    }

    fn replaceHeader(unit: *Unit, sec: *Section, dwarf: *Dwarf, contents: []const u8) UpdateError!void {
        assert(contents.len == unit.header_len);
        try dwarf.getFile().?.pwriteAll(contents, sec.off(dwarf) + unit.off);
    }

    fn writeTrailer(unit: *Unit, sec: *Section, dwarf: *Dwarf) UpdateError!void {
        const start = unit.off + unit.header_len + if (unit.last.unwrap()) |last_entry| end: {
            const last_entry_ptr = unit.getEntry(last_entry);
            break :end last_entry_ptr.off + last_entry_ptr.len;
        } else 0;
        const end = if (unit.next.unwrap()) |next_unit| sec.getUnit(next_unit).off else sec.len;
        const len: usize = @intCast(end - start);
        assert(len >= unit.trailer_len);
        if (sec == &dwarf.debug_line.section) {
            var buf: [1 + uleb128Bytes(std.math.maxInt(u32)) + 1]u8 = undefined;
            var fbs = std.io.fixedBufferStream(&buf);
            const writer = fbs.writer();
            writer.writeByte(DW.LNS.extended_op) catch unreachable;
            const extended_op_bytes = fbs.pos;
            var op_len_bytes: u5 = 1;
            while (true) switch (std.math.order(len - extended_op_bytes - op_len_bytes, @as(u32, 1) << 7 * op_len_bytes)) {
                .lt => break uleb128(writer, len - extended_op_bytes - op_len_bytes) catch unreachable,
                .eq => {
                    // no length will ever work, so undercount and futz with the leb encoding to make up the missing byte
                    op_len_bytes += 1;
                    std.leb.writeUnsignedExtended(buf[fbs.pos..][0..op_len_bytes], len - extended_op_bytes - op_len_bytes);
                    fbs.pos += op_len_bytes;
                    break;
                },
                .gt => op_len_bytes += 1,
            };
            assert(fbs.pos == extended_op_bytes + op_len_bytes);
            writer.writeByte(DW.LNE.padding) catch unreachable;
            assert(fbs.pos >= unit.trailer_len and fbs.pos <= len);
            return dwarf.getFile().?.pwriteAll(fbs.getWritten(), sec.off(dwarf) + start);
        }
        var trailer = try std.ArrayList(u8).initCapacity(dwarf.gpa, len);
        defer trailer.deinit();
        const fill_byte: u8 = if (sec == &dwarf.debug_abbrev.section) fill: {
            assert(uleb128Bytes(@intFromEnum(AbbrevCode.null)) == 1);
            trailer.appendAssumeCapacity(@intFromEnum(AbbrevCode.null));
            break :fill @intFromEnum(AbbrevCode.null);
        } else if (sec == &dwarf.debug_aranges.section) fill: {
            trailer.appendNTimesAssumeCapacity(0, @intFromEnum(dwarf.address_size) * 2);
            break :fill 0;
        } else if (sec == &dwarf.debug_frame.section) fill: {
            switch (dwarf.debug_frame.header.format) {
                .none => {},
                .debug_frame, .eh_frame => |format| {
                    const unit_len = len - dwarf.unitLengthBytes();
                    switch (dwarf.format) {
                        .@"32" => std.mem.writeInt(u32, trailer.addManyAsArrayAssumeCapacity(4), @intCast(unit_len), dwarf.endian),
                        .@"64" => {
                            std.mem.writeInt(u32, trailer.addManyAsArrayAssumeCapacity(4), std.math.maxInt(u32), dwarf.endian);
                            std.mem.writeInt(u64, trailer.addManyAsArrayAssumeCapacity(8), unit_len, dwarf.endian);
                        },
                    }
                    switch (format) {
                        .none => unreachable,
                        .debug_frame => {
                            switch (dwarf.format) {
                                .@"32" => std.mem.writeInt(u32, trailer.addManyAsArrayAssumeCapacity(4), std.math.maxInt(u32), dwarf.endian),
                                .@"64" => std.mem.writeInt(u64, trailer.addManyAsArrayAssumeCapacity(8), std.math.maxInt(u64), dwarf.endian),
                            }
                            trailer.appendAssumeCapacity(4);
                            trailer.appendSliceAssumeCapacity("\x00");
                            trailer.appendAssumeCapacity(@intFromEnum(dwarf.address_size));
                            trailer.appendAssumeCapacity(0);
                        },
                        .eh_frame => {
                            std.mem.writeInt(u32, trailer.addManyAsArrayAssumeCapacity(4), 0, dwarf.endian);
                            trailer.appendAssumeCapacity(1);
                            trailer.appendSliceAssumeCapacity("\x00");
                        },
                    }
                    uleb128(trailer.fixedWriter(), 1) catch unreachable;
                    sleb128(trailer.fixedWriter(), 1) catch unreachable;
                    uleb128(trailer.fixedWriter(), 0) catch unreachable;
                },
            }
            trailer.appendNTimesAssumeCapacity(DW.CFA.nop, unit.trailer_len - trailer.items.len);
            break :fill DW.CFA.nop;
        } else if (sec == &dwarf.debug_info.section) fill: {
            assert(uleb128Bytes(@intFromEnum(AbbrevCode.null)) == 1);
            trailer.appendNTimesAssumeCapacity(@intFromEnum(AbbrevCode.null), 2);
            break :fill @intFromEnum(AbbrevCode.null);
        } else if (sec == &dwarf.debug_rnglists.section) fill: {
            trailer.appendAssumeCapacity(DW.RLE.end_of_list);
            break :fill DW.RLE.end_of_list;
        } else unreachable;
        assert(trailer.items.len == unit.trailer_len);
        trailer.appendNTimesAssumeCapacity(fill_byte, len - unit.trailer_len);
        assert(trailer.items.len == len);
        try dwarf.getFile().?.pwriteAll(trailer.items, sec.off(dwarf) + start);
    }

    fn resolveRelocs(unit: *Unit, sec: *Section, dwarf: *Dwarf) RelocError!void {
        const unit_off = sec.off(dwarf) + unit.off;
        for (unit.cross_unit_relocs.items) |reloc| {
            const target_unit = sec.getUnit(reloc.target_unit);
            try dwarf.resolveReloc(
                unit_off + reloc.source_off,
                target_unit.off + (if (reloc.target_entry.unwrap()) |target_entry|
                    target_unit.header_len + target_unit.getEntry(target_entry).assertNonEmpty(unit, sec, dwarf).off
                else
                    0) + reloc.target_off,
                dwarf.sectionOffsetBytes(),
            );
        }
        for (unit.cross_section_relocs.items) |reloc| {
            const target_sec = switch (reloc.target_sec) {
                inline else => |target_sec| &@field(dwarf, @tagName(target_sec)).section,
            };
            const target_unit = target_sec.getUnit(reloc.target_unit);
            try dwarf.resolveReloc(
                unit_off + reloc.source_off,
                target_unit.off + (if (reloc.target_entry.unwrap()) |target_entry|
                    target_unit.header_len + target_unit.getEntry(target_entry).assertNonEmpty(unit, sec, dwarf).off
                else
                    0) + reloc.target_off,
                dwarf.sectionOffsetBytes(),
            );
        }
        for (unit.entries.items) |*entry| try entry.resolveRelocs(unit, sec, dwarf);
    }
};

/// An indivisible entry within a `Unit` containing section-specific data.
const Entry = struct {
    prev: Index.Optional,
    next: Index.Optional,
    /// offset from end of containing unit header
    off: u32,
    /// data length in bytes
    len: u32,
    cross_entry_relocs: std.ArrayListUnmanaged(CrossEntryReloc),
    cross_unit_relocs: std.ArrayListUnmanaged(CrossUnitReloc),
    cross_section_relocs: std.ArrayListUnmanaged(CrossSectionReloc),
    external_relocs: std.ArrayListUnmanaged(ExternalReloc),

    fn clear(entry: *Entry) void {
        entry.cross_entry_relocs.clearRetainingCapacity();
        entry.cross_unit_relocs.clearRetainingCapacity();
        entry.cross_section_relocs.clearRetainingCapacity();
        entry.external_relocs.clearRetainingCapacity();
    }

    fn deinit(entry: *Entry, gpa: std.mem.Allocator) void {
        entry.cross_entry_relocs.deinit(gpa);
        entry.cross_unit_relocs.deinit(gpa);
        entry.cross_section_relocs.deinit(gpa);
        entry.external_relocs.deinit(gpa);
        entry.* = undefined;
    }

    const Index = enum(u32) {
        _,

        const Optional = enum(u32) {
            none = std.math.maxInt(u32),
            _,

            pub fn unwrap(eio: Optional) ?Index {
                return if (eio != .none) @enumFromInt(@intFromEnum(eio)) else null;
            }
        };

        fn toOptional(ei: Index) Optional {
            return @enumFromInt(@intFromEnum(ei));
        }
    };

    fn pad(entry: *Entry, unit: *Unit, sec: *Section, dwarf: *Dwarf) UpdateError!void {
        assert(entry.len > 0);
        const start = entry.off + entry.len;
        if (sec == &dwarf.debug_frame.section) {
            const len = if (entry.next.unwrap()) |next_entry|
                unit.getEntry(next_entry).off - entry.off
            else
                entry.len;
            var unit_len: [8]u8 = undefined;
            dwarf.writeInt(unit_len[0..dwarf.sectionOffsetBytes()], len - dwarf.unitLengthBytes());
            try dwarf.getFile().?.pwriteAll(
                unit_len[0..dwarf.sectionOffsetBytes()],
                sec.off(dwarf) + unit.off + unit.header_len + entry.off,
            );
            const buf = try dwarf.gpa.alloc(u8, len - entry.len);
            defer dwarf.gpa.free(buf);
            @memset(buf, DW.CFA.nop);
            try dwarf.getFile().?.pwriteAll(buf, sec.off(dwarf) + unit.off + unit.header_len + start);
            return;
        }
        const len = unit.getEntry(entry.next.unwrap() orelse return).off - start;
        var buf: [
            @max(
                uleb128Bytes(@intFromEnum(AbbrevCode.pad_1)),
                uleb128Bytes(@intFromEnum(AbbrevCode.pad_n)) + uleb128Bytes(std.math.maxInt(u32)),
                1 + uleb128Bytes(std.math.maxInt(u32)) + 1,
            )
        ]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buf);
        const writer = fbs.writer();
        if (sec == &dwarf.debug_info.section) switch (len) {
            0 => {},
            1 => uleb128(writer, try dwarf.refAbbrevCode(.pad_1)) catch unreachable,
            else => {
                uleb128(writer, try dwarf.refAbbrevCode(.pad_n)) catch unreachable;
                const abbrev_code_bytes = fbs.pos;
                var block_len_bytes: u5 = 1;
                while (true) switch (std.math.order(len - abbrev_code_bytes - block_len_bytes, @as(u32, 1) << 7 * block_len_bytes)) {
                    .lt => break uleb128(writer, len - abbrev_code_bytes - block_len_bytes) catch unreachable,
                    .eq => {
                        // no length will ever work, so undercount and futz with the leb encoding to make up the missing byte
                        block_len_bytes += 1;
                        std.leb.writeUnsignedExtended(buf[fbs.pos..][0..block_len_bytes], len - abbrev_code_bytes - block_len_bytes);
                        fbs.pos += block_len_bytes;
                        break;
                    },
                    .gt => block_len_bytes += 1,
                };
                assert(fbs.pos == abbrev_code_bytes + block_len_bytes);
            },
        } else if (sec == &dwarf.debug_line.section) switch (len) {
            0 => {},
            1 => writer.writeByte(DW.LNS.const_add_pc) catch unreachable,
            else => {
                writer.writeByte(DW.LNS.extended_op) catch unreachable;
                const extended_op_bytes = fbs.pos;
                var op_len_bytes: u5 = 1;
                while (true) switch (std.math.order(len - extended_op_bytes - op_len_bytes, @as(u32, 1) << 7 * op_len_bytes)) {
                    .lt => break uleb128(writer, len - extended_op_bytes - op_len_bytes) catch unreachable,
                    .eq => {
                        // no length will ever work, so undercount and futz with the leb encoding to make up the missing byte
                        op_len_bytes += 1;
                        std.leb.writeUnsignedExtended(buf[fbs.pos..][0..op_len_bytes], len - extended_op_bytes - op_len_bytes);
                        fbs.pos += op_len_bytes;
                        break;
                    },
                    .gt => op_len_bytes += 1,
                };
                assert(fbs.pos == extended_op_bytes + op_len_bytes);
                if (len > 2) writer.writeByte(DW.LNE.padding) catch unreachable;
            },
        } else assert(!sec.pad_to_ideal and len == 0);
        assert(fbs.pos <= len);
        try dwarf.getFile().?.pwriteAll(fbs.getWritten(), sec.off(dwarf) + unit.off + unit.header_len + start);
    }

    fn resize(entry_ptr: *Entry, unit: *Unit, sec: *Section, dwarf: *Dwarf, len: u32) UpdateError!void {
        assert(len > 0);
        assert(sec.alignment.check(len));
        if (entry_ptr.len == len) return;
        const end = if (entry_ptr.next.unwrap()) |next_entry|
            unit.getEntry(next_entry).off
        else
            unit.len -| (unit.header_len + unit.trailer_len);
        if (entry_ptr.off + len > end) {
            if (entry_ptr.next.unwrap()) |next_entry| {
                if (entry_ptr.prev.unwrap()) |prev_entry|
                    unit.getEntry(prev_entry).next = entry_ptr.next
                else
                    unit.first = entry_ptr.next;
                const next_entry_ptr = unit.getEntry(next_entry);
                const entry = next_entry_ptr.prev;
                next_entry_ptr.prev = entry_ptr.prev;
                const last_entry_ptr = unit.getEntry(unit.last.unwrap().?);
                last_entry_ptr.next = entry;
                entry_ptr.prev = unit.last;
                entry_ptr.next = .none;
                entry_ptr.off = last_entry_ptr.off + sec.padToIdeal(last_entry_ptr.len);
                unit.last = entry;
            }
            try unit.resize(sec, dwarf, 0, @intCast(unit.header_len + entry_ptr.off + sec.padToIdeal(len) + unit.trailer_len));
        }
        entry_ptr.len = len;
        try entry_ptr.pad(unit, sec, dwarf);
    }

    fn replace(entry_ptr: *Entry, unit: *Unit, sec: *Section, dwarf: *Dwarf, contents: []const u8) UpdateError!void {
        assert(contents.len == entry_ptr.len);
        try dwarf.getFile().?.pwriteAll(contents, sec.off(dwarf) + unit.off + unit.header_len + entry_ptr.off);
        if (false) {
            const buf = try dwarf.gpa.alloc(u8, sec.len);
            defer dwarf.gpa.free(buf);
            _ = try dwarf.getFile().?.preadAll(buf, sec.off(dwarf));
            log.info("Section{{ .first = {}, .last = {}, .off = 0x{x}, .len = 0x{x} }}", .{
                @intFromEnum(sec.first),
                @intFromEnum(sec.last),
                sec.off(dwarf),
                sec.len,
            });
            for (sec.units.items) |*unit_ptr| {
                log.info("  Unit{{ .prev = {}, .next = {}, .first = {}, .last = {}, .off = 0x{x}, .header_len = 0x{x}, .trailer_len = 0x{x}, .len = 0x{x} }}", .{
                    @intFromEnum(unit_ptr.prev),
                    @intFromEnum(unit_ptr.next),
                    @intFromEnum(unit_ptr.first),
                    @intFromEnum(unit_ptr.last),
                    unit_ptr.off,
                    unit_ptr.header_len,
                    unit_ptr.trailer_len,
                    unit_ptr.len,
                });
                for (unit_ptr.entries.items) |*entry| {
                    log.info("    Entry{{ .prev = {}, .next = {}, .off = 0x{x}, .len = 0x{x} }}", .{
                        @intFromEnum(entry.prev),
                        @intFromEnum(entry.next),
                        entry.off,
                        entry.len,
                    });
                }
            }
            std.debug.dumpHex(buf);
        }
    }

    pub fn assertNonEmpty(entry: *Entry, unit: *Unit, sec: *Section, dwarf: *Dwarf) *Entry {
        if (entry.len > 0) return entry;
        if (std.debug.runtime_safety) {
            log.err("missing {} from {s}", .{
                @as(Entry.Index, @enumFromInt(entry - unit.entries.items.ptr)),
                std.mem.sliceTo(if (dwarf.bin_file.cast(.elf)) |elf_file| sh_name: {
                    const zo = elf_file.zigObjectPtr().?;
                    const shndx = zo.symbol(sec.index).atom(elf_file).?.output_section_index;
                    break :sh_name elf_file.shstrtab.items[elf_file.sections.items(.shdr)[shndx].sh_name..];
                } else if (dwarf.bin_file.cast(.macho)) |macho_file|
                    if (macho_file.d_sym) |*d_sym|
                        &d_sym.sections.items[sec.index].segname
                    else
                        &macho_file.sections.items(.header)[sec.index].segname
                else
                    "?", 0),
            });
            const zcu = dwarf.bin_file.comp.zcu.?;
            const ip = &zcu.intern_pool;
            for (dwarf.types.keys(), dwarf.types.values()) |ty, other_entry| {
                const ty_unit: Unit.Index = if (Type.fromInterned(ty).typeDeclInst(zcu)) |inst_index|
                    dwarf.getUnit(zcu.fileByIndex(inst_index.resolveFile(ip)).mod) catch unreachable
                else
                    .main;
                if (sec.getUnit(ty_unit) == unit and unit.getEntry(other_entry) == entry)
                    log.err("missing Type({}({d}))", .{
                        Type.fromInterned(ty).fmt(.{ .tid = .main, .zcu = zcu }),
                        @intFromEnum(ty),
                    });
            }
            for (dwarf.navs.keys(), dwarf.navs.values()) |nav, other_entry| {
                const nav_unit = dwarf.getUnit(zcu.fileByIndex(ip.getNav(nav).srcInst(ip).resolveFile(ip)).mod) catch unreachable;
                if (sec.getUnit(nav_unit) == unit and unit.getEntry(other_entry) == entry)
                    log.err("missing Nav({}({d}))", .{ ip.getNav(nav).fqn.fmt(ip), @intFromEnum(nav) });
            }
        }
        @panic("missing dwarf relocation target");
    }

    fn resolveRelocs(entry: *Entry, unit: *Unit, sec: *Section, dwarf: *Dwarf) RelocError!void {
        const entry_off = sec.off(dwarf) + unit.off + unit.header_len + entry.off;
        for (entry.cross_entry_relocs.items) |reloc| {
            try dwarf.resolveReloc(
                entry_off + reloc.source_off,
                unit.off + unit.header_len + unit.getEntry(reloc.target_entry).assertNonEmpty(unit, sec, dwarf).off + reloc.target_off,
                dwarf.sectionOffsetBytes(),
            );
        }
        for (entry.cross_unit_relocs.items) |reloc| {
            const target_unit = sec.getUnit(reloc.target_unit);
            try dwarf.resolveReloc(
                entry_off + reloc.source_off,
                target_unit.off + (if (reloc.target_entry.unwrap()) |target_entry|
                    target_unit.header_len + target_unit.getEntry(target_entry).assertNonEmpty(unit, sec, dwarf).off
                else
                    0) + reloc.target_off,
                dwarf.sectionOffsetBytes(),
            );
        }
        for (entry.cross_section_relocs.items) |reloc| {
            const target_sec = switch (reloc.target_sec) {
                inline else => |target_sec| &@field(dwarf, @tagName(target_sec)).section,
            };
            const target_unit = target_sec.getUnit(reloc.target_unit);
            try dwarf.resolveReloc(
                entry_off + reloc.source_off,
                target_unit.off + (if (reloc.target_entry.unwrap()) |target_entry|
                    target_unit.header_len + target_unit.getEntry(target_entry).assertNonEmpty(unit, sec, dwarf).off
                else
                    0) + reloc.target_off,
                dwarf.sectionOffsetBytes(),
            );
        }
        if (sec == &dwarf.debug_frame.section) switch (DebugFrame.format(dwarf)) {
            .none, .debug_frame => {},
            .eh_frame => return if (dwarf.bin_file.cast(.elf)) |elf_file| {
                const zo = elf_file.zigObjectPtr().?;
                const shndx = zo.symbol(sec.index).atom(elf_file).?.output_section_index;
                const entry_addr: i64 = @intCast(entry_off - sec.off(dwarf) + elf_file.shdrs.items[shndx].sh_addr);
                for (entry.external_relocs.items) |reloc| {
                    const symbol = zo.symbol(reloc.target_sym);
                    try dwarf.resolveReloc(
                        entry_off + reloc.source_off,
                        @bitCast((symbol.address(.{}, elf_file) + @as(i64, @intCast(reloc.target_off))) -
                            (entry_addr + reloc.source_off + 4)),
                        4,
                    );
                }
            } else unreachable,
        };
        if (dwarf.bin_file.cast(.elf)) |elf_file| {
            const zo = elf_file.zigObjectPtr().?;
            for (entry.external_relocs.items) |reloc| {
                const symbol = zo.symbol(reloc.target_sym);
                try dwarf.resolveReloc(
                    entry_off + reloc.source_off,
                    @bitCast(symbol.address(.{}, elf_file) + @as(i64, @intCast(reloc.target_off)) -
                        if (symbol.flags.is_tls) elf_file.dtpAddress() else 0),
                    @intFromEnum(dwarf.address_size),
                );
            }
        } else if (dwarf.bin_file.cast(.macho)) |macho_file| {
            const zo = macho_file.getZigObject().?;
            for (entry.external_relocs.items) |reloc| {
                const ref = zo.getSymbolRef(reloc.target_sym, macho_file);
                try dwarf.resolveReloc(
                    entry_off + reloc.source_off,
                    ref.getSymbol(macho_file).?.getAddress(.{}, macho_file),
                    @intFromEnum(dwarf.address_size),
                );
            }
        }
    }
};

const CrossEntryReloc = struct {
    source_off: u32 = 0,
    target_entry: Entry.Index.Optional = .none,
    target_off: u32 = 0,
};
const CrossUnitReloc = struct {
    source_off: u32 = 0,
    target_unit: Unit.Index,
    target_entry: Entry.Index.Optional = .none,
    target_off: u32 = 0,
};
const CrossSectionReloc = struct {
    source_off: u32 = 0,
    target_sec: Section.Index,
    target_unit: Unit.Index,
    target_entry: Entry.Index.Optional = .none,
    target_off: u32 = 0,
};
const ExternalReloc = struct {
    source_off: u32 = 0,
    target_sym: u32,
    target_off: u64 = 0,
};

pub const Loc = union(enum) {
    empty,
    addr: union(enum) { sym: u32 },
    constu: u64,
    consts: i64,
    plus: Bin,
    reg: u32,
    breg: u32,
    push_object_address,
    form_tls_address: *const Loc,
    implicit_value: []const u8,
    stack_value: *const Loc,
    wasm_ext: union(enum) {
        local: u32,
        global: u32,
        operand_stack: u32,
    },

    pub const Bin = struct { *const Loc, *const Loc };

    fn getConst(loc: Loc, comptime Int: type) ?Int {
        return switch (loc) {
            .constu => |constu| std.math.cast(Int, constu),
            .consts => |consts| std.math.cast(Int, consts),
            else => null,
        };
    }

    fn getBaseReg(loc: Loc) ?u32 {
        return switch (loc) {
            .breg => |breg| breg,
            else => null,
        };
    }

    fn writeReg(reg: u32, op0: u8, opx: u8, writer: anytype) @TypeOf(writer).Error!void {
        if (std.math.cast(u5, reg)) |small_reg| {
            try writer.writeByte(op0 + small_reg);
        } else {
            try writer.writeByte(opx);
            try uleb128(writer, reg);
        }
    }

    fn write(loc: Loc, adapter: anytype) UpdateError!void {
        const writer = adapter.writer();
        switch (loc) {
            .empty => {},
            .addr => |addr| {
                try writer.writeByte(DW.OP.addr);
                switch (addr) {
                    .sym => |sym_index| try adapter.addrSym(sym_index),
                }
            },
            .constu => |constu| if (std.math.cast(u5, constu)) |lit| {
                try writer.writeByte(@as(u8, DW.OP.lit0) + lit);
            } else if (std.math.cast(u8, constu)) |const1u| {
                try writer.writeAll(&.{ DW.OP.const1u, const1u });
            } else if (std.math.cast(u16, constu)) |const2u| {
                try writer.writeByte(DW.OP.const2u);
                try writer.writeInt(u16, const2u, adapter.endian());
            } else if (std.math.cast(u21, constu)) |const3u| {
                try writer.writeByte(DW.OP.constu);
                try uleb128(writer, const3u);
            } else if (std.math.cast(u32, constu)) |const4u| {
                try writer.writeByte(DW.OP.const4u);
                try writer.writeInt(u32, const4u, adapter.endian());
            } else if (std.math.cast(u49, constu)) |const7u| {
                try writer.writeByte(DW.OP.constu);
                try uleb128(writer, const7u);
            } else {
                try writer.writeByte(DW.OP.const8u);
                try writer.writeInt(u64, constu, adapter.endian());
            },
            .consts => |consts| if (std.math.cast(i8, consts)) |const1s| {
                try writer.writeAll(&.{ DW.OP.const1s, @bitCast(const1s) });
            } else if (std.math.cast(i16, consts)) |const2s| {
                try writer.writeByte(DW.OP.const2s);
                try writer.writeInt(i16, const2s, adapter.endian());
            } else if (std.math.cast(i21, consts)) |const3s| {
                try writer.writeByte(DW.OP.consts);
                try sleb128(writer, const3s);
            } else if (std.math.cast(i32, consts)) |const4s| {
                try writer.writeByte(DW.OP.const4s);
                try writer.writeInt(i32, const4s, adapter.endian());
            } else if (std.math.cast(i49, consts)) |const7s| {
                try writer.writeByte(DW.OP.consts);
                try sleb128(writer, const7s);
            } else {
                try writer.writeByte(DW.OP.const8s);
                try writer.writeInt(i64, consts, adapter.endian());
            },
            .plus => |plus| done: {
                if (plus[0].getConst(u0)) |_| {
                    try plus[1].write(adapter);
                    break :done;
                }
                if (plus[1].getConst(u0)) |_| {
                    try plus[0].write(adapter);
                    break :done;
                }
                if (plus[0].getBaseReg()) |breg| {
                    if (plus[1].getConst(i65)) |offset| {
                        try writeReg(breg, DW.OP.breg0, DW.OP.bregx, writer);
                        try sleb128(writer, offset);
                        break :done;
                    }
                }
                if (plus[1].getBaseReg()) |breg| {
                    if (plus[0].getConst(i65)) |offset| {
                        try writeReg(breg, DW.OP.breg0, DW.OP.bregx, writer);
                        try sleb128(writer, offset);
                        break :done;
                    }
                }
                if (plus[0].getConst(u64)) |uconst| {
                    try plus[1].write(adapter);
                    try writer.writeByte(DW.OP.plus_uconst);
                    try uleb128(writer, uconst);
                    break :done;
                }
                if (plus[1].getConst(u64)) |uconst| {
                    try plus[0].write(adapter);
                    try writer.writeByte(DW.OP.plus_uconst);
                    try uleb128(writer, uconst);
                    break :done;
                }
                try plus[0].write(adapter);
                try plus[1].write(adapter);
                try writer.writeByte(DW.OP.plus);
            },
            .reg => |reg| try writeReg(reg, DW.OP.reg0, DW.OP.regx, writer),
            .breg => |breg| {
                try writeReg(breg, DW.OP.breg0, DW.OP.bregx, writer);
                try sleb128(writer, 0);
            },
            .push_object_address => try writer.writeByte(DW.OP.push_object_address),
            .form_tls_address => |addr| {
                try addr.write(adapter);
                try writer.writeByte(DW.OP.form_tls_address);
            },
            .implicit_value => |value| {
                try writer.writeByte(DW.OP.implicit_value);
                try uleb128(writer, value.len);
                try writer.writeAll(value);
            },
            .stack_value => |value| {
                try value.write(adapter);
                try writer.writeByte(DW.OP.stack_value);
            },
            .wasm_ext => |wasm_ext| {
                try writer.writeByte(DW.OP.WASM_location);
                switch (wasm_ext) {
                    .local => |local| {
                        try writer.writeByte(DW.OP.WASM_local);
                        try uleb128(writer, local);
                    },
                    .global => |global| if (std.math.cast(u21, global)) |global_u21| {
                        try writer.writeByte(DW.OP.WASM_global);
                        try uleb128(writer, global_u21);
                    } else {
                        try writer.writeByte(DW.OP.WASM_global_u32);
                        try writer.writeInt(u32, global, adapter.endian());
                    },
                    .operand_stack => |operand_stack| {
                        try writer.writeByte(DW.OP.WASM_operand_stack);
                        try uleb128(writer, operand_stack);
                    },
                }
            },
        }
    }
};

pub const Cfa = union(enum) {
    nop,
    advance_loc: u32,
    offset: RegOff,
    rel_offset: RegOff,
    restore: u32,
    undefined: u32,
    same_value: u32,
    register: [2]u32,
    remember_state,
    restore_state,
    def_cfa: RegOff,
    def_cfa_register: u32,
    def_cfa_offset: i64,
    adjust_cfa_offset: i64,
    def_cfa_expression: Loc,
    expression: RegExpr,
    val_offset: RegOff,
    val_expression: RegExpr,
    escape: []const u8,

    const RegOff = struct { reg: u32, off: i64 };
    const RegExpr = struct { reg: u32, expr: Loc };

    fn write(cfa: Cfa, wip_nav: *WipNav) UpdateError!void {
        const writer = wip_nav.debug_frame.writer(wip_nav.dwarf.gpa);
        switch (cfa) {
            .nop => try writer.writeByte(DW.CFA.nop),
            .advance_loc => |loc| {
                const delta = @divExact(loc - wip_nav.cfi.loc, wip_nav.dwarf.debug_frame.header.code_alignment_factor);
                if (delta == 0) {} else if (std.math.cast(u6, delta)) |small_delta|
                    try writer.writeByte(@as(u8, DW.CFA.advance_loc) + small_delta)
                else if (std.math.cast(u8, delta)) |ubyte_delta|
                    try writer.writeAll(&.{ DW.CFA.advance_loc1, ubyte_delta })
                else if (std.math.cast(u16, delta)) |uhalf_delta| {
                    try writer.writeByte(DW.CFA.advance_loc2);
                    try writer.writeInt(u16, uhalf_delta, wip_nav.dwarf.endian);
                } else if (std.math.cast(u32, delta)) |uword_delta| {
                    try writer.writeByte(DW.CFA.advance_loc4);
                    try writer.writeInt(u32, uword_delta, wip_nav.dwarf.endian);
                }
                wip_nav.cfi.loc = loc;
            },
            .offset, .rel_offset => |reg_off| {
                const factored_off = @divExact(reg_off.off - switch (cfa) {
                    else => unreachable,
                    .offset => 0,
                    .rel_offset => wip_nav.cfi.cfa.off,
                }, wip_nav.dwarf.debug_frame.header.data_alignment_factor);
                if (std.math.cast(u63, factored_off)) |unsigned_off| {
                    if (std.math.cast(u6, reg_off.reg)) |small_reg| {
                        try writer.writeByte(@as(u8, DW.CFA.offset) + small_reg);
                    } else {
                        try writer.writeByte(DW.CFA.offset_extended);
                        try uleb128(writer, reg_off.reg);
                    }
                    try uleb128(writer, unsigned_off);
                } else {
                    try writer.writeByte(DW.CFA.offset_extended_sf);
                    try uleb128(writer, reg_off.reg);
                    try sleb128(writer, factored_off);
                }
            },
            .restore => |reg| if (std.math.cast(u6, reg)) |small_reg|
                try writer.writeByte(@as(u8, DW.CFA.restore) + small_reg)
            else {
                try writer.writeByte(DW.CFA.restore_extended);
                try uleb128(writer, reg);
            },
            .undefined => |reg| {
                try writer.writeByte(DW.CFA.undefined);
                try uleb128(writer, reg);
            },
            .same_value => |reg| {
                try writer.writeByte(DW.CFA.same_value);
                try uleb128(writer, reg);
            },
            .register => |regs| if (regs[0] != regs[1]) {
                try writer.writeByte(DW.CFA.register);
                for (regs) |reg| try uleb128(writer, reg);
            } else {
                try writer.writeByte(DW.CFA.same_value);
                try uleb128(writer, regs[0]);
            },
            .remember_state => try writer.writeByte(DW.CFA.remember_state),
            .restore_state => try writer.writeByte(DW.CFA.restore_state),
            .def_cfa, .def_cfa_register, .def_cfa_offset, .adjust_cfa_offset => {
                const reg_off: RegOff = switch (cfa) {
                    else => unreachable,
                    .def_cfa => |reg_off| reg_off,
                    .def_cfa_register => |reg| .{ .reg = reg, .off = wip_nav.cfi.cfa.off },
                    .def_cfa_offset => |off| .{ .reg = wip_nav.cfi.cfa.reg, .off = off },
                    .adjust_cfa_offset => |off| .{ .reg = wip_nav.cfi.cfa.reg, .off = wip_nav.cfi.cfa.off + off },
                };
                const changed_reg = reg_off.reg != wip_nav.cfi.cfa.reg;
                const unsigned_off = std.math.cast(u63, reg_off.off);
                if (reg_off.off == wip_nav.cfi.cfa.off) {
                    if (changed_reg) {
                        try writer.writeByte(DW.CFA.def_cfa_register);
                        try uleb128(writer, reg_off.reg);
                    }
                } else if (switch (wip_nav.dwarf.debug_frame.header.data_alignment_factor) {
                    0 => unreachable,
                    1 => unsigned_off != null,
                    else => |data_alignment_factor| @rem(reg_off.off, data_alignment_factor) != 0,
                }) {
                    try writer.writeByte(if (changed_reg) DW.CFA.def_cfa else DW.CFA.def_cfa_offset);
                    if (changed_reg) try uleb128(writer, reg_off.reg);
                    try uleb128(writer, unsigned_off.?);
                } else {
                    try writer.writeByte(if (changed_reg) DW.CFA.def_cfa_sf else DW.CFA.def_cfa_offset_sf);
                    if (changed_reg) try uleb128(writer, reg_off.reg);
                    try sleb128(writer, @divExact(reg_off.off, wip_nav.dwarf.debug_frame.header.data_alignment_factor));
                }
                wip_nav.cfi.cfa = reg_off;
            },
            .def_cfa_expression => |expr| {
                try writer.writeByte(DW.CFA.def_cfa_expression);
                try wip_nav.frameExprloc(expr);
            },
            .expression => |reg_expr| {
                try writer.writeByte(DW.CFA.expression);
                try uleb128(writer, reg_expr.reg);
                try wip_nav.frameExprloc(reg_expr.expr);
            },
            .val_offset => |reg_off| {
                const factored_off = @divExact(reg_off.off, wip_nav.dwarf.debug_frame.header.data_alignment_factor);
                if (std.math.cast(u63, factored_off)) |unsigned_off| {
                    try writer.writeByte(DW.CFA.val_offset);
                    try uleb128(writer, reg_off.reg);
                    try uleb128(writer, unsigned_off);
                } else {
                    try writer.writeByte(DW.CFA.val_offset_sf);
                    try uleb128(writer, reg_off.reg);
                    try sleb128(writer, factored_off);
                }
            },
            .val_expression => |reg_expr| {
                try writer.writeByte(DW.CFA.val_expression);
                try uleb128(writer, reg_expr.reg);
                try wip_nav.frameExprloc(reg_expr.expr);
            },
            .escape => |bytes| try writer.writeAll(bytes),
        }
    }
};

pub const WipNav = struct {
    dwarf: *Dwarf,
    pt: Zcu.PerThread,
    unit: Unit.Index,
    entry: Entry.Index,
    any_children: bool,
    func: InternPool.Index,
    func_sym_index: u32,
    func_high_reloc: u32,
    inlined_funcs: std.ArrayListUnmanaged(struct {
        abbrev_code: u32,
        high_reloc: u32,
    }),
    cfi: struct {
        loc: u32,
        cfa: Cfa.RegOff,
    },
    debug_frame: std.ArrayListUnmanaged(u8),
    debug_info: std.ArrayListUnmanaged(u8),
    debug_line: std.ArrayListUnmanaged(u8),
    debug_loclists: std.ArrayListUnmanaged(u8),
    pending_types: std.ArrayListUnmanaged(InternPool.Index),

    pub fn deinit(wip_nav: *WipNav) void {
        const gpa = wip_nav.dwarf.gpa;
        if (wip_nav.func != .none) wip_nav.inlined_funcs.deinit(gpa);
        wip_nav.debug_frame.deinit(gpa);
        wip_nav.debug_info.deinit(gpa);
        wip_nav.debug_line.deinit(gpa);
        wip_nav.debug_loclists.deinit(gpa);
        wip_nav.pending_types.deinit(gpa);
    }

    pub fn genDebugFrame(wip_nav: *WipNav, loc: u32, cfa: Cfa) UpdateError!void {
        assert(wip_nav.func != .none);
        if (wip_nav.dwarf.debug_frame.header.format == .none) return;
        const loc_cfa: Cfa = .{ .advance_loc = loc };
        try loc_cfa.write(wip_nav);
        try cfa.write(wip_nav);
    }

    pub const LocalTag = enum { local_arg, local_var };
    pub fn genLocalDebugInfo(
        wip_nav: *WipNav,
        tag: LocalTag,
        name: []const u8,
        ty: Type,
        loc: Loc,
    ) UpdateError!void {
        assert(wip_nav.func != .none);
        try wip_nav.abbrevCode(switch (tag) {
            inline else => |ct_tag| @field(AbbrevCode, @tagName(ct_tag)),
        });
        try wip_nav.strp(name);
        try wip_nav.refType(ty);
        try wip_nav.exprloc(loc);
        wip_nav.any_children = true;
    }

    pub fn genVarArgsDebugInfo(wip_nav: *WipNav) UpdateError!void {
        assert(wip_nav.func != .none);
        try wip_nav.abbrevCode(.is_var_args);
        wip_nav.any_children = true;
    }

    pub fn advancePCAndLine(
        wip_nav: *WipNav,
        delta_line: i33,
        delta_pc: u64,
    ) error{OutOfMemory}!void {
        const dlw = wip_nav.debug_line.writer(wip_nav.dwarf.gpa);

        const header = wip_nav.dwarf.debug_line.header;
        assert(header.maximum_operations_per_instruction == 1);
        const delta_op: u64 = 0;

        const remaining_delta_line: i9 = @intCast(if (delta_line < header.line_base or
            delta_line - header.line_base >= header.line_range)
        remaining: {
            assert(delta_line != 0);
            try dlw.writeByte(DW.LNS.advance_line);
            try sleb128(dlw, delta_line);
            break :remaining 0;
        } else delta_line);

        const op_advance = @divExact(delta_pc, header.minimum_instruction_length) *
            header.maximum_operations_per_instruction + delta_op;
        const max_op_advance: u9 = (std.math.maxInt(u8) - header.opcode_base) / header.line_range;
        const remaining_op_advance: u8 = @intCast(if (op_advance >= 2 * max_op_advance) remaining: {
            try dlw.writeByte(DW.LNS.advance_pc);
            try uleb128(dlw, op_advance);
            break :remaining 0;
        } else if (op_advance >= max_op_advance) remaining: {
            try dlw.writeByte(DW.LNS.const_add_pc);
            break :remaining op_advance - max_op_advance;
        } else op_advance);

        if (remaining_delta_line == 0 and remaining_op_advance == 0)
            try dlw.writeByte(DW.LNS.copy)
        else
            try dlw.writeByte(@intCast((remaining_delta_line - header.line_base) +
                (header.line_range * remaining_op_advance) + header.opcode_base));
    }

    pub fn setColumn(wip_nav: *WipNav, column: u32) error{OutOfMemory}!void {
        const dlw = wip_nav.debug_line.writer(wip_nav.dwarf.gpa);
        try dlw.writeByte(DW.LNS.set_column);
        try uleb128(dlw, column + 1);
    }

    pub fn setPrologueEnd(wip_nav: *WipNav) error{OutOfMemory}!void {
        const dlw = wip_nav.debug_line.writer(wip_nav.dwarf.gpa);
        try dlw.writeByte(DW.LNS.set_prologue_end);
    }

    pub fn setEpilogueBegin(wip_nav: *WipNav) error{OutOfMemory}!void {
        const dlw = wip_nav.debug_line.writer(wip_nav.dwarf.gpa);
        try dlw.writeByte(DW.LNS.set_epilogue_begin);
    }

    pub fn enterInlineFunc(wip_nav: *WipNav, func: InternPool.Index, code_off: u64, line: u32, column: u32) UpdateError!void {
        const dwarf = wip_nav.dwarf;
        const zcu = wip_nav.pt.zcu;
        const diw = wip_nav.debug_info.writer(dwarf.gpa);
        const inlined_func = try wip_nav.inlined_funcs.addOne(dwarf.gpa);

        inlined_func.abbrev_code = @intCast(wip_nav.debug_info.items.len);
        try wip_nav.abbrevCode(.inlined_func);
        try wip_nav.refNav(zcu.funcInfo(func).owner_nav);
        try uleb128(diw, zcu.navSrcLine(zcu.funcInfo(wip_nav.func).owner_nav) + line + 1);
        try uleb128(diw, column + 1);
        const external_relocs = &dwarf.debug_info.section.getUnit(wip_nav.unit).getEntry(wip_nav.entry).external_relocs;
        try external_relocs.ensureUnusedCapacity(dwarf.gpa, 2);
        external_relocs.appendAssumeCapacity(.{
            .source_off = @intCast(wip_nav.debug_info.items.len),
            .target_sym = wip_nav.func_sym_index,
            .target_off = code_off,
        });
        try diw.writeByteNTimes(0, @intFromEnum(dwarf.address_size));
        inlined_func.high_reloc = @intCast(external_relocs.items.len);
        external_relocs.appendAssumeCapacity(.{
            .source_off = @intCast(wip_nav.debug_info.items.len),
            .target_sym = wip_nav.func_sym_index,
            .target_off = undefined,
        });
        try diw.writeByteNTimes(0, @intFromEnum(dwarf.address_size));
        try wip_nav.setInlineFunc(func);
        wip_nav.any_children = false;
    }

    pub fn leaveInlineFunc(wip_nav: *WipNav, func: InternPool.Index, code_off: u64) UpdateError!void {
        const inlined_func_bytes = comptime uleb128Bytes(@intFromEnum(AbbrevCode.inlined_func));
        const inlined_func = wip_nav.inlined_funcs.pop();
        const external_relocs = &wip_nav.dwarf.debug_info.section.getUnit(wip_nav.unit).getEntry(wip_nav.entry).external_relocs;
        external_relocs.items[inlined_func.high_reloc].target_off = code_off;
        if (wip_nav.any_children)
            try uleb128(wip_nav.debug_info.writer(wip_nav.dwarf.gpa), @intFromEnum(AbbrevCode.null))
        else
            std.leb.writeUnsignedFixed(
                inlined_func_bytes,
                wip_nav.debug_info.items[inlined_func.abbrev_code..][0..inlined_func_bytes],
                try wip_nav.dwarf.refAbbrevCode(.empty_inlined_func),
            );
        try wip_nav.setInlineFunc(func);
        wip_nav.any_children = true;
    }

    pub fn setInlineFunc(wip_nav: *WipNav, func: InternPool.Index) UpdateError!void {
        const zcu = wip_nav.pt.zcu;
        const dwarf = wip_nav.dwarf;
        if (wip_nav.func == func) return;

        const new_func_info = zcu.funcInfo(func);
        const new_file = zcu.navFileScopeIndex(new_func_info.owner_nav);
        const new_unit = try dwarf.getUnit(zcu.fileByIndex(new_file).mod);

        const dlw = wip_nav.debug_line.writer(dwarf.gpa);
        if (dwarf.incremental()) {
            const new_nav_gop = try dwarf.navs.getOrPut(dwarf.gpa, new_func_info.owner_nav);
            errdefer _ = dwarf.navs.pop();
            if (!new_nav_gop.found_existing) new_nav_gop.value_ptr.* = try dwarf.addCommonEntry(new_unit);

            try dlw.writeByte(DW.LNS.extended_op);
            try uleb128(dlw, 1 + dwarf.sectionOffsetBytes());
            try dlw.writeByte(DW.LNE.ZIG_set_decl);
            try dwarf.debug_line.section.getUnit(wip_nav.unit).getEntry(wip_nav.entry).cross_section_relocs.append(dwarf.gpa, .{
                .source_off = @intCast(wip_nav.debug_line.items.len),
                .target_sec = .debug_info,
                .target_unit = new_unit,
                .target_entry = new_nav_gop.value_ptr.toOptional(),
            });
            try dlw.writeByteNTimes(0, dwarf.sectionOffsetBytes());
            return;
        }

        const old_func_info = zcu.funcInfo(wip_nav.func);
        const old_file = zcu.navFileScopeIndex(old_func_info.owner_nav);
        if (old_file != new_file) {
            const mod_info = dwarf.getModInfo(wip_nav.unit);
            const mod_gop = try mod_info.dirs.getOrPut(dwarf.gpa, new_unit);
            errdefer _ = if (!mod_gop.found_existing) mod_info.dirs.pop();
            const file_gop = try mod_info.files.getOrPut(dwarf.gpa, new_file);
            errdefer _ = if (!file_gop.found_existing) mod_info.files.pop();

            try dlw.writeByte(DW.LNS.set_file);
            try uleb128(dlw, file_gop.index);
        }

        const old_src_line: i33 = zcu.navSrcLine(old_func_info.owner_nav);
        const new_src_line: i33 = zcu.navSrcLine(new_func_info.owner_nav);
        if (new_src_line != old_src_line) {
            try dlw.writeByte(DW.LNS.advance_line);
            try sleb128(dlw, new_src_line - old_src_line);
        }

        wip_nav.func = func;
    }

    fn abbrevCode(wip_nav: *WipNav, abbrev_code: AbbrevCode) UpdateError!void {
        try uleb128(wip_nav.debug_info.writer(wip_nav.dwarf.gpa), try wip_nav.dwarf.refAbbrevCode(abbrev_code));
    }

    fn infoSectionOffset(wip_nav: *WipNav, sec: Section.Index, unit: Unit.Index, entry: Entry.Index, off: u32) UpdateError!void {
        const dwarf = wip_nav.dwarf;
        const gpa = dwarf.gpa;
        const entry_ptr = dwarf.debug_info.section.getUnit(wip_nav.unit).getEntry(wip_nav.entry);
        if (sec != .debug_info) {
            try entry_ptr.cross_section_relocs.append(gpa, .{
                .source_off = @intCast(wip_nav.debug_info.items.len),
                .target_sec = sec,
                .target_unit = unit,
                .target_entry = entry.toOptional(),
                .target_off = off,
            });
        } else if (unit != wip_nav.unit) {
            try entry_ptr.cross_unit_relocs.append(gpa, .{
                .source_off = @intCast(wip_nav.debug_info.items.len),
                .target_unit = unit,
                .target_entry = entry.toOptional(),
                .target_off = off,
            });
        } else {
            try entry_ptr.cross_entry_relocs.append(gpa, .{
                .source_off = @intCast(wip_nav.debug_info.items.len),
                .target_entry = entry.toOptional(),
                .target_off = off,
            });
        }
        try wip_nav.debug_info.appendNTimes(gpa, 0, dwarf.sectionOffsetBytes());
    }

    fn strp(wip_nav: *WipNav, str: []const u8) UpdateError!void {
        try wip_nav.infoSectionOffset(.debug_str, StringSection.unit, try wip_nav.dwarf.debug_str.addString(wip_nav.dwarf, str), 0);
    }

    const ExprLocCounter = struct {
        const Stream = std.io.CountingWriter(std.io.NullWriter);
        stream: Stream,
        address_size: AddressSize,
        fn writer(counter: *ExprLocCounter) Stream.Writer {
            return counter.stream.writer();
        }
        fn endian(_: ExprLocCounter) std.builtin.Endian {
            return @import("builtin").cpu.arch.endian();
        }
        fn addrSym(counter: *ExprLocCounter, _: u32) error{}!void {
            counter.stream.bytes_written += @intFromEnum(counter.address_size);
        }
    };

    fn exprloc(wip_nav: *WipNav, loc: Loc) UpdateError!void {
        var counter: ExprLocCounter = .{
            .stream = std.io.countingWriter(std.io.null_writer),
            .address_size = wip_nav.dwarf.address_size,
        };
        try loc.write(&counter);

        const adapter: struct {
            wip_nav: *WipNav,
            fn writer(ctx: @This()) std.ArrayListUnmanaged(u8).Writer {
                return ctx.wip_nav.debug_info.writer(ctx.wip_nav.dwarf.gpa);
            }
            fn endian(ctx: @This()) std.builtin.Endian {
                return ctx.wip_nav.dwarf.endian;
            }
            fn addrSym(ctx: @This(), sym_index: u32) UpdateError!void {
                try ctx.wip_nav.infoAddrSym(sym_index);
            }
        } = .{ .wip_nav = wip_nav };
        try uleb128(adapter.writer(), counter.stream.bytes_written);
        try loc.write(adapter);
    }

    fn infoAddrSym(wip_nav: *WipNav, sym_index: u32) UpdateError!void {
        const dwarf = wip_nav.dwarf;
        try dwarf.debug_info.section.getUnit(wip_nav.unit).getEntry(wip_nav.entry).external_relocs.append(dwarf.gpa, .{
            .source_off = @intCast(wip_nav.debug_info.items.len),
            .target_sym = sym_index,
        });
        try wip_nav.debug_info.appendNTimes(dwarf.gpa, 0, @intFromEnum(dwarf.address_size));
    }

    fn frameExprloc(wip_nav: *WipNav, loc: Loc) UpdateError!void {
        var counter: ExprLocCounter = .{
            .stream = std.io.countingWriter(std.io.null_writer),
            .address_size = wip_nav.dwarf.address_size,
        };
        try loc.write(&counter);

        const adapter: struct {
            wip_nav: *WipNav,
            fn writer(ctx: @This()) std.ArrayListUnmanaged(u8).Writer {
                return ctx.wip_nav.debug_frame.writer(ctx.wip_nav.dwarf.gpa);
            }
            fn endian(ctx: @This()) std.builtin.Endian {
                return ctx.wip_nav.dwarf.endian;
            }
            fn addrSym(ctx: @This(), sym_index: u32) UpdateError!void {
                try ctx.wip_nav.frameAddrSym(sym_index);
            }
        } = .{ .wip_nav = wip_nav };
        try uleb128(adapter.writer(), counter.stream.bytes_written);
        try loc.write(adapter);
    }

    fn frameAddrSym(wip_nav: *WipNav, sym_index: u32) UpdateError!void {
        const dwarf = wip_nav.dwarf;
        try dwarf.debug_frame.section.getUnit(wip_nav.unit).getEntry(wip_nav.entry).external_relocs.append(dwarf.gpa, .{
            .source_off = @intCast(wip_nav.debug_frame.items.len),
            .target_sym = sym_index,
        });
        try wip_nav.debug_frame.appendNTimes(dwarf.gpa, 0, @intFromEnum(dwarf.address_size));
    }

    fn getTypeEntry(wip_nav: *WipNav, ty: Type) UpdateError!struct { Unit.Index, Entry.Index } {
        const zcu = wip_nav.pt.zcu;
        const ip = &zcu.intern_pool;
        const maybe_inst_index = ty.typeDeclInst(zcu);
        const unit = if (maybe_inst_index) |inst_index|
            try wip_nav.dwarf.getUnit(zcu.fileByIndex(inst_index.resolveFile(ip)).mod)
        else
            .main;
        const gop = try wip_nav.dwarf.types.getOrPut(wip_nav.dwarf.gpa, ty.toIntern());
        if (gop.found_existing) return .{ unit, gop.value_ptr.* };
        const entry = try wip_nav.dwarf.addCommonEntry(unit);
        gop.value_ptr.* = entry;
        if (maybe_inst_index == null) try wip_nav.pending_types.append(wip_nav.dwarf.gpa, ty.toIntern());
        return .{ unit, entry };
    }

    fn refType(wip_nav: *WipNav, ty: Type) UpdateError!void {
        const unit, const entry = try wip_nav.getTypeEntry(ty);
        try wip_nav.infoSectionOffset(.debug_info, unit, entry, 0);
    }

    fn refNav(wip_nav: *WipNav, nav_index: InternPool.Nav.Index) UpdateError!void {
        const zcu = wip_nav.pt.zcu;
        const ip = &zcu.intern_pool;
        const unit = try wip_nav.dwarf.getUnit(zcu.fileByIndex(ip.getNav(nav_index).srcInst(ip).resolveFile(ip)).mod);
        const nav_gop = try wip_nav.dwarf.navs.getOrPut(wip_nav.dwarf.gpa, nav_index);
        if (!nav_gop.found_existing) nav_gop.value_ptr.* = try wip_nav.dwarf.addCommonEntry(unit);
        try wip_nav.infoSectionOffset(.debug_info, unit, nav_gop.value_ptr.*, 0);
    }

    fn refForward(wip_nav: *WipNav) std.mem.Allocator.Error!u32 {
        const dwarf = wip_nav.dwarf;
        const cross_entry_relocs = &dwarf.debug_info.section.getUnit(wip_nav.unit).getEntry(wip_nav.entry).cross_entry_relocs;
        const reloc_index: u32 = @intCast(cross_entry_relocs.items.len);
        try cross_entry_relocs.append(dwarf.gpa, .{
            .source_off = @intCast(wip_nav.debug_info.items.len),
            .target_entry = undefined,
            .target_off = undefined,
        });
        try wip_nav.debug_info.appendNTimes(dwarf.gpa, 0, dwarf.sectionOffsetBytes());
        return reloc_index;
    }

    fn finishForward(wip_nav: *WipNav, reloc_index: u32) void {
        const reloc = &wip_nav.dwarf.debug_info.section.getUnit(wip_nav.unit).getEntry(wip_nav.entry).cross_entry_relocs.items[reloc_index];
        reloc.target_entry = wip_nav.entry.toOptional();
        reloc.target_off = @intCast(wip_nav.debug_info.items.len);
    }

    fn enumConstValue(
        wip_nav: *WipNav,
        loaded_enum: InternPool.LoadedEnumType,
        abbrev_code: struct {
            sdata: AbbrevCode,
            udata: AbbrevCode,
            block: AbbrevCode,
        },
        field_index: usize,
    ) UpdateError!void {
        const zcu = wip_nav.pt.zcu;
        const ip = &zcu.intern_pool;
        const diw = wip_nav.debug_info.writer(wip_nav.dwarf.gpa);
        const signedness = switch (loaded_enum.tag_ty) {
            .comptime_int_type => .signed,
            else => Type.fromInterned(loaded_enum.tag_ty).intInfo(zcu).signedness,
        };
        if (loaded_enum.values.len > 0) {
            var big_int_space: Value.BigIntSpace = undefined;
            const big_int = ip.indexToKey(loaded_enum.values.get(ip)[field_index]).int.storage.toBigInt(&big_int_space);
            const bits = @max(1, big_int.bitCountTwosCompForSignedness(signedness));
            if (bits <= 64) {
                try wip_nav.abbrevCode(switch (signedness) {
                    .signed => abbrev_code.sdata,
                    .unsigned => abbrev_code.udata,
                });
                try wip_nav.debug_info.ensureUnusedCapacity(wip_nav.dwarf.gpa, std.math.divCeil(usize, bits, 7) catch unreachable);
                var bit: usize = 0;
                var carry: u1 = 1;
                while (bit < bits) : (bit += 7) {
                    const limb_bits = @typeInfo(std.math.big.Limb).int.bits;
                    const limb_index = bit / limb_bits;
                    const limb_shift: std.math.Log2Int(std.math.big.Limb) = @intCast(bit % limb_bits);
                    const low_abs_part: u7 = @truncate(big_int.limbs[limb_index] >> limb_shift);
                    const abs_part = if (limb_shift > limb_bits - 7 and limb_index + 1 < big_int.limbs.len) abs_part: {
                        const high_abs_part: u7 = @truncate(big_int.limbs[limb_index + 1] << -%limb_shift);
                        break :abs_part high_abs_part | low_abs_part;
                    } else low_abs_part;
                    const twos_comp_part = if (big_int.positive) abs_part else twos_comp_part: {
                        const twos_comp_part, carry = @addWithOverflow(~abs_part, carry);
                        break :twos_comp_part twos_comp_part;
                    };
                    wip_nav.debug_info.appendAssumeCapacity(@as(u8, if (bit + 7 < bits) 0x80 else 0x00) | twos_comp_part);
                }
            } else {
                try wip_nav.abbrevCode(abbrev_code.block);
                const bytes = Type.fromInterned(loaded_enum.tag_ty).abiSize(zcu);
                try uleb128(diw, bytes);
                big_int.writeTwosComplement(
                    try wip_nav.debug_info.addManyAsSlice(wip_nav.dwarf.gpa, @intCast(bytes)),
                    wip_nav.dwarf.endian,
                );
            }
        } else switch (signedness) {
            .signed => {
                try wip_nav.abbrevCode(abbrev_code.sdata);
                try sleb128(diw, field_index);
            },
            .unsigned => {
                try wip_nav.abbrevCode(abbrev_code.udata);
                try uleb128(diw, field_index);
            },
        }
    }

    fn flush(wip_nav: *WipNav) UpdateError!void {
        while (wip_nav.pending_types.popOrNull()) |ty| try wip_nav.dwarf.updateType(wip_nav.pt, ty, &wip_nav.pending_types);
    }
};

/// When allocating, the ideal_capacity is calculated by
/// actual_capacity + (actual_capacity / ideal_factor)
const ideal_factor = 3;

fn padToIdeal(actual_size: anytype) @TypeOf(actual_size) {
    return actual_size +| (actual_size / ideal_factor);
}

pub fn init(lf: *link.File, format: DW.Format) Dwarf {
    const comp = lf.comp;
    const gpa = comp.gpa;
    const target = comp.root_mod.resolved_target.result;
    return .{
        .gpa = gpa,
        .bin_file = lf,
        .format = format,
        .address_size = switch (target.ptrBitWidth()) {
            0...32 => .@"32",
            33...64 => .@"64",
            else => unreachable,
        },
        .endian = target.cpu.arch.endian(),

        .mods = .{},
        .types = .{},
        .navs = .{},

        .debug_abbrev = .{ .section = Section.init },
        .debug_aranges = .{ .section = Section.init },
        .debug_frame = .{
            .header = if (target.cpu.arch == .x86_64 and target.ofmt == .elf) header: {
                const Register = @import("../arch/x86_64/bits.zig").Register;
                break :header comptime .{
                    .format = .eh_frame,
                    .code_alignment_factor = 1,
                    .data_alignment_factor = -8,
                    .return_address_register = Register.rip.dwarfNum(),
                    .initial_instructions = &.{
                        .{ .def_cfa = .{ .reg = Register.rsp.dwarfNum(), .off = 8 } },
                        .{ .offset = .{ .reg = Register.rip.dwarfNum(), .off = -8 } },
                    },
                };
            } else .{
                .format = .none,
                .code_alignment_factor = undefined,
                .data_alignment_factor = undefined,
                .return_address_register = undefined,
                .initial_instructions = &.{},
            },
            .section = Section.init,
        },
        .debug_info = .{ .section = Section.init },
        .debug_line = .{
            .header = switch (target.cpu.arch) {
                .x86_64, .aarch64 => .{
                    .minimum_instruction_length = 1,
                    .maximum_operations_per_instruction = 1,
                    .default_is_stmt = true,
                    .line_base = -5,
                    .line_range = 14,
                    .opcode_base = DW.LNS.set_isa + 1,
                },
                else => .{
                    .minimum_instruction_length = 1,
                    .maximum_operations_per_instruction = 1,
                    .default_is_stmt = true,
                    .line_base = 0,
                    .line_range = 1,
                    .opcode_base = DW.LNS.set_isa + 1,
                },
            },
            .section = Section.init,
        },
        .debug_line_str = StringSection.init,
        .debug_loclists = .{ .section = Section.init },
        .debug_rnglists = .{ .section = Section.init },
        .debug_str = StringSection.init,
    };
}

pub fn reloadSectionMetadata(dwarf: *Dwarf) void {
    if (dwarf.bin_file.cast(.macho)) |macho_file| {
        if (macho_file.d_sym) |*d_sym| {
            for ([_]*Section{
                &dwarf.debug_abbrev.section,
                &dwarf.debug_aranges.section,
                &dwarf.debug_info.section,
                &dwarf.debug_line.section,
                &dwarf.debug_line_str.section,
                &dwarf.debug_loclists.section,
                &dwarf.debug_rnglists.section,
                &dwarf.debug_str.section,
            }, [_]u8{
                d_sym.debug_abbrev_section_index.?,
                d_sym.debug_aranges_section_index.?,
                d_sym.debug_info_section_index.?,
                d_sym.debug_line_section_index.?,
                d_sym.debug_line_str_section_index.?,
                d_sym.debug_loclists_section_index.?,
                d_sym.debug_rnglists_section_index.?,
                d_sym.debug_str_section_index.?,
            }) |sec, sect_index| {
                const header = &d_sym.sections.items[sect_index];
                sec.index = sect_index;
                sec.len = header.size;
            }
        } else {
            for ([_]*Section{
                &dwarf.debug_abbrev.section,
                &dwarf.debug_aranges.section,
                &dwarf.debug_info.section,
                &dwarf.debug_line.section,
                &dwarf.debug_line_str.section,
                &dwarf.debug_loclists.section,
                &dwarf.debug_rnglists.section,
                &dwarf.debug_str.section,
            }, [_]u8{
                macho_file.debug_abbrev_sect_index.?,
                macho_file.debug_aranges_sect_index.?,
                macho_file.debug_info_sect_index.?,
                macho_file.debug_line_sect_index.?,
                macho_file.debug_line_str_sect_index.?,
                macho_file.debug_loclists_sect_index.?,
                macho_file.debug_rnglists_sect_index.?,
                macho_file.debug_str_sect_index.?,
            }) |sec, sect_index| {
                const header = &macho_file.sections.items(.header)[sect_index];
                sec.index = sect_index;
                sec.len = header.size;
            }
        }
    }
}

pub fn initMetadata(dwarf: *Dwarf) UpdateError!void {
    if (dwarf.bin_file.cast(.elf)) |elf_file| {
        const zo = elf_file.zigObjectPtr().?;
        for ([_]*Section{
            &dwarf.debug_abbrev.section,
            &dwarf.debug_aranges.section,
            &dwarf.debug_frame.section,
            &dwarf.debug_info.section,
            &dwarf.debug_line.section,
            &dwarf.debug_line_str.section,
            &dwarf.debug_loclists.section,
            &dwarf.debug_rnglists.section,
            &dwarf.debug_str.section,
        }, [_]u32{
            zo.debug_abbrev_index.?,
            zo.debug_aranges_index.?,
            zo.eh_frame_index.?,
            zo.debug_info_index.?,
            zo.debug_line_index.?,
            zo.debug_line_str_index.?,
            zo.debug_loclists_index.?,
            zo.debug_rnglists_index.?,
            zo.debug_str_index.?,
        }) |sec, sym_index| {
            sec.index = sym_index;
        }
    }
    dwarf.reloadSectionMetadata();

    dwarf.debug_abbrev.section.pad_to_ideal = false;
    assert(try dwarf.debug_abbrev.section.addUnit(DebugAbbrev.header_bytes, DebugAbbrev.trailer_bytes, dwarf) == DebugAbbrev.unit);
    errdefer dwarf.debug_abbrev.section.popUnit(dwarf.gpa);
    for (std.enums.values(AbbrevCode)) |abbrev_code|
        assert(@intFromEnum(try dwarf.debug_abbrev.section.getUnit(DebugAbbrev.unit).addEntry(dwarf.gpa)) == @intFromEnum(abbrev_code));

    dwarf.debug_aranges.section.pad_to_ideal = false;
    dwarf.debug_aranges.section.alignment = InternPool.Alignment.fromNonzeroByteUnits(@intFromEnum(dwarf.address_size) * 2);

    dwarf.debug_frame.section.alignment = switch (dwarf.debug_frame.header.format) {
        .none => .@"1",
        .debug_frame => InternPool.Alignment.fromNonzeroByteUnits(@intFromEnum(dwarf.address_size)),
        .eh_frame => .@"4",
    };

    dwarf.debug_line_str.section.pad_to_ideal = false;
    assert(try dwarf.debug_line_str.section.addUnit(0, 0, dwarf) == StringSection.unit);
    errdefer dwarf.debug_line_str.section.popUnit(dwarf.gpa);

    dwarf.debug_str.section.pad_to_ideal = false;
    assert(try dwarf.debug_str.section.addUnit(0, 0, dwarf) == StringSection.unit);
    errdefer dwarf.debug_str.section.popUnit(dwarf.gpa);

    dwarf.debug_loclists.section.pad_to_ideal = false;

    dwarf.debug_rnglists.section.pad_to_ideal = false;
}

pub fn deinit(dwarf: *Dwarf) void {
    const gpa = dwarf.gpa;
    for (dwarf.mods.values()) |*mod_info| mod_info.deinit(gpa);
    dwarf.mods.deinit(gpa);
    dwarf.types.deinit(gpa);
    dwarf.navs.deinit(gpa);
    dwarf.debug_abbrev.section.deinit(gpa);
    dwarf.debug_aranges.section.deinit(gpa);
    dwarf.debug_frame.section.deinit(gpa);
    dwarf.debug_info.section.deinit(gpa);
    dwarf.debug_line.section.deinit(gpa);
    dwarf.debug_line_str.deinit(gpa);
    dwarf.debug_loclists.section.deinit(gpa);
    dwarf.debug_rnglists.section.deinit(gpa);
    dwarf.debug_str.deinit(gpa);
    dwarf.* = undefined;
}

fn getUnit(dwarf: *Dwarf, mod: *Module) UpdateError!Unit.Index {
    const mod_gop = try dwarf.mods.getOrPut(dwarf.gpa, mod);
    const unit: Unit.Index = @enumFromInt(mod_gop.index);
    if (!mod_gop.found_existing) {
        errdefer _ = dwarf.mods.pop();
        mod_gop.value_ptr.* = .{
            .root_dir_path = undefined,
            .dirs = .{},
            .files = .{},
        };
        errdefer mod_gop.value_ptr.dirs.deinit(dwarf.gpa);
        try mod_gop.value_ptr.dirs.putNoClobber(dwarf.gpa, unit, {});
        assert(try dwarf.debug_aranges.section.addUnit(
            DebugAranges.headerBytes(dwarf),
            DebugAranges.trailerBytes(dwarf),
            dwarf,
        ) == unit);
        errdefer dwarf.debug_aranges.section.popUnit(dwarf.gpa);
        assert(try dwarf.debug_frame.section.addUnit(
            DebugFrame.headerBytes(dwarf),
            DebugFrame.trailerBytes(dwarf),
            dwarf,
        ) == unit);
        errdefer dwarf.debug_frame.section.popUnit(dwarf.gpa);
        assert(try dwarf.debug_info.section.addUnit(
            DebugInfo.headerBytes(dwarf),
            DebugInfo.trailer_bytes,
            dwarf,
        ) == unit);
        errdefer dwarf.debug_info.section.popUnit(dwarf.gpa);
        assert(try dwarf.debug_line.section.addUnit(
            DebugLine.headerBytes(dwarf, 5, 25),
            DebugLine.trailer_bytes,
            dwarf,
        ) == unit);
        errdefer dwarf.debug_line.section.popUnit(dwarf.gpa);
        assert(try dwarf.debug_loclists.section.addUnit(
            DebugLocLists.headerBytes(dwarf),
            DebugLocLists.trailer_bytes,
            dwarf,
        ) == unit);
        errdefer dwarf.debug_loclists.section.popUnit(dwarf.gpa);
        assert(try dwarf.debug_rnglists.section.addUnit(
            DebugRngLists.headerBytes(dwarf),
            DebugRngLists.trailer_bytes,
            dwarf,
        ) == unit);
        errdefer dwarf.debug_rnglists.section.popUnit(dwarf.gpa);
    }
    return unit;
}

fn getUnitIfExists(dwarf: *const Dwarf, mod: *Module) ?Unit.Index {
    return @enumFromInt(dwarf.mods.getIndex(mod) orelse return null);
}

fn getModInfo(dwarf: *Dwarf, unit: Unit.Index) *ModInfo {
    return &dwarf.mods.values()[@intFromEnum(unit)];
}

pub fn initWipNav(dwarf: *Dwarf, pt: Zcu.PerThread, nav_index: InternPool.Nav.Index, sym_index: u32) UpdateError!?WipNav {
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;

    const nav = ip.getNav(nav_index);
    log.debug("initWipNav({})", .{nav.fqn.fmt(ip)});

    const inst_info = nav.srcInst(ip).resolveFull(ip).?;
    const file = zcu.fileByIndex(inst_info.file);

    const unit = try dwarf.getUnit(file.mod);
    const nav_gop = try dwarf.navs.getOrPut(dwarf.gpa, nav_index);
    errdefer _ = dwarf.navs.pop();
    if (nav_gop.found_existing) {
        for ([_]*Section{
            &dwarf.debug_aranges.section,
            &dwarf.debug_info.section,
            &dwarf.debug_line.section,
            &dwarf.debug_loclists.section,
            &dwarf.debug_rnglists.section,
        }) |sec| sec.getUnit(unit).getEntry(nav_gop.value_ptr.*).clear();
    } else nav_gop.value_ptr.* = try dwarf.addCommonEntry(unit);
    const nav_val = zcu.navValue(nav_index);
    var wip_nav: WipNav = .{
        .dwarf = dwarf,
        .pt = pt,
        .unit = unit,
        .entry = nav_gop.value_ptr.*,
        .any_children = false,
        .func = .none,
        .func_sym_index = undefined,
        .func_high_reloc = undefined,
        .inlined_funcs = undefined,
        .cfi = undefined,
        .debug_frame = .{},
        .debug_info = .{},
        .debug_line = .{},
        .debug_loclists = .{},
        .pending_types = .{},
    };
    errdefer wip_nav.deinit();

    switch (ip.indexToKey(nav_val.toIntern())) {
        else => {
            assert(file.zir_loaded);
            const decl_inst = file.zir.instructions.get(@intFromEnum(inst_info.inst));
            assert(decl_inst.tag == .declaration);
            const tree = try file.getTree(dwarf.gpa);
            const loc = tree.tokenLocation(0, tree.nodes.items(.main_token)[decl_inst.data.declaration.src_node]);
            assert(loc.line == zcu.navSrcLine(nav_index));

            const parent_type, const accessibility: u8 = if (nav.analysis_owner.unwrap()) |cau| parent: {
                const decl_extra = file.zir.extraData(Zir.Inst.Declaration, decl_inst.data.declaration.payload_index).data;
                const parent_namespace_ptr = ip.namespacePtr(ip.getCau(cau).namespace);
                break :parent .{
                    parent_namespace_ptr.owner_type,
                    switch (decl_extra.name) {
                        .@"comptime",
                        .@"usingnamespace",
                        .unnamed_test,
                        .decltest,
                        => DW.ACCESS.private,
                        _ => if (decl_extra.name.isNamedTest(file.zir))
                            DW.ACCESS.private
                        else if (parent_namespace_ptr.pub_decls.containsContext(nav_index, .{ .zcu = zcu }))
                            DW.ACCESS.public
                        else if (parent_namespace_ptr.priv_decls.containsContext(nav_index, .{ .zcu = zcu }))
                            DW.ACCESS.private
                        else
                            unreachable,
                    },
                };
            } else .{ zcu.fileRootType(inst_info.file), DW.ACCESS.private };

            const diw = wip_nav.debug_info.writer(dwarf.gpa);
            try wip_nav.abbrevCode(.decl_var);
            try wip_nav.refType(Type.fromInterned(parent_type));
            assert(wip_nav.debug_info.items.len == DebugInfo.declEntryLineOff(dwarf));
            try diw.writeInt(u32, @intCast(loc.line + 1), dwarf.endian);
            try uleb128(diw, loc.column + 1);
            try diw.writeByte(accessibility);
            try wip_nav.strp(nav.name.toSlice(ip));
            try wip_nav.strp(nav.fqn.toSlice(ip));
            const ty = nav_val.typeOf(zcu);
            const ty_reloc_index = try wip_nav.refForward();
            try wip_nav.exprloc(.{ .addr = .{ .sym = sym_index } });
            try uleb128(diw, nav.status.resolved.alignment.toByteUnits() orelse
                ty.abiAlignment(zcu).toByteUnits().?);
            try diw.writeByte(@intFromBool(false));
            wip_nav.finishForward(ty_reloc_index);
            try wip_nav.abbrevCode(.is_const);
            try wip_nav.refType(ty);
        },
        .variable => |variable| {
            assert(file.zir_loaded);
            const decl_inst = file.zir.instructions.get(@intFromEnum(inst_info.inst));
            assert(decl_inst.tag == .declaration);
            const tree = try file.getTree(dwarf.gpa);
            const loc = tree.tokenLocation(0, tree.nodes.items(.main_token)[decl_inst.data.declaration.src_node]);
            assert(loc.line == zcu.navSrcLine(nav_index));

            const parent_type, const accessibility: u8 = if (nav.analysis_owner.unwrap()) |cau| parent: {
                const decl_extra = file.zir.extraData(Zir.Inst.Declaration, decl_inst.data.declaration.payload_index).data;
                const parent_namespace_ptr = ip.namespacePtr(ip.getCau(cau).namespace);
                break :parent .{
                    parent_namespace_ptr.owner_type,
                    switch (decl_extra.name) {
                        .@"comptime",
                        .@"usingnamespace",
                        .unnamed_test,
                        .decltest,
                        => DW.ACCESS.private,
                        _ => if (decl_extra.name.isNamedTest(file.zir))
                            DW.ACCESS.private
                        else if (parent_namespace_ptr.pub_decls.containsContext(nav_index, .{ .zcu = zcu }))
                            DW.ACCESS.public
                        else if (parent_namespace_ptr.priv_decls.containsContext(nav_index, .{ .zcu = zcu }))
                            DW.ACCESS.private
                        else
                            unreachable,
                    },
                };
            } else .{ zcu.fileRootType(inst_info.file), DW.ACCESS.private };

            const diw = wip_nav.debug_info.writer(dwarf.gpa);
            try wip_nav.abbrevCode(.decl_var);
            try wip_nav.refType(Type.fromInterned(parent_type));
            assert(wip_nav.debug_info.items.len == DebugInfo.declEntryLineOff(dwarf));
            try diw.writeInt(u32, @intCast(loc.line + 1), dwarf.endian);
            try uleb128(diw, loc.column + 1);
            try diw.writeByte(accessibility);
            try wip_nav.strp(nav.name.toSlice(ip));
            try wip_nav.strp(nav.fqn.toSlice(ip));
            const ty = Type.fromInterned(variable.ty);
            try wip_nav.refType(ty);
            const addr: Loc = .{ .addr = .{ .sym = sym_index } };
            try wip_nav.exprloc(if (variable.is_threadlocal) .{ .form_tls_address = &addr } else addr);
            try uleb128(diw, nav.status.resolved.alignment.toByteUnits() orelse
                ty.abiAlignment(zcu).toByteUnits().?);
            try diw.writeByte(@intFromBool(false));
        },
        .func => |func| {
            assert(file.zir_loaded);
            const decl_inst = file.zir.instructions.get(@intFromEnum(inst_info.inst));
            assert(decl_inst.tag == .declaration);
            const tree = try file.getTree(dwarf.gpa);
            const loc = tree.tokenLocation(0, tree.nodes.items(.main_token)[decl_inst.data.declaration.src_node]);
            assert(loc.line == zcu.navSrcLine(nav_index));

            const parent_type, const accessibility: u8 = if (nav.analysis_owner.unwrap()) |cau| parent: {
                const decl_extra = file.zir.extraData(Zir.Inst.Declaration, decl_inst.data.declaration.payload_index).data;
                const parent_namespace_ptr = ip.namespacePtr(ip.getCau(cau).namespace);
                break :parent .{
                    parent_namespace_ptr.owner_type,
                    switch (decl_extra.name) {
                        .@"comptime",
                        .@"usingnamespace",
                        .unnamed_test,
                        .decltest,
                        => DW.ACCESS.private,
                        _ => if (decl_extra.name.isNamedTest(file.zir))
                            DW.ACCESS.private
                        else if (parent_namespace_ptr.pub_decls.containsContext(nav_index, .{ .zcu = zcu }))
                            DW.ACCESS.public
                        else if (parent_namespace_ptr.priv_decls.containsContext(nav_index, .{ .zcu = zcu }))
                            DW.ACCESS.private
                        else
                            unreachable,
                    },
                };
            } else .{ zcu.fileRootType(inst_info.file), DW.ACCESS.private };

            const func_type = ip.indexToKey(func.ty).func_type;
            wip_nav.func = nav_val.toIntern();
            wip_nav.func_sym_index = sym_index;
            wip_nav.inlined_funcs = .{};
            if (dwarf.debug_frame.header.format != .none) wip_nav.cfi = .{
                .loc = 0,
                .cfa = dwarf.debug_frame.header.initial_instructions[0].def_cfa,
            };

            switch (dwarf.debug_frame.header.format) {
                .none => {},
                .debug_frame, .eh_frame => |format| {
                    const entry = dwarf.debug_frame.section.getUnit(wip_nav.unit).getEntry(wip_nav.entry);
                    const dfw = wip_nav.debug_frame.writer(dwarf.gpa);
                    switch (dwarf.format) {
                        .@"32" => try dfw.writeInt(u32, undefined, dwarf.endian),
                        .@"64" => {
                            try dfw.writeInt(u32, std.math.maxInt(u32), dwarf.endian);
                            try dfw.writeInt(u64, undefined, dwarf.endian);
                        },
                    }
                    switch (format) {
                        .none => unreachable,
                        .debug_frame => {
                            try entry.cross_entry_relocs.append(dwarf.gpa, .{
                                .source_off = @intCast(wip_nav.debug_frame.items.len),
                            });
                            try dfw.writeByteNTimes(0, dwarf.sectionOffsetBytes());
                            try entry.external_relocs.append(dwarf.gpa, .{
                                .source_off = @intCast(wip_nav.debug_frame.items.len),
                                .target_sym = sym_index,
                            });
                            try dfw.writeByteNTimes(0, @intFromEnum(dwarf.address_size));
                            try dfw.writeByteNTimes(undefined, @intFromEnum(dwarf.address_size));
                        },
                        .eh_frame => {
                            try dfw.writeInt(u32, undefined, dwarf.endian);
                            try entry.external_relocs.append(dwarf.gpa, .{
                                .source_off = @intCast(wip_nav.debug_frame.items.len),
                                .target_sym = sym_index,
                            });
                            try dfw.writeByteNTimes(0, dwarf.sectionOffsetBytes());
                            try dfw.writeInt(u32, undefined, dwarf.endian);
                            try uleb128(dfw, 0);
                        },
                    }
                },
            }

            const diw = wip_nav.debug_info.writer(dwarf.gpa);
            try wip_nav.abbrevCode(.decl_func);
            try wip_nav.refType(Type.fromInterned(parent_type));
            assert(wip_nav.debug_info.items.len == DebugInfo.declEntryLineOff(dwarf));
            try diw.writeInt(u32, @intCast(loc.line + 1), dwarf.endian);
            try uleb128(diw, loc.column + 1);
            try diw.writeByte(accessibility);
            try wip_nav.strp(nav.name.toSlice(ip));
            try wip_nav.strp(nav.fqn.toSlice(ip));
            try wip_nav.refType(Type.fromInterned(func_type.return_type));
            const external_relocs = &dwarf.debug_info.section.getUnit(wip_nav.unit).getEntry(wip_nav.entry).external_relocs;
            try external_relocs.ensureUnusedCapacity(dwarf.gpa, 2);
            external_relocs.appendAssumeCapacity(.{
                .source_off = @intCast(wip_nav.debug_info.items.len),
                .target_sym = sym_index,
            });
            try diw.writeByteNTimes(0, @intFromEnum(dwarf.address_size));
            wip_nav.func_high_reloc = @intCast(external_relocs.items.len);
            external_relocs.appendAssumeCapacity(.{
                .source_off = @intCast(wip_nav.debug_info.items.len),
                .target_sym = sym_index,
                .target_off = undefined,
            });
            try diw.writeByteNTimes(0, @intFromEnum(dwarf.address_size));
            try uleb128(diw, nav.status.resolved.alignment.toByteUnits() orelse
                target_info.defaultFunctionAlignment(file.mod.resolved_target.result).toByteUnits().?);
            try diw.writeByte(@intFromBool(false));
            try diw.writeByte(@intFromBool(func_type.return_type == .noreturn_type));

            const dlw = wip_nav.debug_line.writer(dwarf.gpa);
            try dlw.writeByte(DW.LNS.extended_op);
            if (dwarf.incremental()) {
                try uleb128(dlw, 1 + dwarf.sectionOffsetBytes());
                try dlw.writeByte(DW.LNE.ZIG_set_decl);
                try dwarf.debug_line.section.getUnit(wip_nav.unit).getEntry(wip_nav.entry).cross_section_relocs.append(dwarf.gpa, .{
                    .source_off = @intCast(wip_nav.debug_line.items.len),
                    .target_sec = .debug_info,
                    .target_unit = wip_nav.unit,
                    .target_entry = wip_nav.entry.toOptional(),
                });
                try dlw.writeByteNTimes(0, dwarf.sectionOffsetBytes());

                try dlw.writeByte(DW.LNS.set_column);
                try uleb128(dlw, func.lbrace_column + 1);

                try wip_nav.advancePCAndLine(func.lbrace_line, 0);
            } else {
                try uleb128(dlw, 1 + @intFromEnum(dwarf.address_size));
                try dlw.writeByte(DW.LNE.set_address);
                try dwarf.debug_line.section.getUnit(wip_nav.unit).getEntry(wip_nav.entry).external_relocs.append(dwarf.gpa, .{
                    .source_off = @intCast(wip_nav.debug_line.items.len),
                    .target_sym = sym_index,
                });
                try dlw.writeByteNTimes(0, @intFromEnum(dwarf.address_size));

                const file_gop = try dwarf.getModInfo(unit).files.getOrPut(dwarf.gpa, inst_info.file);
                try dlw.writeByte(DW.LNS.set_file);
                try uleb128(dlw, file_gop.index);

                try dlw.writeByte(DW.LNS.set_column);
                try uleb128(dlw, func.lbrace_column + 1);

                try wip_nav.advancePCAndLine(@intCast(loc.line + func.lbrace_line), 0);
            }
        },
    }
    return wip_nav;
}

pub fn finishWipNav(
    dwarf: *Dwarf,
    pt: Zcu.PerThread,
    nav_index: InternPool.Nav.Index,
    sym: struct { index: u32, addr: u64, size: u64 },
    wip_nav: *WipNav,
) UpdateError!void {
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const nav = ip.getNav(nav_index);
    log.debug("finishWipNav({})", .{nav.fqn.fmt(ip)});

    if (wip_nav.func != .none) {
        {
            const external_relocs = &dwarf.debug_aranges.section.getUnit(wip_nav.unit).getEntry(wip_nav.entry).external_relocs;
            try external_relocs.append(dwarf.gpa, .{ .target_sym = sym.index });
            var entry: [8 + 8]u8 = undefined;
            @memset(entry[0..@intFromEnum(dwarf.address_size)], 0);
            dwarf.writeInt(entry[@intFromEnum(dwarf.address_size)..][0..@intFromEnum(dwarf.address_size)], sym.size);
            try dwarf.debug_aranges.section.replaceEntry(
                wip_nav.unit,
                wip_nav.entry,
                dwarf,
                entry[0 .. @intFromEnum(dwarf.address_size) * 2],
            );
        }
        switch (dwarf.debug_frame.header.format) {
            .none => {},
            .debug_frame, .eh_frame => |format| {
                try wip_nav.debug_frame.appendNTimes(
                    dwarf.gpa,
                    DW.CFA.nop,
                    @intCast(dwarf.debug_frame.section.alignment.forward(wip_nav.debug_frame.items.len) - wip_nav.debug_frame.items.len),
                );
                const contents = wip_nav.debug_frame.items;
                try dwarf.debug_frame.section.resizeEntry(wip_nav.unit, wip_nav.entry, dwarf, @intCast(contents.len));
                const unit = dwarf.debug_frame.section.getUnit(wip_nav.unit);
                const entry = unit.getEntry(wip_nav.entry);
                const unit_len = (if (entry.next.unwrap()) |next_entry|
                    unit.getEntry(next_entry).off - entry.off
                else
                    entry.len) - dwarf.unitLengthBytes();
                dwarf.writeInt(contents[dwarf.unitLengthBytes() - dwarf.sectionOffsetBytes() ..][0..dwarf.sectionOffsetBytes()], unit_len);
                switch (format) {
                    .none => unreachable,
                    .debug_frame => dwarf.writeInt(contents[dwarf.unitLengthBytes() + dwarf.sectionOffsetBytes() +
                        @intFromEnum(dwarf.address_size) ..][0..@intFromEnum(dwarf.address_size)], sym.size),
                    .eh_frame => {
                        std.mem.writeInt(
                            u32,
                            contents[dwarf.unitLengthBytes()..][0..4],
                            unit.header_len + entry.off + dwarf.unitLengthBytes(),
                            dwarf.endian,
                        );
                        std.mem.writeInt(u32, contents[dwarf.unitLengthBytes() + 4 + 4 ..][0..4], @intCast(sym.size), dwarf.endian);
                    },
                }
                try entry.replace(unit, &dwarf.debug_frame.section, dwarf, contents);
            },
        }
        {
            const external_relocs = &dwarf.debug_info.section.getUnit(wip_nav.unit).getEntry(wip_nav.entry).external_relocs;
            external_relocs.items[wip_nav.func_high_reloc].target_off = sym.size;
            if (wip_nav.any_children) {
                const diw = wip_nav.debug_info.writer(dwarf.gpa);
                try uleb128(diw, @intFromEnum(AbbrevCode.null));
            } else std.leb.writeUnsignedFixed(
                AbbrevCode.decl_bytes,
                wip_nav.debug_info.items[0..AbbrevCode.decl_bytes],
                try dwarf.refAbbrevCode(.decl_empty_func),
            );
        }
        {
            try dwarf.debug_rnglists.section.getUnit(wip_nav.unit).getEntry(wip_nav.entry).external_relocs.appendSlice(dwarf.gpa, &.{
                .{
                    .source_off = 1,
                    .target_sym = sym.index,
                },
                .{
                    .source_off = 1 + @intFromEnum(dwarf.address_size),
                    .target_sym = sym.index,
                    .target_off = sym.size,
                },
            });
            try dwarf.debug_rnglists.section.replaceEntry(
                wip_nav.unit,
                wip_nav.entry,
                dwarf,
                ([1]u8{DW.RLE.start_end} ++ [1]u8{0} ** (8 + 8))[0 .. 1 + @intFromEnum(dwarf.address_size) + @intFromEnum(dwarf.address_size)],
            );
        }
    }

    try dwarf.debug_info.section.replaceEntry(wip_nav.unit, wip_nav.entry, dwarf, wip_nav.debug_info.items);
    if (wip_nav.debug_line.items.len > 0) {
        const dlw = wip_nav.debug_line.writer(dwarf.gpa);
        try dlw.writeByte(DW.LNS.extended_op);
        try uleb128(dlw, 1);
        try dlw.writeByte(DW.LNE.end_sequence);
        try dwarf.debug_line.section.replaceEntry(wip_nav.unit, wip_nav.entry, dwarf, wip_nav.debug_line.items);
    }
    try dwarf.debug_loclists.section.replaceEntry(wip_nav.unit, wip_nav.entry, dwarf, wip_nav.debug_loclists.items);

    try wip_nav.flush();
}

pub fn updateComptimeNav(dwarf: *Dwarf, pt: Zcu.PerThread, nav_index: InternPool.Nav.Index) UpdateError!void {
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const nav_val = zcu.navValue(nav_index);

    const nav = ip.getNav(nav_index);
    log.debug("updateComptimeNav({})", .{nav.fqn.fmt(ip)});

    const inst_info = nav.srcInst(ip).resolveFull(ip).?;
    const file = zcu.fileByIndex(inst_info.file);
    assert(file.zir_loaded);
    const decl_inst = file.zir.instructions.get(@intFromEnum(inst_info.inst));
    assert(decl_inst.tag == .declaration);
    const decl_extra = file.zir.extraData(Zir.Inst.Declaration, decl_inst.data.declaration.payload_index);

    const is_test = switch (decl_extra.data.name) {
        .unnamed_test, .decltest => true,
        .@"comptime", .@"usingnamespace" => false,
        _ => decl_extra.data.name.isNamedTest(file.zir),
    };
    if (is_test) {
        // This isn't actually a comptime Nav! It's a test, so it'll definitely never be referenced at comptime.
        return;
    }

    const tree = try file.getTree(dwarf.gpa);
    const loc = tree.tokenLocation(0, tree.nodes.items(.main_token)[decl_inst.data.declaration.src_node]);
    assert(loc.line == zcu.navSrcLine(nav_index));

    var wip_nav: WipNav = .{
        .dwarf = dwarf,
        .pt = pt,
        .unit = try dwarf.getUnit(file.mod),
        .entry = undefined,
        .any_children = false,
        .func = .none,
        .func_sym_index = undefined,
        .func_high_reloc = undefined,
        .inlined_funcs = undefined,
        .cfi = undefined,
        .debug_frame = .{},
        .debug_info = .{},
        .debug_line = .{},
        .debug_loclists = .{},
        .pending_types = .{},
    };
    defer wip_nav.deinit();

    const nav_gop = try dwarf.navs.getOrPut(dwarf.gpa, nav_index);
    errdefer _ = dwarf.navs.pop();
    switch (ip.indexToKey(nav_val.toIntern())) {
        .func => |func| {
            if (nav_gop.found_existing) {
                const unit_ptr = dwarf.debug_info.section.getUnit(wip_nav.unit);
                const entry_ptr = unit_ptr.getEntry(nav_gop.value_ptr.*);
                if (entry_ptr.len >= AbbrevCode.decl_bytes) {
                    var abbrev_code_buf: [AbbrevCode.decl_bytes]u8 = undefined;
                    if (try dwarf.getFile().?.preadAll(
                        &abbrev_code_buf,
                        dwarf.debug_info.section.off(dwarf) + unit_ptr.off + unit_ptr.header_len + entry_ptr.off,
                    ) != abbrev_code_buf.len) return error.InputOutput;
                    var abbrev_code_fbs = std.io.fixedBufferStream(&abbrev_code_buf);
                    const abbrev_code: AbbrevCode = @enumFromInt(
                        std.leb.readUleb128(@typeInfo(AbbrevCode).@"enum".tag_type, abbrev_code_fbs.reader()) catch unreachable,
                    );
                    switch (abbrev_code) {
                        else => unreachable,
                        .decl_func, .decl_empty_func => return,
                        .decl_func_generic, .decl_empty_func_generic => {},
                    }
                }
                entry_ptr.clear();
            } else nav_gop.value_ptr.* = try dwarf.addCommonEntry(wip_nav.unit);
            wip_nav.entry = nav_gop.value_ptr.*;

            const parent_type, const accessibility: u8 = if (nav.analysis_owner.unwrap()) |cau| parent: {
                const parent_namespace_ptr = ip.namespacePtr(ip.getCau(cau).namespace);
                break :parent .{
                    parent_namespace_ptr.owner_type,
                    if (parent_namespace_ptr.pub_decls.containsContext(nav_index, .{ .zcu = zcu }))
                        DW.ACCESS.public
                    else if (parent_namespace_ptr.priv_decls.containsContext(nav_index, .{ .zcu = zcu }))
                        DW.ACCESS.private
                    else
                        unreachable,
                };
            } else .{ zcu.fileRootType(inst_info.file), DW.ACCESS.private };

            const func_type = ip.indexToKey(func.ty).func_type;
            const diw = wip_nav.debug_info.writer(dwarf.gpa);
            try wip_nav.abbrevCode(if (func_type.param_types.len > 0 or func_type.is_var_args)
                .decl_func_generic
            else
                .decl_empty_func_generic);
            try wip_nav.refType(Type.fromInterned(parent_type));
            assert(wip_nav.debug_info.items.len == DebugInfo.declEntryLineOff(dwarf));
            try diw.writeInt(u32, @intCast(loc.line + 1), dwarf.endian);
            try uleb128(diw, loc.column + 1);
            try diw.writeByte(accessibility);
            try wip_nav.strp(nav.name.toSlice(ip));
            try wip_nav.refType(Type.fromInterned(func_type.return_type));
            if (func_type.param_types.len > 0 or func_type.is_var_args) {
                for (0..func_type.param_types.len) |param_index| {
                    try wip_nav.abbrevCode(.func_type_param);
                    try wip_nav.refType(Type.fromInterned(func_type.param_types.get(ip)[param_index]));
                }
                if (func_type.is_var_args) try wip_nav.abbrevCode(.is_var_args);
                try uleb128(diw, @intFromEnum(AbbrevCode.null));
            }
        },
        .struct_type => done: {
            const loaded_struct = ip.loadStructType(nav_val.toIntern());

            const parent_type, const accessibility: u8 = if (nav.analysis_owner.unwrap()) |cau| parent: {
                const parent_namespace_ptr = ip.namespacePtr(ip.getCau(cau).namespace);
                break :parent .{
                    parent_namespace_ptr.owner_type,
                    if (parent_namespace_ptr.pub_decls.containsContext(nav_index, .{ .zcu = zcu }))
                        DW.ACCESS.public
                    else if (parent_namespace_ptr.priv_decls.containsContext(nav_index, .{ .zcu = zcu }))
                        DW.ACCESS.private
                    else
                        unreachable,
                };
            } else .{ zcu.fileRootType(inst_info.file), DW.ACCESS.private };

            decl_struct: {
                if (loaded_struct.zir_index == .none) break :decl_struct;

                const type_inst_info = loaded_struct.zir_index.unwrap().?.resolveFull(ip).?;
                if (type_inst_info.file != inst_info.file) break :decl_struct;

                const value_inst = value_inst: {
                    const decl_value_body = decl_extra.data.getBodies(@intCast(decl_extra.end), file.zir).value_body;
                    const break_inst = file.zir.instructions.get(@intFromEnum(decl_value_body[decl_value_body.len - 1]));
                    if (break_inst.tag != .break_inline) break :value_inst null;
                    assert(file.zir.extraData(Zir.Inst.Break, break_inst.data.@"break".payload_index).data.block_inst == inst_info.inst);
                    var value_inst = break_inst.data.@"break".operand.toIndex();
                    while (value_inst) |value_inst_index| switch (file.zir.instructions.items(.tag)[@intFromEnum(value_inst_index)]) {
                        else => break,
                        .as_node => value_inst = file.zir.extraData(
                            Zir.Inst.As,
                            file.zir.instructions.items(.data)[@intFromEnum(value_inst_index)].pl_node.payload_index,
                        ).data.operand.toIndex(),
                    };
                    break :value_inst value_inst;
                };
                if (type_inst_info.inst != value_inst) break :decl_struct;

                const type_gop = try dwarf.types.getOrPut(dwarf.gpa, nav_val.toIntern());
                if (type_gop.found_existing) {
                    dwarf.debug_info.section.getUnit(wip_nav.unit).getEntry(type_gop.value_ptr.*).clear();
                    nav_gop.value_ptr.* = type_gop.value_ptr.*;
                } else {
                    if (nav_gop.found_existing)
                        dwarf.debug_info.section.getUnit(wip_nav.unit).getEntry(nav_gop.value_ptr.*).clear()
                    else
                        nav_gop.value_ptr.* = try dwarf.addCommonEntry(wip_nav.unit);
                    type_gop.value_ptr.* = nav_gop.value_ptr.*;
                }
                wip_nav.entry = nav_gop.value_ptr.*;

                const diw = wip_nav.debug_info.writer(dwarf.gpa);

                switch (loaded_struct.layout) {
                    .auto, .@"extern" => {
                        try wip_nav.abbrevCode(if (loaded_struct.field_types.len == 0) .decl_namespace_struct else .decl_struct);
                        try wip_nav.refType(Type.fromInterned(parent_type));
                        assert(wip_nav.debug_info.items.len == DebugInfo.declEntryLineOff(dwarf));
                        try diw.writeInt(u32, @intCast(loc.line + 1), dwarf.endian);
                        try uleb128(diw, loc.column + 1);
                        try diw.writeByte(accessibility);
                        try wip_nav.strp(nav.name.toSlice(ip));
                        if (loaded_struct.field_types.len == 0) try diw.writeByte(@intFromBool(false)) else {
                            try uleb128(diw, nav_val.toType().abiSize(zcu));
                            try uleb128(diw, nav_val.toType().abiAlignment(zcu).toByteUnits().?);
                            for (0..loaded_struct.field_types.len) |field_index| {
                                const is_comptime = loaded_struct.fieldIsComptime(ip, field_index);
                                try wip_nav.abbrevCode(if (is_comptime) .struct_field_comptime else .struct_field);
                                if (loaded_struct.fieldName(ip, field_index).unwrap()) |field_name| try wip_nav.strp(field_name.toSlice(ip)) else {
                                    const field_name = try std.fmt.allocPrint(dwarf.gpa, "{d}", .{field_index});
                                    defer dwarf.gpa.free(field_name);
                                    try wip_nav.strp(field_name);
                                }
                                const field_type = Type.fromInterned(loaded_struct.field_types.get(ip)[field_index]);
                                try wip_nav.refType(field_type);
                                if (!is_comptime) {
                                    try uleb128(diw, loaded_struct.offsets.get(ip)[field_index]);
                                    try uleb128(diw, loaded_struct.fieldAlign(ip, field_index).toByteUnits() orelse
                                        field_type.abiAlignment(zcu).toByteUnits().?);
                                }
                            }
                            try uleb128(diw, @intFromEnum(AbbrevCode.null));
                        }
                    },
                    .@"packed" => {
                        try wip_nav.abbrevCode(.decl_packed_struct);
                        try wip_nav.refType(Type.fromInterned(parent_type));
                        assert(wip_nav.debug_info.items.len == DebugInfo.declEntryLineOff(dwarf));
                        try diw.writeInt(u32, @intCast(loc.line + 1), dwarf.endian);
                        try uleb128(diw, loc.column + 1);
                        try diw.writeByte(accessibility);
                        try wip_nav.strp(nav.name.toSlice(ip));
                        try wip_nav.refType(Type.fromInterned(loaded_struct.backingIntTypeUnordered(ip)));
                        var field_bit_offset: u16 = 0;
                        for (0..loaded_struct.field_types.len) |field_index| {
                            try wip_nav.abbrevCode(.packed_struct_field);
                            try wip_nav.strp(loaded_struct.fieldName(ip, field_index).unwrap().?.toSlice(ip));
                            const field_type = Type.fromInterned(loaded_struct.field_types.get(ip)[field_index]);
                            try wip_nav.refType(field_type);
                            try uleb128(diw, field_bit_offset);
                            field_bit_offset += @intCast(field_type.bitSize(zcu));
                        }
                        try uleb128(diw, @intFromEnum(AbbrevCode.null));
                    },
                }
                break :done;
            }

            if (nav_gop.found_existing)
                dwarf.debug_info.section.getUnit(wip_nav.unit).getEntry(nav_gop.value_ptr.*).clear()
            else
                nav_gop.value_ptr.* = try dwarf.addCommonEntry(wip_nav.unit);
            wip_nav.entry = nav_gop.value_ptr.*;
            const diw = wip_nav.debug_info.writer(dwarf.gpa);
            try wip_nav.abbrevCode(.decl_alias);
            try wip_nav.refType(Type.fromInterned(parent_type));
            assert(wip_nav.debug_info.items.len == DebugInfo.declEntryLineOff(dwarf));
            try diw.writeInt(u32, @intCast(loc.line + 1), dwarf.endian);
            try uleb128(diw, loc.column + 1);
            try diw.writeByte(accessibility);
            try wip_nav.strp(nav.name.toSlice(ip));
            try wip_nav.refType(nav_val.toType());
        },
        .enum_type => done: {
            const loaded_enum = ip.loadEnumType(nav_val.toIntern());

            const parent_type, const accessibility: u8 = if (nav.analysis_owner.unwrap()) |cau| parent: {
                const parent_namespace_ptr = ip.namespacePtr(ip.getCau(cau).namespace);
                break :parent .{
                    parent_namespace_ptr.owner_type,
                    if (parent_namespace_ptr.pub_decls.containsContext(nav_index, .{ .zcu = zcu }))
                        DW.ACCESS.public
                    else if (parent_namespace_ptr.priv_decls.containsContext(nav_index, .{ .zcu = zcu }))
                        DW.ACCESS.private
                    else
                        unreachable,
                };
            } else .{ zcu.fileRootType(inst_info.file), DW.ACCESS.private };

            decl_enum: {
                if (loaded_enum.zir_index == .none) break :decl_enum;

                const type_inst_info = loaded_enum.zir_index.unwrap().?.resolveFull(ip).?;
                if (type_inst_info.file != inst_info.file) break :decl_enum;

                const value_inst = value_inst: {
                    const decl_value_body = decl_extra.data.getBodies(@intCast(decl_extra.end), file.zir).value_body;
                    const break_inst = file.zir.instructions.get(@intFromEnum(decl_value_body[decl_value_body.len - 1]));
                    if (break_inst.tag != .break_inline) break :value_inst null;
                    assert(file.zir.extraData(Zir.Inst.Break, break_inst.data.@"break".payload_index).data.block_inst == inst_info.inst);
                    var value_inst = break_inst.data.@"break".operand.toIndex();
                    while (value_inst) |value_inst_index| switch (file.zir.instructions.items(.tag)[@intFromEnum(value_inst_index)]) {
                        else => break,
                        .as_node => value_inst = file.zir.extraData(
                            Zir.Inst.As,
                            file.zir.instructions.items(.data)[@intFromEnum(value_inst_index)].pl_node.payload_index,
                        ).data.operand.toIndex(),
                    };
                    break :value_inst value_inst;
                };
                if (type_inst_info.inst != value_inst) break :decl_enum;

                const type_gop = try dwarf.types.getOrPut(dwarf.gpa, nav_val.toIntern());
                if (type_gop.found_existing) {
                    dwarf.debug_info.section.getUnit(wip_nav.unit).getEntry(type_gop.value_ptr.*).clear();
                    nav_gop.value_ptr.* = type_gop.value_ptr.*;
                } else {
                    if (nav_gop.found_existing)
                        dwarf.debug_info.section.getUnit(wip_nav.unit).getEntry(nav_gop.value_ptr.*).clear()
                    else
                        nav_gop.value_ptr.* = try dwarf.addCommonEntry(wip_nav.unit);
                    type_gop.value_ptr.* = nav_gop.value_ptr.*;
                }
                wip_nav.entry = nav_gop.value_ptr.*;
                const diw = wip_nav.debug_info.writer(dwarf.gpa);
                try wip_nav.abbrevCode(if (loaded_enum.names.len > 0) .decl_enum else .decl_empty_enum);
                try wip_nav.refType(Type.fromInterned(parent_type));
                assert(wip_nav.debug_info.items.len == DebugInfo.declEntryLineOff(dwarf));
                try diw.writeInt(u32, @intCast(loc.line + 1), dwarf.endian);
                try uleb128(diw, loc.column + 1);
                try diw.writeByte(accessibility);
                try wip_nav.strp(nav.name.toSlice(ip));
                try wip_nav.refType(Type.fromInterned(loaded_enum.tag_ty));
                for (0..loaded_enum.names.len) |field_index| {
                    try wip_nav.enumConstValue(loaded_enum, .{
                        .sdata = .signed_enum_field,
                        .udata = .unsigned_enum_field,
                        .block = .big_enum_field,
                    }, field_index);
                    try wip_nav.strp(loaded_enum.names.get(ip)[field_index].toSlice(ip));
                }
                if (loaded_enum.names.len > 0) try uleb128(diw, @intFromEnum(AbbrevCode.null));
                break :done;
            }

            if (nav_gop.found_existing)
                dwarf.debug_info.section.getUnit(wip_nav.unit).getEntry(nav_gop.value_ptr.*).clear()
            else
                nav_gop.value_ptr.* = try dwarf.addCommonEntry(wip_nav.unit);
            wip_nav.entry = nav_gop.value_ptr.*;
            const diw = wip_nav.debug_info.writer(dwarf.gpa);
            try wip_nav.abbrevCode(.decl_alias);
            try wip_nav.refType(Type.fromInterned(parent_type));
            assert(wip_nav.debug_info.items.len == DebugInfo.declEntryLineOff(dwarf));
            try diw.writeInt(u32, @intCast(loc.line + 1), dwarf.endian);
            try uleb128(diw, loc.column + 1);
            try diw.writeByte(accessibility);
            try wip_nav.strp(nav.name.toSlice(ip));
            try wip_nav.refType(nav_val.toType());
        },
        .union_type => done: {
            const loaded_union = ip.loadUnionType(nav_val.toIntern());

            const parent_type, const accessibility: u8 = if (nav.analysis_owner.unwrap()) |cau| parent: {
                const parent_namespace_ptr = ip.namespacePtr(ip.getCau(cau).namespace);
                break :parent .{
                    parent_namespace_ptr.owner_type,
                    if (parent_namespace_ptr.pub_decls.containsContext(nav_index, .{ .zcu = zcu }))
                        DW.ACCESS.public
                    else if (parent_namespace_ptr.priv_decls.containsContext(nav_index, .{ .zcu = zcu }))
                        DW.ACCESS.private
                    else
                        unreachable,
                };
            } else .{ zcu.fileRootType(inst_info.file), DW.ACCESS.private };

            decl_union: {
                const type_inst_info = loaded_union.zir_index.resolveFull(ip).?;
                if (type_inst_info.file != inst_info.file) break :decl_union;

                const value_inst = value_inst: {
                    const decl_value_body = decl_extra.data.getBodies(@intCast(decl_extra.end), file.zir).value_body;
                    const break_inst = file.zir.instructions.get(@intFromEnum(decl_value_body[decl_value_body.len - 1]));
                    if (break_inst.tag != .break_inline) break :value_inst null;
                    assert(file.zir.extraData(Zir.Inst.Break, break_inst.data.@"break".payload_index).data.block_inst == inst_info.inst);
                    var value_inst = break_inst.data.@"break".operand.toIndex();
                    while (value_inst) |value_inst_index| switch (file.zir.instructions.items(.tag)[@intFromEnum(value_inst_index)]) {
                        else => break,
                        .as_node => value_inst = file.zir.extraData(
                            Zir.Inst.As,
                            file.zir.instructions.items(.data)[@intFromEnum(value_inst_index)].pl_node.payload_index,
                        ).data.operand.toIndex(),
                    };
                    break :value_inst value_inst;
                };
                if (type_inst_info.inst != value_inst) break :decl_union;

                const type_gop = try dwarf.types.getOrPut(dwarf.gpa, nav_val.toIntern());
                if (type_gop.found_existing) {
                    dwarf.debug_info.section.getUnit(wip_nav.unit).getEntry(type_gop.value_ptr.*).clear();
                    nav_gop.value_ptr.* = type_gop.value_ptr.*;
                } else {
                    if (nav_gop.found_existing)
                        dwarf.debug_info.section.getUnit(wip_nav.unit).getEntry(nav_gop.value_ptr.*).clear()
                    else
                        nav_gop.value_ptr.* = try dwarf.addCommonEntry(wip_nav.unit);
                    type_gop.value_ptr.* = nav_gop.value_ptr.*;
                }
                wip_nav.entry = nav_gop.value_ptr.*;
                const diw = wip_nav.debug_info.writer(dwarf.gpa);
                try wip_nav.abbrevCode(.decl_union);
                try wip_nav.refType(Type.fromInterned(parent_type));
                assert(wip_nav.debug_info.items.len == DebugInfo.declEntryLineOff(dwarf));
                try diw.writeInt(u32, @intCast(loc.line + 1), dwarf.endian);
                try uleb128(diw, loc.column + 1);
                try diw.writeByte(accessibility);
                try wip_nav.strp(nav.name.toSlice(ip));
                const union_layout = Type.getUnionLayout(loaded_union, zcu);
                try uleb128(diw, union_layout.abi_size);
                try uleb128(diw, union_layout.abi_align.toByteUnits().?);
                const loaded_tag = loaded_union.loadTagType(ip);
                if (loaded_union.hasTag(ip)) {
                    try wip_nav.abbrevCode(.tagged_union);
                    try wip_nav.infoSectionOffset(
                        .debug_info,
                        wip_nav.unit,
                        wip_nav.entry,
                        @intCast(wip_nav.debug_info.items.len + dwarf.sectionOffsetBytes()),
                    );
                    {
                        try wip_nav.abbrevCode(.generated_field);
                        try wip_nav.strp("tag");
                        try wip_nav.refType(Type.fromInterned(loaded_union.enum_tag_ty));
                        try uleb128(diw, union_layout.tagOffset());

                        for (0..loaded_union.field_types.len) |field_index| {
                            try wip_nav.enumConstValue(loaded_tag, .{
                                .sdata = .signed_tagged_union_field,
                                .udata = .unsigned_tagged_union_field,
                                .block = .big_tagged_union_field,
                            }, field_index);
                            {
                                try wip_nav.abbrevCode(.struct_field);
                                try wip_nav.strp(loaded_tag.names.get(ip)[field_index].toSlice(ip));
                                const field_type = Type.fromInterned(loaded_union.field_types.get(ip)[field_index]);
                                try wip_nav.refType(field_type);
                                try uleb128(diw, union_layout.payloadOffset());
                                try uleb128(diw, loaded_union.fieldAlign(ip, field_index).toByteUnits() orelse
                                    if (field_type.isNoReturn(zcu)) 1 else field_type.abiAlignment(zcu).toByteUnits().?);
                            }
                            try uleb128(diw, @intFromEnum(AbbrevCode.null));
                        }
                    }
                    try uleb128(diw, @intFromEnum(AbbrevCode.null));
                } else for (0..loaded_union.field_types.len) |field_index| {
                    try wip_nav.abbrevCode(.untagged_union_field);
                    try wip_nav.strp(loaded_tag.names.get(ip)[field_index].toSlice(ip));
                    const field_type = Type.fromInterned(loaded_union.field_types.get(ip)[field_index]);
                    try wip_nav.refType(field_type);
                    try uleb128(diw, loaded_union.fieldAlign(ip, field_index).toByteUnits() orelse
                        field_type.abiAlignment(zcu).toByteUnits().?);
                }
                try uleb128(diw, @intFromEnum(AbbrevCode.null));
                break :done;
            }

            if (nav_gop.found_existing)
                dwarf.debug_info.section.getUnit(wip_nav.unit).getEntry(nav_gop.value_ptr.*).clear()
            else
                nav_gop.value_ptr.* = try dwarf.addCommonEntry(wip_nav.unit);
            wip_nav.entry = nav_gop.value_ptr.*;
            const diw = wip_nav.debug_info.writer(dwarf.gpa);
            try wip_nav.abbrevCode(.decl_alias);
            try wip_nav.refType(Type.fromInterned(parent_type));
            assert(wip_nav.debug_info.items.len == DebugInfo.declEntryLineOff(dwarf));
            try diw.writeInt(u32, @intCast(loc.line + 1), dwarf.endian);
            try uleb128(diw, loc.column + 1);
            try diw.writeByte(accessibility);
            try wip_nav.strp(nav.name.toSlice(ip));
            try wip_nav.refType(nav_val.toType());
        },
        .opaque_type => done: {
            const loaded_opaque = ip.loadOpaqueType(nav_val.toIntern());

            const parent_type, const accessibility: u8 = if (nav.analysis_owner.unwrap()) |cau| parent: {
                const parent_namespace_ptr = ip.namespacePtr(ip.getCau(cau).namespace);
                break :parent .{
                    parent_namespace_ptr.owner_type,
                    if (parent_namespace_ptr.pub_decls.containsContext(nav_index, .{ .zcu = zcu }))
                        DW.ACCESS.public
                    else if (parent_namespace_ptr.priv_decls.containsContext(nav_index, .{ .zcu = zcu }))
                        DW.ACCESS.private
                    else
                        unreachable,
                };
            } else .{ zcu.fileRootType(inst_info.file), DW.ACCESS.private };

            decl_opaque: {
                const type_inst_info = loaded_opaque.zir_index.resolveFull(ip).?;
                if (type_inst_info.file != inst_info.file) break :decl_opaque;

                const value_inst = value_inst: {
                    const decl_value_body = decl_extra.data.getBodies(@intCast(decl_extra.end), file.zir).value_body;
                    const break_inst = file.zir.instructions.get(@intFromEnum(decl_value_body[decl_value_body.len - 1]));
                    if (break_inst.tag != .break_inline) break :value_inst null;
                    assert(file.zir.extraData(Zir.Inst.Break, break_inst.data.@"break".payload_index).data.block_inst == inst_info.inst);
                    var value_inst = break_inst.data.@"break".operand.toIndex();
                    while (value_inst) |value_inst_index| switch (file.zir.instructions.items(.tag)[@intFromEnum(value_inst_index)]) {
                        else => break,
                        .as_node => value_inst = file.zir.extraData(
                            Zir.Inst.As,
                            file.zir.instructions.items(.data)[@intFromEnum(value_inst_index)].pl_node.payload_index,
                        ).data.operand.toIndex(),
                    };
                    break :value_inst value_inst;
                };
                if (type_inst_info.inst != value_inst) break :decl_opaque;

                const type_gop = try dwarf.types.getOrPut(dwarf.gpa, nav_val.toIntern());
                if (type_gop.found_existing) {
                    dwarf.debug_info.section.getUnit(wip_nav.unit).getEntry(type_gop.value_ptr.*).clear();
                    nav_gop.value_ptr.* = type_gop.value_ptr.*;
                } else {
                    if (nav_gop.found_existing)
                        dwarf.debug_info.section.getUnit(wip_nav.unit).getEntry(nav_gop.value_ptr.*).clear()
                    else
                        nav_gop.value_ptr.* = try dwarf.addCommonEntry(wip_nav.unit);
                    type_gop.value_ptr.* = nav_gop.value_ptr.*;
                }
                wip_nav.entry = nav_gop.value_ptr.*;
                const diw = wip_nav.debug_info.writer(dwarf.gpa);
                try wip_nav.abbrevCode(.decl_namespace_struct);
                try wip_nav.refType(Type.fromInterned(parent_type));
                assert(wip_nav.debug_info.items.len == DebugInfo.declEntryLineOff(dwarf));
                try diw.writeInt(u32, @intCast(loc.line + 1), dwarf.endian);
                try uleb128(diw, loc.column + 1);
                try diw.writeByte(accessibility);
                try wip_nav.strp(nav.name.toSlice(ip));
                try diw.writeByte(@intFromBool(false));
                break :done;
            }

            if (nav_gop.found_existing)
                dwarf.debug_info.section.getUnit(wip_nav.unit).getEntry(nav_gop.value_ptr.*).clear()
            else
                nav_gop.value_ptr.* = try dwarf.addCommonEntry(wip_nav.unit);
            wip_nav.entry = nav_gop.value_ptr.*;
            const diw = wip_nav.debug_info.writer(dwarf.gpa);
            try wip_nav.abbrevCode(.decl_alias);
            try wip_nav.refType(Type.fromInterned(parent_type));
            assert(wip_nav.debug_info.items.len == DebugInfo.declEntryLineOff(dwarf));
            try diw.writeInt(u32, @intCast(loc.line + 1), dwarf.endian);
            try uleb128(diw, loc.column + 1);
            try diw.writeByte(accessibility);
            try wip_nav.strp(nav.name.toSlice(ip));
            try wip_nav.refType(nav_val.toType());
        },
        else => {
            _ = dwarf.navs.pop();
            return;
        },
    }
    try dwarf.debug_info.section.replaceEntry(wip_nav.unit, wip_nav.entry, dwarf, wip_nav.debug_info.items);
    try wip_nav.flush();
}

fn updateType(
    dwarf: *Dwarf,
    pt: Zcu.PerThread,
    type_index: InternPool.Index,
    pending_types: *std.ArrayListUnmanaged(InternPool.Index),
) UpdateError!void {
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const ty = Type.fromInterned(type_index);
    switch (type_index) {
        .generic_poison_type => log.debug("updateType({s})", .{"anytype"}),
        else => log.debug("updateType({})", .{ty.fmt(pt)}),
    }

    var wip_nav: WipNav = .{
        .dwarf = dwarf,
        .pt = pt,
        .unit = .main,
        .entry = dwarf.types.get(type_index).?,
        .any_children = false,
        .func = .none,
        .func_sym_index = undefined,
        .func_high_reloc = undefined,
        .inlined_funcs = undefined,
        .cfi = undefined,
        .debug_frame = .{},
        .debug_info = .{},
        .debug_line = .{},
        .debug_loclists = .{},
        .pending_types = pending_types.*,
    };
    defer {
        pending_types.* = wip_nav.pending_types;
        wip_nav.pending_types = .{};
        wip_nav.deinit();
    }
    const diw = wip_nav.debug_info.writer(dwarf.gpa);
    const name = switch (type_index) {
        .generic_poison_type => "",
        else => try std.fmt.allocPrint(dwarf.gpa, "{}", .{ty.fmt(pt)}),
    };
    defer dwarf.gpa.free(name);

    switch (ip.indexToKey(type_index)) {
        .int_type => |int_type| {
            try wip_nav.abbrevCode(.numeric_type);
            try wip_nav.strp(name);
            try diw.writeByte(switch (int_type.signedness) {
                inline .signed, .unsigned => |signedness| @field(DW.ATE, @tagName(signedness)),
            });
            try uleb128(diw, int_type.bits);
            try uleb128(diw, ty.abiSize(zcu));
            try uleb128(diw, ty.abiAlignment(zcu).toByteUnits().?);
        },
        .ptr_type => |ptr_type| switch (ptr_type.flags.size) {
            .One, .Many, .C => {
                const ptr_child_type = Type.fromInterned(ptr_type.child);
                try wip_nav.abbrevCode(if (ptr_type.sentinel == .none) .ptr_type else .ptr_sentinel_type);
                try wip_nav.strp(name);
                if (ptr_type.sentinel != .none) {
                    const bytes = ptr_child_type.abiSize(zcu);
                    try uleb128(diw, bytes);
                    const mem = try wip_nav.debug_info.addManyAsSlice(dwarf.gpa, @intCast(bytes));
                    Value.fromInterned(ptr_type.sentinel).writeToMemory(pt, mem) catch |err| switch (err) {
                        error.IllDefinedMemoryLayout => @memset(mem, 0),
                        else => |e| return e,
                    };
                }
                try uleb128(diw, ptr_type.flags.alignment.toByteUnits() orelse
                    ptr_child_type.abiAlignment(zcu).toByteUnits().?);
                try diw.writeByte(@intFromEnum(ptr_type.flags.address_space));
                if (ptr_type.flags.is_const or ptr_type.flags.is_volatile) try wip_nav.infoSectionOffset(
                    .debug_info,
                    wip_nav.unit,
                    wip_nav.entry,
                    @intCast(wip_nav.debug_info.items.len + dwarf.sectionOffsetBytes()),
                ) else try wip_nav.refType(ptr_child_type);
                if (ptr_type.flags.is_const) {
                    try wip_nav.abbrevCode(.is_const);
                    if (ptr_type.flags.is_volatile) try wip_nav.infoSectionOffset(
                        .debug_info,
                        wip_nav.unit,
                        wip_nav.entry,
                        @intCast(wip_nav.debug_info.items.len + dwarf.sectionOffsetBytes()),
                    ) else try wip_nav.refType(ptr_child_type);
                }
                if (ptr_type.flags.is_volatile) {
                    try wip_nav.abbrevCode(.is_volatile);
                    try wip_nav.refType(ptr_child_type);
                }
            },
            .Slice => {
                try wip_nav.abbrevCode(.struct_type);
                try wip_nav.strp(name);
                try uleb128(diw, ty.abiSize(zcu));
                try uleb128(diw, ty.abiAlignment(zcu).toByteUnits().?);
                try wip_nav.abbrevCode(.generated_field);
                try wip_nav.strp("ptr");
                const ptr_field_type = ty.slicePtrFieldType(zcu);
                try wip_nav.refType(ptr_field_type);
                try uleb128(diw, 0);
                try wip_nav.abbrevCode(.generated_field);
                try wip_nav.strp("len");
                const len_field_type = Type.usize;
                try wip_nav.refType(len_field_type);
                try uleb128(diw, len_field_type.abiAlignment(zcu).forward(ptr_field_type.abiSize(zcu)));
                try uleb128(diw, @intFromEnum(AbbrevCode.null));
            },
        },
        .array_type => |array_type| {
            const array_child_type = Type.fromInterned(array_type.child);
            try wip_nav.abbrevCode(if (array_type.sentinel == .none) .array_type else .array_sentinel_type);
            try wip_nav.strp(name);
            if (array_type.sentinel != .none) {
                const bytes = array_child_type.abiSize(zcu);
                try uleb128(diw, bytes);
                const mem = try wip_nav.debug_info.addManyAsSlice(dwarf.gpa, @intCast(bytes));
                Value.fromInterned(array_type.sentinel).writeToMemory(pt, mem) catch |err| switch (err) {
                    error.IllDefinedMemoryLayout => @memset(mem, 0),
                    else => |e| return e,
                };
            }
            try wip_nav.refType(array_child_type);
            try wip_nav.abbrevCode(.array_index);
            try wip_nav.refType(Type.usize);
            try uleb128(diw, array_type.len);
            try uleb128(diw, @intFromEnum(AbbrevCode.null));
        },
        .vector_type => |vector_type| {
            try wip_nav.abbrevCode(.vector_type);
            try wip_nav.strp(name);
            try wip_nav.refType(Type.fromInterned(vector_type.child));
            try wip_nav.abbrevCode(.array_index);
            try wip_nav.refType(Type.usize);
            try uleb128(diw, vector_type.len);
            try uleb128(diw, @intFromEnum(AbbrevCode.null));
        },
        .opt_type => |opt_child_type_index| {
            const opt_child_type = Type.fromInterned(opt_child_type_index);
            try wip_nav.abbrevCode(.union_type);
            try wip_nav.strp(name);
            try uleb128(diw, ty.abiSize(zcu));
            try uleb128(diw, ty.abiAlignment(zcu).toByteUnits().?);
            if (opt_child_type.isNoReturn(zcu)) {
                try wip_nav.abbrevCode(.generated_field);
                try wip_nav.strp("null");
                try wip_nav.refType(Type.null);
                try uleb128(diw, 0);
            } else {
                try wip_nav.abbrevCode(.tagged_union);
                try wip_nav.infoSectionOffset(
                    .debug_info,
                    wip_nav.unit,
                    wip_nav.entry,
                    @intCast(wip_nav.debug_info.items.len + dwarf.sectionOffsetBytes()),
                );
                {
                    try wip_nav.abbrevCode(.generated_field);
                    try wip_nav.strp("has_value");
                    const repr: enum { unpacked, error_set, pointer } = switch (opt_child_type_index) {
                        .anyerror_type => .error_set,
                        else => switch (ip.indexToKey(opt_child_type_index)) {
                            else => .unpacked,
                            .error_set_type, .inferred_error_set_type => .error_set,
                            .ptr_type => |ptr_type| if (ptr_type.flags.is_allowzero) .unpacked else .pointer,
                        },
                    };
                    switch (repr) {
                        .unpacked => {
                            try wip_nav.refType(Type.bool);
                            try uleb128(diw, if (opt_child_type.hasRuntimeBits(zcu))
                                opt_child_type.abiSize(zcu)
                            else
                                0);
                        },
                        .error_set => {
                            try wip_nav.refType(Type.fromInterned(try pt.intern(.{ .int_type = .{
                                .signedness = .unsigned,
                                .bits = zcu.errorSetBits(),
                            } })));
                            try uleb128(diw, 0);
                        },
                        .pointer => {
                            try wip_nav.refType(Type.usize);
                            try uleb128(diw, 0);
                        },
                    }

                    try wip_nav.abbrevCode(.unsigned_tagged_union_field);
                    try uleb128(diw, 0);
                    {
                        try wip_nav.abbrevCode(.generated_field);
                        try wip_nav.strp("null");
                        try wip_nav.refType(Type.null);
                        try uleb128(diw, 0);
                    }
                    try uleb128(diw, @intFromEnum(AbbrevCode.null));

                    try wip_nav.abbrevCode(.tagged_union_default_field);
                    {
                        try wip_nav.abbrevCode(.generated_field);
                        try wip_nav.strp("?");
                        try wip_nav.refType(opt_child_type);
                        try uleb128(diw, 0);
                    }
                    try uleb128(diw, @intFromEnum(AbbrevCode.null));
                }
                try uleb128(diw, @intFromEnum(AbbrevCode.null));
            }
            try uleb128(diw, @intFromEnum(AbbrevCode.null));
        },
        .anyframe_type => unreachable,
        .error_union_type => |error_union_type| {
            const error_union_error_set_type = Type.fromInterned(error_union_type.error_set_type);
            const error_union_payload_type = Type.fromInterned(error_union_type.payload_type);
            const error_union_error_set_offset, const error_union_payload_offset = switch (error_union_type.payload_type) {
                .generic_poison_type => .{ 0, 0 },
                else => .{
                    codegen.errUnionErrorOffset(error_union_payload_type, zcu),
                    codegen.errUnionPayloadOffset(error_union_payload_type, zcu),
                },
            };

            try wip_nav.abbrevCode(.union_type);
            try wip_nav.strp(name);
            if (error_union_type.error_set_type != .generic_poison_type and
                error_union_type.payload_type != .generic_poison_type)
            {
                try uleb128(diw, ty.abiSize(zcu));
                try uleb128(diw, ty.abiAlignment(zcu).toByteUnits().?);
            } else {
                try uleb128(diw, 0);
                try uleb128(diw, 1);
            }
            {
                try wip_nav.abbrevCode(.tagged_union);
                try wip_nav.infoSectionOffset(
                    .debug_info,
                    wip_nav.unit,
                    wip_nav.entry,
                    @intCast(wip_nav.debug_info.items.len + dwarf.sectionOffsetBytes()),
                );
                {
                    try wip_nav.abbrevCode(.generated_field);
                    try wip_nav.strp("is_error");
                    try wip_nav.refType(Type.fromInterned(try pt.intern(.{ .int_type = .{
                        .signedness = .unsigned,
                        .bits = zcu.errorSetBits(),
                    } })));
                    try uleb128(diw, error_union_error_set_offset);

                    try wip_nav.abbrevCode(.unsigned_tagged_union_field);
                    try uleb128(diw, 0);
                    {
                        try wip_nav.abbrevCode(.generated_field);
                        try wip_nav.strp("value");
                        try wip_nav.refType(error_union_payload_type);
                        try uleb128(diw, error_union_payload_offset);
                    }
                    try uleb128(diw, @intFromEnum(AbbrevCode.null));

                    try wip_nav.abbrevCode(.tagged_union_default_field);
                    {
                        try wip_nav.abbrevCode(.generated_field);
                        try wip_nav.strp("error");
                        try wip_nav.refType(error_union_error_set_type);
                        try uleb128(diw, error_union_error_set_offset);
                    }
                    try uleb128(diw, @intFromEnum(AbbrevCode.null));
                }
                try uleb128(diw, @intFromEnum(AbbrevCode.null));
            }
            try uleb128(diw, @intFromEnum(AbbrevCode.null));
        },
        .simple_type => |simple_type| switch (simple_type) {
            .f16,
            .f32,
            .f64,
            .f80,
            .f128,
            .usize,
            .isize,
            .c_char,
            .c_short,
            .c_ushort,
            .c_int,
            .c_uint,
            .c_long,
            .c_ulong,
            .c_longlong,
            .c_ulonglong,
            .c_longdouble,
            .bool,
            => {
                try wip_nav.abbrevCode(.numeric_type);
                try wip_nav.strp(name);
                try diw.writeByte(if (type_index == .bool_type)
                    DW.ATE.boolean
                else if (ty.isRuntimeFloat())
                    DW.ATE.float
                else if (ty.isSignedInt(zcu))
                    DW.ATE.signed
                else if (ty.isUnsignedInt(zcu))
                    DW.ATE.unsigned
                else
                    unreachable);
                try uleb128(diw, ty.bitSize(zcu));
                try uleb128(diw, ty.abiSize(zcu));
                try uleb128(diw, ty.abiAlignment(zcu).toByteUnits().?);
            },
            .anyopaque,
            .void,
            .type,
            .comptime_int,
            .comptime_float,
            .noreturn,
            .null,
            .undefined,
            .enum_literal,
            .generic_poison,
            => {
                try wip_nav.abbrevCode(.void_type);
                try wip_nav.strp(if (type_index == .generic_poison_type) "anytype" else name);
            },
            .anyerror => return, // delay until flush
            .adhoc_inferred_error_set => unreachable,
        },
        .struct_type,
        .union_type,
        .opaque_type,
        => unreachable,
        .anon_struct_type => |anon_struct_type| if (anon_struct_type.types.len == 0) {
            try wip_nav.abbrevCode(.namespace_struct_type);
            try wip_nav.strp(name);
            try diw.writeByte(@intFromBool(false));
        } else {
            try wip_nav.abbrevCode(.struct_type);
            try wip_nav.strp(name);
            try uleb128(diw, ty.abiSize(zcu));
            try uleb128(diw, ty.abiAlignment(zcu).toByteUnits().?);
            var field_byte_offset: u64 = 0;
            for (0..anon_struct_type.types.len) |field_index| {
                const comptime_value = anon_struct_type.values.get(ip)[field_index];
                try wip_nav.abbrevCode(if (comptime_value != .none) .struct_field_comptime else .struct_field);
                if (anon_struct_type.fieldName(ip, field_index).unwrap()) |field_name| try wip_nav.strp(field_name.toSlice(ip)) else {
                    const field_name = try std.fmt.allocPrint(dwarf.gpa, "{d}", .{field_index});
                    defer dwarf.gpa.free(field_name);
                    try wip_nav.strp(field_name);
                }
                const field_type = Type.fromInterned(anon_struct_type.types.get(ip)[field_index]);
                try wip_nav.refType(field_type);
                if (comptime_value == .none) {
                    const field_align = field_type.abiAlignment(zcu);
                    field_byte_offset = field_align.forward(field_byte_offset);
                    try uleb128(diw, field_byte_offset);
                    try uleb128(diw, field_type.abiAlignment(zcu).toByteUnits().?);
                    field_byte_offset += field_type.abiSize(zcu);
                }
            }
            try uleb128(diw, @intFromEnum(AbbrevCode.null));
        },
        .enum_type => {
            const loaded_enum = ip.loadEnumType(type_index);
            try wip_nav.abbrevCode(if (loaded_enum.names.len > 0) .enum_type else .empty_enum_type);
            try wip_nav.strp(name);
            try wip_nav.refType(Type.fromInterned(loaded_enum.tag_ty));
            for (0..loaded_enum.names.len) |field_index| {
                try wip_nav.enumConstValue(loaded_enum, .{
                    .sdata = .signed_enum_field,
                    .udata = .unsigned_enum_field,
                    .block = .big_enum_field,
                }, field_index);
                try wip_nav.strp(loaded_enum.names.get(ip)[field_index].toSlice(ip));
            }
            if (loaded_enum.names.len > 0) try uleb128(diw, @intFromEnum(AbbrevCode.null));
        },
        .func_type => |func_type| {
            const is_nullary = func_type.param_types.len == 0 and !func_type.is_var_args;
            try wip_nav.abbrevCode(if (is_nullary) .nullary_func_type else .func_type);
            try wip_nav.strp(name);
            try diw.writeByte(@intFromEnum(@as(DW.CC, switch (func_type.cc) {
                .Unspecified, .C => .normal,
                .Naked, .Async, .Inline => .nocall,
                .Interrupt, .Signal => .nocall,
                .Stdcall => .BORLAND_stdcall,
                .Fastcall => .BORLAND_fastcall,
                .Vectorcall => .LLVM_vectorcall,
                .Thiscall => .BORLAND_thiscall,
                .APCS => .nocall,
                .AAPCS => .LLVM_AAPCS,
                .AAPCSVFP => .LLVM_AAPCS_VFP,
                .SysV => .LLVM_X86_64SysV,
                .Win64 => .LLVM_Win64,
                .Kernel, .Fragment, .Vertex => .nocall,
            })));
            try wip_nav.refType(Type.fromInterned(func_type.return_type));
            for (0..func_type.param_types.len) |param_index| {
                try wip_nav.abbrevCode(.func_type_param);
                try wip_nav.refType(Type.fromInterned(func_type.param_types.get(ip)[param_index]));
            }
            if (func_type.is_var_args) try wip_nav.abbrevCode(.is_var_args);
            if (!is_nullary) try uleb128(diw, @intFromEnum(AbbrevCode.null));
        },
        .error_set_type => |error_set_type| {
            try wip_nav.abbrevCode(if (error_set_type.names.len > 0) .enum_type else .empty_enum_type);
            try wip_nav.strp(name);
            try wip_nav.refType(Type.fromInterned(try pt.intern(.{ .int_type = .{
                .signedness = .unsigned,
                .bits = zcu.errorSetBits(),
            } })));
            for (0..error_set_type.names.len) |field_index| {
                const field_name = error_set_type.names.get(ip)[field_index];
                try wip_nav.abbrevCode(.unsigned_enum_field);
                try uleb128(diw, ip.getErrorValueIfExists(field_name).?);
                try wip_nav.strp(field_name.toSlice(ip));
            }
            if (error_set_type.names.len > 0) try uleb128(diw, @intFromEnum(AbbrevCode.null));
        },
        .inferred_error_set_type => |func| switch (ip.funcIesResolvedUnordered(func)) {
            .none => {
                try wip_nav.abbrevCode(.void_type);
                try wip_nav.strp(name);
            },
            else => |ies| {
                try wip_nav.abbrevCode(.inferred_error_set_type);
                try wip_nav.strp(name);
                try wip_nav.refType(Type.fromInterned(ies));
            },
        },

        // values, not types
        .undef,
        .simple_value,
        .variable,
        .@"extern",
        .func,
        .int,
        .err,
        .error_union,
        .enum_literal,
        .enum_tag,
        .empty_enum_value,
        .float,
        .ptr,
        .slice,
        .opt,
        .aggregate,
        .un,
        // memoization, not types
        .memoized_call,
        => unreachable,
    }
    try dwarf.debug_info.section.replaceEntry(wip_nav.unit, wip_nav.entry, dwarf, wip_nav.debug_info.items);
}

pub fn updateContainerType(dwarf: *Dwarf, pt: Zcu.PerThread, type_index: InternPool.Index) UpdateError!void {
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const ty = Type.fromInterned(type_index);
    log.debug("updateContainerType({}({d}))", .{ ty.fmt(pt), @intFromEnum(type_index) });

    const inst_info = ty.typeDeclInst(zcu).?.resolveFull(ip).?;
    const file = zcu.fileByIndex(inst_info.file);
    if (inst_info.inst == .main_struct_inst) {
        const unit = try dwarf.getUnit(file.mod);
        const type_gop = try dwarf.types.getOrPut(dwarf.gpa, type_index);
        if (!type_gop.found_existing) type_gop.value_ptr.* = try dwarf.addCommonEntry(unit);
        var wip_nav: WipNav = .{
            .dwarf = dwarf,
            .pt = pt,
            .unit = unit,
            .entry = type_gop.value_ptr.*,
            .any_children = false,
            .func = .none,
            .func_sym_index = undefined,
            .func_high_reloc = undefined,
            .inlined_funcs = undefined,
            .cfi = undefined,
            .debug_frame = .{},
            .debug_info = .{},
            .debug_line = .{},
            .debug_loclists = .{},
            .pending_types = .{},
        };
        defer wip_nav.deinit();

        const loaded_struct = ip.loadStructType(type_index);

        const diw = wip_nav.debug_info.writer(dwarf.gpa);
        try wip_nav.abbrevCode(if (loaded_struct.field_types.len == 0) .namespace_file else .file);
        const file_gop = try dwarf.getModInfo(unit).files.getOrPut(dwarf.gpa, inst_info.file);
        try uleb128(diw, file_gop.index);
        try wip_nav.strp(loaded_struct.name.toSlice(ip));
        if (loaded_struct.field_types.len > 0) {
            try uleb128(diw, ty.abiSize(zcu));
            try uleb128(diw, ty.abiAlignment(zcu).toByteUnits().?);
            for (0..loaded_struct.field_types.len) |field_index| {
                const is_comptime = loaded_struct.fieldIsComptime(ip, field_index);
                try wip_nav.abbrevCode(if (is_comptime) .struct_field_comptime else .struct_field);
                if (loaded_struct.fieldName(ip, field_index).unwrap()) |field_name| try wip_nav.strp(field_name.toSlice(ip)) else {
                    const field_name = try std.fmt.allocPrint(dwarf.gpa, "{d}", .{field_index});
                    defer dwarf.gpa.free(field_name);
                    try wip_nav.strp(field_name);
                }
                const field_type = Type.fromInterned(loaded_struct.field_types.get(ip)[field_index]);
                try wip_nav.refType(field_type);
                if (!is_comptime) {
                    try uleb128(diw, loaded_struct.offsets.get(ip)[field_index]);
                    try uleb128(diw, loaded_struct.fieldAlign(ip, field_index).toByteUnits() orelse
                        field_type.abiAlignment(zcu).toByteUnits().?);
                }
            }
            try uleb128(diw, @intFromEnum(AbbrevCode.null));
        }

        try dwarf.debug_info.section.replaceEntry(wip_nav.unit, wip_nav.entry, dwarf, wip_nav.debug_info.items);
        try wip_nav.flush();
    } else {
        const decl_inst = file.zir.instructions.get(@intFromEnum(inst_info.inst));
        assert(decl_inst.tag == .extended);
        if (switch (decl_inst.data.extended.opcode) {
            .struct_decl => @as(Zir.Inst.StructDecl.Small, @bitCast(decl_inst.data.extended.small)).name_strategy,
            .enum_decl => @as(Zir.Inst.EnumDecl.Small, @bitCast(decl_inst.data.extended.small)).name_strategy,
            .union_decl => @as(Zir.Inst.UnionDecl.Small, @bitCast(decl_inst.data.extended.small)).name_strategy,
            .opaque_decl => @as(Zir.Inst.OpaqueDecl.Small, @bitCast(decl_inst.data.extended.small)).name_strategy,
            .reify => @as(Zir.Inst.NameStrategy, @enumFromInt(decl_inst.data.extended.small)),
            else => unreachable,
        } == .parent) return;

        const unit = try dwarf.getUnit(file.mod);
        const type_gop = try dwarf.types.getOrPut(dwarf.gpa, type_index);
        if (!type_gop.found_existing) type_gop.value_ptr.* = try dwarf.addCommonEntry(unit);
        var wip_nav: WipNav = .{
            .dwarf = dwarf,
            .pt = pt,
            .unit = unit,
            .entry = type_gop.value_ptr.*,
            .any_children = false,
            .func = .none,
            .func_sym_index = undefined,
            .func_high_reloc = undefined,
            .inlined_funcs = undefined,
            .cfi = undefined,
            .debug_frame = .{},
            .debug_info = .{},
            .debug_line = .{},
            .debug_loclists = .{},
            .pending_types = .{},
        };
        defer wip_nav.deinit();
        const diw = wip_nav.debug_info.writer(dwarf.gpa);
        const name = try std.fmt.allocPrint(dwarf.gpa, "{}", .{ty.fmt(pt)});
        defer dwarf.gpa.free(name);

        switch (ip.indexToKey(type_index)) {
            .struct_type => {
                const loaded_struct = ip.loadStructType(type_index);
                switch (loaded_struct.layout) {
                    .auto, .@"extern" => {
                        try wip_nav.abbrevCode(if (loaded_struct.field_types.len == 0) .namespace_struct_type else .struct_type);
                        try wip_nav.strp(name);
                        if (loaded_struct.field_types.len == 0) try diw.writeByte(@intFromBool(false)) else {
                            try uleb128(diw, ty.abiSize(zcu));
                            try uleb128(diw, ty.abiAlignment(zcu).toByteUnits().?);
                            for (0..loaded_struct.field_types.len) |field_index| {
                                const is_comptime = loaded_struct.fieldIsComptime(ip, field_index);
                                try wip_nav.abbrevCode(if (is_comptime) .struct_field_comptime else .struct_field);
                                if (loaded_struct.fieldName(ip, field_index).unwrap()) |field_name| try wip_nav.strp(field_name.toSlice(ip)) else {
                                    const field_name = try std.fmt.allocPrint(dwarf.gpa, "{d}", .{field_index});
                                    defer dwarf.gpa.free(field_name);
                                    try wip_nav.strp(field_name);
                                }
                                const field_type = Type.fromInterned(loaded_struct.field_types.get(ip)[field_index]);
                                try wip_nav.refType(field_type);
                                if (!is_comptime) {
                                    try uleb128(diw, loaded_struct.offsets.get(ip)[field_index]);
                                    try uleb128(diw, loaded_struct.fieldAlign(ip, field_index).toByteUnits() orelse
                                        field_type.abiAlignment(zcu).toByteUnits().?);
                                }
                            }
                            try uleb128(diw, @intFromEnum(AbbrevCode.null));
                        }
                    },
                    .@"packed" => {
                        try wip_nav.abbrevCode(if (loaded_struct.field_types.len > 0) .packed_struct_type else .empty_packed_struct_type);
                        try wip_nav.strp(name);
                        try wip_nav.refType(Type.fromInterned(loaded_struct.backingIntTypeUnordered(ip)));
                        var field_bit_offset: u16 = 0;
                        for (0..loaded_struct.field_types.len) |field_index| {
                            try wip_nav.abbrevCode(.packed_struct_field);
                            try wip_nav.strp(loaded_struct.fieldName(ip, field_index).unwrap().?.toSlice(ip));
                            const field_type = Type.fromInterned(loaded_struct.field_types.get(ip)[field_index]);
                            try wip_nav.refType(field_type);
                            try uleb128(diw, field_bit_offset);
                            field_bit_offset += @intCast(field_type.bitSize(zcu));
                        }
                        if (loaded_struct.field_types.len > 0) try uleb128(diw, @intFromEnum(AbbrevCode.null));
                    },
                }
            },
            .enum_type => {
                const loaded_enum = ip.loadEnumType(type_index);
                try wip_nav.abbrevCode(if (loaded_enum.names.len > 0) .enum_type else .empty_enum_type);
                try wip_nav.strp(name);
                try wip_nav.refType(Type.fromInterned(loaded_enum.tag_ty));
                for (0..loaded_enum.names.len) |field_index| {
                    try wip_nav.enumConstValue(loaded_enum, .{
                        .sdata = .signed_enum_field,
                        .udata = .unsigned_enum_field,
                        .block = .big_enum_field,
                    }, field_index);
                    try wip_nav.strp(loaded_enum.names.get(ip)[field_index].toSlice(ip));
                }
                if (loaded_enum.names.len > 0) try uleb128(diw, @intFromEnum(AbbrevCode.null));
            },
            .union_type => {
                const loaded_union = ip.loadUnionType(type_index);
                try wip_nav.abbrevCode(if (loaded_union.field_types.len > 0) .union_type else .empty_union_type);
                try wip_nav.strp(name);
                const union_layout = Type.getUnionLayout(loaded_union, zcu);
                try uleb128(diw, union_layout.abi_size);
                try uleb128(diw, union_layout.abi_align.toByteUnits().?);
                const loaded_tag = loaded_union.loadTagType(ip);
                if (loaded_union.hasTag(ip)) {
                    try wip_nav.abbrevCode(.tagged_union);
                    try wip_nav.infoSectionOffset(
                        .debug_info,
                        wip_nav.unit,
                        wip_nav.entry,
                        @intCast(wip_nav.debug_info.items.len + dwarf.sectionOffsetBytes()),
                    );
                    {
                        try wip_nav.abbrevCode(.generated_field);
                        try wip_nav.strp("tag");
                        try wip_nav.refType(Type.fromInterned(loaded_union.enum_tag_ty));
                        try uleb128(diw, union_layout.tagOffset());

                        for (0..loaded_union.field_types.len) |field_index| {
                            try wip_nav.enumConstValue(loaded_tag, .{
                                .sdata = .signed_tagged_union_field,
                                .udata = .unsigned_tagged_union_field,
                                .block = .big_tagged_union_field,
                            }, field_index);
                            {
                                try wip_nav.abbrevCode(.struct_field);
                                try wip_nav.strp(loaded_tag.names.get(ip)[field_index].toSlice(ip));
                                const field_type = Type.fromInterned(loaded_union.field_types.get(ip)[field_index]);
                                try wip_nav.refType(field_type);
                                try uleb128(diw, union_layout.payloadOffset());
                                try uleb128(diw, loaded_union.fieldAlign(ip, field_index).toByteUnits() orelse
                                    if (field_type.isNoReturn(zcu)) 1 else field_type.abiAlignment(zcu).toByteUnits().?);
                            }
                            try uleb128(diw, @intFromEnum(AbbrevCode.null));
                        }
                    }
                    try uleb128(diw, @intFromEnum(AbbrevCode.null));
                } else for (0..loaded_union.field_types.len) |field_index| {
                    try wip_nav.abbrevCode(.untagged_union_field);
                    try wip_nav.strp(loaded_tag.names.get(ip)[field_index].toSlice(ip));
                    const field_type = Type.fromInterned(loaded_union.field_types.get(ip)[field_index]);
                    try wip_nav.refType(field_type);
                    try uleb128(diw, loaded_union.fieldAlign(ip, field_index).toByteUnits() orelse
                        field_type.abiAlignment(zcu).toByteUnits().?);
                }
                if (loaded_union.field_types.len > 0) try uleb128(diw, @intFromEnum(AbbrevCode.null));
            },
            .opaque_type => {
                try wip_nav.abbrevCode(.namespace_struct_type);
                try wip_nav.strp(name);
                try diw.writeByte(@intFromBool(true));
            },
            else => unreachable,
        }
        try dwarf.debug_info.section.replaceEntry(wip_nav.unit, wip_nav.entry, dwarf, wip_nav.debug_info.items);
        try dwarf.debug_loclists.section.replaceEntry(wip_nav.unit, wip_nav.entry, dwarf, wip_nav.debug_loclists.items);
        try wip_nav.flush();
    }
}

pub fn updateNavLineNumber(dwarf: *Dwarf, zcu: *Zcu, nav_index: InternPool.Nav.Index) UpdateError!void {
    const ip = &zcu.intern_pool;

    const zir_index = ip.getCau(ip.getNav(nav_index).analysis_owner.unwrap() orelse return).zir_index;
    const inst_info = zir_index.resolveFull(ip).?;
    assert(inst_info.inst != .main_struct_inst);
    const file = zcu.fileByIndex(inst_info.file);

    const inst = file.zir.instructions.get(@intFromEnum(inst_info.inst));
    assert(inst.tag == .declaration);
    const line = file.zir.extraData(Zir.Inst.Declaration, inst.data.declaration.payload_index).data.src_line;
    var line_buf: [4]u8 = undefined;
    std.mem.writeInt(u32, &line_buf, line, dwarf.endian);

    const unit = dwarf.debug_line.section.getUnit(dwarf.mods.get(file.mod).?);
    const entry = unit.getEntry(dwarf.navs.get(nav_index).?);
    try dwarf.getFile().?.pwriteAll(&line, dwarf.debug_line.section.off + unit.off + unit.header_len + entry.off + DebugInfo.declEntryLineOff(dwarf));
}

pub fn freeNav(dwarf: *Dwarf, nav_index: InternPool.Nav.Index) void {
    _ = dwarf;
    _ = nav_index;
}

fn refAbbrevCode(dwarf: *Dwarf, abbrev_code: AbbrevCode) UpdateError!@typeInfo(AbbrevCode).@"enum".tag_type {
    assert(abbrev_code != .null);
    const entry: Entry.Index = @enumFromInt(@intFromEnum(abbrev_code));
    if (dwarf.debug_abbrev.section.getUnit(DebugAbbrev.unit).getEntry(entry).len > 0) return @intFromEnum(abbrev_code);
    var debug_abbrev = std.ArrayList(u8).init(dwarf.gpa);
    defer debug_abbrev.deinit();
    const daw = debug_abbrev.writer();
    const abbrev = AbbrevCode.abbrevs.get(abbrev_code);
    try uleb128(daw, @intFromEnum(abbrev_code));
    try uleb128(daw, @intFromEnum(abbrev.tag));
    try daw.writeByte(if (abbrev.children) DW.CHILDREN.yes else DW.CHILDREN.no);
    for (abbrev.attrs) |*attr| inline for (attr) |info| try uleb128(daw, @intFromEnum(info));
    for (0..2) |_| try uleb128(daw, 0);
    try dwarf.debug_abbrev.section.replaceEntry(DebugAbbrev.unit, entry, dwarf, debug_abbrev.items);
    return @intFromEnum(abbrev_code);
}

pub fn flushModule(dwarf: *Dwarf, pt: Zcu.PerThread) FlushError!void {
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    if (dwarf.types.get(.anyerror_type)) |entry| {
        var wip_nav: WipNav = .{
            .dwarf = dwarf,
            .pt = pt,
            .unit = .main,
            .entry = entry,
            .any_children = false,
            .func = .none,
            .func_sym_index = undefined,
            .func_high_reloc = undefined,
            .inlined_funcs = undefined,
            .cfi = undefined,
            .debug_frame = .{},
            .debug_info = .{},
            .debug_line = .{},
            .debug_loclists = .{},
            .pending_types = .{},
        };
        defer wip_nav.deinit();
        const diw = wip_nav.debug_info.writer(dwarf.gpa);
        const global_error_set_names = ip.global_error_set.getNamesFromMainThread();
        try wip_nav.abbrevCode(if (global_error_set_names.len > 0) .enum_type else .empty_enum_type);
        try wip_nav.strp("anyerror");
        try wip_nav.refType(Type.fromInterned(try pt.intern(.{ .int_type = .{
            .signedness = .unsigned,
            .bits = zcu.errorSetBits(),
        } })));
        for (global_error_set_names, 1..) |name, value| {
            try wip_nav.abbrevCode(.unsigned_enum_field);
            try uleb128(diw, value);
            try wip_nav.strp(name.toSlice(ip));
        }
        if (global_error_set_names.len > 0) try uleb128(diw, @intFromEnum(AbbrevCode.null));
        try dwarf.debug_info.section.replaceEntry(wip_nav.unit, wip_nav.entry, dwarf, wip_nav.debug_info.items);
    }

    {
        const cwd = try std.process.getCwdAlloc(dwarf.gpa);
        defer dwarf.gpa.free(cwd);
        for (dwarf.mods.keys(), dwarf.mods.values()) |mod, *mod_info| {
            const root_dir_path = try std.fs.path.resolve(dwarf.gpa, &.{
                cwd,
                mod.root.root_dir.path orelse "",
                mod.root.sub_path,
            });
            defer dwarf.gpa.free(root_dir_path);
            mod_info.root_dir_path = try dwarf.debug_line_str.addString(dwarf, root_dir_path);
        }
    }

    var header = std.ArrayList(u8).init(dwarf.gpa);
    defer header.deinit();
    if (dwarf.debug_aranges.section.dirty) {
        for (dwarf.debug_aranges.section.units.items, 0..) |*unit_ptr, unit_index| {
            const unit: Unit.Index = @enumFromInt(unit_index);
            unit_ptr.clear();
            try unit_ptr.cross_section_relocs.ensureTotalCapacity(dwarf.gpa, 1);
            header.clearRetainingCapacity();
            try header.ensureTotalCapacity(unit_ptr.header_len);
            const unit_len = (if (unit_ptr.next.unwrap()) |next_unit|
                dwarf.debug_aranges.section.getUnit(next_unit).off
            else
                dwarf.debug_aranges.section.len) - unit_ptr.off - dwarf.unitLengthBytes();
            switch (dwarf.format) {
                .@"32" => std.mem.writeInt(u32, header.addManyAsArrayAssumeCapacity(4), @intCast(unit_len), dwarf.endian),
                .@"64" => {
                    std.mem.writeInt(u32, header.addManyAsArrayAssumeCapacity(4), std.math.maxInt(u32), dwarf.endian);
                    std.mem.writeInt(u64, header.addManyAsArrayAssumeCapacity(8), unit_len, dwarf.endian);
                },
            }
            std.mem.writeInt(u16, header.addManyAsArrayAssumeCapacity(2), 2, dwarf.endian);
            unit_ptr.cross_section_relocs.appendAssumeCapacity(.{
                .source_off = @intCast(header.items.len),
                .target_sec = .debug_info,
                .target_unit = unit,
            });
            header.appendNTimesAssumeCapacity(0, dwarf.sectionOffsetBytes());
            header.appendSliceAssumeCapacity(&.{ @intFromEnum(dwarf.address_size), 0 });
            header.appendNTimesAssumeCapacity(0, unit_ptr.header_len - header.items.len);
            try unit_ptr.replaceHeader(&dwarf.debug_aranges.section, dwarf, header.items);
            try unit_ptr.writeTrailer(&dwarf.debug_aranges.section, dwarf);
        }
        dwarf.debug_aranges.section.dirty = false;
    }
    if (dwarf.debug_frame.section.dirty) {
        const target = dwarf.bin_file.comp.root_mod.resolved_target.result;
        switch (dwarf.debug_frame.header.format) {
            .none => {},
            .debug_frame => unreachable,
            .eh_frame => switch (target.cpu.arch) {
                .x86_64 => {
                    dev.check(.x86_64_backend);
                    const Register = @import("../arch/x86_64/bits.zig").Register;
                    for (dwarf.debug_frame.section.units.items) |*unit| {
                        header.clearRetainingCapacity();
                        try header.ensureTotalCapacity(unit.header_len);
                        const unit_len = unit.header_len - dwarf.unitLengthBytes();
                        switch (dwarf.format) {
                            .@"32" => std.mem.writeInt(u32, header.addManyAsArrayAssumeCapacity(4), @intCast(unit_len), dwarf.endian),
                            .@"64" => {
                                std.mem.writeInt(u32, header.addManyAsArrayAssumeCapacity(4), std.math.maxInt(u32), dwarf.endian);
                                std.mem.writeInt(u64, header.addManyAsArrayAssumeCapacity(8), unit_len, dwarf.endian);
                            },
                        }
                        header.appendNTimesAssumeCapacity(0, 4);
                        header.appendAssumeCapacity(1);
                        header.appendSliceAssumeCapacity("zR\x00");
                        uleb128(header.fixedWriter(), dwarf.debug_frame.header.code_alignment_factor) catch unreachable;
                        sleb128(header.fixedWriter(), dwarf.debug_frame.header.data_alignment_factor) catch unreachable;
                        uleb128(header.fixedWriter(), dwarf.debug_frame.header.return_address_register) catch unreachable;
                        uleb128(header.fixedWriter(), 1) catch unreachable;
                        header.appendAssumeCapacity(DW.EH.PE.pcrel | DW.EH.PE.sdata4);
                        header.appendAssumeCapacity(DW.CFA.def_cfa_sf);
                        uleb128(header.fixedWriter(), Register.rsp.dwarfNum()) catch unreachable;
                        sleb128(header.fixedWriter(), -1) catch unreachable;
                        header.appendAssumeCapacity(@as(u8, DW.CFA.offset) + Register.rip.dwarfNum());
                        uleb128(header.fixedWriter(), 1) catch unreachable;
                        header.appendNTimesAssumeCapacity(DW.CFA.nop, unit.header_len - header.items.len);
                        try unit.replaceHeader(&dwarf.debug_frame.section, dwarf, header.items);
                        try unit.writeTrailer(&dwarf.debug_frame.section, dwarf);
                    }
                },
                else => unreachable,
            },
        }
        dwarf.debug_frame.section.dirty = false;
    }
    if (dwarf.debug_info.section.dirty) {
        for (dwarf.mods.keys(), dwarf.mods.values(), dwarf.debug_info.section.units.items, 0..) |mod, mod_info, *unit_ptr, unit_index| {
            const unit: Unit.Index = @enumFromInt(unit_index);
            unit_ptr.clear();
            try unit_ptr.cross_unit_relocs.ensureTotalCapacity(dwarf.gpa, 1);
            try unit_ptr.cross_section_relocs.ensureTotalCapacity(dwarf.gpa, 7);
            header.clearRetainingCapacity();
            try header.ensureTotalCapacity(unit_ptr.header_len);
            const unit_len = (if (unit_ptr.next.unwrap()) |next_unit|
                dwarf.debug_info.section.getUnit(next_unit).off
            else
                dwarf.debug_info.section.len) - unit_ptr.off - dwarf.unitLengthBytes();
            switch (dwarf.format) {
                .@"32" => std.mem.writeInt(u32, header.addManyAsArrayAssumeCapacity(4), @intCast(unit_len), dwarf.endian),
                .@"64" => {
                    std.mem.writeInt(u32, header.addManyAsArrayAssumeCapacity(4), std.math.maxInt(u32), dwarf.endian);
                    std.mem.writeInt(u64, header.addManyAsArrayAssumeCapacity(8), unit_len, dwarf.endian);
                },
            }
            std.mem.writeInt(u16, header.addManyAsArrayAssumeCapacity(2), 5, dwarf.endian);
            header.appendSliceAssumeCapacity(&.{ DW.UT.compile, @intFromEnum(dwarf.address_size) });
            unit_ptr.cross_section_relocs.appendAssumeCapacity(.{
                .source_off = @intCast(header.items.len),
                .target_sec = .debug_abbrev,
                .target_unit = DebugAbbrev.unit,
            });
            header.appendNTimesAssumeCapacity(0, dwarf.sectionOffsetBytes());
            const compile_unit_off: u32 = @intCast(header.items.len);
            uleb128(header.fixedWriter(), try dwarf.refAbbrevCode(.compile_unit)) catch unreachable;
            header.appendAssumeCapacity(DW.LANG.Zig);
            unit_ptr.cross_section_relocs.appendAssumeCapacity(.{
                .source_off = @intCast(header.items.len),
                .target_sec = .debug_line_str,
                .target_unit = StringSection.unit,
                .target_entry = (try dwarf.debug_line_str.addString(dwarf, "zig " ++ @import("build_options").version)).toOptional(),
            });
            header.appendNTimesAssumeCapacity(0, dwarf.sectionOffsetBytes());
            unit_ptr.cross_section_relocs.appendAssumeCapacity(.{
                .source_off = @intCast(header.items.len),
                .target_sec = .debug_line_str,
                .target_unit = StringSection.unit,
                .target_entry = mod_info.root_dir_path.toOptional(),
            });
            header.appendNTimesAssumeCapacity(0, dwarf.sectionOffsetBytes());
            unit_ptr.cross_section_relocs.appendAssumeCapacity(.{
                .source_off = @intCast(header.items.len),
                .target_sec = .debug_line_str,
                .target_unit = StringSection.unit,
                .target_entry = (try dwarf.debug_line_str.addString(dwarf, mod.root_src_path)).toOptional(),
            });
            header.appendNTimesAssumeCapacity(0, dwarf.sectionOffsetBytes());
            unit_ptr.cross_unit_relocs.appendAssumeCapacity(.{
                .source_off = @intCast(header.items.len),
                .target_unit = .main,
                .target_off = compile_unit_off,
            });
            header.appendNTimesAssumeCapacity(0, dwarf.sectionOffsetBytes());
            unit_ptr.cross_section_relocs.appendAssumeCapacity(.{
                .source_off = @intCast(header.items.len),
                .target_sec = .debug_line,
                .target_unit = unit,
            });
            header.appendNTimesAssumeCapacity(0, dwarf.sectionOffsetBytes());
            unit_ptr.cross_section_relocs.appendAssumeCapacity(.{
                .source_off = @intCast(header.items.len),
                .target_sec = .debug_rnglists,
                .target_unit = unit,
                .target_off = DebugRngLists.baseOffset(dwarf),
            });
            header.appendNTimesAssumeCapacity(0, dwarf.sectionOffsetBytes());
            uleb128(header.fixedWriter(), 0) catch unreachable;
            uleb128(header.fixedWriter(), try dwarf.refAbbrevCode(.module)) catch unreachable;
            unit_ptr.cross_section_relocs.appendAssumeCapacity(.{
                .source_off = @intCast(header.items.len),
                .target_sec = .debug_str,
                .target_unit = StringSection.unit,
                .target_entry = (try dwarf.debug_str.addString(dwarf, mod.fully_qualified_name)).toOptional(),
            });
            header.appendNTimesAssumeCapacity(0, dwarf.sectionOffsetBytes());
            uleb128(header.fixedWriter(), 0) catch unreachable;
            try unit_ptr.replaceHeader(&dwarf.debug_info.section, dwarf, header.items);
            try unit_ptr.writeTrailer(&dwarf.debug_info.section, dwarf);
        }
        dwarf.debug_info.section.dirty = false;
    }
    if (dwarf.debug_abbrev.section.dirty) {
        assert(!dwarf.debug_info.section.dirty);
        try dwarf.debug_abbrev.section.getUnit(DebugAbbrev.unit).writeTrailer(&dwarf.debug_abbrev.section, dwarf);
        dwarf.debug_abbrev.section.dirty = false;
    }
    if (dwarf.debug_str.section.dirty) {
        const contents = dwarf.debug_str.contents.items;
        try dwarf.debug_str.section.resize(dwarf, contents.len);
        try dwarf.getFile().?.pwriteAll(contents, dwarf.debug_str.section.off(dwarf));
        dwarf.debug_str.section.dirty = false;
    }
    if (dwarf.debug_line.section.dirty) {
        for (dwarf.mods.values(), dwarf.debug_line.section.units.items) |mod_info, *unit| try unit.resizeHeader(
            &dwarf.debug_line.section,
            dwarf,
            DebugLine.headerBytes(dwarf, @intCast(mod_info.dirs.count()), @intCast(mod_info.files.count())),
        );
        for (dwarf.mods.values(), dwarf.debug_line.section.units.items) |mod_info, *unit| {
            unit.clear();
            try unit.cross_section_relocs.ensureTotalCapacity(dwarf.gpa, 2 * (1 + mod_info.files.count()));
            header.clearRetainingCapacity();
            try header.ensureTotalCapacity(unit.header_len);
            const unit_len = (if (unit.next.unwrap()) |next_unit|
                dwarf.debug_line.section.getUnit(next_unit).off
            else
                dwarf.debug_line.section.len) - unit.off - dwarf.unitLengthBytes();
            switch (dwarf.format) {
                .@"32" => std.mem.writeInt(u32, header.addManyAsArrayAssumeCapacity(4), @intCast(unit_len), dwarf.endian),
                .@"64" => {
                    std.mem.writeInt(u32, header.addManyAsArrayAssumeCapacity(4), std.math.maxInt(u32), dwarf.endian);
                    std.mem.writeInt(u64, header.addManyAsArrayAssumeCapacity(8), unit_len, dwarf.endian);
                },
            }
            std.mem.writeInt(u16, header.addManyAsArrayAssumeCapacity(2), 5, dwarf.endian);
            header.appendSliceAssumeCapacity(&.{ @intFromEnum(dwarf.address_size), 0 });
            dwarf.writeInt(header.addManyAsSliceAssumeCapacity(dwarf.sectionOffsetBytes()), unit.header_len - header.items.len);
            const StandardOpcode = DeclValEnum(DW.LNS);
            header.appendSliceAssumeCapacity(&[_]u8{
                dwarf.debug_line.header.minimum_instruction_length,
                dwarf.debug_line.header.maximum_operations_per_instruction,
                @intFromBool(dwarf.debug_line.header.default_is_stmt),
                @bitCast(dwarf.debug_line.header.line_base),
                dwarf.debug_line.header.line_range,
                dwarf.debug_line.header.opcode_base,
            });
            header.appendSliceAssumeCapacity(std.enums.EnumArray(StandardOpcode, u8).init(.{
                .extended_op = undefined,
                .copy = 0,
                .advance_pc = 1,
                .advance_line = 1,
                .set_file = 1,
                .set_column = 1,
                .negate_stmt = 0,
                .set_basic_block = 0,
                .const_add_pc = 0,
                .fixed_advance_pc = 1,
                .set_prologue_end = 0,
                .set_epilogue_begin = 0,
                .set_isa = 1,
            }).values[1..dwarf.debug_line.header.opcode_base]);
            header.appendAssumeCapacity(1);
            uleb128(header.fixedWriter(), DW.LNCT.path) catch unreachable;
            uleb128(header.fixedWriter(), DW.FORM.line_strp) catch unreachable;
            uleb128(header.fixedWriter(), mod_info.dirs.count()) catch unreachable;
            for (mod_info.dirs.keys()) |dir_unit| {
                unit.cross_section_relocs.appendAssumeCapacity(.{
                    .source_off = @intCast(header.items.len),
                    .target_sec = .debug_line_str,
                    .target_unit = StringSection.unit,
                    .target_entry = dwarf.getModInfo(dir_unit).root_dir_path.toOptional(),
                });
                header.appendNTimesAssumeCapacity(0, dwarf.sectionOffsetBytes());
            }
            const dir_index_info = DebugLine.dirIndexInfo(@intCast(mod_info.dirs.count()));
            header.appendAssumeCapacity(3);
            uleb128(header.fixedWriter(), DW.LNCT.path) catch unreachable;
            uleb128(header.fixedWriter(), DW.FORM.line_strp) catch unreachable;
            uleb128(header.fixedWriter(), DW.LNCT.directory_index) catch unreachable;
            uleb128(header.fixedWriter(), @intFromEnum(dir_index_info.form)) catch unreachable;
            uleb128(header.fixedWriter(), DW.LNCT.LLVM_source) catch unreachable;
            uleb128(header.fixedWriter(), DW.FORM.line_strp) catch unreachable;
            uleb128(header.fixedWriter(), mod_info.files.count()) catch unreachable;
            for (mod_info.files.keys()) |file_index| {
                const file = zcu.fileByIndex(file_index);
                unit.cross_section_relocs.appendAssumeCapacity(.{
                    .source_off = @intCast(header.items.len),
                    .target_sec = .debug_line_str,
                    .target_unit = StringSection.unit,
                    .target_entry = (try dwarf.debug_line_str.addString(dwarf, file.sub_file_path)).toOptional(),
                });
                header.appendNTimesAssumeCapacity(0, dwarf.sectionOffsetBytes());
                dwarf.writeInt(
                    header.addManyAsSliceAssumeCapacity(dir_index_info.bytes),
                    mod_info.dirs.getIndex(dwarf.getUnitIfExists(file.mod).?).?,
                );
                unit.cross_section_relocs.appendAssumeCapacity(.{
                    .source_off = @intCast(header.items.len),
                    .target_sec = .debug_line_str,
                    .target_unit = StringSection.unit,
                    .target_entry = (try dwarf.debug_line_str.addString(
                        dwarf,
                        if (file.mod.builtin_file == file) file.source else "",
                    )).toOptional(),
                });
                header.appendNTimesAssumeCapacity(0, dwarf.sectionOffsetBytes());
            }
            try unit.replaceHeader(&dwarf.debug_line.section, dwarf, header.items);
            try unit.writeTrailer(&dwarf.debug_line.section, dwarf);
        }
        dwarf.debug_line.section.dirty = false;
    }
    if (dwarf.debug_line_str.section.dirty) {
        const contents = dwarf.debug_line_str.contents.items;
        try dwarf.debug_line_str.section.resize(dwarf, contents.len);
        try dwarf.getFile().?.pwriteAll(contents, dwarf.debug_line_str.section.off(dwarf));
        dwarf.debug_line_str.section.dirty = false;
    }
    if (dwarf.debug_loclists.section.dirty) {
        dwarf.debug_loclists.section.dirty = false;
    }
    if (dwarf.debug_rnglists.section.dirty) {
        for (dwarf.debug_rnglists.section.units.items) |*unit| {
            header.clearRetainingCapacity();
            try header.ensureTotalCapacity(unit.header_len);
            const unit_len = (if (unit.next.unwrap()) |next_unit|
                dwarf.debug_rnglists.section.getUnit(next_unit).off
            else
                dwarf.debug_rnglists.section.len) - unit.off - dwarf.unitLengthBytes();
            switch (dwarf.format) {
                .@"32" => std.mem.writeInt(u32, header.addManyAsArrayAssumeCapacity(4), @intCast(unit_len), dwarf.endian),
                .@"64" => {
                    std.mem.writeInt(u32, header.addManyAsArrayAssumeCapacity(4), std.math.maxInt(u32), dwarf.endian);
                    std.mem.writeInt(u64, header.addManyAsArrayAssumeCapacity(8), unit_len, dwarf.endian);
                },
            }
            std.mem.writeInt(u16, header.addManyAsArrayAssumeCapacity(2), 5, dwarf.endian);
            header.appendSliceAssumeCapacity(&.{ @intFromEnum(dwarf.address_size), 0 });
            std.mem.writeInt(u32, header.addManyAsArrayAssumeCapacity(4), 1, dwarf.endian);
            dwarf.writeInt(header.addManyAsSliceAssumeCapacity(dwarf.sectionOffsetBytes()), dwarf.sectionOffsetBytes() * 1);
            try unit.replaceHeader(&dwarf.debug_rnglists.section, dwarf, header.items);
            try unit.writeTrailer(&dwarf.debug_rnglists.section, dwarf);
        }
        dwarf.debug_rnglists.section.dirty = false;
    }
    assert(!dwarf.debug_abbrev.section.dirty);
    assert(!dwarf.debug_aranges.section.dirty);
    assert(!dwarf.debug_frame.section.dirty);
    assert(!dwarf.debug_info.section.dirty);
    assert(!dwarf.debug_line.section.dirty);
    assert(!dwarf.debug_line_str.section.dirty);
    assert(!dwarf.debug_loclists.section.dirty);
    assert(!dwarf.debug_rnglists.section.dirty);
    assert(!dwarf.debug_str.section.dirty);
}

pub fn resolveRelocs(dwarf: *Dwarf) RelocError!void {
    for ([_]*Section{
        &dwarf.debug_abbrev.section,
        &dwarf.debug_aranges.section,
        &dwarf.debug_frame.section,
        &dwarf.debug_info.section,
        &dwarf.debug_line.section,
        &dwarf.debug_line_str.section,
        &dwarf.debug_loclists.section,
        &dwarf.debug_rnglists.section,
        &dwarf.debug_str.section,
    }) |sec| try sec.resolveRelocs(dwarf);
}

fn DeclValEnum(comptime T: type) type {
    const decls = @typeInfo(T).@"struct".decls;
    @setEvalBranchQuota(7 * decls.len);
    var fields: [decls.len]std.builtin.Type.EnumField = undefined;
    var fields_len = 0;
    var min_value: ?comptime_int = null;
    var max_value: ?comptime_int = null;
    for (decls) |decl| {
        if (std.mem.startsWith(u8, decl.name, "HP_") or std.mem.endsWith(u8, decl.name, "_user")) continue;
        const value = @field(T, decl.name);
        fields[fields_len] = .{ .name = decl.name, .value = value };
        fields_len += 1;
        if (min_value == null or min_value.? > value) min_value = value;
        if (max_value == null or max_value.? < value) max_value = value;
    }
    return @Type(.{ .@"enum" = .{
        .tag_type = std.math.IntFittingRange(min_value orelse 0, max_value orelse 0),
        .fields = fields[0..fields_len],
        .decls = &.{},
        .is_exhaustive = true,
    } });
}

const AbbrevCode = enum {
    null,
    // padding codes must be one byte uleb128 values to function
    pad_1,
    pad_n,
    // decl codes are assumed to all have the same uleb128 length
    decl_alias,
    decl_enum,
    decl_empty_enum,
    decl_namespace_struct,
    decl_struct,
    decl_packed_struct,
    decl_union,
    decl_var,
    decl_func,
    decl_empty_func,
    decl_func_generic,
    decl_empty_func_generic,
    // the rest are unrestricted
    compile_unit,
    module,
    namespace_file,
    file,
    signed_enum_field,
    unsigned_enum_field,
    big_enum_field,
    generated_field,
    struct_field,
    struct_field_comptime,
    packed_struct_field,
    untagged_union_field,
    tagged_union,
    signed_tagged_union_field,
    unsigned_tagged_union_field,
    big_tagged_union_field,
    tagged_union_default_field,
    void_type,
    numeric_type,
    inferred_error_set_type,
    ptr_type,
    ptr_sentinel_type,
    is_const,
    is_volatile,
    array_type,
    array_sentinel_type,
    vector_type,
    array_index,
    nullary_func_type,
    func_type,
    func_type_param,
    is_var_args,
    enum_type,
    empty_enum_type,
    namespace_struct_type,
    struct_type,
    packed_struct_type,
    empty_packed_struct_type,
    union_type,
    empty_union_type,
    empty_inlined_func,
    inlined_func,
    local_arg,
    local_var,

    const decl_bytes = uleb128Bytes(@intFromEnum(AbbrevCode.decl_empty_func_generic));

    const Attr = struct {
        DeclValEnum(DW.AT),
        DeclValEnum(DW.FORM),
    };
    const decl_abbrev_common_attrs = &[_]Attr{
        .{ .ZIG_parent, .ref_addr },
        .{ .decl_line, .data4 },
        .{ .decl_column, .udata },
        .{ .accessibility, .data1 },
        .{ .name, .strp },
    };
    const abbrevs = std.EnumArray(AbbrevCode, struct {
        tag: DeclValEnum(DW.TAG),
        children: bool = false,
        attrs: []const Attr = &.{},
    }).init(.{
        .pad_1 = .{
            .tag = .ZIG_padding,
        },
        .pad_n = .{
            .tag = .ZIG_padding,
            .attrs = &.{
                .{ .ZIG_padding, .block },
            },
        },
        .decl_alias = .{
            .tag = .imported_declaration,
            .attrs = decl_abbrev_common_attrs ++ .{
                .{ .import, .ref_addr },
            },
        },
        .decl_enum = .{
            .tag = .enumeration_type,
            .children = true,
            .attrs = decl_abbrev_common_attrs ++ .{
                .{ .type, .ref_addr },
            },
        },
        .decl_empty_enum = .{
            .tag = .enumeration_type,
            .attrs = decl_abbrev_common_attrs ++ .{
                .{ .type, .ref_addr },
            },
        },
        .decl_namespace_struct = .{
            .tag = .structure_type,
            .attrs = decl_abbrev_common_attrs ++ .{
                .{ .declaration, .flag },
            },
        },
        .decl_struct = .{
            .tag = .structure_type,
            .children = true,
            .attrs = decl_abbrev_common_attrs ++ .{
                .{ .byte_size, .udata },
                .{ .alignment, .udata },
            },
        },
        .decl_packed_struct = .{
            .tag = .structure_type,
            .children = true,
            .attrs = decl_abbrev_common_attrs ++ .{
                .{ .type, .ref_addr },
            },
        },
        .decl_union = .{
            .tag = .union_type,
            .children = true,
            .attrs = decl_abbrev_common_attrs ++ .{
                .{ .byte_size, .udata },
                .{ .alignment, .udata },
            },
        },
        .decl_var = .{
            .tag = .variable,
            .attrs = decl_abbrev_common_attrs ++ .{
                .{ .linkage_name, .strp },
                .{ .type, .ref_addr },
                .{ .location, .exprloc },
                .{ .alignment, .udata },
                .{ .external, .flag },
            },
        },
        .decl_func = .{
            .tag = .subprogram,
            .children = true,
            .attrs = decl_abbrev_common_attrs ++ .{
                .{ .linkage_name, .strp },
                .{ .type, .ref_addr },
                .{ .low_pc, .addr },
                .{ .high_pc, .addr },
                .{ .alignment, .udata },
                .{ .external, .flag },
                .{ .noreturn, .flag },
            },
        },
        .decl_empty_func = .{
            .tag = .subprogram,
            .attrs = decl_abbrev_common_attrs ++ .{
                .{ .linkage_name, .strp },
                .{ .type, .ref_addr },
                .{ .low_pc, .addr },
                .{ .high_pc, .addr },
                .{ .alignment, .udata },
                .{ .external, .flag },
                .{ .noreturn, .flag },
            },
        },
        .decl_func_generic = .{
            .tag = .subprogram,
            .children = true,
            .attrs = decl_abbrev_common_attrs ++ .{
                .{ .type, .ref_addr },
            },
        },
        .decl_empty_func_generic = .{
            .tag = .subprogram,
            .attrs = decl_abbrev_common_attrs ++ .{
                .{ .type, .ref_addr },
            },
        },
        .compile_unit = .{
            .tag = .compile_unit,
            .children = true,
            .attrs = &.{
                .{ .language, .data1 },
                .{ .producer, .line_strp },
                .{ .comp_dir, .line_strp },
                .{ .name, .line_strp },
                .{ .base_types, .ref_addr },
                .{ .stmt_list, .sec_offset },
                .{ .rnglists_base, .sec_offset },
                .{ .ranges, .rnglistx },
            },
        },
        .module = .{
            .tag = .module,
            .children = true,
            .attrs = &.{
                .{ .name, .strp },
                .{ .ranges, .rnglistx },
            },
        },
        .namespace_file = .{
            .tag = .structure_type,
            .attrs = &.{
                .{ .decl_file, .udata },
                .{ .name, .strp },
            },
        },
        .file = .{
            .tag = .structure_type,
            .children = true,
            .attrs = &.{
                .{ .decl_file, .udata },
                .{ .name, .strp },
                .{ .byte_size, .udata },
                .{ .alignment, .udata },
            },
        },
        .signed_enum_field = .{
            .tag = .enumerator,
            .attrs = &.{
                .{ .const_value, .sdata },
                .{ .name, .strp },
            },
        },
        .unsigned_enum_field = .{
            .tag = .enumerator,
            .attrs = &.{
                .{ .const_value, .udata },
                .{ .name, .strp },
            },
        },
        .big_enum_field = .{
            .tag = .enumerator,
            .attrs = &.{
                .{ .const_value, .block },
                .{ .name, .strp },
            },
        },
        .generated_field = .{
            .tag = .member,
            .attrs = &.{
                .{ .name, .strp },
                .{ .type, .ref_addr },
                .{ .data_member_location, .udata },
                .{ .artificial, .flag_present },
            },
        },
        .struct_field = .{
            .tag = .member,
            .attrs = &.{
                .{ .name, .strp },
                .{ .type, .ref_addr },
                .{ .data_member_location, .udata },
                .{ .alignment, .udata },
            },
        },
        .struct_field_comptime = .{
            .tag = .member,
            .attrs = &.{
                .{ .name, .strp },
                .{ .type, .ref_addr },
                .{ .const_expr, .flag_present },
            },
        },
        .packed_struct_field = .{
            .tag = .member,
            .attrs = &.{
                .{ .name, .strp },
                .{ .type, .ref_addr },
                .{ .data_bit_offset, .udata },
            },
        },
        .untagged_union_field = .{
            .tag = .member,
            .attrs = &.{
                .{ .name, .strp },
                .{ .type, .ref_addr },
                .{ .alignment, .udata },
            },
        },
        .tagged_union = .{
            .tag = .variant_part,
            .children = true,
            .attrs = &.{
                .{ .discr, .ref_addr },
            },
        },
        .signed_tagged_union_field = .{
            .tag = .variant,
            .children = true,
            .attrs = &.{
                .{ .discr_value, .sdata },
            },
        },
        .unsigned_tagged_union_field = .{
            .tag = .variant,
            .children = true,
            .attrs = &.{
                .{ .discr_value, .udata },
            },
        },
        .big_tagged_union_field = .{
            .tag = .variant,
            .children = true,
            .attrs = &.{
                .{ .discr_value, .block },
            },
        },
        .tagged_union_default_field = .{
            .tag = .variant,
            .children = true,
            .attrs = &.{},
        },
        .void_type = .{
            .tag = .unspecified_type,
            .attrs = &.{
                .{ .name, .strp },
            },
        },
        .numeric_type = .{
            .tag = .base_type,
            .attrs = &.{
                .{ .name, .strp },
                .{ .encoding, .data1 },
                .{ .bit_size, .udata },
                .{ .byte_size, .udata },
                .{ .alignment, .udata },
            },
        },
        .inferred_error_set_type = .{
            .tag = .typedef,
            .attrs = &.{
                .{ .name, .strp },
                .{ .type, .ref_addr },
            },
        },
        .ptr_type = .{
            .tag = .pointer_type,
            .attrs = &.{
                .{ .name, .strp },
                .{ .alignment, .udata },
                .{ .address_class, .data1 },
                .{ .type, .ref_addr },
            },
        },
        .ptr_sentinel_type = .{
            .tag = .pointer_type,
            .attrs = &.{
                .{ .name, .strp },
                .{ .ZIG_sentinel, .block },
                .{ .alignment, .udata },
                .{ .address_class, .data1 },
                .{ .type, .ref_addr },
            },
        },
        .is_const = .{
            .tag = .const_type,
            .attrs = &.{
                .{ .type, .ref_addr },
            },
        },
        .is_volatile = .{
            .tag = .volatile_type,
            .attrs = &.{
                .{ .type, .ref_addr },
            },
        },
        .array_type = .{
            .tag = .array_type,
            .children = true,
            .attrs = &.{
                .{ .name, .strp },
                .{ .type, .ref_addr },
            },
        },
        .array_sentinel_type = .{
            .tag = .array_type,
            .children = true,
            .attrs = &.{
                .{ .name, .strp },
                .{ .ZIG_sentinel, .block },
                .{ .type, .ref_addr },
            },
        },
        .vector_type = .{
            .tag = .array_type,
            .children = true,
            .attrs = &.{
                .{ .name, .strp },
                .{ .type, .ref_addr },
                .{ .GNU_vector, .flag_present },
            },
        },
        .array_index = .{
            .tag = .subrange_type,
            .attrs = &.{
                .{ .type, .ref_addr },
                .{ .count, .udata },
            },
        },
        .nullary_func_type = .{
            .tag = .subroutine_type,
            .attrs = &.{
                .{ .name, .strp },
                .{ .calling_convention, .data1 },
                .{ .type, .ref_addr },
            },
        },
        .func_type = .{
            .tag = .subroutine_type,
            .children = true,
            .attrs = &.{
                .{ .name, .strp },
                .{ .calling_convention, .data1 },
                .{ .type, .ref_addr },
            },
        },
        .func_type_param = .{
            .tag = .formal_parameter,
            .attrs = &.{
                .{ .type, .ref_addr },
            },
        },
        .is_var_args = .{
            .tag = .unspecified_parameters,
        },
        .enum_type = .{
            .tag = .enumeration_type,
            .children = true,
            .attrs = &.{
                .{ .name, .strp },
                .{ .type, .ref_addr },
            },
        },
        .empty_enum_type = .{
            .tag = .enumeration_type,
            .attrs = &.{
                .{ .name, .strp },
                .{ .type, .ref_addr },
            },
        },
        .namespace_struct_type = .{
            .tag = .structure_type,
            .attrs = &.{
                .{ .name, .strp },
                .{ .declaration, .flag },
            },
        },
        .struct_type = .{
            .tag = .structure_type,
            .children = true,
            .attrs = &.{
                .{ .name, .strp },
                .{ .byte_size, .udata },
                .{ .alignment, .udata },
            },
        },
        .packed_struct_type = .{
            .tag = .structure_type,
            .children = true,
            .attrs = &.{
                .{ .name, .strp },
                .{ .type, .ref_addr },
            },
        },
        .empty_packed_struct_type = .{
            .tag = .structure_type,
            .attrs = &.{
                .{ .name, .strp },
                .{ .type, .ref_addr },
            },
        },
        .union_type = .{
            .tag = .union_type,
            .children = true,
            .attrs = &.{
                .{ .name, .strp },
                .{ .byte_size, .udata },
                .{ .alignment, .udata },
            },
        },
        .empty_union_type = .{
            .tag = .union_type,
            .attrs = &.{
                .{ .name, .strp },
                .{ .byte_size, .udata },
                .{ .alignment, .udata },
            },
        },
        .empty_inlined_func = .{
            .tag = .inlined_subroutine,
            .attrs = &.{
                .{ .abstract_origin, .ref_addr },
                .{ .call_line, .udata },
                .{ .call_column, .udata },
                .{ .low_pc, .addr },
                .{ .high_pc, .addr },
            },
        },
        .inlined_func = .{
            .tag = .inlined_subroutine,
            .children = true,
            .attrs = &.{
                .{ .abstract_origin, .ref_addr },
                .{ .call_line, .udata },
                .{ .call_column, .udata },
                .{ .low_pc, .addr },
                .{ .high_pc, .addr },
            },
        },
        .local_arg = .{
            .tag = .formal_parameter,
            .attrs = &.{
                .{ .name, .strp },
                .{ .type, .ref_addr },
                .{ .location, .exprloc },
            },
        },
        .local_var = .{
            .tag = .variable,
            .attrs = &.{
                .{ .name, .strp },
                .{ .type, .ref_addr },
                .{ .location, .exprloc },
            },
        },
        .null = undefined,
    });
};

fn getFile(dwarf: *Dwarf) ?std.fs.File {
    if (dwarf.bin_file.cast(.macho)) |macho_file| if (macho_file.d_sym) |*d_sym| return d_sym.file;
    return dwarf.bin_file.file;
}

fn addCommonEntry(dwarf: *Dwarf, unit: Unit.Index) UpdateError!Entry.Index {
    const entry = try dwarf.debug_aranges.section.getUnit(unit).addEntry(dwarf.gpa);
    assert(try dwarf.debug_frame.section.getUnit(unit).addEntry(dwarf.gpa) == entry);
    assert(try dwarf.debug_info.section.getUnit(unit).addEntry(dwarf.gpa) == entry);
    assert(try dwarf.debug_line.section.getUnit(unit).addEntry(dwarf.gpa) == entry);
    assert(try dwarf.debug_loclists.section.getUnit(unit).addEntry(dwarf.gpa) == entry);
    assert(try dwarf.debug_rnglists.section.getUnit(unit).addEntry(dwarf.gpa) == entry);
    return entry;
}

fn writeInt(dwarf: *Dwarf, buf: []u8, int: u64) void {
    switch (buf.len) {
        inline 0...8 => |len| std.mem.writeInt(@Type(.{ .int = .{
            .signedness = .unsigned,
            .bits = len * 8,
        } }), buf[0..len], @intCast(int), dwarf.endian),
        else => unreachable,
    }
}

fn resolveReloc(dwarf: *Dwarf, source: u64, target: u64, size: u32) RelocError!void {
    var buf: [8]u8 = undefined;
    dwarf.writeInt(buf[0..size], target);
    try dwarf.getFile().?.pwriteAll(buf[0..size], source);
}

fn unitLengthBytes(dwarf: *Dwarf) u32 {
    return switch (dwarf.format) {
        .@"32" => 4,
        .@"64" => 4 + 8,
    };
}

fn sectionOffsetBytes(dwarf: *Dwarf) u32 {
    return switch (dwarf.format) {
        .@"32" => 4,
        .@"64" => 8,
    };
}

fn uleb128Bytes(value: anytype) u32 {
    var cw = std.io.countingWriter(std.io.null_writer);
    try uleb128(cw.writer(), value);
    return @intCast(cw.bytes_written);
}

fn sleb128Bytes(value: anytype) u32 {
    var cw = std.io.countingWriter(std.io.null_writer);
    try sleb128(cw.writer(), value);
    return @intCast(cw.bytes_written);
}

/// overrides `-fno-incremental` for testing incremental debug info until `-fincremental` is functional
const force_incremental = false;
inline fn incremental(dwarf: Dwarf) bool {
    return force_incremental or dwarf.bin_file.comp.incremental;
}

const DW = std.dwarf;
const Dwarf = @This();
const InternPool = @import("../InternPool.zig");
const Module = @import("../Package.zig").Module;
const Type = @import("../Type.zig");
const Value = @import("../Value.zig");
const Zcu = @import("../Zcu.zig");
const Zir = std.zig.Zir;
const assert = std.debug.assert;
const codegen = @import("../codegen.zig");
const dev = @import("../dev.zig");
const link = @import("../link.zig");
const log = std.log.scoped(.dwarf);
const sleb128 = std.leb.writeIleb128;
const std = @import("std");
const target_info = @import("../target.zig");
const uleb128 = std.leb.writeUleb128;
