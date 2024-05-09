/// List of all unwind records gathered from all objects and sorted
/// by allocated relative function address within the section.
records: std.ArrayListUnmanaged(Record.Index) = .{},

/// List of all personalities referenced by either unwind info entries
/// or __eh_frame entries.
personalities: [max_personalities]Symbol.Index = undefined,
personalities_count: u2 = 0,

/// List of common encodings sorted in descending order with the most common first.
common_encodings: [max_common_encodings]Encoding = undefined,
common_encodings_count: u7 = 0,

/// List of record indexes containing an LSDA pointer.
lsdas: std.ArrayListUnmanaged(u32) = .{},
lsdas_lookup: std.ArrayListUnmanaged(u32) = .{},

/// List of second level pages.
pages: std.ArrayListUnmanaged(Page) = .{},

pub fn deinit(info: *UnwindInfo, allocator: Allocator) void {
    info.records.deinit(allocator);
    info.pages.deinit(allocator);
    info.lsdas.deinit(allocator);
    info.lsdas_lookup.deinit(allocator);
}

fn canFold(macho_file: *MachO, lhs_index: Record.Index, rhs_index: Record.Index) bool {
    const cpu_arch = macho_file.getTarget().cpu.arch;
    const lhs = macho_file.getUnwindRecord(lhs_index);
    const rhs = macho_file.getUnwindRecord(rhs_index);
    if (cpu_arch == .x86_64) {
        if (lhs.enc.getMode() == @intFromEnum(macho.UNWIND_X86_64_MODE.STACK_IND) or
            rhs.enc.getMode() == @intFromEnum(macho.UNWIND_X86_64_MODE.STACK_IND)) return false;
    }
    const lhs_per = lhs.personality orelse 0;
    const rhs_per = rhs.personality orelse 0;
    return lhs.enc.eql(rhs.enc) and
        lhs_per == rhs_per and
        lhs.fde == rhs.fde and
        lhs.getLsdaAtom(macho_file) == null and rhs.getLsdaAtom(macho_file) == null;
}

