const UnwindInfo = @This();

const std = @import("std");
const assert = std.debug.assert;
const eh_frame = @import("eh_frame.zig");
const fs = std.fs;
const leb = std.leb;
const log = std.log.scoped(.unwind_info);
const macho = std.macho;
const math = std.math;
const mem = std.mem;
const trace = @import("../../tracy.zig").trace;

const Allocator = mem.Allocator;
const Atom = @import("ZldAtom.zig");
const AtomIndex = @import("zld.zig").AtomIndex;
const EhFrameRecord = eh_frame.EhFrameRecord;
const Object = @import("Object.zig");
const SymbolWithLoc = @import("zld.zig").SymbolWithLoc;
const Zld = @import("zld.zig").Zld;

const N_DEAD = @import("zld.zig").N_DEAD;

gpa: Allocator,

/// List of all unwind records gathered from all objects and sorted
/// by source function address.
records: std.ArrayListUnmanaged(macho.compact_unwind_entry) = .{},
records_lookup: std.AutoHashMapUnmanaged(AtomIndex, RecordIndex) = .{},

/// List of all personalities referenced by either unwind info entries
/// or __eh_frame entries.
personalities: [max_personalities]SymbolWithLoc = undefined,
personalities_count: u2 = 0,

/// List of common encodings sorted in descending order with the most common first.
common_encodings: [max_common_encodings]macho.compact_unwind_encoding_t = undefined,
common_encodings_count: u7 = 0,

/// List of record indexes containing an LSDA pointer.
lsdas: std.ArrayListUnmanaged(RecordIndex) = .{},
lsdas_lookup: std.AutoHashMapUnmanaged(RecordIndex, u32) = .{},

/// List of second level pages.
pages: std.ArrayListUnmanaged(Page) = .{},

const RecordIndex = u32;

const max_personalities = 3;
const max_common_encodings = 127;
const max_compact_encodings = 256;

const second_level_page_bytes = 0x1000;
const second_level_page_words = second_level_page_bytes / @sizeOf(u32);

const max_regular_second_level_entries =
    (second_level_page_bytes - @sizeOf(macho.unwind_info_regular_second_level_page_header)) /
    @sizeOf(macho.unwind_info_regular_second_level_entry);

const max_compressed_second_level_entries =
    (second_level_page_bytes - @sizeOf(macho.unwind_info_compressed_second_level_page_header)) /
    @sizeOf(u32);

const compressed_entry_func_offset_mask = ~@as(u24, 0);

