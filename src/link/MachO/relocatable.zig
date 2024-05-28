pub fn flushObject(macho_file: *MachO, comp: *Compilation, module_obj_path: ?[]const u8) link.File.FlushError!void {
    const gpa = macho_file.base.comp.gpa;

    var positionals = std.ArrayList(Compilation.LinkObject).init(gpa);
    defer positionals.deinit();
    try positionals.ensureUnusedCapacity(comp.objects.len);
    positionals.appendSliceAssumeCapacity(comp.objects);

    for (comp.c_object_table.keys()) |key| {
        try positionals.append(.{ .path = key.status.success.object_path });
    }

    if (module_obj_path) |path| try positionals.append(.{ .path = path });

    if (macho_file.getZigObject() == null and positionals.items.len == 1) {
        // Instead of invoking a full-blown `-r` mode on the input which sadly will strip all
        // debug info segments/sections (this is apparently by design by Apple), we copy
        // the *only* input file over.
        // TODO: in the future, when we implement `dsymutil` alternative directly in the Zig
        // compiler, investigate if we can get rid of this `if` prong here.
        const path = positionals.items[0].path;
        const in_file = try std.fs.cwd().openFile(path, .{});
        const stat = try in_file.stat();
        const amt = try in_file.copyRangeAll(0, macho_file.base.file.?, 0, stat.size);
        if (amt != stat.size) return error.InputOutput; // TODO: report an actual user error
        return;
    }

    for (positionals.items) |obj| {
        macho_file.parsePositional(obj.path, obj.must_link) catch |err| switch (err) {
            error.MalformedObject,
            error.MalformedArchive,
            error.InvalidCpuArch,
            error.InvalidTarget,
            => continue, // already reported
            error.UnknownFileType => try macho_file.reportParseError(obj.path, "unknown file type for an object file", .{}),
            else => |e| try macho_file.reportParseError(
                obj.path,
                "unexpected error: parsing input file failed with error {s}",
                .{@errorName(e)},
            ),
        };
    }

    if (comp.link_errors.items.len > 0) return error.FlushFailure;

    try macho_file.addUndefinedGlobals();
    try macho_file.resolveSymbols();
    try macho_file.parseDebugInfo();
    try macho_file.dedupLiterals();
    markExports(macho_file);
    claimUnresolved(macho_file);
    try initOutputSections(macho_file);
    try macho_file.sortSections();
    try macho_file.addAtomsToSections();
    try calcSectionSizes(macho_file);

    try createSegment(macho_file);
    try allocateSections(macho_file);
    allocateSegment(macho_file);

    var off = off: {
        const seg = macho_file.segments.items[0];
        const off = math.cast(u32, seg.fileoff + seg.filesize) orelse return error.Overflow;
        break :off mem.alignForward(u32, off, @alignOf(macho.relocation_info));
    };
    off = allocateSectionsRelocs(macho_file, off);

    if (build_options.enable_logging) {
        state_log.debug("{}", .{macho_file.dumpState()});
    }

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

    // In order to please Apple ld (and possibly other MachO linkers in the wild),
    // we will now sanitize segment names of Zig-specific segments.
    sanitizeZigSections(macho_file);

    const ncmds, const sizeofcmds = try writeLoadCommands(macho_file);
    try writeHeader(macho_file, ncmds, sizeofcmds);
}

