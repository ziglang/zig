pub fn flushObject(macho_file: *MachO, comp: *Compilation, module_obj_path: ?Path) link.File.FlushError!void {
    const gpa = macho_file.base.comp.gpa;
    const diags = &macho_file.base.comp.link_diags;

    // TODO: "positional arguments" is a CLI concept, not a linker concept. Delete this unnecessary array list.
    var positionals = std.ArrayList(link.Input).init(gpa);
    defer positionals.deinit();
    try positionals.ensureUnusedCapacity(comp.link_inputs.len);
    positionals.appendSliceAssumeCapacity(comp.link_inputs);

    for (comp.c_object_table.keys()) |key| {
        try positionals.append(try link.openObjectInput(diags, key.status.success.object_path));
    }

    if (module_obj_path) |path| try positionals.append(try link.openObjectInput(diags, path));

    if (macho_file.getZigObject() == null and positionals.items.len == 1) {
        // Instead of invoking a full-blown `-r` mode on the input which sadly will strip all
        // debug info segments/sections (this is apparently by design by Apple), we copy
        // the *only* input file over.
        const path = positionals.items[0].path().?;
        const in_file = path.root_dir.handle.openFile(path.sub_path, .{}) catch |err|
            return diags.fail("failed to open {f}: {s}", .{ path, @errorName(err) });
        const stat = in_file.stat() catch |err|
            return diags.fail("failed to stat {f}: {s}", .{ path, @errorName(err) });
        const amt = in_file.copyRangeAll(0, macho_file.base.file.?, 0, stat.size) catch |err|
            return diags.fail("failed to copy range of file {f}: {s}", .{ path, @errorName(err) });
        if (amt != stat.size)
            return diags.fail("unexpected short write in copy range of file {f}", .{path});
        return;
    }

    for (positionals.items) |link_input| {
        macho_file.classifyInputFile(link_input) catch |err|
            diags.addParseError(link_input.path().?, "failed to read input file: {s}", .{@errorName(err)});
    }

    if (diags.hasErrors()) return error.LinkFailure;

    try macho_file.parseInputFiles();

    if (diags.hasErrors()) return error.LinkFailure;

    try macho_file.resolveSymbols();
    macho_file.dedupLiterals() catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.LinkFailure => return error.LinkFailure,
        else => |e| return diags.fail("failed to update ar size: {s}", .{@errorName(e)}),
    };
    markExports(macho_file);
    claimUnresolved(macho_file);
    try initOutputSections(macho_file);
    try macho_file.sortSections();
    try macho_file.addAtomsToSections();
    try calcSectionSizes(macho_file);

    try createSegment(macho_file);
    allocateSections(macho_file) catch |err| switch (err) {
        error.LinkFailure => return error.LinkFailure,
        else => |e| return diags.fail("failed to allocate sections: {s}", .{@errorName(e)}),
    };
    allocateSegment(macho_file);

    if (build_options.enable_logging) {
        state_log.debug("{f}", .{macho_file.dumpState()});
    }

    try writeSections(macho_file);
    sortRelocs(macho_file);
    try writeSectionsToFile(macho_file);

    // In order to please Apple ld (and possibly other MachO linkers in the wild),
    // we will now sanitize segment names of Zig-specific segments.
    sanitizeZigSections(macho_file);

    const ncmds, const sizeofcmds = try writeLoadCommands(macho_file);
    try writeHeader(macho_file, ncmds, sizeofcmds);
}