pub fn generate(info: *UnwindInfo, macho_file: *MachO) !void {
    const gpa = macho_file.base.comp.gpa;

    log.debug("generating unwind info", .{});

    // Collect all unwind records
    for (macho_file.sections.items(.atoms)) |atoms| {
        for (atoms.items) |atom_index| {
            const atom = macho_file.getAtom(atom_index) orelse continue;
            if (!atom.flags.alive) continue;
            const recs = atom.getUnwindRecords(macho_file);
            try info.records.ensureUnusedCapacity(gpa, recs.len);
            for (recs) |rec| {
                if (!macho_file.getUnwindRecord(rec).alive) continue;
                info.records.appendAssumeCapacity(rec);
            }
        }
    }

    // Encode records
    for (info.records.items) |index| {
        const rec = macho_file.getUnwindRecord(index);
        if (rec.getFde(macho_file)) |fde| {
            rec.enc.setDwarfSectionOffset(@intCast(fde.out_offset));
            if (fde.getLsdaAtom(macho_file)) |lsda| {
                rec.lsda = lsda.atom_index;
                rec.lsda_offset = fde.lsda_offset;
                rec.enc.setHasLsda(true);
            }
            const cie = fde.getCie(macho_file);
            if (cie.getPersonality(macho_file)) |_| {
                const personality_index = try info.getOrPutPersonalityFunction(cie.personality.?.index); // TODO handle error
                rec.enc.setPersonalityIndex(personality_index + 1);
            }
        } else if (rec.getPersonality(macho_file)) |_| {
            const personality_index = try info.getOrPutPersonalityFunction(rec.personality.?); // TODO handle error
            rec.enc.setPersonalityIndex(personality_index + 1);
        }
    }

    // Sort by assigned relative address within each output section
    const sortFn = struct {
        fn sortFn(ctx: *MachO, lhs_index: Record.Index, rhs_index: Record.Index) bool {
            const lhs = ctx.getUnwindRecord(lhs_index);
            const rhs = ctx.getUnwindRecord(rhs_index);
            const lhsa = lhs.getAtom(ctx);
            const rhsa = rhs.getAtom(ctx);
            if (lhsa.out_n_sect == rhsa.out_n_sect) return lhs.getAtomAddress(ctx) < rhs.getAtomAddress(ctx);
            return lhsa.out_n_sect < rhsa.out_n_sect;
        }
    }.sortFn;
    mem.sort(Record.Index, info.records.items, macho_file, sortFn);

    // Fold the records
    // Any adjacent two records that share encoding can be folded into one.
    {
        var i: usize = 0;
        var j: usize = 1;
        while (j < info.records.items.len) : (j += 1) {
            if (canFold(macho_file, info.records.items[i], info.records.items[j])) {
                const rec = macho_file.getUnwindRecord(info.records.items[i]);
                rec.length += macho_file.getUnwindRecord(info.records.items[j]).length + 1;
            } else {
                i += 1;
                info.records.items[i] = info.records.items[j];
            }
        }
        info.records.shrinkAndFree(gpa, i + 1);
    }

    for (info.records.items) |rec_index| {
        const rec = macho_file.getUnwindRecord(rec_index);
        const atom = rec.getAtom(macho_file);
        log.debug("@{x}-{x} : {s} : rec({d}) : {}", .{
            rec.getAtomAddress(macho_file),
            rec.getAtomAddress(macho_file) + rec.length,
            atom.getName(macho_file),
            rec_index,
            rec.enc,
        });
    }

    // Calculate common encodings
    {
        const CommonEncWithCount = struct {
            enc: Encoding,
            count: u32,

            fn greaterThan(ctx: void, lhs: @This(), rhs: @This()) bool {
                _ = ctx;
                return lhs.count > rhs.count;
            }
        };

        const Context = struct {
            pub fn hash(ctx: @This(), key: Encoding) u32 {
                _ = ctx;
                return key.enc;
            }

            pub fn eql(
                ctx: @This(),
                key1: Encoding,
                key2: Encoding,
                b_index: usize,
            ) bool {
                _ = ctx;
                _ = b_index;
                return key1.eql(key2);
            }
        };

        var common_encodings_counts = std.ArrayHashMap(
            Encoding,
            CommonEncWithCount,
            Context,
            false,
        ).init(gpa);
        defer common_encodings_counts.deinit();

        for (info.records.items) |rec_index| {
            const rec = macho_file.getUnwindRecord(rec_index);
            if (rec.enc.isDwarf(macho_file)) continue;
            const gop = try common_encodings_counts.getOrPut(rec.enc);
            if (!gop.found_existing) {
                gop.value_ptr.* = .{
                    .enc = rec.enc,
                    .count = 0,
                };
            }
            gop.value_ptr.count += 1;
        }

        const slice = common_encodings_counts.values();
        mem.sort(CommonEncWithCount, slice, {}, CommonEncWithCount.greaterThan);

        var i: u7 = 0;
        while (i < slice.len) : (i += 1) {
            if (i >= max_common_encodings) break;
            if (slice[i].count < 2) continue;
            info.appendCommonEncoding(slice[i].enc);
            log.debug("adding common encoding: {d} => {}", .{ i, slice[i].enc });
        }
    }

    // Compute page allocations
    {
        var i: u32 = 0;
        while (i < info.records.items.len) {
            const rec = macho_file.getUnwindRecord(info.records.items[i]);
            const range_start_max: u64 = rec.getAtomAddress(macho_file) + compressed_entry_func_offset_mask;
            var encoding_count: u9 = info.common_encodings_count;
            var space_left: u32 = second_level_page_words -
                @sizeOf(macho.unwind_info_compressed_second_level_page_header) / @sizeOf(u32);
            var page = Page{
                .kind = undefined,
                .start = i,
                .count = 0,
            };

            while (space_left >= 1 and i < info.records.items.len) {
                const next = macho_file.getUnwindRecord(info.records.items[i]);
                const is_dwarf = next.enc.isDwarf(macho_file);

                if (next.getAtomAddress(macho_file) >= range_start_max) {
                    break;
                } else if (info.getCommonEncoding(next.enc) != null or
                    page.getPageEncoding(next.enc) != null and !is_dwarf)
                {
                    i += 1;
                    space_left -= 1;
                } else if (space_left >= 2 and encoding_count < max_compact_encodings) {
                    page.appendPageEncoding(next.enc);
                    i += 1;
                    space_left -= 2;
                    encoding_count += 1;
                } else {
                    break;
                }
            }

            page.count = @as(u16, @intCast(i - page.start));

            if (i < info.records.items.len and page.count < max_regular_second_level_entries) {
                page.kind = .regular;
                page.count = @as(u16, @intCast(@min(
                    max_regular_second_level_entries,
                    info.records.items.len - page.start,
                )));
                i = page.start + page.count;
            } else {
                page.kind = .compressed;
            }

            log.debug("{}", .{page.fmt(info.*)});

            try info.pages.append(gpa, page);
        }
    }

    // Save records having an LSDA pointer
    log.debug("LSDA pointers:", .{});
    try info.lsdas_lookup.ensureTotalCapacityPrecise(gpa, info.records.items.len);
    for (info.records.items, 0..) |index, i| {
        const rec = macho_file.getUnwindRecord(index);
        info.lsdas_lookup.appendAssumeCapacity(@intCast(info.lsdas.items.len));
        if (rec.getLsdaAtom(macho_file)) |lsda| {
            log.debug("  @{x} => lsda({d})", .{ rec.getAtomAddress(macho_file), lsda.atom_index });
            try info.lsdas.append(gpa, @intCast(i));
        }
    }
}