pub fn flushStaticLib(macho_file: *MachO, comp: *Compilation, module_obj_path: ?[]const u8) link.File.FlushError!void {
    const gpa = comp.gpa;

    var positionals = std.ArrayList(Compilation.LinkObject).init(gpa);
    defer positionals.deinit();

    try positionals.ensureUnusedCapacity(comp.objects.len);
    positionals.appendSliceAssumeCapacity(comp.objects);

    for (comp.c_object_table.keys()) |key| {
        try positionals.append(.{ .path = key.status.success.object_path });
    }

    if (module_obj_path) |path| try positionals.append(.{ .path = path });

    if (comp.include_compiler_rt) {
        try positionals.append(.{ .path = comp.compiler_rt_obj.?.full_object_path });
    }

    for (positionals.items) |obj| {
        parsePositional(macho_file, obj.path) catch |err| switch (err) {
            error.MalformedObject,
            error.MalformedArchive,
            error.InvalidCpuArch,
            error.InvalidTarget,
            => continue, // already reported
            error.UnknownFileType => try macho_file.reportParseError(obj.path, "unknown file type for an object file", .{}),
            else => |e| try macho_file.reportParseError(
                obj.path,
                "unexpected error: parsing input file failed with error {s}",
                .{@errorName(e)},
            ),
        };
    }

    if (comp.link_errors.items.len > 0) return error.FlushFailure;

    // First, we flush relocatable object file generated with our backends.
    if (macho_file.getZigObject()) |zo| {
        zo.resolveSymbols(macho_file);
        zo.asFile().markExportsRelocatable(macho_file);
        zo.asFile().claimUnresolvedRelocatable(macho_file);
        try macho_file.sortSections();
        try macho_file.addAtomsToSections();
        try calcSectionSizes(macho_file);
        try createSegment(macho_file);
        try allocateSections(macho_file);
        allocateSegment(macho_file);

        var off = off: {
            const seg = macho_file.segments.items[0];
            const off = math.cast(u32, seg.fileoff + seg.filesize) orelse return error.Overflow;
            break :off mem.alignForward(u32, off, @alignOf(macho.relocation_info));
        };
        off = allocateSectionsRelocs(macho_file, off);

        if (build_options.enable_logging) {
            state_log.debug("{}", .{macho_file.dumpState()});
        }

        try macho_file.calcSymtabSize();
        try writeAtoms(macho_file);

        off = mem.alignForward(u32, off, @alignOf(u64));
        off = try macho_file.writeDataInCode(0, off);
        off = mem.alignForward(u32, off, @alignOf(u64));
        off = try macho_file.writeSymtab(off);
        off = mem.alignForward(u32, off, @alignOf(u64));
        off = try macho_file.writeStrtab(off);

        // In order to please Apple ld (and possibly other MachO linkers in the wild),
        // we will now sanitize segment names of Zig-specific segments.
        sanitizeZigSections(macho_file);

        const ncmds, const sizeofcmds = try writeLoadCommands(macho_file);
        try writeHeader(macho_file, ncmds, sizeofcmds);

        // TODO we can avoid reading in the file contents we just wrote if we give the linker
        // ability to write directly to a buffer.
        try zo.readFileContents(off, macho_file);
    }

    var files = std.ArrayList(File.Index).init(gpa);
    defer files.deinit();
    try files.ensureTotalCapacityPrecise(macho_file.objects.items.len + 1);
    if (macho_file.getZigObject()) |zo| files.appendAssumeCapacity(zo.index);
    for (macho_file.objects.items) |index| files.appendAssumeCapacity(index);

    const format: Archive.Format = .p32;
    const ptr_width = Archive.ptrWidth(format);

    // Update ar symtab from parsed objects
    var ar_symtab: Archive.ArSymtab = .{};
    defer ar_symtab.deinit(gpa);

    for (files.items) |index| {
        try macho_file.getFile(index).?.updateArSymtab(&ar_symtab, macho_file);
    }

    ar_symtab.sort();

    // Update sizes of contributing objects
    for (files.items) |index| {
        try macho_file.getFile(index).?.updateArSize(macho_file);
    }

    // Update file offsets of contributing objects
    const total_size: usize = blk: {
        var pos: usize = Archive.SARMAG;
        pos += @sizeOf(Archive.ar_hdr);
        pos += mem.alignForward(usize, Archive.SYMDEF.len + 1, ptr_width);
        pos += ar_symtab.size(format);

        for (files.items) |index| {
            const file = macho_file.getFile(index).?;
            const state = switch (file) {
                .zig_object => |x| &x.output_ar_state,
                .object => |x| &x.output_ar_state,
                else => unreachable,
            };
            const path = switch (file) {
                .zig_object => |x| x.path,
                .object => |x| x.path,
                else => unreachable,
            };
            pos = mem.alignForward(usize, pos, 2);
            state.file_off = pos;
            pos += @sizeOf(Archive.ar_hdr);
            pos += mem.alignForward(usize, path.len + 1, ptr_width);
            pos += math.cast(usize, state.size) orelse return error.Overflow;
        }

        break :blk pos;
    };

    if (build_options.enable_logging) {
        state_log.debug("ar_symtab\n{}\n", .{ar_symtab.fmt(macho_file)});
    }

    var buffer = std.ArrayList(u8).init(gpa);
    defer buffer.deinit();
    try buffer.ensureTotalCapacityPrecise(total_size);
    const writer = buffer.writer();

    // Write magic
    try writer.writeAll(Archive.ARMAG);

    // Write symtab
    try ar_symtab.write(format, macho_file, writer);

    // Write object files
    for (files.items) |index| {
        const aligned = mem.alignForward(usize, buffer.items.len, 2);
        const padding = aligned - buffer.items.len;
        if (padding > 0) {
            try writer.writeByteNTimes(0, padding);
        }
        try macho_file.getFile(index).?.writeAr(format, macho_file, writer);
    }

    assert(buffer.items.len == total_size);

    try macho_file.base.file.?.setEndPos(total_size);
    try macho_file.base.file.?.pwriteAll(buffer.items, 0);

    if (comp.link_errors.items.len > 0) return error.FlushFailure;
}