pub fn flushStaticLib(macho_file: *MachO, comp: *Compilation, module_obj_path: ?Path) link.File.FlushError!void {
    const gpa = comp.gpa;
    const diags = &macho_file.base.comp.link_diags;

    var positionals = std.ArrayList(link.Input).init(gpa);
    defer positionals.deinit();

    try positionals.ensureUnusedCapacity(comp.link_inputs.len);
    positionals.appendSliceAssumeCapacity(comp.link_inputs);

    for (comp.c_object_table.keys()) |key| {
        try positionals.append(try link.openObjectInput(diags, key.status.success.object_path));
    }

    if (module_obj_path) |path| try positionals.append(try link.openObjectInput(diags, path));

    if (comp.compiler_rt_strat == .obj) {
        try positionals.append(try link.openObjectInput(diags, comp.compiler_rt_obj.?.full_object_path));
    }

    if (comp.ubsan_rt_strat == .obj) {
        try positionals.append(try link.openObjectInput(diags, comp.ubsan_rt_obj.?.full_object_path));
    }

    for (positionals.items) |link_input| {
        macho_file.classifyInputFile(link_input) catch |err|
            diags.addParseError(link_input.path().?, "failed to read input file: {s}", .{@errorName(err)});
    }

    if (diags.hasErrors()) return error.LinkFailure;

    try parseInputFilesAr(macho_file);

    if (diags.hasErrors()) return error.LinkFailure;

    // First, we flush relocatable object file generated with our backends.
    if (macho_file.getZigObject()) |zo| {
        try zo.resolveSymbols(macho_file);
        zo.asFile().markExportsRelocatable(macho_file);
        zo.asFile().claimUnresolvedRelocatable(macho_file);
        try macho_file.sortSections();
        try macho_file.addAtomsToSections();
        try calcSectionSizes(macho_file);
        try createSegment(macho_file);
        allocateSections(macho_file) catch |err|
            return diags.fail("failed to allocate sections: {s}", .{@errorName(err)});
        allocateSegment(macho_file);

        if (build_options.enable_logging) {
            state_log.debug("{f}", .{macho_file.dumpState()});
        }

        try writeSections(macho_file);
        sortRelocs(macho_file);
        try writeSectionsToFile(macho_file);

        // In order to please Apple ld (and possibly other MachO linkers in the wild),
        // we will now sanitize segment names of Zig-specific segments.
        sanitizeZigSections(macho_file);

        const ncmds, const sizeofcmds = try writeLoadCommands(macho_file);
        try writeHeader(macho_file, ncmds, sizeofcmds);

        try zo.readFileContents(macho_file);
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
        macho_file.getFile(index).?.updateArSize(macho_file) catch |err|
            return diags.fail("failed to update ar size: {s}", .{@errorName(err)});
    }

    // Update file offsets of contributing objects
    const total_size: usize = blk: {
        var pos: usize = Archive.SARMAG;
        pos += @sizeOf(Archive.ar_hdr);
        pos += mem.alignForward(usize, Archive.SYMDEF.len + 1, ptr_width);
        pos += ar_symtab.size(format);

        for (files.items) |index| {
            const file = macho_file.getFile(index).?;
            switch (file) {
                .zig_object => |zo| {
                    const state = &zo.output_ar_state;
                    pos = mem.alignForward(usize, pos, 2);
                    state.file_off = pos;
                    pos += @sizeOf(Archive.ar_hdr);
                    pos += mem.alignForward(usize, zo.basename.len + 1, ptr_width);
                    pos += try macho_file.cast(usize, state.size);
                },
                .object => |o| {
                    const state = &o.output_ar_state;
                    pos = mem.alignForward(usize, pos, 2);
                    state.file_off = pos;
                    pos += @sizeOf(Archive.ar_hdr);
                    pos += mem.alignForward(usize, o.path.basename().len + 1, ptr_width);
                    pos += try macho_file.cast(usize, state.size);
                },
                else => unreachable,
            }
        }

        break :blk pos;
    };

    if (build_options.enable_logging) {
        state_log.debug("ar_symtab\n{f}\n", .{ar_symtab.fmt(macho_file)});
    }

    var bw: std.io.BufferedWriter = undefined;
    bw.initFixed(try gpa.alloc(u8, total_size));
    defer gpa.free(bw.buffer);

    // Write magic
    bw.writeAll(Archive.ARMAG) catch unreachable;

    // Write symtab
    ar_symtab.write(&bw, format, macho_file) catch |err| switch (err) {
        error.OutOfMemory => unreachable,
        else => |e| return diags.fail("failed to write archive symbol table: {s}", .{@errorName(e)}),
    };

    // Write object files
    for (files.items) |index| {
        bw.splatByteAll(0, mem.alignForward(usize, bw.end, 2) - bw.end) catch unreachable;
        macho_file.getFile(index).?.writeAr(&bw, format, macho_file) catch |err|
            return diags.fail("failed to write archive: {s}", .{@errorName(err)});
    }

    assert(bw.end == bw.buffer.len);
    try macho_file.setEndPos(bw.end);
    try macho_file.pwriteAll(bw.buffer, 0);

    if (diags.hasErrors()) return error.LinkFailure;
}