pub fn calcSize(info: UnwindInfo) usize {
    var total_size: usize = 0;
    total_size += @sizeOf(macho.unwind_info_section_header);
    total_size +=
        @as(usize, @intCast(info.common_encodings_count)) * @sizeOf(macho.compact_unwind_encoding_t);
    total_size += @as(usize, @intCast(info.personalities_count)) * @sizeOf(u32);
    total_size += (info.pages.items.len + 1) * @sizeOf(macho.unwind_info_section_header_index_entry);
    total_size += info.lsdas.items.len * @sizeOf(macho.unwind_info_section_header_lsda_index_entry);
    total_size += info.pages.items.len * second_level_page_bytes;
    return total_size;
}

pub fn write(info: UnwindInfo, macho_file: *MachO, buffer: []u8) !void {
    const seg = macho_file.getTextSegment();
    const header = macho_file.sections.items(.header)[macho_file.unwind_info_sect_index.?];

    var stream = std.io.fixedBufferStream(buffer);
    const writer = stream.writer();

    const common_encodings_offset: u32 = @sizeOf(macho.unwind_info_section_header);
    const common_encodings_count: u32 = info.common_encodings_count;
    const personalities_offset: u32 = common_encodings_offset + common_encodings_count * @sizeOf(u32);
    const personalities_count: u32 = info.personalities_count;
    const indexes_offset: u32 = personalities_offset + personalities_count * @sizeOf(u32);
    const indexes_count: u32 = @as(u32, @intCast(info.pages.items.len + 1));

    try writer.writeStruct(macho.unwind_info_section_header{
        .commonEncodingsArraySectionOffset = common_encodings_offset,
        .commonEncodingsArrayCount = common_encodings_count,
        .personalityArraySectionOffset = personalities_offset,
        .personalityArrayCount = personalities_count,
        .indexSectionOffset = indexes_offset,
        .indexCount = indexes_count,
    });

    try writer.writeAll(mem.sliceAsBytes(info.common_encodings[0..info.common_encodings_count]));

    for (info.personalities[0..info.personalities_count]) |sym_index| {
        const sym = macho_file.getSymbol(sym_index);
        try writer.writeInt(u32, @intCast(sym.getGotAddress(macho_file) - seg.vmaddr), .little);
    }

    const pages_base_offset = @as(u32, @intCast(header.size - (info.pages.items.len * second_level_page_bytes)));
    const lsda_base_offset = @as(u32, @intCast(pages_base_offset -
        (info.lsdas.items.len * @sizeOf(macho.unwind_info_section_header_lsda_index_entry))));
    for (info.pages.items, 0..) |page, i| {
        assert(page.count > 0);
        const rec = macho_file.getUnwindRecord(info.records.items[page.start]);
        try writer.writeStruct(macho.unwind_info_section_header_index_entry{
            .functionOffset = @as(u32, @intCast(rec.getAtomAddress(macho_file) - seg.vmaddr)),
            .secondLevelPagesSectionOffset = @as(u32, @intCast(pages_base_offset + i * second_level_page_bytes)),
            .lsdaIndexArraySectionOffset = lsda_base_offset +
                info.lsdas_lookup.items[page.start] * @sizeOf(macho.unwind_info_section_header_lsda_index_entry),
        });
    }

    const last_rec = macho_file.getUnwindRecord(info.records.items[info.records.items.len - 1]);
    const sentinel_address = @as(u32, @intCast(last_rec.getAtomAddress(macho_file) + last_rec.length - seg.vmaddr));
    try writer.writeStruct(macho.unwind_info_section_header_index_entry{
        .functionOffset = sentinel_address,
        .secondLevelPagesSectionOffset = 0,
        .lsdaIndexArraySectionOffset = lsda_base_offset +
            @as(u32, @intCast(info.lsdas.items.len)) * @sizeOf(macho.unwind_info_section_header_lsda_index_entry),
    });

    for (info.lsdas.items) |index| {
        const rec = macho_file.getUnwindRecord(info.records.items[index]);
        try writer.writeStruct(macho.unwind_info_section_header_lsda_index_entry{
            .functionOffset = @as(u32, @intCast(rec.getAtomAddress(macho_file) - seg.vmaddr)),
            .lsdaOffset = @as(u32, @intCast(rec.getLsdaAddress(macho_file) - seg.vmaddr)),
        });
    }

    for (info.pages.items) |page| {
        const start = stream.pos;
        try page.write(info, macho_file, writer);
        const nwritten = stream.pos - start;
        if (nwritten < second_level_page_bytes) {
            const padding = math.cast(usize, second_level_page_bytes - nwritten) orelse return error.Overflow;
            try writer.writeByteNTimes(0, padding);
        }
    }

    @memset(buffer[stream.pos..], 0);
}