fn parsePositional(macho_file: *MachO, path: []const u8) MachO.ParseError!void {
    const tracy = trace(@src());
    defer tracy.end();
    if (try Object.isObject(path)) {
        try parseObject(macho_file, path);
    } else if (try fat.isFatLibrary(path)) {
        const fat_arch = try macho_file.parseFatLibrary(path);
        if (try Archive.isArchive(path, fat_arch)) {
            try parseArchive(macho_file, path, fat_arch);
        } else return error.UnknownFileType;
    } else if (try Archive.isArchive(path, null)) {
        try parseArchive(macho_file, path, null);
    } else return error.UnknownFileType;
}

fn parseObject(macho_file: *MachO, path: []const u8) MachO.ParseError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = macho_file.base.comp.gpa;
    const file = try std.fs.cwd().openFile(path, .{});
    errdefer file.close();
    const handle = try macho_file.addFileHandle(file);
    const mtime: u64 = mtime: {
        const stat = file.stat() catch break :mtime 0;
        break :mtime @as(u64, @intCast(@divFloor(stat.mtime, 1_000_000_000)));
    };
    const index = @as(File.Index, @intCast(try macho_file.files.addOne(gpa)));
    macho_file.files.set(index, .{ .object = .{
        .path = try gpa.dupe(u8, path),
        .file_handle = handle,
        .mtime = mtime,
        .index = index,
    } });
    try macho_file.objects.append(gpa, index);

    const object = macho_file.getFile(index).?.object;
    try object.parseAr(macho_file);
}

fn parseArchive(macho_file: *MachO, path: []const u8, fat_arch: ?fat.Arch) MachO.ParseError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = macho_file.base.comp.gpa;

    const file = try std.fs.cwd().openFile(path, .{});
    errdefer file.close();
    const handle = try macho_file.addFileHandle(file);

    var archive = Archive{};
    defer archive.deinit(gpa);
    try archive.parse(macho_file, path, handle, fat_arch);

    var has_parse_error = false;
    for (archive.objects.items) |extracted| {
        const index = @as(File.Index, @intCast(try macho_file.files.addOne(gpa)));
        macho_file.files.set(index, .{ .object = extracted });
        const object = &macho_file.files.items(.data)[index].object;
        object.index = index;
        object.parseAr(macho_file) catch |err| switch (err) {
            error.InvalidCpuArch => has_parse_error = true,
            else => |e| return e,
        };
        try macho_file.objects.append(gpa, index);
    }
    if (has_parse_error) return error.MalformedArchive;
}

fn markExports(macho_file: *MachO) void {
    if (macho_file.getZigObject()) |zo| {
        zo.asFile().markExportsRelocatable(macho_file);
    }
    for (macho_file.objects.items) |index| {
        macho_file.getFile(index).?.markExportsRelocatable(macho_file);
    }
}

pub fn claimUnresolved(macho_file: *MachO) void {
    if (macho_file.getZigObject()) |zo| {
        zo.asFile().claimUnresolvedRelocatable(macho_file);
    }
    for (macho_file.objects.items) |index| {
        macho_file.getFile(index).?.claimUnresolvedRelocatable(macho_file);
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
        if (macho_file.getFile(index).?.object.hasUnwindRecords()) break true;
    } else false;
    if (needs_unwind_info) {
        macho_file.unwind_info_sect_index = try macho_file.addSection("__LD", "__compact_unwind", .{
            .flags = macho.S_ATTR_DEBUG,
        });
    }

    const needs_eh_frame = for (macho_file.objects.items) |index| {
        if (macho_file.getFile(index).?.object.hasEhFrameRecords()) break true;
    } else false;
    if (needs_eh_frame) {
        assert(needs_unwind_info);
        macho_file.eh_frame_sect_index = try macho_file.addSection("__TEXT", "__eh_frame", .{});
    }
}