const Page = struct {
    kind: enum { regular, compressed },
    start: RecordIndex,
    count: u16,
    page_encodings: [max_compact_encodings]RecordIndex = undefined,
    page_encodings_count: u9 = 0,

    fn appendPageEncoding(page: *Page, record_id: RecordIndex) void {
        assert(page.page_encodings_count <= max_compact_encodings);
        page.page_encodings[page.page_encodings_count] = record_id;
        page.page_encodings_count += 1;
    }

    fn getPageEncoding(
        page: *const Page,
        info: *const UnwindInfo,
        enc: macho.compact_unwind_encoding_t,
    ) ?u8 {
        comptime var index: u9 = 0;
        inline while (index < max_compact_encodings) : (index += 1) {
            if (index >= page.page_encodings_count) return null;
            const record_id = page.page_encodings[index];
            const record = info.records.items[record_id];
            if (record.compactUnwindEncoding == enc) {
                return @intCast(u8, index);
            }
        }
        return null;
    }

    fn format(
        page: *const Page,
        comptime unused_format_string: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = page;
        _ = unused_format_string;
        _ = options;
        _ = writer;
        @compileError("do not format Page directly; use page.fmtDebug()");
    }

    const DumpCtx = struct {
        page: *const Page,
        info: *const UnwindInfo,
    };

    fn dump(
        ctx: DumpCtx,
        comptime unused_format_string: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        _ = options;
        comptime assert(unused_format_string.len == 0);
        try writer.writeAll("Page:\n");
        try writer.print("  kind: {s}\n", .{@tagName(ctx.page.kind)});
        try writer.print("  entries: {d} - {d}\n", .{
            ctx.page.start,
            ctx.page.start + ctx.page.count,
        });
        try writer.print("  encodings (count = {d})\n", .{ctx.page.page_encodings_count});
        for (ctx.page.page_encodings[0..ctx.page.page_encodings_count]) |record_id, i| {
            const record = ctx.info.records.items[record_id];
            const enc = record.compactUnwindEncoding;
            try writer.print("    {d}: 0x{x:0>8}\n", .{ ctx.info.common_encodings_count + i, enc });
        }
    }

    fn fmtDebug(page: *const Page, info: *const UnwindInfo) std.fmt.Formatter(dump) {
        return .{ .data = .{
            .page = page,
            .info = info,
        } };
    }

    fn write(page: *const Page, info: *const UnwindInfo, writer: anytype) !void {
        switch (page.kind) {
            .regular => {
                try writer.writeStruct(macho.unwind_info_regular_second_level_page_header{
                    .entryPageOffset = @sizeOf(macho.unwind_info_regular_second_level_page_header),
                    .entryCount = page.count,
                });

                for (info.records.items[page.start..][0..page.count]) |record| {
                    try writer.writeStruct(macho.unwind_info_regular_second_level_entry{
                        .functionOffset = @intCast(u32, record.rangeStart),
                        .encoding = record.compactUnwindEncoding,
                    });
                }
            },
            .compressed => {
                const entry_offset = @sizeOf(macho.unwind_info_compressed_second_level_page_header) +
                    @intCast(u16, page.page_encodings_count) * @sizeOf(u32);
                try writer.writeStruct(macho.unwind_info_compressed_second_level_page_header{
                    .entryPageOffset = entry_offset,
                    .entryCount = page.count,
                    .encodingsPageOffset = @sizeOf(
                        macho.unwind_info_compressed_second_level_page_header,
                    ),
                    .encodingsCount = page.page_encodings_count,
                });

                for (page.page_encodings[0..page.page_encodings_count]) |record_id| {
                    const enc = info.records.items[record_id].compactUnwindEncoding;
                    try writer.writeIntLittle(u32, enc);
                }

                assert(page.count > 0);
                const first_entry = info.records.items[page.start];
                for (info.records.items[page.start..][0..page.count]) |record| {
                    const enc_index = blk: {
                        if (info.getCommonEncoding(record.compactUnwindEncoding)) |id| {
                            break :blk id;
                        }
                        const ncommon = info.common_encodings_count;
                        break :blk ncommon + page.getPageEncoding(info, record.compactUnwindEncoding).?;
                    };
                    const compressed = macho.UnwindInfoCompressedEntry{
                        .funcOffset = @intCast(u24, record.rangeStart - first_entry.rangeStart),
                        .encodingIndex = @intCast(u8, enc_index),
                    };
                    try writer.writeStruct(compressed);
                }
            },
        }
    }
};

pub fn deinit(info: *UnwindInfo) void {
    info.records.deinit(info.gpa);
    info.records_lookup.deinit(info.gpa);
    info.pages.deinit(info.gpa);
    info.lsdas.deinit(info.gpa);
    info.lsdas_lookup.deinit(info.gpa);
}

pub fn scanRelocs(zld: *Zld) !void {
    if (zld.getSectionByName("__TEXT", "__unwind_info") == null) return;

    const cpu_arch = zld.options.target.cpu.arch;
    for (zld.objects.items) |*object, object_id| {
        const unwind_records = object.getUnwindRecords();
        for (object.exec_atoms.items) |atom_index| {
            const record_id = object.unwind_records_lookup.get(atom_index) orelse continue;
            if (object.unwind_relocs_lookup[record_id].dead) continue;
            const record = unwind_records[record_id];
            if (!UnwindEncoding.isDwarf(record.compactUnwindEncoding, cpu_arch)) {
                if (getPersonalityFunctionReloc(
                    zld,
                    @intCast(u32, object_id),
                    record_id,
                )) |rel| {
                    // Personality function; add GOT pointer.
                    const target = parseRelocTarget(
                        zld,
                        @intCast(u32, object_id),
                        rel,
                        mem.asBytes(&record),
                        @intCast(i32, record_id * @sizeOf(macho.compact_unwind_entry)),
                    );
                    try Atom.addGotEntry(zld, target);
                }
            }
        }
    }
}