fn getOrPutPersonalityFunction(info: *UnwindInfo, sym_index: Symbol.Index) error{TooManyPersonalities}!u2 {
    comptime var index: u2 = 0;
    inline while (index < max_personalities) : (index += 1) {
        if (info.personalities[index] == sym_index) {
            return index;
        } else if (index == info.personalities_count) {
            info.personalities[index] = sym_index;
            info.personalities_count += 1;
            return index;
        }
    }
    return error.TooManyPersonalities;
}

fn appendCommonEncoding(info: *UnwindInfo, enc: Encoding) void {
    assert(info.common_encodings_count <= max_common_encodings);
    info.common_encodings[info.common_encodings_count] = enc;
    info.common_encodings_count += 1;
}

fn getCommonEncoding(info: UnwindInfo, enc: Encoding) ?u7 {
    comptime var index: u7 = 0;
    inline while (index < max_common_encodings) : (index += 1) {
        if (index >= info.common_encodings_count) return null;
        if (info.common_encodings[index].eql(enc)) {
            return index;
        }
    }
    return null;
}

pub const Encoding = extern struct {
    enc: macho.compact_unwind_encoding_t,

    pub fn getMode(enc: Encoding) u4 {
        comptime assert(macho.UNWIND_ARM64_MODE_MASK == macho.UNWIND_X86_64_MODE_MASK);
        const shift = comptime @ctz(macho.UNWIND_ARM64_MODE_MASK);
        return @as(u4, @truncate((enc.enc & macho.UNWIND_ARM64_MODE_MASK) >> shift));
    }

    pub fn isDwarf(enc: Encoding, macho_file: *MachO) bool {
        const mode = enc.getMode();
        return switch (macho_file.getTarget().cpu.arch) {
            .aarch64 => @as(macho.UNWIND_ARM64_MODE, @enumFromInt(mode)) == .DWARF,
            .x86_64 => @as(macho.UNWIND_X86_64_MODE, @enumFromInt(mode)) == .DWARF,
            else => unreachable,
        };
    }

    pub fn setMode(enc: *Encoding, mode: anytype) void {
        comptime assert(macho.UNWIND_ARM64_MODE_MASK == macho.UNWIND_X86_64_MODE_MASK);
        const shift = comptime @ctz(macho.UNWIND_ARM64_MODE_MASK);
        enc.enc |= @as(u32, @intCast(@intFromEnum(mode))) << shift;
    }

    pub fn hasLsda(enc: Encoding) bool {
        const shift = comptime @ctz(macho.UNWIND_HAS_LSDA);
        const has_lsda = @as(u1, @truncate((enc.enc & macho.UNWIND_HAS_LSDA) >> shift));
        return has_lsda == 1;
    }

    pub fn setHasLsda(enc: *Encoding, has_lsda: bool) void {
        const shift = comptime @ctz(macho.UNWIND_HAS_LSDA);
        const mask = @as(u32, @intCast(@intFromBool(has_lsda))) << shift;
        enc.enc |= mask;
    }

    pub fn getPersonalityIndex(enc: Encoding) u2 {
        const shift = comptime @ctz(macho.UNWIND_PERSONALITY_MASK);
        const index = @as(u2, @truncate((enc.enc & macho.UNWIND_PERSONALITY_MASK) >> shift));
        return index;
    }

    pub fn setPersonalityIndex(enc: *Encoding, index: u2) void {
        const shift = comptime @ctz(macho.UNWIND_PERSONALITY_MASK);
        const mask = @as(u32, @intCast(index)) << shift;
        enc.enc |= mask;
    }

    pub fn getDwarfSectionOffset(enc: Encoding) u24 {
        const offset = @as(u24, @truncate(enc.enc));
        return offset;
    }

    pub fn setDwarfSectionOffset(enc: *Encoding, offset: u24) void {
        enc.enc |= offset;
    }

    pub fn eql(enc: Encoding, other: Encoding) bool {
        return enc.enc == other.enc;
    }

    pub fn format(
        enc: Encoding,
        comptime unused_fmt_string: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = unused_fmt_string;
        _ = options;
        try writer.print("0x{x:0>8}", .{enc.enc});
    }
};