fn calcSectionSizes(macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const slice = macho_file.sections.slice();
    for (slice.items(.header), slice.items(.atoms)) |*header, atoms| {
        if (atoms.items.len == 0) continue;
        for (atoms.items) |atom_index| {
            const atom = macho_file.getAtom(atom_index).?;
            const atom_alignment = atom.alignment.toByteUnits() orelse 1;
            const offset = mem.alignForward(u64, header.size, atom_alignment);
            const padding = offset - header.size;
            atom.value = offset;
            header.size += padding + atom.size;
            header.@"align" = @max(header.@"align", atom.alignment.toLog2Units());
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

    if (macho_file.getZigObject()) |zo| {
        for (zo.atoms.items) |atom_index| {
            const atom = macho_file.getAtom(atom_index) orelse continue;
            if (!atom.flags.alive) continue;
            const header = &macho_file.sections.items(.header)[atom.out_n_sect];
            if (!macho_file.isZigSection(atom.out_n_sect) and !macho_file.isDebugSection(atom.out_n_sect)) continue;
            header.nreloc += atom.calcNumRelocs(macho_file);
        }
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

fn allocateSections(macho_file: *MachO) !void {
    const slice = macho_file.sections.slice();
    for (slice.items(.header)) |*header| {
        const needed_size = header.size;
        header.size = 0;
        const alignment = try math.powi(u32, 2, header.@"align");
        if (!header.isZerofill()) {
            if (needed_size > macho_file.allocatedSize(header.offset)) {
                header.offset = math.cast(u32, macho_file.findFreeSpace(needed_size, alignment)) orelse
                    return error.Overflow;
            }
        }
        if (needed_size > macho_file.allocatedSizeVirtual(header.addr)) {
            header.addr = macho_file.findFreeSpaceVirtual(needed_size, alignment);
        }
        header.size = needed_size;
    }
}

/// Renames segment names in Zig sections to standard MachO segment names such as
/// `__TEXT`, `__DATA_CONST` and `__DATA`.
/// TODO: I think I may be able to get rid of this if I rework section/segment
/// allocation mechanism to not rely so much on having `_ZIG` sections always
/// pushed to the back. For instance, this is not a problem in ELF linker.
/// Then, we can create sections with the correct name from the start in `MachO.initMetadata`.
fn sanitizeZigSections(macho_file: *MachO) void {
    if (macho_file.zig_text_sect_index) |index| {
        const header = &macho_file.sections.items(.header)[index];
        header.segname = MachO.makeStaticString("__TEXT");
    }
    if (macho_file.zig_const_sect_index) |index| {
        const header = &macho_file.sections.items(.header)[index];
        header.segname = MachO.makeStaticString("__DATA_CONST");
    }
    if (macho_file.zig_data_sect_index) |index| {
        const header = &macho_file.sections.items(.header)[index];
        header.segname = MachO.makeStaticString("__DATA");
    }
    if (macho_file.zig_bss_sect_index) |index| {
        const header = &macho_file.sections.items(.header)[index];
        header.segname = MachO.makeStaticString("__DATA");
    }
}

fn createSegment(macho_file: *MachO) !void {
    const gpa = macho_file.base.comp.gpa;

    // For relocatable, we only ever need a single segment so create it now.
    const prot: macho.vm_prot_t = macho.PROT.READ | macho.PROT.WRITE | macho.PROT.EXEC;
    try macho_file.segments.append(gpa, .{
        .cmdsize = @sizeOf(macho.segment_command_64),
        .segname = MachO.makeStaticString(""),
        .maxprot = prot,
        .initprot = prot,
    });
    const seg = &macho_file.segments.items[0];
    seg.nsects = @intCast(macho_file.sections.items(.header).len);
    seg.cmdsize += seg.nsects * @sizeOf(macho.section_64);
}

fn allocateSegment(macho_file: *MachO) void {
    // Allocate the single segment.
    const seg = &macho_file.segments.items[0];
    var vmaddr: u64 = 0;
    var fileoff: u64 = load_commands.calcLoadCommandsSizeObject(macho_file) + @sizeOf(macho.mach_header_64);
    seg.vmaddr = vmaddr;
    seg.fileoff = fileoff;

    for (macho_file.sections.items(.header)) |header| {
        vmaddr = @max(vmaddr, header.addr + header.size);
        if (!header.isZerofill()) {
            fileoff = @max(fileoff, header.offset + header.size);
        }
    }

    seg.vmsize = vmaddr - seg.vmaddr;
    seg.filesize = fileoff - seg.fileoff;
}

fn allocateSectionsRelocs(macho_file: *MachO, off: u32) u32 {
    var fileoff = off;
    const slice = macho_file.sections.slice();
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

    const gpa = macho_file.base.comp.gpa;
    const cpu_arch = macho_file.getTarget().cpu.arch;
    const slice = macho_file.sections.slice();

    var relocs = std.ArrayList(macho.relocation_info).init(gpa);
    defer relocs.deinit();

    for (slice.items(.header), slice.items(.atoms), 0..) |header, atoms, i| {
        if (atoms.items.len == 0) continue;
        if (header.isZerofill()) continue;
        if (macho_file.isZigSection(@intCast(i)) or macho_file.isDebugSection(@intCast(i))) continue;

        const size = math.cast(usize, header.size) orelse return error.Overflow;
        const code = try gpa.alloc(u8, size);
        defer gpa.free(code);
        const padding_byte: u8 = if (header.isCode() and cpu_arch == .x86_64) 0xcc else 0;
        @memset(code, padding_byte);

        try relocs.ensureTotalCapacity(header.nreloc);

        for (atoms.items) |atom_index| {
            const atom = macho_file.getAtom(atom_index).?;
            assert(atom.flags.alive);
            const off = math.cast(usize, atom.value) orelse return error.Overflow;
            const atom_size = math.cast(usize, atom.size) orelse return error.Overflow;
            try atom.getData(macho_file, code[off..][0..atom_size]);
            try atom.writeRelocs(macho_file, code[off..][0..atom_size], &relocs);
        }

        assert(relocs.items.len == header.nreloc);

        mem.sort(macho.relocation_info, relocs.items, {}, sortReloc);

        // TODO scattered writes?
        try macho_file.base.file.?.pwriteAll(code, header.offset);
        try macho_file.base.file.?.pwriteAll(mem.sliceAsBytes(relocs.items), header.reloff);

        relocs.clearRetainingCapacity();
    }

    if (macho_file.getZigObject()) |zo| {
        // TODO: this is ugly; perhaps we should aggregrate before?
        var zo_relocs = std.AutoArrayHashMap(u8, std.ArrayList(macho.relocation_info)).init(gpa);
        defer {
            for (zo_relocs.values()) |*list| {
                list.deinit();
            }
            zo_relocs.deinit();
        }

        for (macho_file.sections.items(.header), 0..) |header, n_sect| {
            if (header.isZerofill()) continue;
            if (!macho_file.isZigSection(@intCast(n_sect)) and !macho_file.isDebugSection(@intCast(n_sect))) continue;
            const gop = try zo_relocs.getOrPut(@intCast(n_sect));
            if (gop.found_existing) continue;
            gop.value_ptr.* = try std.ArrayList(macho.relocation_info).initCapacity(gpa, header.nreloc);
        }

        for (zo.atoms.items) |atom_index| {
            const atom = macho_file.getAtom(atom_index) orelse continue;
            if (!atom.flags.alive) continue;
            const header = macho_file.sections.items(.header)[atom.out_n_sect];
            if (header.isZerofill()) continue;
            if (!macho_file.isZigSection(atom.out_n_sect) and !macho_file.isDebugSection(atom.out_n_sect)) continue;
            if (atom.getRelocs(macho_file).len == 0) continue;
            const atom_size = math.cast(usize, atom.size) orelse return error.Overflow;
            const code = try gpa.alloc(u8, atom_size);
            defer gpa.free(code);
            atom.getData(macho_file, code) catch |err| switch (err) {
                error.InputOutput => {
                    try macho_file.reportUnexpectedError("fetching code for '{s}' failed", .{
                        atom.getName(macho_file),
                    });
                    return error.FlushFailure;
                },
                else => |e| {
                    try macho_file.reportUnexpectedError("unexpected error while fetching code for '{s}': {s}", .{
                        atom.getName(macho_file),
                        @errorName(e),
                    });
                    return error.FlushFailure;
                },
            };
            const file_offset = header.offset + atom.value;
            const rels = zo_relocs.getPtr(atom.out_n_sect).?;
            try atom.writeRelocs(macho_file, code, rels);
            try macho_file.base.file.?.pwriteAll(code, file_offset);
        }

        for (zo_relocs.keys(), zo_relocs.values()) |sect_id, rels| {
            const header = macho_file.sections.items(.header)[sect_id];
            assert(rels.items.len == header.nreloc);
            mem.sort(macho.relocation_info, rels.items, {}, sortReloc);
            try macho_file.base.file.?.pwriteAll(mem.sliceAsBytes(rels.items), header.reloff);
        }
    }
}

fn writeCompactUnwind(macho_file: *MachO) !void {
    const sect_index = macho_file.unwind_info_sect_index orelse return;
    const gpa = macho_file.base.comp.gpa;
    const header = macho_file.sections.items(.header)[sect_index];

    const nrecs = math.cast(usize, @divExact(header.size, @sizeOf(macho.compact_unwind_entry))) orelse return error.Overflow;
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
                var reloc = addReloc(offset, macho_file.getTarget().cpu.arch);
                reloc.r_symbolnum = atom.out_n_sect + 1;
                relocs.appendAssumeCapacity(reloc);
            }

            // Personality function
            if (rec.getPersonality(macho_file)) |sym| {
                const r_symbolnum = math.cast(u24, sym.getOutputSymtabIndex(macho_file).?) orelse return error.Overflow;
                var reloc = addReloc(offset + 16, macho_file.getTarget().cpu.arch);
                reloc.r_symbolnum = r_symbolnum;
                reloc.r_extern = 1;
                relocs.appendAssumeCapacity(reloc);
            }

            // LSDA address
            if (rec.getLsdaAtom(macho_file)) |atom| {
                const addr = rec.getLsdaAddress(macho_file);
                out.lsda = addr;
                var reloc = addReloc(offset + 24, macho_file.getTarget().cpu.arch);
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
    try macho_file.base.file.?.pwriteAll(mem.sliceAsBytes(entries.items), header.offset);
    try macho_file.base.file.?.pwriteAll(mem.sliceAsBytes(relocs.items), header.reloff);
}

fn writeEhFrame(macho_file: *MachO) !void {
    const sect_index = macho_file.eh_frame_sect_index orelse return;
    const gpa = macho_file.base.comp.gpa;
    const header = macho_file.sections.items(.header)[sect_index];
    const size = math.cast(usize, header.size) orelse return error.Overflow;

    const code = try gpa.alloc(u8, size);
    defer gpa.free(code);

    var relocs = try std.ArrayList(macho.relocation_info).initCapacity(gpa, header.nreloc);
    defer relocs.deinit();

    try eh_frame.writeRelocs(macho_file, code, &relocs);
    assert(relocs.items.len == header.nreloc);

    mem.sort(macho.relocation_info, relocs.items, {}, sortReloc);

    // TODO scattered writes?
    try macho_file.base.file.?.pwriteAll(code, header.offset);
    try macho_file.base.file.?.pwriteAll(mem.sliceAsBytes(relocs.items), header.reloff);
}

fn writeLoadCommands(macho_file: *MachO) !struct { usize, usize } {
    const gpa = macho_file.base.comp.gpa;
    const needed_size = load_commands.calcLoadCommandsSizeObject(macho_file);
    const buffer = try gpa.alloc(u8, needed_size);
    defer gpa.free(buffer);

    var stream = std.io.fixedBufferStream(buffer);
    const writer = stream.writer();

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

    if (macho_file.platform.isBuildVersionCompatible()) {
        try load_commands.writeBuildVersionLC(macho_file.platform, macho_file.sdk_version, writer);
        ncmds += 1;
    } else {
        try load_commands.writeVersionMinLC(macho_file.platform, macho_file.sdk_version, writer);
        ncmds += 1;
    }

    assert(stream.pos == needed_size);

    try macho_file.base.file.?.pwriteAll(buffer, @sizeOf(macho.mach_header_64));

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

    switch (macho_file.getTarget().cpu.arch) {
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

    try macho_file.base.file.?.pwriteAll(mem.asBytes(&header), 0);
}

const assert = std.debug.assert;
const build_options = @import("build_options");
const eh_frame = @import("eh_frame.zig");
const fat = @import("fat.zig");
const link = @import("../../link.zig");
const load_commands = @import("load_commands.zig");
const log = std.log.scoped(.link);
const macho = std.macho;
const math = std.math;
const mem = std.mem;
const state_log = std.log.scoped(.link_state);
const std = @import("std");
const trace = @import("../../tracy.zig").trace;

const Archive = @import("Archive.zig");
const Atom = @import("Atom.zig");
const Compilation = @import("../../Compilation.zig");
const File = @import("file.zig").File;
const MachO = @import("../MachO.zig");
const Object = @import("Object.zig");
const Symbol = @import("Symbol.zig");