pub fn collect(info: *UnwindInfo, zld: *Zld) !void {
    if (zld.getSectionByName("__TEXT", "__unwind_info") == null) return;

    const cpu_arch = zld.options.target.cpu.arch;

    var records = std.ArrayList(macho.compact_unwind_entry).init(info.gpa);
    defer records.deinit();

    var atom_indexes = std.ArrayList(AtomIndex).init(info.gpa);
    defer atom_indexes.deinit();

    // TODO handle dead stripping
    for (zld.objects.items) |*object, object_id| {
        log.debug("collecting unwind records in {s} ({d})", .{ object.name, object_id });
        const unwind_records = object.getUnwindRecords();

        // Contents of unwind records does not have to cover all symbol in executable section
        // so we need insert them ourselves.
        try records.ensureUnusedCapacity(object.exec_atoms.items.len);
        try atom_indexes.ensureUnusedCapacity(object.exec_atoms.items.len);

        for (object.exec_atoms.items) |atom_index| {
            var record = if (object.unwind_records_lookup.get(atom_index)) |record_id| blk: {
                if (object.unwind_relocs_lookup[record_id].dead) continue;
                var record = unwind_records[record_id];

                if (UnwindEncoding.isDwarf(record.compactUnwindEncoding, cpu_arch)) {
                    try info.collectPersonalityFromDwarf(zld, @intCast(u32, object_id), atom_index, &record);
                } else {
                    if (getPersonalityFunctionReloc(
                        zld,
                        @intCast(u32, object_id),
                        record_id,
                    )) |rel| {
                        const target = parseRelocTarget(
                            zld,
                            @intCast(u32, object_id),
                            rel,
                            mem.asBytes(&record),
                            @intCast(i32, record_id * @sizeOf(macho.compact_unwind_entry)),
                        );
                        const personality_index = info.getPersonalityFunction(target) orelse inner: {
                            const personality_index = info.personalities_count;
                            info.personalities[personality_index] = target;
                            info.personalities_count += 1;
                            break :inner personality_index;
                        };

                        record.personalityFunction = personality_index + 1;
                        UnwindEncoding.setPersonalityIndex(&record.compactUnwindEncoding, personality_index + 1);
                    }

                    if (getLsdaReloc(zld, @intCast(u32, object_id), record_id)) |rel| {
                        const target = parseRelocTarget(
                            zld,
                            @intCast(u32, object_id),
                            rel,
                            mem.asBytes(&record),
                            @intCast(i32, record_id * @sizeOf(macho.compact_unwind_entry)),
                        );
                        record.lsda = @bitCast(u64, target);
                    }
                }
                break :blk record;
            } else blk: {
                const atom = zld.getAtom(atom_index);
                const sym = zld.getSymbol(atom.getSymbolWithLoc());
                if (sym.n_desc == N_DEAD) continue;

                if (!object.hasUnwindRecords()) {
                    if (object.eh_frame_records_lookup.get(atom_index)) |fde_offset| {
                        if (object.eh_frame_relocs_lookup.get(fde_offset).?.dead) continue;
                        var record = nullRecord();
                        try info.collectPersonalityFromDwarf(zld, @intCast(u32, object_id), atom_index, &record);
                        switch (cpu_arch) {
                            .aarch64 => UnwindEncoding.setMode(&record.compactUnwindEncoding, macho.UNWIND_ARM64_MODE.DWARF),
                            .x86_64 => UnwindEncoding.setMode(&record.compactUnwindEncoding, macho.UNWIND_X86_64_MODE.DWARF),
                            else => unreachable,
                        }
                        break :blk record;
                    }
                }

                break :blk nullRecord();
            };

            const atom = zld.getAtom(atom_index);
            const sym_loc = atom.getSymbolWithLoc();
            const sym = zld.getSymbol(sym_loc);
            assert(sym.n_desc != N_DEAD);
            record.rangeStart = sym.n_value;
            record.rangeLength = @intCast(u32, atom.size);

            records.appendAssumeCapacity(record);
            atom_indexes.appendAssumeCapacity(atom_index);
        }
    }

    // Fold records
    try info.records.ensureTotalCapacity(info.gpa, records.items.len);
    try info.records_lookup.ensureTotalCapacity(info.gpa, @intCast(u32, atom_indexes.items.len));

    var maybe_prev: ?macho.compact_unwind_entry = null;
    for (records.items) |record, i| {
        const record_id = blk: {
            if (maybe_prev) |prev| {
                const is_dwarf = UnwindEncoding.isDwarf(record.compactUnwindEncoding, cpu_arch);
                if (is_dwarf or
                    (prev.compactUnwindEncoding != record.compactUnwindEncoding) or
                    (prev.personalityFunction != record.personalityFunction) or
                    record.lsda > 0)
                {
                    const record_id = @intCast(RecordIndex, info.records.items.len);
                    info.records.appendAssumeCapacity(record);
                    maybe_prev = record;
                    break :blk record_id;
                } else {
                    break :blk @intCast(RecordIndex, info.records.items.len - 1);
                }
            } else {
                const record_id = @intCast(RecordIndex, info.records.items.len);
                info.records.appendAssumeCapacity(record);
                maybe_prev = record;
                break :blk record_id;
            }
        };
        info.records_lookup.putAssumeCapacityNoClobber(atom_indexes.items[i], record_id);
    }

    // Calculate common encodings
    {
        const CommonEncWithCount = struct {
            enc: macho.compact_unwind_encoding_t,
            count: u32,

            fn greaterThan(ctx: void, lhs: @This(), rhs: @This()) bool {
                _ = ctx;
                return lhs.count > rhs.count;
            }
        };

        const Context = struct {
            pub fn hash(ctx: @This(), key: macho.compact_unwind_encoding_t) u32 {
                _ = ctx;
                return key;
            }

            pub fn eql(
                ctx: @This(),
                key1: macho.compact_unwind_encoding_t,
                key2: macho.compact_unwind_encoding_t,
                b_index: usize,
            ) bool {
                _ = ctx;
                _ = b_index;
                return key1 == key2;
            }
        };

        var common_encodings_counts = std.ArrayHashMap(
            macho.compact_unwind_encoding_t,
            CommonEncWithCount,
            Context,
            false,
        ).init(info.gpa);
        defer common_encodings_counts.deinit();

        for (info.records.items) |record| {
            assert(!isNull(record));
            if (UnwindEncoding.isDwarf(record.compactUnwindEncoding, cpu_arch)) continue;
            const enc = record.compactUnwindEncoding;
            const gop = try common_encodings_counts.getOrPut(enc);
            if (!gop.found_existing) {
                gop.value_ptr.* = .{
                    .enc = enc,
                    .count = 0,
                };
            }
            gop.value_ptr.count += 1;
        }

        var slice = common_encodings_counts.values();
        std.sort.sort(CommonEncWithCount, slice, {}, CommonEncWithCount.greaterThan);

        var i: u7 = 0;
        while (i < slice.len) : (i += 1) {
            if (i >= max_common_encodings) break;
            if (slice[i].count < 2) continue;
            info.appendCommonEncoding(slice[i].enc);
            log.debug("adding common encoding: {d} => 0x{x:0>8}", .{ i, slice[i].enc });
        }
    }

    // Compute page allocations
    {
        var i: u32 = 0;
        while (i < info.records.items.len) {
            const range_start_max: u64 =
                info.records.items[i].rangeStart + compressed_entry_func_offset_mask;
            var encoding_count: u9 = info.common_encodings_count;
            var space_left: u32 = second_level_page_words -
                @sizeOf(macho.unwind_info_compressed_second_level_page_header) / @sizeOf(u32);
            var page = Page{
                .kind = undefined,
                .start = i,
                .count = 0,
            };

            while (space_left >= 1 and i < info.records.items.len) {
                const record = info.records.items[i];
                const enc = record.compactUnwindEncoding;
                const is_dwarf = UnwindEncoding.isDwarf(record.compactUnwindEncoding, cpu_arch);

                if (record.rangeStart >= range_start_max) {
                    break;
                } else if (info.getCommonEncoding(enc) != null or
                    page.getPageEncoding(info, enc) != null and !is_dwarf)
                {
                    i += 1;
                    space_left -= 1;
                } else if (space_left >= 2 and encoding_count < max_compact_encodings) {
                    page.appendPageEncoding(i);
                    i += 1;
                    space_left -= 2;
                    encoding_count += 1;
                } else {
                    break;
                }
            }

            page.count = @intCast(u16, i - page.start);

            if (i < info.records.items.len and page.count < max_regular_second_level_entries) {
                page.kind = .regular;
                page.count = @intCast(u16, @min(
                    max_regular_second_level_entries,
                    info.records.items.len - page.start,
                ));
                i = page.start + page.count;
            } else {
                page.kind = .compressed;
            }

            log.debug("{}", .{page.fmtDebug(info)});

            try info.pages.append(info.gpa, page);
        }
    }

    // Save indices of records requiring LSDA relocation
    try info.lsdas_lookup.ensureTotalCapacity(info.gpa, @intCast(u32, info.records.items.len));
    for (info.records.items) |rec, i| {
        info.lsdas_lookup.putAssumeCapacityNoClobber(@intCast(RecordIndex, i), @intCast(u32, info.lsdas.items.len));
        if (rec.lsda == 0) continue;
        try info.lsdas.append(info.gpa, @intCast(RecordIndex, i));
    }
}