pub const Record = struct {
    length: u32 = 0,
    enc: Encoding = .{ .enc = 0 },
    atom: Atom.Index = 0,
    atom_offset: u32 = 0,
    lsda: Atom.Index = 0,
    lsda_offset: u32 = 0,
    personality: ?Symbol.Index = null, // TODO make this zero-is-null
    fde: Fde.Index = 0, // TODO actually make FDE at 0 an invalid FDE
    file: File.Index = 0,
    alive: bool = true,

    pub fn getObject(rec: Record, macho_file: *MachO) *Object {
        return macho_file.getFile(rec.file).?.object;
    }

    pub fn getAtom(rec: Record, macho_file: *MachO) *Atom {
        return macho_file.getAtom(rec.atom).?;
    }

    pub fn getLsdaAtom(rec: Record, macho_file: *MachO) ?*Atom {
        return macho_file.getAtom(rec.lsda);
    }

    pub fn getPersonality(rec: Record, macho_file: *MachO) ?*Symbol {
        const personality = rec.personality orelse return null;
        return macho_file.getSymbol(personality);
    }

    pub fn getFde(rec: Record, macho_file: *MachO) ?Fde {
        if (!rec.enc.isDwarf(macho_file)) return null;
        return rec.getObject(macho_file).fdes.items[rec.fde];
    }

    pub fn getFdePtr(rec: Record, macho_file: *MachO) ?*Fde {
        if (!rec.enc.isDwarf(macho_file)) return null;
        return &rec.getObject(macho_file).fdes.items[rec.fde];
    }

    pub fn getAtomAddress(rec: Record, macho_file: *MachO) u64 {
        const atom = rec.getAtom(macho_file);
        return atom.getAddress(macho_file) + rec.atom_offset;
    }

    pub fn getLsdaAddress(rec: Record, macho_file: *MachO) u64 {
        const lsda = rec.getLsdaAtom(macho_file) orelse return 0;
        return lsda.getAddress(macho_file) + rec.lsda_offset;
    }

    pub fn format(
        rec: Record,
        comptime unused_fmt_string: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = rec;
        _ = unused_fmt_string;
        _ = options;
        _ = writer;
        @compileError("do not format UnwindInfo.Records directly");
    }

    pub fn fmt(rec: Record, macho_file: *MachO) std.fmt.Formatter(format2) {
        return .{ .data = .{
            .rec = rec,
            .macho_file = macho_file,
        } };
    }

    const FormatContext = struct {
        rec: Record,
        macho_file: *MachO,
    };

    fn format2(
        ctx: FormatContext,
        comptime unused_fmt_string: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = unused_fmt_string;
        _ = options;
        const rec = ctx.rec;
        const macho_file = ctx.macho_file;
        try writer.print("{x} : len({x})", .{
            rec.enc.enc, rec.length,
        });
        if (rec.enc.isDwarf(macho_file)) try writer.print(" : fde({d})", .{rec.fde});
        try writer.print(" : {s}", .{rec.getAtom(macho_file).getName(macho_file)});
        if (!rec.alive) try writer.writeAll(" : [*]");
    }

    pub const Index = u32;
};

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
    start: u32,
    count: u16,
    page_encodings: [max_compact_encodings]Encoding = undefined,
    page_encodings_count: u9 = 0,

    fn appendPageEncoding(page: *Page, enc: Encoding) void {
        assert(page.page_encodings_count <= max_compact_encodings);
        page.page_encodings[page.page_encodings_count] = enc;
        page.page_encodings_count += 1;
    }

    fn getPageEncoding(page: Page, enc: Encoding) ?u8 {
        comptime var index: u9 = 0;
        inline while (index < max_compact_encodings) : (index += 1) {
            if (index >= page.page_encodings_count) return null;
            if (page.page_encodings[index].eql(enc)) {
                return @as(u8, @intCast(index));
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
        @compileError("do not format Page directly; use page.fmt()");
    }

    const FormatPageContext = struct {
        page: Page,
        info: UnwindInfo,
    };

    fn format2(
        ctx: FormatPageContext,
        comptime unused_format_string: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        _ = options;
        _ = unused_format_string;
        try writer.writeAll("Page:\n");
        try writer.print("  kind: {s}\n", .{@tagName(ctx.page.kind)});
        try writer.print("  entries: {d} - {d}\n", .{
            ctx.page.start,
            ctx.page.start + ctx.page.count,
        });
        try writer.print("  encodings (count = {d})\n", .{ctx.page.page_encodings_count});
        for (ctx.page.page_encodings[0..ctx.page.page_encodings_count], 0..) |enc, i| {
            try writer.print("    {d}: {}\n", .{ ctx.info.common_encodings_count + i, enc });
        }
    }

    fn fmt(page: Page, info: UnwindInfo) std.fmt.Formatter(format2) {
        return .{ .data = .{
            .page = page,
            .info = info,
        } };
    }

    fn write(page: Page, info: UnwindInfo, macho_file: *MachO, writer: anytype) !void {
        const seg = macho_file.getTextSegment();

        switch (page.kind) {
            .regular => {
                try writer.writeStruct(macho.unwind_info_regular_second_level_page_header{
                    .entryPageOffset = @sizeOf(macho.unwind_info_regular_second_level_page_header),
                    .entryCount = page.count,
                });

                for (info.records.items[page.start..][0..page.count]) |index| {
                    const rec = macho_file.getUnwindRecord(index);
                    try writer.writeStruct(macho.unwind_info_regular_second_level_entry{
                        .functionOffset = @as(u32, @intCast(rec.getAtomAddress(macho_file) - seg.vmaddr)),
                        .encoding = rec.enc.enc,
                    });
                }
            },
            .compressed => {
                const entry_offset = @sizeOf(macho.unwind_info_compressed_second_level_page_header) +
                    @as(u16, @intCast(page.page_encodings_count)) * @sizeOf(u32);
                try writer.writeStruct(macho.unwind_info_compressed_second_level_page_header{
                    .entryPageOffset = entry_offset,
                    .entryCount = page.count,
                    .encodingsPageOffset = @sizeOf(macho.unwind_info_compressed_second_level_page_header),
                    .encodingsCount = page.page_encodings_count,
                });

                for (page.page_encodings[0..page.page_encodings_count]) |enc| {
                    try writer.writeInt(u32, enc.enc, .little);
                }

                assert(page.count > 0);
                const first_rec = macho_file.getUnwindRecord(info.records.items[page.start]);
                for (info.records.items[page.start..][0..page.count]) |index| {
                    const rec = macho_file.getUnwindRecord(index);
                    const enc_index = blk: {
                        if (info.getCommonEncoding(rec.enc)) |id| break :blk id;
                        const ncommon = info.common_encodings_count;
                        break :blk ncommon + page.getPageEncoding(rec.enc).?;
                    };
                    const compressed = macho.UnwindInfoCompressedEntry{
                        .funcOffset = @as(u24, @intCast(rec.getAtomAddress(macho_file) - first_rec.getAtomAddress(macho_file))),
                        .encodingIndex = @as(u8, @intCast(enc_index)),
                    };
                    try writer.writeStruct(compressed);
                }
            },
        }
    }
};

const std = @import("std");
const assert = std.debug.assert;
const eh_frame = @import("eh_frame.zig");
const fs = std.fs;
const leb = std.leb;
const log = std.log.scoped(.link);
const macho = std.macho;
const math = std.math;
const mem = std.mem;
const trace = @import("../../tracy.zig").trace;

const Allocator = mem.Allocator;
const Atom = @import("Atom.zig");
const Fde = eh_frame.Fde;
const File = @import("file.zig").File;
const MachO = @import("../MachO.zig");
const Object = @import("Object.zig");
const Symbol = @import("Symbol.zig");
const UnwindInfo = @This();
