pub fn flush(macho_file: *MachO) !void {
    markExports(macho_file);
    claimUnresolved(macho_file);
    try initOutputSections(macho_file);
    try macho_file.sortSections();
    try macho_file.addAtomsToSections();
    try calcSectionSizes(macho_file);

    {
        // For relocatable, we only ever need a single segment so create it now.
        const prot: macho.vm_prot_t = macho.PROT.READ | macho.PROT.WRITE | macho.PROT.EXEC;
        try macho_file.segments.append(macho_file.base.allocator, .{
            .cmdsize = @sizeOf(macho.segment_command_64),
            .segname = MachO.makeStaticString(""),
            .maxprot = prot,
            .initprot = prot,
        });
        const seg = &macho_file.segments.items[0];
        seg.nsects = @intCast(macho_file.sections.items(.header).len);
        seg.cmdsize += seg.nsects * @sizeOf(macho.section_64);
    }

    var off = try allocateSections(macho_file);

    {
        // Allocate the single segment.
        assert(macho_file.segments.items.len == 1);
        const seg = &macho_file.segments.items[0];
        var vmaddr: u64 = 0;
        var fileoff: u64 = load_commands.calcLoadCommandsSizeObject(macho_file) + @sizeOf(macho.mach_header_64);
        seg.vmaddr = vmaddr;
        seg.fileoff = fileoff;

        for (macho_file.sections.items(.header)) |header| {
            vmaddr = header.addr + header.size;
            if (!header.isZerofill()) {
                fileoff = header.offset + header.size;
            }
        }

        seg.vmsize = vmaddr - seg.vmaddr;
        seg.filesize = fileoff - seg.fileoff;
    }

    macho_file.allocateAtoms();

    state_log.debug("{}", .{macho_file.dumpState()});

    try macho_file.calcSymtabSize();
    try writeAtoms(macho_file);
    try writeCompactUnwind(macho_file);
    try writeEhFrame(macho_file);

    off = mem.alignForward(u32, off, @alignOf(u64));
    off = try macho_file.writeDataInCode(0, off);
    off = mem.alignForward(u32, off, @alignOf(u64));
    off = try macho_file.writeSymtab(off);
    off = mem.alignForward(u32, off, @alignOf(u64));
    off = try macho_file.writeStrtab(off);

    const ncmds, const sizeofcmds = try writeLoadCommands(macho_file);
    try writeHeader(macho_file, ncmds, sizeofcmds);
}

fn markExports(macho_file: *MachO) void {
    for (macho_file.objects.items) |index| {
        for (macho_file.getFile(index).?.getSymbols()) |sym_index| {
            const sym = macho_file.getSymbol(sym_index);
            const file = sym.getFile(macho_file) orelse continue;
            if (sym.visibility != .global) continue;
            if (file.getIndex() == index) {
                sym.flags.@"export" = true;
            }
        }
    }
}

fn claimUnresolved(macho_file: *MachO) void {
    for (macho_file.objects.items) |index| {
        const object = macho_file.getFile(index).?.object;

        for (object.symbols.items, 0..) |sym_index, i| {
            const nlist_idx = @as(Symbol.Index, @intCast(i));
            const nlist = object.symtab.items(.nlist)[nlist_idx];
            if (!nlist.ext()) continue;
            if (!nlist.undf()) continue;

            const sym = macho_file.getSymbol(sym_index);
            if (sym.getFile(macho_file) != null) continue;

            sym.value = 0;
            sym.atom = 0;
            sym.nlist_idx = nlist_idx;
            sym.file = index;
            sym.flags.weak_ref = nlist.weakRef();
            sym.flags.import = true;
            sym.visibility = .global;
        }
    }
}

fn initOutputSections(macho_file: *MachO) !void {
    for (macho_file.objects.items) |index| {
        const object = macho_file.getFile(index).?.object;
        for (object.atoms.items) |atom_index| {
            const atom = macho_file.getAtom(atom_index) orelse continue;
            if (!atom.flags.alive) continue;
            atom.out_n_sect = try Atom.initOutputSection(atom.getInputSection(macho_file), macho_file);
        }
    }

    const needs_unwind_info = for (macho_file.objects.items) |index| {
        if (macho_file.getFile(index).?.object.compact_unwind_sect_index != null) break true;
    } else false;
    if (needs_unwind_info) {
        macho_file.unwind_info_sect_index = try macho_file.addSection("__LD", "__compact_unwind", .{
            .flags = macho.S_ATTR_DEBUG,
        });
    }

    const needs_eh_frame = for (macho_file.objects.items) |index| {
        if (macho_file.getFile(index).?.object.eh_frame_sect_index != null) break true;
    } else false;
    if (needs_eh_frame) {
        assert(needs_unwind_info);
        macho_file.eh_frame_sect_index = try macho_file.addSection("__TEXT", "__eh_frame", .{});
    }
}