fn collectPersonalityFromDwarf(
    info: *UnwindInfo,
    zld: *Zld,
    object_id: u32,
    atom_index: u32,
    record: *macho.compact_unwind_entry,
) !void {
    const object = &zld.objects.items[object_id];
    var it = object.getEhFrameRecordsIterator();
    const fde_offset = object.eh_frame_records_lookup.get(atom_index).?;
    it.seekTo(fde_offset);
    const fde = (try it.next()).?;
    const cie_ptr = fde.getCiePointer();
    const cie_offset = fde_offset + 4 - cie_ptr;
    it.seekTo(cie_offset);
    const cie = (try it.next()).?;

    if (cie.getPersonalityPointerReloc(
        zld,
        @intCast(u32, object_id),
        cie_offset,
    )) |target| {
        const personality_index = info.getPersonalityFunction(target) orelse inner: {
            const personality_index = info.personalities_count;
            info.personalities[personality_index] = target;
            info.personalities_count += 1;
            break :inner personality_index;
        };

        record.personalityFunction = personality_index + 1;
        UnwindEncoding.setPersonalityIndex(&record.compactUnwindEncoding, personality_index + 1);
    }
}

pub fn calcSectionSize(info: UnwindInfo, zld: *Zld) !void {
    const sect_id = zld.getSectionByName("__TEXT", "__unwind_info") orelse return;
    const sect = &zld.sections.items(.header)[sect_id];
    sect.@"align" = 2;
    sect.size = info.calcRequiredSize();
}