fn parseInputFilesAr(macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    for (macho_file.objects.items) |index| {
        macho_file.getFile(index).?.parseAr(macho_file) catch |err| switch (err) {
            error.InvalidMachineType => {}, // already reported
            else => |e| try macho_file.reportParseError2(index, "unexpected error: parsing input file failed with error {s}", .{@errorName(e)}),
        };
    }
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
        const file = macho_file.getFile(index).?;
        for (file.getAtoms()) |atom_index| {
            const atom = file.getAtom(atom_index) orelse continue;
            if (!atom.isAlive()) continue;
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

    const diags = &macho_file.base.comp.link_diags;

    if (macho_file.getZigObject()) |zo| {
        // TODO this will create a race as we need to track merging of debug sections which we currently don't
        zo.calcNumRelocs(macho_file);
    }

    {
        for (macho_file.sections.items(.atoms), 0..) |atoms, i| {
            if (atoms.items.len == 0) continue;
            calcSectionSizeWorker(macho_file, @as(u8, @intCast(i)));
        }

        if (macho_file.eh_frame_sect_index) |_| {
            calcEhFrameSizeWorker(macho_file);
        }

        if (macho_file.unwind_info_sect_index) |_| {
            for (macho_file.objects.items) |index| {
                Object.calcCompactUnwindSizeRelocatable(
                    macho_file.getFile(index).?.object,
                    macho_file,
                );
            }
        }

        for (macho_file.objects.items) |index| {
            File.calcSymtabSize(macho_file.getFile(index).?, macho_file);
        }
        if (macho_file.getZigObject()) |zo| {
            File.calcSymtabSize(zo.asFile(), macho_file);
        }

        MachO.updateLinkeditSizeWorker(macho_file, .data_in_code);
    }

    if (macho_file.unwind_info_sect_index) |_| {
        calcCompactUnwindSize(macho_file);
    }
    try calcSymtabSize(macho_file);

    if (diags.hasErrors()) return error.LinkFailure;
}

fn calcSectionSizeWorker(macho_file: *MachO, sect_id: u8) void {
    const tracy = trace(@src());
    defer tracy.end();

    const slice = macho_file.sections.slice();
    const header = &slice.items(.header)[sect_id];
    const atoms = slice.items(.atoms)[sect_id].items;
    for (atoms) |ref| {
        const atom = ref.getAtom(macho_file).?;
        const atom_alignment = atom.alignment.toByteUnits() orelse 1;
        const offset = mem.alignForward(u64, header.size, atom_alignment);
        const padding = offset - header.size;
        atom.value = offset;
        header.size += padding + atom.size;
        header.@"align" = @max(header.@"align", atom.alignment.toLog2Units());
        const nreloc = atom.calcNumRelocs(macho_file);
        atom.addExtra(.{ .rel_out_index = header.nreloc, .rel_out_count = nreloc }, macho_file);
        header.nreloc += nreloc;
    }
}

fn calcEhFrameSizeWorker(macho_file: *MachO) void {
    const tracy = trace(@src());
    defer tracy.end();

    const diags = &macho_file.base.comp.link_diags;

    const doWork = struct {
        fn doWork(mfile: *MachO, header: *macho.section_64) !void {
            header.size = try eh_frame.calcSize(mfile);
            header.@"align" = 3;
            header.nreloc = eh_frame.calcNumRelocs(mfile);
        }
    }.doWork;

    const header = &macho_file.sections.items(.header)[macho_file.eh_frame_sect_index.?];
    doWork(macho_file, header) catch |err|
        diags.addError("failed to calculate size of section '__TEXT,__eh_frame': {s}", .{@errorName(err)});
}

fn calcCompactUnwindSize(macho_file: *MachO) void {
    const tracy = trace(@src());
    defer tracy.end();

    var nrec: u32 = 0;
    var nreloc: u32 = 0;

    for (macho_file.objects.items) |index| {
        const ctx = &macho_file.getFile(index).?.object.compact_unwind_ctx;
        ctx.rec_index = nrec;
        ctx.reloc_index = nreloc;
        nrec += ctx.rec_count;
        nreloc += ctx.reloc_count;
    }

    const sect = &macho_file.sections.items(.header)[macho_file.unwind_info_sect_index.?];
    sect.size = nrec * @sizeOf(macho.compact_unwind_entry);
    sect.nreloc = nreloc;
    sect.@"align" = 3;
}

fn calcSymtabSize(macho_file: *MachO) error{OutOfMemory}!void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = macho_file.base.comp.gpa;

    var nlocals: u32 = 0;
    var nstabs: u32 = 0;
    var nexports: u32 = 0;
    var nimports: u32 = 0;
    var strsize: u32 = 1;

    var objects = try std.ArrayList(File.Index).initCapacity(gpa, macho_file.objects.items.len + 1);
    defer objects.deinit();
    if (macho_file.getZigObject()) |zo| objects.appendAssumeCapacity(zo.index);
    objects.appendSliceAssumeCapacity(macho_file.objects.items);

    for (objects.items) |index| {
        const ctx = switch (macho_file.getFile(index).?) {
            inline else => |x| &x.output_symtab_ctx,
        };
        ctx.ilocal = nlocals;
        ctx.istab = nstabs;
        ctx.iexport = nexports;
        ctx.iimport = nimports;
        ctx.stroff = strsize;
        nlocals += ctx.nlocals;
        nstabs += ctx.nstabs;
        nexports += ctx.nexports;
        nimports += ctx.nimports;
        strsize += ctx.strsize;
    }

    for (objects.items) |index| {
        const ctx = switch (macho_file.getFile(index).?) {
            inline else => |x| &x.output_symtab_ctx,
        };
        ctx.istab += nlocals;
        ctx.iexport += nlocals + nstabs;
        ctx.iimport += nlocals + nstabs + nexports;
    }

    {
        const cmd = &macho_file.symtab_cmd;
        cmd.nsyms = nlocals + nstabs + nexports + nimports;
        cmd.strsize = strsize;
    }

    {
        const cmd = &macho_file.dysymtab_cmd;
        cmd.ilocalsym = 0;
        cmd.nlocalsym = nlocals + nstabs;
        cmd.iextdefsym = nlocals + nstabs;
        cmd.nextdefsym = nexports;
        cmd.iundefsym = nlocals + nstabs + nexports;
        cmd.nundefsym = nimports;
    }
}