fn calcSectionSizes(macho_file: *MachO) !void {
    const slice = macho_file.sections.slice();
    for (slice.items(.header), slice.items(.atoms)) |*header, atoms| {
        if (atoms.items.len == 0) continue;
        for (atoms.items) |atom_index| {
            const atom = macho_file.getAtom(atom_index).?;
            const atom_alignment = try math.powi(u32, 2, atom.alignment);
            const offset = mem.alignForward(u64, header.size, atom_alignment);
            const padding = offset - header.size;
            atom.value = offset;
            header.size += padding + atom.size;
            header.@"align" = @max(header.@"align", atom.alignment);
            header.nreloc += atom.calcNumRelocs(macho_file);
        }
    }

    if (macho_file.unwind_info_sect_index) |index| {
        calcCompactUnwindSize(macho_file, index);
    }

    if (macho_file.eh_frame_sect_index) |index| {
        const sect = &macho_file.sections.items(.header)[index];
        sect.size = try eh_frame.calcSize(macho_file);
        sect.@"align" = 3;
        sect.nreloc = eh_frame.calcNumRelocs(macho_file);
    }
}

fn calcCompactUnwindSize(macho_file: *MachO, sect_index: u8) void {
    var size: u32 = 0;
    var nreloc: u32 = 0;

    for (macho_file.objects.items) |index| {
        const object = macho_file.getFile(index).?.object;
        for (object.unwind_records.items) |irec| {
            const rec = macho_file.getUnwindRecord(irec);
            if (!rec.alive) continue;
            size += @sizeOf(macho.compact_unwind_entry);
            nreloc += 1;
            if (rec.getPersonality(macho_file)) |_| {
                nreloc += 1;
            }
            if (rec.getLsdaAtom(macho_file)) |_| {
                nreloc += 1;
            }
        }
    }

    const sect = &macho_file.sections.items(.header)[sect_index];
    sect.size = size;
    sect.nreloc = nreloc;
    sect.@"align" = 3;
}

fn allocateSections(macho_file: *MachO) !u32 {
    var fileoff = load_commands.calcLoadCommandsSizeObject(macho_file) + @sizeOf(macho.mach_header_64);
    var vmaddr: u64 = 0;
    const slice = macho_file.sections.slice();

    for (slice.items(.header)) |*header| {
        const alignment = try math.powi(u32, 2, header.@"align");
        vmaddr = mem.alignForward(u64, vmaddr, alignment);
        header.addr = vmaddr;
        vmaddr += header.size;

        if (!header.isZerofill()) {
            fileoff = mem.alignForward(u32, fileoff, alignment);
            header.offset = fileoff;
            fileoff += @intCast(header.size);
        }
    }

    for (slice.items(.header)) |*header| {
        if (header.nreloc == 0) continue;
        header.reloff = mem.alignForward(u32, fileoff, @alignOf(macho.relocation_info));
        fileoff = header.reloff + header.nreloc * @sizeOf(macho.relocation_info);
    }

    return fileoff;
}

// We need to sort relocations in descending order to be compatible with Apple's linker.
fn sortReloc(ctx: void, lhs: macho.relocation_info, rhs: macho.relocation_info) bool {
    _ = ctx;
    return lhs.r_address > rhs.r_address;
}