fn calcRequiredSize(info: UnwindInfo) usize {
    var total_size: usize = 0;
    total_size += @sizeOf(macho.unwind_info_section_header);
    total_size +=
        @intCast(usize, info.common_encodings_count) * @sizeOf(macho.compact_unwind_encoding_t);
    total_size += @intCast(usize, info.personalities_count) * @sizeOf(u32);
    total_size += (info.pages.items.len + 1) * @sizeOf(macho.unwind_info_section_header_index_entry);
    total_size += info.lsdas.items.len * @sizeOf(macho.unwind_info_section_header_lsda_index_entry);
    total_size += info.pages.items.len * second_level_page_bytes;
    return total_size;
}

pub fn write(info: *UnwindInfo, zld: *Zld) !void {
    const sect_id = zld.getSectionByName("__TEXT", "__unwind_info") orelse return;
    const sect = &zld.sections.items(.header)[sect_id];
    const seg_id = zld.sections.items(.segment_index)[sect_id];
    const seg = zld.segments.items[seg_id];

    const text_sect_id = zld.getSectionByName("__TEXT", "__text").?;
    const text_sect = zld.sections.items(.header)[text_sect_id];

    var personalities: [max_personalities]u32 = undefined;
    const cpu_arch = zld.options.target.cpu.arch;

    log.debug("Personalities:", .{});
    for (info.personalities[0..info.personalities_count]) |target, i| {
        const atom_index = zld.getGotAtomIndexForSymbol(target).?;
        const atom = zld.getAtom(atom_index);
        const sym = zld.getSymbol(atom.getSymbolWithLoc());
        personalities[i] = @intCast(u32, sym.n_value - seg.vmaddr);
        log.debug("  {d}: 0x{x} ({s})", .{ i, personalities[i], zld.getSymbolName(target) });
    }

    for (info.records.items) |*rec| {
        // Finalize missing address values
        rec.rangeStart += text_sect.addr - seg.vmaddr;
        if (rec.personalityFunction > 0) {
            const index = math.cast(usize, rec.personalityFunction - 1) orelse return error.Overflow;
            rec.personalityFunction = personalities[index];
        }

        if (rec.compactUnwindEncoding > 0 and !UnwindEncoding.isDwarf(rec.compactUnwindEncoding, cpu_arch)) {
            const lsda_target = @bitCast(SymbolWithLoc, rec.lsda);
            if (lsda_target.getFile()) |_| {
                const sym = zld.getSymbol(lsda_target);
                rec.lsda = sym.n_value - seg.vmaddr;
            }
        }
    }

    for (info.records.items) |record, i| {
        log.debug("Unwind record at offset 0x{x}", .{i * @sizeOf(macho.compact_unwind_entry)});
        log.debug("  start: 0x{x}", .{record.rangeStart});
        log.debug("  length: 0x{x}", .{record.rangeLength});
        log.debug("  compact encoding: 0x{x:0>8}", .{record.compactUnwindEncoding});
        log.debug("  personality: 0x{x}", .{record.personalityFunction});
        log.debug("  LSDA: 0x{x}", .{record.lsda});
    }

    var buffer = std.ArrayList(u8).init(info.gpa);
    defer buffer.deinit();

    const size = info.calcRequiredSize();
    try buffer.ensureTotalCapacityPrecise(size);

    var cwriter = std.io.countingWriter(buffer.writer());
    const writer = cwriter.writer();

    const common_encodings_offset: u32 = @sizeOf(macho.unwind_info_section_header);
    const common_encodings_count: u32 = info.common_encodings_count;
    const personalities_offset: u32 = common_encodings_offset + common_encodings_count * @sizeOf(u32);
    const personalities_count: u32 = info.personalities_count;
    const indexes_offset: u32 = personalities_offset + personalities_count * @sizeOf(u32);
    const indexes_count: u32 = @intCast(u32, info.pages.items.len + 1);

    try writer.writeStruct(macho.unwind_info_section_header{
        .commonEncodingsArraySectionOffset = common_encodings_offset,
        .commonEncodingsArrayCount = common_encodings_count,
        .personalityArraySectionOffset = personalities_offset,
        .personalityArrayCount = personalities_count,
        .indexSectionOffset = indexes_offset,
        .indexCount = indexes_count,
    });

    try writer.writeAll(mem.sliceAsBytes(info.common_encodings[0..info.common_encodings_count]));
    try writer.writeAll(mem.sliceAsBytes(personalities[0..info.personalities_count]));

    const pages_base_offset = @intCast(u32, size - (info.pages.items.len * second_level_page_bytes));
    const lsda_base_offset = @intCast(u32, pages_base_offset -
        (info.lsdas.items.len * @sizeOf(macho.unwind_info_section_header_lsda_index_entry)));
    for (info.pages.items) |page, i| {
        assert(page.count > 0);
        const first_entry = info.records.items[page.start];
        try writer.writeStruct(macho.unwind_info_section_header_index_entry{
            .functionOffset = @intCast(u32, first_entry.rangeStart),
            .secondLevelPagesSectionOffset = @intCast(u32, pages_base_offset + i * second_level_page_bytes),
            .lsdaIndexArraySectionOffset = lsda_base_offset +
                info.lsdas_lookup.get(page.start).? * @sizeOf(macho.unwind_info_section_header_lsda_index_entry),
        });
    }

    const last_entry = info.records.items[info.records.items.len - 1];
    const sentinel_address = @intCast(u32, last_entry.rangeStart + last_entry.rangeLength);
    try writer.writeStruct(macho.unwind_info_section_header_index_entry{
        .functionOffset = sentinel_address,
        .secondLevelPagesSectionOffset = 0,
        .lsdaIndexArraySectionOffset = lsda_base_offset +
            @intCast(u32, info.lsdas.items.len) * @sizeOf(macho.unwind_info_section_header_lsda_index_entry),
    });

    for (info.lsdas.items) |record_id| {
        const record = info.records.items[record_id];
        try writer.writeStruct(macho.unwind_info_section_header_lsda_index_entry{
            .functionOffset = @intCast(u32, record.rangeStart),
            .lsdaOffset = @intCast(u32, record.lsda),
        });
    }

    for (info.pages.items) |page| {
        const start = cwriter.bytes_written;
        try page.write(info, writer);
        const nwritten = cwriter.bytes_written - start;
        if (nwritten < second_level_page_bytes) {
            const offset = math.cast(usize, second_level_page_bytes - nwritten) orelse return error.Overflow;
            try writer.writeByteNTimes(0, offset);
        }
    }

    const padding = buffer.items.len - cwriter.bytes_written;
    if (padding > 0) {
        const offset = math.cast(usize, cwriter.bytes_written) orelse return error.Overflow;
        mem.set(u8, buffer.items[offset..], 0);
    }

    try zld.file.pwriteAll(buffer.items, sect.offset);
}