fn allocateSections(macho_file: *MachO) !void {
    const slice = macho_file.sections.slice();
    for (slice.items(.header)) |*header| {
        const needed_size = header.size;
        header.size = 0;
        const alignment = try macho_file.alignPow(header.@"align");
        if (!header.isZerofill()) {
            if (needed_size > macho_file.allocatedSize(header.offset)) {
                header.offset = try macho_file.cast(u32, try macho_file.findFreeSpace(needed_size, alignment));
            }
        }
        if (needed_size > macho_file.allocatedSizeVirtual(header.addr)) {
            header.addr = macho_file.findFreeSpaceVirtual(needed_size, alignment);
        }
        header.size = needed_size;
    }

    var fileoff: u32 = 0;
    for (slice.items(.header)) |header| {
        fileoff = @max(fileoff, header.offset + @as(u32, @intCast(header.size)));
    }

    for (slice.items(.header)) |*header| {
        if (header.nreloc == 0) continue;
        header.reloff = mem.alignForward(u32, fileoff, @alignOf(macho.relocation_info));
        fileoff = header.reloff + header.nreloc * @sizeOf(macho.relocation_info);
    }

    // In -r mode, there is no LINKEDIT segment and so we allocate required LINKEDIT commands
    // as if they were detached or part of the single segment.

    // DATA_IN_CODE
    {
        const cmd = &macho_file.data_in_code_cmd;
        cmd.dataoff = fileoff;
        fileoff += cmd.datasize;
        fileoff = mem.alignForward(u32, fileoff, @alignOf(u64));
    }

    // SYMTAB
    {
        const cmd = &macho_file.symtab_cmd;
        cmd.symoff = fileoff;
        fileoff += cmd.nsyms * @sizeOf(macho.nlist_64);
        fileoff = mem.alignForward(u32, fileoff, @alignOf(u32));
        cmd.stroff = fileoff;
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

// We need to sort relocations in descending order to be compatible with Apple's linker.
fn sortReloc(ctx: void, lhs: macho.relocation_info, rhs: macho.relocation_info) bool {
    _ = ctx;
    return lhs.r_address > rhs.r_address;
}

fn sortRelocs(macho_file: *MachO) void {
    const tracy = trace(@src());
    defer tracy.end();

    for (macho_file.sections.items(.relocs)) |*relocs| {
        mem.sort(macho.relocation_info, relocs.items, {}, sortReloc);
    }
}

fn writeSections(macho_file: *MachO) link.File.FlushError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = macho_file.base.comp.gpa;
    const diags = &macho_file.base.comp.link_diags;
    const cpu_arch = macho_file.getTarget().cpu.arch;
    const slice = macho_file.sections.slice();
    for (slice.items(.header), slice.items(.out), slice.items(.relocs), 0..) |header, *out, *relocs, n_sect| {
        if (header.isZerofill()) continue;
        if (!macho_file.isZigSection(@intCast(n_sect))) { // TODO this is wrong; what about debug sections?
            const size = try macho_file.cast(usize, header.size);
            try out.resize(gpa, size);
            const padding_byte: u8 = if (header.isCode() and cpu_arch == .x86_64) 0xcc else 0;
            @memset(out.items, padding_byte);
        }
        try relocs.resize(gpa, header.nreloc);
    }

    const cmd = macho_file.symtab_cmd;
    try macho_file.symtab.resize(gpa, cmd.nsyms);
    try macho_file.strtab.resize(gpa, cmd.strsize);
    macho_file.strtab.items[0] = 0;

    {
        for (macho_file.objects.items) |index| {
            writeAtomsWorker(macho_file, macho_file.getFile(index).?);
            File.writeSymtab(macho_file.getFile(index).?, macho_file, macho_file);
        }

        if (macho_file.getZigObject()) |zo| {
            writeAtomsWorker(macho_file, zo.asFile());
            File.writeSymtab(zo.asFile(), macho_file, macho_file);
        }

        if (macho_file.eh_frame_sect_index) |_| {
            writeEhFrameWorker(macho_file);
        }

        if (macho_file.unwind_info_sect_index) |_| {
            for (macho_file.objects.items) |index| {
                writeCompactUnwindWorker(macho_file, macho_file.getFile(index).?.object);
            }
        }
    }

    if (diags.hasErrors()) return error.LinkFailure;

    if (macho_file.getZigObject()) |zo| {
        try zo.writeRelocs(macho_file);
    }
}

fn writeAtomsWorker(macho_file: *MachO, file: File) void {
    const tracy = trace(@src());
    defer tracy.end();
    file.writeAtomsRelocatable(macho_file) catch |err| {
        macho_file.reportParseError2(file.getIndex(), "failed to write atoms: {s}", .{
            @errorName(err),
        }) catch {};
    };
}

fn writeEhFrameWorker(macho_file: *MachO) void {
    const tracy = trace(@src());
    defer tracy.end();

    const diags = &macho_file.base.comp.link_diags;
    const sect_index = macho_file.eh_frame_sect_index.?;
    const buffer = macho_file.sections.items(.out)[sect_index];
    const relocs = macho_file.sections.items(.relocs)[sect_index];
    eh_frame.writeRelocs(macho_file, buffer.items, relocs.items) catch |err|
        diags.addError("failed to write '__LD,__eh_frame' section: {s}", .{@errorName(err)});
}

fn writeCompactUnwindWorker(macho_file: *MachO, object: *Object) void {
    const tracy = trace(@src());
    defer tracy.end();

    const diags = &macho_file.base.comp.link_diags;
    object.writeCompactUnwindRelocatable(macho_file) catch |err|
        diags.addError("failed to write '__LD,__eh_frame' section: {s}", .{@errorName(err)});
}

fn writeSectionsToFile(macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const slice = macho_file.sections.slice();
    for (slice.items(.header), slice.items(.out), slice.items(.relocs)) |header, out, relocs| {
        try macho_file.pwriteAll(out.items, header.offset);
        try macho_file.pwriteAll(mem.sliceAsBytes(relocs.items), header.reloff);
    }

    try macho_file.writeDataInCode();
    try macho_file.pwriteAll(mem.sliceAsBytes(macho_file.symtab.items), macho_file.symtab_cmd.symoff);
    try macho_file.pwriteAll(macho_file.strtab.items, macho_file.symtab_cmd.stroff);
}

fn writeLoadCommands(macho_file: *MachO) error{ LinkFailure, OutOfMemory }!struct { usize, usize } {
    const gpa = macho_file.base.comp.gpa;
    var bw: std.io.BufferedWriter = undefined;
    bw.initFixed(try gpa.alloc(u8, load_commands.calcLoadCommandsSizeObject(macho_file)));
    defer gpa.free(bw.buffer);

    var ncmds: usize = 0;

    // Segment and section load commands
    {
        assert(macho_file.segments.items.len == 1);
        const seg = macho_file.segments.items[0];
        bw.writeStruct(seg) catch unreachable;
        for (macho_file.sections.items(.header)) |header| {
            bw.writeStruct(header) catch unreachable;
        }
        ncmds += 1;
    }

    bw.writeStruct(macho_file.data_in_code_cmd) catch unreachable;
    ncmds += 1;
    bw.writeStruct(macho_file.symtab_cmd) catch unreachable;
    ncmds += 1;
    bw.writeStruct(macho_file.dysymtab_cmd) catch unreachable;
    ncmds += 1;

    if (macho_file.platform.isBuildVersionCompatible()) {
        load_commands.writeBuildVersionLC(&bw, macho_file.platform, macho_file.sdk_version) catch unreachable;
        ncmds += 1;
    } else {
        load_commands.writeVersionMinLC(&bw, macho_file.platform, macho_file.sdk_version) catch unreachable;
        ncmds += 1;
    }

    assert(bw.end == bw.buffer.len);
    try macho_file.pwriteAll(bw.buffer, @sizeOf(macho.mach_header_64));
    return .{ ncmds, bw.end };
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

    try macho_file.pwriteAll(mem.asBytes(&header), 0);
}

const std = @import("std");
const Path = std.Build.Cache.Path;
const WaitGroup = std.Thread.WaitGroup;
const assert = std.debug.assert;
const log = std.log.scoped(.link);
const macho = std.macho;
const math = std.math;
const mem = std.mem;
const state_log = std.log.scoped(.link_state);

const Archive = @import("Archive.zig");
const Atom = @import("Atom.zig");
const Compilation = @import("../../Compilation.zig");
const File = @import("file.zig").File;
const MachO = @import("../MachO.zig");
const Object = @import("Object.zig");
const Symbol = @import("Symbol.zig");
const build_options = @import("build_options");
const eh_frame = @import("eh_frame.zig");
const fat = @import("fat.zig");
const link = @import("../../link.zig");
const load_commands = @import("load_commands.zig");
const trace = @import("../../tracy.zig").trace;