fn writeAtoms(macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = macho_file.base.allocator;
    const cpu_arch = macho_file.options.cpu_arch.?;
    const slice = macho_file.sections.slice();

    for (slice.items(.header), slice.items(.atoms)) |header, atoms| {
        if (atoms.items.len == 0) continue;
        if (header.isZerofill()) continue;

        const code = try gpa.alloc(u8, header.size);
        defer gpa.free(code);
        const padding_byte: u8 = if (header.isCode() and cpu_arch == .x86_64) 0xcc else 0;
        @memset(code, padding_byte);

        var relocs = try std.ArrayList(macho.relocation_info).initCapacity(gpa, header.nreloc);
        defer relocs.deinit();

        for (atoms.items) |atom_index| {
            const atom = macho_file.getAtom(atom_index).?;
            assert(atom.flags.alive);
            const off = atom.value - header.addr;
            @memcpy(code[off..][0..atom.size], atom.getCode(macho_file));
            try atom.writeRelocs(macho_file, code[off..][0..atom.size], &relocs);
        }

        assert(relocs.items.len == header.nreloc);

        mem.sort(macho.relocation_info, relocs.items, {}, sortReloc);

        // TODO scattered writes?
        try macho_file.base.file.pwriteAll(code, header.offset);
        try macho_file.base.file.pwriteAll(mem.sliceAsBytes(relocs.items), header.reloff);
    }
}

fn writeCompactUnwind(macho_file: *MachO) !void {
    const sect_index = macho_file.unwind_info_sect_index orelse return;
    const gpa = macho_file.base.allocator;
    const header = macho_file.sections.items(.header)[sect_index];

    const nrecs = @divExact(header.size, @sizeOf(macho.compact_unwind_entry));
    var entries = try std.ArrayList(macho.compact_unwind_entry).initCapacity(gpa, nrecs);
    defer entries.deinit();

    var relocs = try std.ArrayList(macho.relocation_info).initCapacity(gpa, header.nreloc);
    defer relocs.deinit();

    const addReloc = struct {
        fn addReloc(offset: i32, cpu_arch: std.Target.Cpu.Arch) macho.relocation_info {
            return .{
                .r_address = offset,
                .r_symbolnum = 0,
                .r_pcrel = 0,
                .r_length = 3,
                .r_extern = 0,
                .r_type = switch (cpu_arch) {
                    .aarch64 => @intFromEnum(macho.reloc_type_arm64.ARM64_RELOC_UNSIGNED),
                    .x86_64 => @intFromEnum(macho.reloc_type_x86_64.X86_64_RELOC_UNSIGNED),
                    else => unreachable,
                },
            };
        }
    }.addReloc;

    var offset: i32 = 0;
    for (macho_file.objects.items) |index| {
        const object = macho_file.getFile(index).?.object;
        for (object.unwind_records.items) |irec| {
            const rec = macho_file.getUnwindRecord(irec);
            if (!rec.alive) continue;

            var out: macho.compact_unwind_entry = .{
                .rangeStart = 0,
                .rangeLength = rec.length,
                .compactUnwindEncoding = rec.enc.enc,
                .personalityFunction = 0,
                .lsda = 0,
            };

            {
                // Function address
                const atom = rec.getAtom(macho_file);
                const addr = rec.getAtomAddress(macho_file);
                out.rangeStart = addr;
                var reloc = addReloc(offset, macho_file.options.cpu_arch.?);
                reloc.r_symbolnum = atom.out_n_sect + 1;
                relocs.appendAssumeCapacity(reloc);
            }

            // Personality function
            if (rec.getPersonality(macho_file)) |sym| {
                const r_symbolnum = math.cast(u24, sym.getOutputSymtabIndex(macho_file).?) orelse return error.Overflow;
                var reloc = addReloc(offset + 16, macho_file.options.cpu_arch.?);
                reloc.r_symbolnum = r_symbolnum;
                reloc.r_extern = 1;
                relocs.appendAssumeCapacity(reloc);
            }

            // LSDA address
            if (rec.getLsdaAtom(macho_file)) |atom| {
                const addr = rec.getLsdaAddress(macho_file);
                out.lsda = addr;
                var reloc = addReloc(offset + 24, macho_file.options.cpu_arch.?);
                reloc.r_symbolnum = atom.out_n_sect + 1;
                relocs.appendAssumeCapacity(reloc);
            }

            entries.appendAssumeCapacity(out);
            offset += @sizeOf(macho.compact_unwind_entry);
        }
    }

    assert(entries.items.len == nrecs);
    assert(relocs.items.len == header.nreloc);

    mem.sort(macho.relocation_info, relocs.items, {}, sortReloc);

    // TODO scattered writes?
    try macho_file.base.file.pwriteAll(mem.sliceAsBytes(entries.items), header.offset);
    try macho_file.base.file.pwriteAll(mem.sliceAsBytes(relocs.items), header.reloff);
}