pub fn parseRelocTarget(
    zld: *Zld,
    object_id: u32,
    rel: macho.relocation_info,
    code: []const u8,
    base_offset: i32,
) SymbolWithLoc {
    const tracy = trace(@src());
    defer tracy.end();

    const object = &zld.objects.items[object_id];

    const sym_index = if (rel.r_extern == 0) blk: {
        const sect_id = @intCast(u8, rel.r_symbolnum - 1);
        const rel_offset = @intCast(u32, rel.r_address - base_offset);
        assert(rel.r_pcrel == 0 and rel.r_length == 3);
        const address_in_section = mem.readIntLittle(u64, code[rel_offset..][0..8]);
        const sym_index = object.getSymbolByAddress(address_in_section, sect_id);
        break :blk sym_index;
    } else object.reverse_symtab_lookup[rel.r_symbolnum];

    const sym_loc = SymbolWithLoc{ .sym_index = sym_index, .file = object_id + 1 };
    const sym = zld.getSymbol(sym_loc);

    if (sym.sect() and !sym.ext()) {
        // Make sure we are not dealing with a local alias.
        const atom_index = object.getAtomIndexForSymbol(sym_index) orelse
            return sym_loc;
        const atom = zld.getAtom(atom_index);
        return atom.getSymbolWithLoc();
    } else if (object.getGlobal(sym_index)) |global_index| {
        return zld.globals.items[global_index];
    } else return sym_loc;
}

fn getRelocs(zld: *Zld, object_id: u32, record_id: usize) []const macho.relocation_info {
    const object = &zld.objects.items[object_id];
    assert(object.hasUnwindRecords());
    const rel_pos = object.unwind_relocs_lookup[record_id].reloc;
    const relocs = object.getRelocs(object.unwind_info_sect_id.?);
    return relocs[rel_pos.start..][0..rel_pos.len];
}

fn isPersonalityFunction(record_id: usize, rel: macho.relocation_info) bool {
    const base_offset = @intCast(i32, record_id * @sizeOf(macho.compact_unwind_entry));
    const rel_offset = rel.r_address - base_offset;
    return rel_offset == 16;
}

pub fn getPersonalityFunctionReloc(
    zld: *Zld,
    object_id: u32,
    record_id: usize,
) ?macho.relocation_info {
    const relocs = getRelocs(zld, object_id, record_id);
    for (relocs) |rel| {
        if (isPersonalityFunction(record_id, rel)) return rel;
    }
    return null;
}

fn getPersonalityFunction(info: UnwindInfo, global_index: SymbolWithLoc) ?u2 {
    comptime var index: u2 = 0;
    inline while (index < max_personalities) : (index += 1) {
        if (index >= info.personalities_count) return null;
        if (info.personalities[index].eql(global_index)) {
            return index;
        }
    }
    return null;
}