fn writeEhFrame(macho_file: *MachO) !void {
    const sect_index = macho_file.eh_frame_sect_index orelse return;
    const gpa = macho_file.base.allocator;
    const header = macho_file.sections.items(.header)[sect_index];

    const code = try gpa.alloc(u8, header.size);
    defer gpa.free(code);

    var relocs = try std.ArrayList(macho.relocation_info).initCapacity(gpa, header.nreloc);
    defer relocs.deinit();

    try eh_frame.writeRelocs(macho_file, code, &relocs);
    assert(relocs.items.len == header.nreloc);

    mem.sort(macho.relocation_info, relocs.items, {}, sortReloc);

    // TODO scattered writes?
    try macho_file.base.file.pwriteAll(code, header.offset);
    try macho_file.base.file.pwriteAll(mem.sliceAsBytes(relocs.items), header.reloff);
}

fn writeLoadCommands(macho_file: *MachO) !struct { usize, usize } {
    const gpa = macho_file.base.allocator;
    const needed_size = load_commands.calcLoadCommandsSizeObject(macho_file);
    const buffer = try gpa.alloc(u8, needed_size);
    defer gpa.free(buffer);

    var stream = std.io.fixedBufferStream(buffer);
    var cwriter = std.io.countingWriter(stream.writer());
    const writer = cwriter.writer();

    var ncmds: usize = 0;

    // Segment and section load commands
    {
        assert(macho_file.segments.items.len == 1);
        const seg = macho_file.segments.items[0];
        try writer.writeStruct(seg);
        for (macho_file.sections.items(.header)) |header| {
            try writer.writeStruct(header);
        }
        ncmds += 1;
    }

    try writer.writeStruct(macho_file.data_in_code_cmd);
    ncmds += 1;
    try writer.writeStruct(macho_file.symtab_cmd);
    ncmds += 1;
    try writer.writeStruct(macho_file.dysymtab_cmd);
    ncmds += 1;

    if (macho_file.options.platform) |platform| {
        if (platform.isBuildVersionCompatible()) {
            try load_commands.writeBuildVersionLC(platform, macho_file.options.sdk_version, writer);
            ncmds += 1;
        } else {
            try load_commands.writeVersionMinLC(platform, macho_file.options.sdk_version, writer);
            ncmds += 1;
        }
    }

    assert(cwriter.bytes_written == needed_size);

    try macho_file.base.file.pwriteAll(buffer, @sizeOf(macho.mach_header_64));

    return .{ ncmds, buffer.len };
}

fn writeHeader(macho_file: *MachO, ncmds: usize, sizeofcmds: usize) !void {
    var header: macho.mach_header_64 = .{};
    header.filetype = macho.MH_OBJECT;

    const subsections_via_symbols = for (macho_file.objects.items) |index| {
        const object = macho_file.getFile(index).?.object;
        if (object.hasSubsections()) break true;
    } else false;
    if (subsections_via_symbols) {
        header.flags |= macho.MH_SUBSECTIONS_VIA_SYMBOLS;
    }

    switch (macho_file.options.cpu_arch.?) {
        .aarch64 => {
            header.cputype = macho.CPU_TYPE_ARM64;
            header.cpusubtype = macho.CPU_SUBTYPE_ARM_ALL;
        },
        .x86_64 => {
            header.cputype = macho.CPU_TYPE_X86_64;
            header.cpusubtype = macho.CPU_SUBTYPE_X86_64_ALL;
        },
        else => {},
    }

    header.ncmds = @intCast(ncmds);
    header.sizeofcmds = @intCast(sizeofcmds);

    try macho_file.base.file.pwriteAll(mem.asBytes(&header), 0);
}

const assert = std.debug.assert;
const eh_frame = @import("eh_frame.zig");
const load_commands = @import("load_commands.zig");
const macho = std.macho;
const math = std.math;
const mem = std.mem;
const state_log = std.log.scoped(.state);
const std = @import("std");
const trace = @import("../tracy.zig").trace;

const Atom = @import("Atom.zig");
const MachO = @import("../MachO.zig");
const Symbol = @import("Symbol.zig");