fn isLsda(record_id: usize, rel: macho.relocation_info) bool {
    const base_offset = @intCast(i32, record_id * @sizeOf(macho.compact_unwind_entry));
    const rel_offset = rel.r_address - base_offset;
    return rel_offset == 24;
}

pub fn getLsdaReloc(zld: *Zld, object_id: u32, record_id: usize) ?macho.relocation_info {
    const relocs = getRelocs(zld, object_id, record_id);
    for (relocs) |rel| {
        if (isLsda(record_id, rel)) return rel;
    }
    return null;
}

pub fn isNull(rec: macho.compact_unwind_entry) bool {
    return rec.rangeStart == 0 and
        rec.rangeLength == 0 and
        rec.compactUnwindEncoding == 0 and
        rec.lsda == 0 and
        rec.personalityFunction == 0;
}

inline fn nullRecord() macho.compact_unwind_entry {
    return .{
        .rangeStart = 0,
        .rangeLength = 0,
        .compactUnwindEncoding = 0,
        .personalityFunction = 0,
        .lsda = 0,
    };
}

fn appendCommonEncoding(info: *UnwindInfo, enc: macho.compact_unwind_encoding_t) void {
    assert(info.common_encodings_count <= max_common_encodings);
    info.common_encodings[info.common_encodings_count] = enc;
    info.common_encodings_count += 1;
}

fn getCommonEncoding(info: UnwindInfo, enc: macho.compact_unwind_encoding_t) ?u7 {
    comptime var index: u7 = 0;
    inline while (index < max_common_encodings) : (index += 1) {
        if (index >= info.common_encodings_count) return null;
        if (info.common_encodings[index] == enc) {
            return index;
        }
    }
    return null;
}

pub const UnwindEncoding = struct {
    pub fn getMode(enc: macho.compact_unwind_encoding_t) u4 {
        comptime assert(macho.UNWIND_ARM64_MODE_MASK == macho.UNWIND_X86_64_MODE_MASK);
        return @truncate(u4, (enc & macho.UNWIND_ARM64_MODE_MASK) >> 24);
    }

    pub fn isDwarf(enc: macho.compact_unwind_encoding_t, cpu_arch: std.Target.Cpu.Arch) bool {
        const mode = getMode(enc);
        return switch (cpu_arch) {
            .aarch64 => @intToEnum(macho.UNWIND_ARM64_MODE, mode) == .DWARF,
            .x86_64 => @intToEnum(macho.UNWIND_X86_64_MODE, mode) == .DWARF,
            else => unreachable,
        };
    }

    pub fn setMode(enc: *macho.compact_unwind_encoding_t, mode: anytype) void {
        enc.* |= @intCast(u32, @enumToInt(mode)) << 24;
    }

    pub fn hasLsda(enc: macho.compact_unwind_encoding_t) bool {
        const has_lsda = @truncate(u1, (enc & macho.UNWIND_HAS_LSDA) >> 31);
        return has_lsda == 1;
    }

    pub fn setHasLsda(enc: *macho.compact_unwind_encoding_t, has_lsda: bool) void {
        const mask = @intCast(u32, @boolToInt(has_lsda)) << 31;
        enc.* |= mask;
    }

    pub fn getPersonalityIndex(enc: macho.compact_unwind_encoding_t) u2 {
        const index = @truncate(u2, (enc & macho.UNWIND_PERSONALITY_MASK) >> 28);
        return index;
    }

    pub fn setPersonalityIndex(enc: *macho.compact_unwind_encoding_t, index: u2) void {
        const mask = @intCast(u32, index) << 28;
        enc.* |= mask;
    }

    pub fn getDwarfSectionOffset(enc: macho.compact_unwind_encoding_t, cpu_arch: std.Target.Cpu.Arch) u24 {
        assert(isDwarf(enc, cpu_arch));
        const offset = @truncate(u24, enc);
        return offset;
    }

    pub fn setDwarfSectionOffset(enc: *macho.compact_unwind_encoding_t, cpu_arch: std.Target.Cpu.Arch, offset: u24) void {
        assert(isDwarf(enc.*, cpu_arch));
        enc.* |= offset;
    }
};
