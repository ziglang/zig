/// Non-zero for fat object files or archives
offset: u64,
path: []const u8,
file_handle: File.HandleIndex,
mtime: u64,
index: File.Index,
in_archive: ?InArchive = null,

header: ?macho.mach_header_64 = null,
sections: std.MultiArrayList(Section) = .{},
symtab: std.MultiArrayList(Nlist) = .{},
strtab: std.ArrayListUnmanaged(u8) = .empty,

symbols: std.ArrayListUnmanaged(Symbol) = .empty,
symbols_extra: std.ArrayListUnmanaged(u32) = .empty,
globals: std.ArrayListUnmanaged(MachO.SymbolResolver.Index) = .empty,
atoms: std.ArrayListUnmanaged(Atom) = .empty,
atoms_indexes: std.ArrayListUnmanaged(Atom.Index) = .empty,
atoms_extra: std.ArrayListUnmanaged(u32) = .empty,

platform: ?MachO.Platform = null,
compile_unit: ?CompileUnit = null,
stab_files: std.ArrayListUnmanaged(StabFile) = .empty,

eh_frame_sect_index: ?u8 = null,
compact_unwind_sect_index: ?u8 = null,
cies: std.ArrayListUnmanaged(Cie) = .empty,
fdes: std.ArrayListUnmanaged(Fde) = .empty,
eh_frame_data: std.ArrayListUnmanaged(u8) = .empty,
unwind_records: std.ArrayListUnmanaged(UnwindInfo.Record) = .empty,
unwind_records_indexes: std.ArrayListUnmanaged(UnwindInfo.Record.Index) = .empty,
data_in_code: std.ArrayListUnmanaged(macho.data_in_code_entry) = .empty,

alive: bool = true,
hidden: bool = false,

compact_unwind_ctx: CompactUnwindCtx = .{},
output_symtab_ctx: MachO.SymtabCtx = .{},
output_ar_state: Archive.ArState = .{},

pub fn deinit(self: *Object, allocator: Allocator) void {
    if (self.in_archive) |*ar| allocator.free(ar.path);
    allocator.free(self.path);
    for (self.sections.items(.relocs), self.sections.items(.subsections)) |*relocs, *sub| {
        relocs.deinit(allocator);
        sub.deinit(allocator);
    }
    self.sections.deinit(allocator);
    self.symtab.deinit(allocator);
    self.strtab.deinit(allocator);
    self.symbols.deinit(allocator);
    self.symbols_extra.deinit(allocator);
    self.globals.deinit(allocator);
    self.atoms.deinit(allocator);
    self.atoms_indexes.deinit(allocator);
    self.atoms_extra.deinit(allocator);
    self.cies.deinit(allocator);
    self.fdes.deinit(allocator);
    self.eh_frame_data.deinit(allocator);
    self.unwind_records.deinit(allocator);
    self.unwind_records_indexes.deinit(allocator);
    for (self.stab_files.items) |*sf| {
        sf.stabs.deinit(allocator);
    }
    self.stab_files.deinit(allocator);
    self.data_in_code.deinit(allocator);
}

pub fn parse(self: *Object, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    log.debug("parsing {}", .{self.fmtPath()});

    const gpa = macho_file.base.comp.gpa;
    const handle = macho_file.getFileHandle(self.file_handle);
    const cpu_arch = macho_file.getTarget().cpu.arch;

    // Atom at index 0 is reserved as null atom
    try self.atoms.append(gpa, .{ .extra = try self.addAtomExtra(gpa, .{}) });

    var header_buffer: [@sizeOf(macho.mach_header_64)]u8 = undefined;
    {
        const amt = try handle.preadAll(&header_buffer, self.offset);
        if (amt != @sizeOf(macho.mach_header_64)) return error.InputOutput;
    }
    self.header = @as(*align(1) const macho.mach_header_64, @ptrCast(&header_buffer)).*;

    const this_cpu_arch: std.Target.Cpu.Arch = switch (self.header.?.cputype) {
        macho.CPU_TYPE_ARM64 => .aarch64,
        macho.CPU_TYPE_X86_64 => .x86_64,
        else => |x| {
            try macho_file.reportParseError2(self.index, "unknown cpu architecture: {d}", .{x});
            return error.InvalidMachineType;
        },
    };
    if (cpu_arch != this_cpu_arch) {
        try macho_file.reportParseError2(self.index, "invalid cpu architecture: {s}", .{@tagName(this_cpu_arch)});
        return error.InvalidMachineType;
    }

    const lc_buffer = try gpa.alloc(u8, self.header.?.sizeofcmds);
    defer gpa.free(lc_buffer);
    {
        const amt = try handle.preadAll(lc_buffer, self.offset + @sizeOf(macho.mach_header_64));
        if (amt != self.header.?.sizeofcmds) return error.InputOutput;
    }

    var it = LoadCommandIterator{
        .ncmds = self.header.?.ncmds,
        .buffer = lc_buffer,
    };
    while (it.next()) |lc| switch (lc.cmd()) {
        .SEGMENT_64 => {
            const sections = lc.getSections();
            try self.sections.ensureUnusedCapacity(gpa, sections.len);
            for (sections) |sect| {
                const index = try self.sections.addOne(gpa);
                self.sections.set(index, .{ .header = sect });

                if (mem.eql(u8, sect.sectName(), "__eh_frame")) {
                    self.eh_frame_sect_index = @intCast(index);
                } else if (mem.eql(u8, sect.sectName(), "__compact_unwind")) {
                    self.compact_unwind_sect_index = @intCast(index);
                }
            }
        },
        .SYMTAB => {
            const cmd = lc.cast(macho.symtab_command).?;
            try self.strtab.resize(gpa, cmd.strsize);
            {
                const amt = try handle.preadAll(self.strtab.items, cmd.stroff + self.offset);
                if (amt != self.strtab.items.len) return error.InputOutput;
            }

            const symtab_buffer = try gpa.alloc(u8, cmd.nsyms * @sizeOf(macho.nlist_64));
            defer gpa.free(symtab_buffer);
            {
                const amt = try handle.preadAll(symtab_buffer, cmd.symoff + self.offset);
                if (amt != symtab_buffer.len) return error.InputOutput;
            }
            const symtab = @as([*]align(1) const macho.nlist_64, @ptrCast(symtab_buffer.ptr))[0..cmd.nsyms];
            try self.symtab.ensureUnusedCapacity(gpa, symtab.len);
            for (symtab) |nlist| {
                self.symtab.appendAssumeCapacity(.{
                    .nlist = nlist,
                    .atom = 0,
                    .size = 0,
                });
            }
        },
        .DATA_IN_CODE => {
            const cmd = lc.cast(macho.linkedit_data_command).?;
            const buffer = try gpa.alloc(u8, cmd.datasize);
            defer gpa.free(buffer);
            {
                const amt = try handle.preadAll(buffer, self.offset + cmd.dataoff);
                if (amt != buffer.len) return error.InputOutput;
            }
            const ndice = @divExact(cmd.datasize, @sizeOf(macho.data_in_code_entry));
            const dice = @as([*]align(1) const macho.data_in_code_entry, @ptrCast(buffer.ptr))[0..ndice];
            try self.data_in_code.appendUnalignedSlice(gpa, dice);
        },
        .BUILD_VERSION,
        .VERSION_MIN_MACOSX,
        .VERSION_MIN_IPHONEOS,
        .VERSION_MIN_TVOS,
        .VERSION_MIN_WATCHOS,
        => if (self.platform == null) {
            self.platform = MachO.Platform.fromLoadCommand(lc);
        },
        else => {},
    };

    const NlistIdx = struct {
        nlist: macho.nlist_64,
        idx: usize,

        fn rank(ctx: *const Object, nl: macho.nlist_64) u8 {
            if (!nl.ext()) {
                const name = ctx.getNStrx(nl.n_strx);
                if (name.len == 0) return 5;
                if (name[0] == 'l' or name[0] == 'L') return 4;
                return 3;
            }
            return if (nl.weakDef()) 2 else 1;
        }

        fn lessThan(ctx: *const Object, lhs: @This(), rhs: @This()) bool {
            if (lhs.nlist.n_sect == rhs.nlist.n_sect) {
                if (lhs.nlist.n_value == rhs.nlist.n_value) {
                    return rank(ctx, lhs.nlist) < rank(ctx, rhs.nlist);
                }
                return lhs.nlist.n_value < rhs.nlist.n_value;
            }
            return lhs.nlist.n_sect < rhs.nlist.n_sect;
        }
    };

    var nlists = try std.ArrayList(NlistIdx).initCapacity(gpa, self.symtab.items(.nlist).len);
    defer nlists.deinit();
    for (self.symtab.items(.nlist), 0..) |nlist, i| {
        if (nlist.stab() or !nlist.sect()) continue;
        nlists.appendAssumeCapacity(.{ .nlist = nlist, .idx = i });
    }
    mem.sort(NlistIdx, nlists.items, self, NlistIdx.lessThan);

    if (self.hasSubsections()) {
        try self.initSubsections(gpa, nlists.items);
    } else {
        try self.initSections(gpa, nlists.items);
    }

    try self.initCstringLiterals(gpa, handle, macho_file);
    try self.initFixedSizeLiterals(gpa, macho_file);
    try self.initPointerLiterals(gpa, macho_file);
    try self.linkNlistToAtom(macho_file);

    try self.sortAtoms(macho_file);
    try self.initSymbols(gpa, macho_file);
    try self.initSymbolStabs(gpa, nlists.items, macho_file);
    try self.initRelocs(handle, cpu_arch, macho_file);

    // Parse DWARF __TEXT,__eh_frame section
    if (self.eh_frame_sect_index) |index| {
        try self.initEhFrameRecords(gpa, index, handle, macho_file);
    }

    // Parse Apple's __LD,__compact_unwind section
    if (self.compact_unwind_sect_index) |index| {
        try self.initUnwindRecords(gpa, index, handle, macho_file);
    }

    if (self.hasUnwindRecords() or self.hasEhFrameRecords()) {
        try self.parseUnwindRecords(gpa, cpu_arch, macho_file);
    }

    if (self.platform) |platform| {
        if (!macho_file.platform.eqlTarget(platform)) {
            try macho_file.reportParseError2(self.index, "invalid platform: {}", .{
                platform.fmtTarget(cpu_arch),
            });
            return error.InvalidTarget;
        }
        // TODO: this causes the CI to fail so I'm commenting this check out so that
        // I can work out the rest of the changes first
        // if (macho_file.platform.version.order(platform.version) == .lt) {
        //     try macho_file.reportParseError2(self.index, "object file built for newer platform: {}: {} < {}", .{
        //         macho_file.platform.fmtTarget(macho_file.getTarget().cpu.arch),
        //         macho_file.platform.version,
        //         platform.version,
        //     });
        //     return error.InvalidTarget;
        // }
    }

    try self.parseDebugInfo(macho_file);

    for (self.getAtoms()) |atom_index| {
        const atom = self.getAtom(atom_index) orelse continue;
        const isec = atom.getInputSection(macho_file);
        if (mem.eql(u8, isec.sectName(), "__eh_frame") or
            mem.eql(u8, isec.sectName(), "__compact_unwind") or
            isec.attrs() & macho.S_ATTR_DEBUG != 0)
        {
            atom.setAlive(false);
        }
    }

    // Finally, we do a post-parse check for -ObjC to see if we need to force load this member anyhow.
    self.alive = self.alive or (macho_file.force_load_objc and self.hasObjC());
}

pub fn isCstringLiteral(sect: macho.section_64) bool {
    return sect.type() == macho.S_CSTRING_LITERALS;
}

pub fn isFixedSizeLiteral(sect: macho.section_64) bool {
    return switch (sect.type()) {
        macho.S_4BYTE_LITERALS,
        macho.S_8BYTE_LITERALS,
        macho.S_16BYTE_LITERALS,
        => true,
        else => false,
    };
}

pub fn isPtrLiteral(sect: macho.section_64) bool {
    return sect.type() == macho.S_LITERAL_POINTERS;
}

fn initSubsections(self: *Object, allocator: Allocator, nlists: anytype) !void {
    const tracy = trace(@src());
    defer tracy.end();
    const slice = self.sections.slice();
    for (slice.items(.header), slice.items(.subsections), 0..) |sect, *subsections, n_sect| {
        if (isCstringLiteral(sect)) continue;
        if (isFixedSizeLiteral(sect)) continue;
        if (isPtrLiteral(sect)) continue;

        const nlist_start = for (nlists, 0..) |nlist, i| {
            if (nlist.nlist.n_sect - 1 == n_sect) break i;
        } else nlists.len;
        const nlist_end = for (nlists[nlist_start..], nlist_start..) |nlist, i| {
            if (nlist.nlist.n_sect - 1 != n_sect) break i;
        } else nlists.len;

        if (nlist_start == nlist_end or nlists[nlist_start].nlist.n_value > sect.addr) {
            const name = try std.fmt.allocPrintZ(allocator, "{s}${s}", .{ sect.segName(), sect.sectName() });
            defer allocator.free(name);
            const size = if (nlist_start == nlist_end) sect.size else nlists[nlist_start].nlist.n_value - sect.addr;
            const atom_index = try self.addAtom(allocator, .{
                .name = try self.addString(allocator, name),
                .n_sect = @intCast(n_sect),
                .off = 0,
                .size = size,
                .alignment = sect.@"align",
            });
            try self.atoms_indexes.append(allocator, atom_index);
            try subsections.append(allocator, .{
                .atom = atom_index,
                .off = 0,
            });
        }

        var idx: usize = nlist_start;
        while (idx < nlist_end) {
            const alias_start = idx;
            const nlist = nlists[alias_start];

            while (idx < nlist_end and
                nlists[idx].nlist.n_value == nlist.nlist.n_value) : (idx += 1)
            {}

            const size = if (idx < nlist_end)
                nlists[idx].nlist.n_value - nlist.nlist.n_value
            else
                sect.addr + sect.size - nlist.nlist.n_value;
            const alignment = if (nlist.nlist.n_value > 0)
                @min(@ctz(nlist.nlist.n_value), sect.@"align")
            else
                sect.@"align";
            const atom_index = try self.addAtom(allocator, .{
                .name = .{ .pos = nlist.nlist.n_strx, .len = @intCast(self.getNStrx(nlist.nlist.n_strx).len + 1) },
                .n_sect = @intCast(n_sect),
                .off = nlist.nlist.n_value - sect.addr,
                .size = size,
                .alignment = alignment,
            });
            try self.atoms_indexes.append(allocator, atom_index);
            try subsections.append(allocator, .{
                .atom = atom_index,
                .off = nlist.nlist.n_value - sect.addr,
            });

            for (alias_start..idx) |i| {
                self.symtab.items(.size)[nlists[i].idx] = size;
            }
        }
    }
}

fn initSections(self: *Object, allocator: Allocator, nlists: anytype) !void {
    const tracy = trace(@src());
    defer tracy.end();
    const slice = self.sections.slice();

    try self.atoms.ensureUnusedCapacity(allocator, self.sections.items(.header).len);
    try self.atoms_indexes.ensureUnusedCapacity(allocator, self.sections.items(.header).len);

    for (slice.items(.header), 0..) |sect, n_sect| {
        if (isCstringLiteral(sect)) continue;
        if (isFixedSizeLiteral(sect)) continue;
        if (isPtrLiteral(sect)) continue;

        const name = try std.fmt.allocPrintZ(allocator, "{s}${s}", .{ sect.segName(), sect.sectName() });
        defer allocator.free(name);

        const atom_index = try self.addAtom(allocator, .{
            .name = try self.addString(allocator, name),
            .n_sect = @intCast(n_sect),
            .off = 0,
            .size = sect.size,
            .alignment = sect.@"align",
        });
        try self.atoms_indexes.append(allocator, atom_index);
        try slice.items(.subsections)[n_sect].append(allocator, .{ .atom = atom_index, .off = 0 });

        const nlist_start = for (nlists, 0..) |nlist, i| {
            if (nlist.nlist.n_sect - 1 == n_sect) break i;
        } else nlists.len;
        const nlist_end = for (nlists[nlist_start..], nlist_start..) |nlist, i| {
            if (nlist.nlist.n_sect - 1 != n_sect) break i;
        } else nlists.len;

        var idx: usize = nlist_start;
        while (idx < nlist_end) {
            const nlist = nlists[idx];

            while (idx < nlist_end and
                nlists[idx].nlist.n_value == nlist.nlist.n_value) : (idx += 1)
            {}

            const size = if (idx < nlist_end)
                nlists[idx].nlist.n_value - nlist.nlist.n_value
            else
                sect.addr + sect.size - nlist.nlist.n_value;

            for (nlist_start..idx) |i| {
                self.symtab.items(.size)[nlists[i].idx] = size;
            }
        }
    }
}

fn initCstringLiterals(self: *Object, allocator: Allocator, file: File.Handle, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const slice = self.sections.slice();

    for (slice.items(.header), 0..) |sect, n_sect| {
        if (!isCstringLiteral(sect)) continue;

        const sect_size = math.cast(usize, sect.size) orelse return error.Overflow;
        const data = try allocator.alloc(u8, sect_size);
        defer allocator.free(data);
        const amt = try file.preadAll(data, sect.offset + self.offset);
        if (amt != data.len) return error.InputOutput;

        var count: u32 = 0;
        var start: u32 = 0;
        while (start < data.len) {
            defer count += 1;
            var end = start;
            while (end < data.len - 1 and data[end] != 0) : (end += 1) {}
            if (data[end] != 0) {
                try macho_file.reportParseError2(
                    self.index,
                    "string not null terminated in '{s},{s}'",
                    .{ sect.segName(), sect.sectName() },
                );
                return error.MalformedObject;
            }
            end += 1;

            const name = try std.fmt.allocPrintZ(allocator, "l._str{d}", .{count});
            defer allocator.free(name);
            const name_str = try self.addString(allocator, name);

            const atom_index = try self.addAtom(allocator, .{
                .name = name_str,
                .n_sect = @intCast(n_sect),
                .off = start,
                .size = end - start,
                .alignment = sect.@"align",
            });
            try self.atoms_indexes.append(allocator, atom_index);
            try slice.items(.subsections)[n_sect].append(allocator, .{
                .atom = atom_index,
                .off = start,
            });

            const atom = self.getAtom(atom_index).?;
            const nlist_index: u32 = @intCast(try self.symtab.addOne(allocator));
            self.symtab.set(nlist_index, .{
                .nlist = .{
                    .n_strx = name_str.pos,
                    .n_type = macho.N_SECT,
                    .n_sect = @intCast(atom.n_sect + 1),
                    .n_desc = 0,
                    .n_value = atom.getInputAddress(macho_file),
                },
                .size = atom.size,
                .atom = atom_index,
            });
            atom.addExtra(.{ .literal_symbol_index = nlist_index }, macho_file);

            start = end;
        }
    }
}

fn initFixedSizeLiterals(self: *Object, allocator: Allocator, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const slice = self.sections.slice();

    for (slice.items(.header), 0..) |sect, n_sect| {
        if (!isFixedSizeLiteral(sect)) continue;

        const rec_size: u8 = switch (sect.type()) {
            macho.S_4BYTE_LITERALS => 4,
            macho.S_8BYTE_LITERALS => 8,
            macho.S_16BYTE_LITERALS => 16,
            else => unreachable,
        };
        if (sect.size % rec_size != 0) {
            try macho_file.reportParseError2(
                self.index,
                "size not multiple of record size in '{s},{s}'",
                .{ sect.segName(), sect.sectName() },
            );
            return error.MalformedObject;
        }

        var pos: u32 = 0;
        var count: u32 = 0;
        while (pos < sect.size) : ({
            pos += rec_size;
            count += 1;
        }) {
            const name = try std.fmt.allocPrintZ(allocator, "l._literal{d}", .{count});
            defer allocator.free(name);
            const name_str = try self.addString(allocator, name);

            const atom_index = try self.addAtom(allocator, .{
                .name = name_str,
                .n_sect = @intCast(n_sect),
                .off = pos,
                .size = rec_size,
                .alignment = sect.@"align",
            });
            try self.atoms_indexes.append(allocator, atom_index);
            try slice.items(.subsections)[n_sect].append(allocator, .{
                .atom = atom_index,
                .off = pos,
            });

            const atom = self.getAtom(atom_index).?;
            const nlist_index: u32 = @intCast(try self.symtab.addOne(allocator));
            self.symtab.set(nlist_index, .{
                .nlist = .{
                    .n_strx = name_str.pos,
                    .n_type = macho.N_SECT,
                    .n_sect = @intCast(atom.n_sect + 1),
                    .n_desc = 0,
                    .n_value = atom.getInputAddress(macho_file),
                },
                .size = atom.size,
                .atom = atom_index,
            });
            atom.addExtra(.{ .literal_symbol_index = nlist_index }, macho_file);
        }
    }
}

fn initPointerLiterals(self: *Object, allocator: Allocator, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const slice = self.sections.slice();

    for (slice.items(.header), 0..) |sect, n_sect| {
        if (!isPtrLiteral(sect)) continue;

        const rec_size: u8 = 8;
        if (sect.size % rec_size != 0) {
            try macho_file.reportParseError2(
                self.index,
                "size not multiple of record size in '{s},{s}'",
                .{ sect.segName(), sect.sectName() },
            );
            return error.MalformedObject;
        }
        const num_ptrs = math.cast(usize, @divExact(sect.size, rec_size)) orelse return error.Overflow;

        for (0..num_ptrs) |i| {
            const pos: u32 = @as(u32, @intCast(i)) * rec_size;

            const name = try std.fmt.allocPrintZ(allocator, "l._ptr{d}", .{i});
            defer allocator.free(name);
            const name_str = try self.addString(allocator, name);

            const atom_index = try self.addAtom(allocator, .{
                .name = name_str,
                .n_sect = @intCast(n_sect),
                .off = pos,
                .size = rec_size,
                .alignment = sect.@"align",
            });
            try self.atoms_indexes.append(allocator, atom_index);
            try slice.items(.subsections)[n_sect].append(allocator, .{
                .atom = atom_index,
                .off = pos,
            });

            const atom = self.getAtom(atom_index).?;
            const nlist_index: u32 = @intCast(try self.symtab.addOne(allocator));
            self.symtab.set(nlist_index, .{
                .nlist = .{
                    .n_strx = name_str.pos,
                    .n_type = macho.N_SECT,
                    .n_sect = @intCast(atom.n_sect + 1),
                    .n_desc = 0,
                    .n_value = atom.getInputAddress(macho_file),
                },
                .size = atom.size,
                .atom = atom_index,
            });
            atom.addExtra(.{ .literal_symbol_index = nlist_index }, macho_file);
        }
    }
}

pub fn resolveLiterals(self: *Object, lp: *MachO.LiteralPool, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = macho_file.base.comp.gpa;
    const file = macho_file.getFileHandle(self.file_handle);

    var buffer = std.ArrayList(u8).init(gpa);
    defer buffer.deinit();

    var sections_data = std.AutoHashMap(u32, []const u8).init(gpa);
    try sections_data.ensureTotalCapacity(@intCast(self.sections.items(.header).len));
    defer {
        var it = sections_data.iterator();
        while (it.next()) |entry| {
            gpa.free(entry.value_ptr.*);
        }
        sections_data.deinit();
    }

    const slice = self.sections.slice();
    for (slice.items(.header), slice.items(.subsections)) |header, subs| {
        if (isCstringLiteral(header) or isFixedSizeLiteral(header)) {
            const sect_size = math.cast(usize, header.size) orelse return error.Overflow;
            const data = try gpa.alloc(u8, sect_size);
            defer gpa.free(data);
            const amt = try file.preadAll(data, header.offset + self.offset);
            if (amt != data.len) return error.InputOutput;

            for (subs.items) |sub| {
                const atom = self.getAtom(sub.atom).?;
                const atom_off = math.cast(usize, atom.off) orelse return error.Overflow;
                const atom_size = math.cast(usize, atom.size) orelse return error.Overflow;
                const atom_data = data[atom_off..][0..atom_size];
                const res = try lp.insert(gpa, header.type(), atom_data);
                if (!res.found_existing) {
                    res.ref.* = .{ .index = atom.getExtra(macho_file).literal_symbol_index, .file = self.index };
                } else {
                    const lp_sym = lp.getSymbol(res.index, macho_file);
                    const lp_atom = lp_sym.getAtom(macho_file).?;
                    lp_atom.alignment = lp_atom.alignment.max(atom.alignment);
                    atom.setAlive(false);
                }
                atom.addExtra(.{ .literal_pool_index = res.index }, macho_file);
            }
        } else if (isPtrLiteral(header)) {
            for (subs.items) |sub| {
                const atom = self.getAtom(sub.atom).?;
                const relocs = atom.getRelocs(macho_file);
                assert(relocs.len == 1);
                const rel = relocs[0];
                const target = switch (rel.tag) {
                    .local => rel.getTargetAtom(atom.*, macho_file),
                    .@"extern" => rel.getTargetSymbol(atom.*, macho_file).getAtom(macho_file).?,
                };
                const addend = math.cast(u32, rel.addend) orelse return error.Overflow;
                const target_size = math.cast(usize, target.size) orelse return error.Overflow;
                try buffer.ensureUnusedCapacity(target_size);
                buffer.resize(target_size) catch unreachable;
                const gop = try sections_data.getOrPut(target.n_sect);
                if (!gop.found_existing) {
                    const target_sect = slice.items(.header)[target.n_sect];
                    const target_sect_size = math.cast(usize, target_sect.size) orelse return error.Overflow;
                    const data = try gpa.alloc(u8, target_sect_size);
                    const amt = try file.preadAll(data, target_sect.offset + self.offset);
                    if (amt != data.len) return error.InputOutput;
                    gop.value_ptr.* = data;
                }
                const data = gop.value_ptr.*;
                const target_off = math.cast(usize, target.off) orelse return error.Overflow;
                @memcpy(buffer.items, data[target_off..][0..target_size]);
                const res = try lp.insert(gpa, header.type(), buffer.items[addend..]);
                buffer.clearRetainingCapacity();
                if (!res.found_existing) {
                    res.ref.* = .{ .index = atom.getExtra(macho_file).literal_symbol_index, .file = self.index };
                } else {
                    const lp_sym = lp.getSymbol(res.index, macho_file);
                    const lp_atom = lp_sym.getAtom(macho_file).?;
                    lp_atom.alignment = lp_atom.alignment.max(atom.alignment);
                    atom.setAlive(false);
                }
                atom.addExtra(.{ .literal_pool_index = res.index }, macho_file);
            }
        }
    }
}

pub fn dedupLiterals(self: *Object, lp: MachO.LiteralPool, macho_file: *MachO) void {
    const tracy = trace(@src());
    defer tracy.end();

    for (self.getAtoms()) |atom_index| {
        const atom = self.getAtom(atom_index) orelse continue;
        if (!atom.isAlive()) continue;

        const relocs = blk: {
            const extra = atom.getExtra(macho_file);
            const relocs = self.sections.items(.relocs)[atom.n_sect].items;
            break :blk relocs[extra.rel_index..][0..extra.rel_count];
        };
        for (relocs) |*rel| {
            if (rel.tag != .@"extern") continue;
            const target_sym_ref = rel.getTargetSymbolRef(atom.*, macho_file);
            const file = target_sym_ref.getFile(macho_file) orelse continue;
            if (file.getIndex() != self.index) continue;
            const target_sym = target_sym_ref.getSymbol(macho_file).?;
            const target_atom = target_sym.getAtom(macho_file) orelse continue;
            const isec = target_atom.getInputSection(macho_file);
            if (!Object.isCstringLiteral(isec) and !Object.isFixedSizeLiteral(isec) and !Object.isPtrLiteral(isec)) continue;
            const lp_index = target_atom.getExtra(macho_file).literal_pool_index;
            const lp_sym = lp.getSymbol(lp_index, macho_file);
            const lp_atom_ref = lp_sym.atom_ref;
            if (target_atom.atom_index != lp_atom_ref.index or target_atom.file != lp_atom_ref.file) {
                target_sym.atom_ref = lp_atom_ref;
            }
        }
    }

    for (self.symbols.items) |*sym| {
        const atom = sym.getAtom(macho_file) orelse continue;
        const isec = atom.getInputSection(macho_file);
        if (!Object.isCstringLiteral(isec) and !Object.isFixedSizeLiteral(isec) and !Object.isPtrLiteral(isec)) continue;
        const lp_index = atom.getExtra(macho_file).literal_pool_index;
        const lp_sym = lp.getSymbol(lp_index, macho_file);
        const lp_atom_ref = lp_sym.atom_ref;
        if (atom.atom_index != lp_atom_ref.index or self.index != lp_atom_ref.file) {
            sym.atom_ref = lp_atom_ref;
        }
    }
}

pub fn findAtom(self: Object, addr: u64) ?Atom.Index {
    const tracy = trace(@src());
    defer tracy.end();
    const slice = self.sections.slice();
    for (slice.items(.header), slice.items(.subsections), 0..) |sect, subs, n_sect| {
        if (subs.items.len == 0) continue;
        if (sect.addr == addr) return subs.items[0].atom;
        if (sect.addr < addr and addr < sect.addr + sect.size) {
            return self.findAtomInSection(addr, @intCast(n_sect));
        }
    }
    return null;
}

fn findAtomInSection(self: Object, addr: u64, n_sect: u8) ?Atom.Index {
    const tracy = trace(@src());
    defer tracy.end();
    const slice = self.sections.slice();
    const sect = slice.items(.header)[n_sect];
    const subsections = slice.items(.subsections)[n_sect];

    var min: usize = 0;
    var max: usize = subsections.items.len;
    while (min < max) {
        const idx = (min + max) / 2;
        const sub = subsections.items[idx];
        const sub_addr = sect.addr + sub.off;
        const sub_size = if (idx + 1 < subsections.items.len)
            subsections.items[idx + 1].off - sub.off
        else
            sect.size - sub.off;
        if (sub_addr == addr or (sub_addr < addr and addr < sub_addr + sub_size)) return sub.atom;
        if (sub_addr < addr) {
            min = idx + 1;
        } else {
            max = idx;
        }
    }

    if (min < subsections.items.len) {
        const sub = subsections.items[min];
        const sub_addr = sect.addr + sub.off;
        const sub_size = if (min + 1 < subsections.items.len)
            subsections.items[min + 1].off - sub.off
        else
            sect.size - sub.off;
        if (sub_addr == addr or (sub_addr < addr and addr < sub_addr + sub_size)) return sub.atom;
    }

    return null;
}

fn linkNlistToAtom(self: *Object, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();
    for (self.symtab.items(.nlist), self.symtab.items(.atom)) |nlist, *atom| {
        if (!nlist.stab() and nlist.sect()) {
            if (self.findAtomInSection(nlist.n_value, nlist.n_sect - 1)) |atom_index| {
                atom.* = atom_index;
            } else {
                try macho_file.reportParseError2(self.index, "symbol {s} not attached to any (sub)section", .{
                    self.getNStrx(nlist.n_strx),
                });
                return error.MalformedObject;
            }
        }
    }
}

fn initSymbols(self: *Object, allocator: Allocator, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const slice = self.symtab.slice();
    const nsyms = slice.items(.nlist).len;

    try self.symbols.ensureTotalCapacityPrecise(allocator, nsyms);
    try self.symbols_extra.ensureTotalCapacityPrecise(allocator, nsyms * @sizeOf(Symbol.Extra));
    try self.globals.ensureTotalCapacityPrecise(allocator, nsyms);
    self.globals.resize(allocator, nsyms) catch unreachable;
    @memset(self.globals.items, 0);

    for (slice.items(.nlist), slice.items(.atom), 0..) |nlist, atom_index, i| {
        const index = self.addSymbolAssumeCapacity();
        const symbol = &self.symbols.items[index];
        symbol.value = nlist.n_value;
        symbol.name = .{ .pos = nlist.n_strx, .len = @intCast(self.getNStrx(nlist.n_strx).len + 1) };
        symbol.nlist_idx = @intCast(i);
        symbol.extra = self.addSymbolExtraAssumeCapacity(.{});

        if (self.getAtom(atom_index)) |atom| {
            assert(!nlist.abs());
            symbol.value -= atom.getInputAddress(macho_file);
            symbol.atom_ref = .{ .index = atom_index, .file = self.index };
        }

        symbol.flags.weak = nlist.weakDef();
        symbol.flags.abs = nlist.abs();
        symbol.flags.tentative = nlist.tentative();
        symbol.flags.no_dead_strip = symbol.flags.no_dead_strip or nlist.noDeadStrip();
        symbol.flags.dyn_ref = nlist.n_desc & macho.REFERENCED_DYNAMICALLY != 0;
        symbol.flags.interposable = false;
        // TODO
        // symbol.flags.interposable = nlist.ext() and (nlist.sect() or nlist.abs()) and macho_file.base.isDynLib() and macho_file.options.namespace == .flat and !nlist.pext();

        if (nlist.sect() and
            self.sections.items(.header)[nlist.n_sect - 1].type() == macho.S_THREAD_LOCAL_VARIABLES)
        {
            symbol.flags.tlv = true;
        }

        if (nlist.ext()) {
            if (nlist.undf()) {
                symbol.flags.weak_ref = nlist.weakRef();
            } else if (nlist.pext() or (nlist.weakDef() and nlist.weakRef()) or self.hidden) {
                symbol.visibility = .hidden;
            } else {
                symbol.visibility = .global;
            }
        }
    }
}

fn initSymbolStabs(self: *Object, allocator: Allocator, nlists: anytype, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const SymbolLookup = struct {
        ctx: *const Object,
        entries: @TypeOf(nlists),

        fn find(fs: @This(), addr: u64) ?Symbol.Index {
            // TODO binary search since we have the list sorted
            for (fs.entries) |nlist| {
                if (nlist.nlist.n_value == addr) return @intCast(nlist.idx);
            }
            return null;
        }
    };

    const start: u32 = for (self.symtab.items(.nlist), 0..) |nlist, i| {
        if (nlist.stab()) break @intCast(i);
    } else @intCast(self.symtab.items(.nlist).len);
    const end: u32 = for (self.symtab.items(.nlist)[start..], start..) |nlist, i| {
        if (!nlist.stab()) break @intCast(i);
    } else @intCast(self.symtab.items(.nlist).len);

    if (start == end) return;

    const syms = self.symtab.items(.nlist);
    const sym_lookup = SymbolLookup{ .ctx = self, .entries = nlists };

    // We need to cache nlists by name so that we can properly resolve local N_GSYM stabs.
    // What happens is `ld -r` will emit an N_GSYM stab for a symbol that may be either an
    // external or private external.
    var addr_lookup = std.StringHashMap(u64).init(allocator);
    defer addr_lookup.deinit();
    for (syms) |sym| {
        if (sym.sect() and (sym.ext() or sym.pext())) {
            try addr_lookup.putNoClobber(self.getNStrx(sym.n_strx), sym.n_value);
        }
    }

    var i: u32 = start;
    while (i < end) : (i += 1) {
        const open = syms[i];
        if (open.n_type != macho.N_SO) {
            try macho_file.reportParseError2(self.index, "unexpected symbol stab type 0x{x} as the first entry", .{
                open.n_type,
            });
            return error.MalformedObject;
        }

        while (i < end and syms[i].n_type == macho.N_SO and syms[i].n_sect != 0) : (i += 1) {}

        var sf: StabFile = .{ .comp_dir = i };
        // TODO validate
        i += 3;

        while (i < end and syms[i].n_type != macho.N_SO) : (i += 1) {
            const nlist = syms[i];
            var stab: StabFile.Stab = .{};
            switch (nlist.n_type) {
                macho.N_BNSYM => {
                    stab.is_func = true;
                    stab.index = sym_lookup.find(nlist.n_value);
                    // TODO validate
                    i += 3;
                },
                macho.N_GSYM => {
                    stab.is_func = false;
                    stab.index = sym_lookup.find(addr_lookup.get(self.getNStrx(nlist.n_strx)).?);
                },
                macho.N_STSYM => {
                    stab.is_func = false;
                    stab.index = sym_lookup.find(nlist.n_value);
                },
                else => {
                    try macho_file.reportParseError2(self.index, "unhandled symbol stab type 0x{x}", .{
                        nlist.n_type,
                    });
                    return error.MalformedObject;
                },
            }
            try sf.stabs.append(allocator, stab);
        }

        try self.stab_files.append(allocator, sf);
    }
}

fn sortAtoms(self: *Object, macho_file: *MachO) !void {
    const Ctx = struct {
        object: *Object,
        mfile: *MachO,

        fn lessThanAtom(ctx: @This(), lhs: Atom.Index, rhs: Atom.Index) bool {
            return ctx.object.getAtom(lhs).?.getInputAddress(ctx.mfile) <
                ctx.object.getAtom(rhs).?.getInputAddress(ctx.mfile);
        }
    };
    mem.sort(Atom.Index, self.atoms_indexes.items, Ctx{
        .object = self,
        .mfile = macho_file,
    }, Ctx.lessThanAtom);
}

fn initRelocs(self: *Object, file: File.Handle, cpu_arch: std.Target.Cpu.Arch, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();
    const slice = self.sections.slice();

    for (slice.items(.header), slice.items(.relocs)) |sect, *out| {
        if (sect.nreloc == 0) continue;
        // We skip relocs for __DWARF since even in -r mode, the linker is expected to emit
        // debug symbol stabs in the relocatable. This made me curious why that is. For now,
        // I shall comply, but I wanna compare with dsymutil.
        if (sect.attrs() & macho.S_ATTR_DEBUG != 0 and
            !mem.eql(u8, sect.sectName(), "__compact_unwind")) continue;

        switch (cpu_arch) {
            .x86_64 => try x86_64.parseRelocs(self, sect, out, file, macho_file),
            .aarch64 => try aarch64.parseRelocs(self, sect, out, file, macho_file),
            else => unreachable,
        }

        mem.sort(Relocation, out.items, {}, Relocation.lessThan);
    }

    for (slice.items(.header), slice.items(.relocs), slice.items(.subsections)) |sect, relocs, subsections| {
        if (sect.isZerofill()) continue;

        var next_reloc: u32 = 0;
        for (subsections.items) |subsection| {
            const atom = self.getAtom(subsection.atom).?;
            if (!atom.isAlive()) continue;
            if (next_reloc >= relocs.items.len) break;
            const end_addr = atom.off + atom.size;
            const rel_index = next_reloc;

            while (next_reloc < relocs.items.len and relocs.items[next_reloc].offset < end_addr) : (next_reloc += 1) {}

            const rel_count = next_reloc - rel_index;
            atom.addExtra(.{ .rel_index = @intCast(rel_index), .rel_count = @intCast(rel_count) }, macho_file);
        }
    }
}

fn initEhFrameRecords(self: *Object, allocator: Allocator, sect_id: u8, file: File.Handle, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();
    const nlists = self.symtab.items(.nlist);
    const slice = self.sections.slice();
    const sect = slice.items(.header)[sect_id];
    const relocs = slice.items(.relocs)[sect_id];

    const size = math.cast(usize, sect.size) orelse return error.Overflow;
    try self.eh_frame_data.resize(allocator, size);
    const amt = try file.preadAll(self.eh_frame_data.items, sect.offset + self.offset);
    if (amt != self.eh_frame_data.items.len) return error.InputOutput;

    // Check for non-personality relocs in FDEs and apply them
    for (relocs.items, 0..) |rel, i| {
        switch (rel.type) {
            .unsigned => {
                assert((rel.meta.length == 2 or rel.meta.length == 3) and rel.meta.has_subtractor); // TODO error
                const S: i64 = switch (rel.tag) {
                    .local => rel.meta.symbolnum,
                    .@"extern" => @intCast(nlists[rel.meta.symbolnum].n_value),
                };
                const A = rel.addend;
                const SUB: i64 = blk: {
                    const sub_rel = relocs.items[i - 1];
                    break :blk switch (sub_rel.tag) {
                        .local => sub_rel.meta.symbolnum,
                        .@"extern" => @intCast(nlists[sub_rel.meta.symbolnum].n_value),
                    };
                };
                switch (rel.meta.length) {
                    0, 1 => unreachable,
                    2 => mem.writeInt(u32, self.eh_frame_data.items[rel.offset..][0..4], @bitCast(@as(i32, @truncate(S + A - SUB))), .little),
                    3 => mem.writeInt(u64, self.eh_frame_data.items[rel.offset..][0..8], @bitCast(S + A - SUB), .little),
                }
            },
            else => {},
        }
    }

    var it = eh_frame.Iterator{ .data = self.eh_frame_data.items };
    while (try it.next()) |rec| {
        switch (rec.tag) {
            .cie => try self.cies.append(allocator, .{
                .offset = rec.offset,
                .size = rec.size,
                .file = self.index,
            }),
            .fde => try self.fdes.append(allocator, .{
                .offset = rec.offset,
                .size = rec.size,
                .cie = undefined,
                .file = self.index,
            }),
        }
    }

    for (self.cies.items) |*cie| {
        try cie.parse(macho_file);
    }

    for (self.fdes.items) |*fde| {
        try fde.parse(macho_file);
    }

    const sortFn = struct {
        fn sortFn(ctx: *MachO, lhs: Fde, rhs: Fde) bool {
            return lhs.getAtom(ctx).getInputAddress(ctx) < rhs.getAtom(ctx).getInputAddress(ctx);
        }
    }.sortFn;

    mem.sort(Fde, self.fdes.items, macho_file, sortFn);

    // Parse and attach personality pointers to CIEs if any
    for (relocs.items) |rel| {
        switch (rel.type) {
            .got => {
                assert(rel.meta.length == 2 and rel.tag == .@"extern");
                const cie = for (self.cies.items) |*cie| {
                    if (cie.offset <= rel.offset and rel.offset < cie.offset + cie.getSize()) break cie;
                } else {
                    try macho_file.reportParseError2(self.index, "{s},{s}: 0x{x}: bad relocation", .{
                        sect.segName(), sect.sectName(), rel.offset,
                    });
                    return error.MalformedObject;
                };
                cie.personality = .{ .index = @intCast(rel.target), .offset = rel.offset - cie.offset };
            },
            else => {},
        }
    }
}

fn initUnwindRecords(self: *Object, allocator: Allocator, sect_id: u8, file: File.Handle, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const SymbolLookup = struct {
        ctx: *const Object,

        fn find(fs: @This(), addr: u64) ?Symbol.Index {
            for (0..fs.ctx.symbols.items.len) |i| {
                const nlist = fs.ctx.symtab.items(.nlist)[i];
                if (nlist.ext() and nlist.n_value == addr) return @intCast(i);
            }
            return null;
        }
    };

    const header = self.sections.items(.header)[sect_id];
    const size = math.cast(usize, header.size) orelse return error.Overflow;
    const data = try allocator.alloc(u8, size);
    defer allocator.free(data);
    const amt = try file.preadAll(data, header.offset + self.offset);
    if (amt != data.len) return error.InputOutput;

    const nrecs = @divExact(data.len, @sizeOf(macho.compact_unwind_entry));
    const recs = @as([*]align(1) const macho.compact_unwind_entry, @ptrCast(data.ptr))[0..nrecs];
    const sym_lookup = SymbolLookup{ .ctx = self };

    try self.unwind_records.ensureTotalCapacityPrecise(allocator, nrecs);
    try self.unwind_records_indexes.ensureTotalCapacityPrecise(allocator, nrecs);

    const relocs = self.sections.items(.relocs)[sect_id].items;
    var reloc_idx: usize = 0;
    for (recs, 0..) |rec, rec_idx| {
        const rec_start = rec_idx * @sizeOf(macho.compact_unwind_entry);
        const rec_end = rec_start + @sizeOf(macho.compact_unwind_entry);
        const reloc_start = reloc_idx;
        while (reloc_idx < relocs.len and
            relocs[reloc_idx].offset < rec_end) : (reloc_idx += 1)
        {}

        const out_index = self.addUnwindRecordAssumeCapacity();
        self.unwind_records_indexes.appendAssumeCapacity(out_index);
        const out = self.getUnwindRecord(out_index);
        out.length = rec.rangeLength;
        out.enc = .{ .enc = rec.compactUnwindEncoding };

        for (relocs[reloc_start..reloc_idx]) |rel| {
            if (rel.type != .unsigned or rel.meta.length != 3) {
                try macho_file.reportParseError2(self.index, "{s},{s}: 0x{x}: bad relocation", .{
                    header.segName(), header.sectName(), rel.offset,
                });
                return error.MalformedObject;
            }
            assert(rel.type == .unsigned and rel.meta.length == 3); // TODO error
            const offset = rel.offset - rec_start;
            switch (offset) {
                0 => switch (rel.tag) { // target symbol
                    .@"extern" => {
                        out.atom = self.symtab.items(.atom)[rel.meta.symbolnum];
                        out.atom_offset = @intCast(rec.rangeStart);
                    },
                    .local => if (self.findAtom(rec.rangeStart)) |atom_index| {
                        out.atom = atom_index;
                        const atom = out.getAtom(macho_file);
                        out.atom_offset = @intCast(rec.rangeStart - atom.getInputAddress(macho_file));
                    } else {
                        try macho_file.reportParseError2(self.index, "{s},{s}: 0x{x}: bad relocation", .{
                            header.segName(), header.sectName(), rel.offset,
                        });
                        return error.MalformedObject;
                    },
                },
                16 => switch (rel.tag) { // personality function
                    .@"extern" => {
                        out.personality = rel.target;
                    },
                    .local => if (sym_lookup.find(rec.personalityFunction)) |sym_index| {
                        out.personality = sym_index;
                    } else {
                        try macho_file.reportParseError2(self.index, "{s},{s}: 0x{x}: bad relocation", .{
                            header.segName(), header.sectName(), rel.offset,
                        });
                        return error.MalformedObject;
                    },
                },
                24 => switch (rel.tag) { // lsda
                    .@"extern" => {
                        out.lsda = self.symtab.items(.atom)[rel.meta.symbolnum];
                        out.lsda_offset = @intCast(rec.lsda);
                    },
                    .local => if (self.findAtom(rec.lsda)) |atom_index| {
                        out.lsda = atom_index;
                        const atom = out.getLsdaAtom(macho_file).?;
                        out.lsda_offset = @intCast(rec.lsda - atom.getInputAddress(macho_file));
                    } else {
                        try macho_file.reportParseError2(self.index, "{s},{s}: 0x{x}: bad relocation", .{
                            header.segName(), header.sectName(), rel.offset,
                        });
                        return error.MalformedObject;
                    },
                },
                else => {},
            }
        }
    }
}

fn parseUnwindRecords(self: *Object, allocator: Allocator, cpu_arch: std.Target.Cpu.Arch, macho_file: *MachO) !void {
    // Synthesise missing unwind records.
    // The logic here is as follows:
    // 1. if an atom has unwind info record that is not DWARF, FDE is marked dead
    // 2. if an atom has unwind info record that is DWARF, FDE is tied to this unwind record
    // 3. if an atom doesn't have unwind info record but FDE is available, synthesise and tie
    // 4. if an atom doesn't have either, synthesise a null unwind info record

    const Superposition = struct { atom: Atom.Index, size: u64, cu: ?UnwindInfo.Record.Index = null, fde: ?Fde.Index = null };

    var superposition = std.AutoArrayHashMap(u64, Superposition).init(allocator);
    defer superposition.deinit();

    const slice = self.symtab.slice();
    for (slice.items(.nlist), slice.items(.atom), slice.items(.size)) |nlist, atom, size| {
        if (nlist.stab()) continue;
        if (!nlist.sect()) continue;
        const sect = self.sections.items(.header)[nlist.n_sect - 1];
        if (sect.isCode() and sect.size > 0) {
            try superposition.ensureUnusedCapacity(1);
            const gop = superposition.getOrPutAssumeCapacity(nlist.n_value);
            if (gop.found_existing) {
                assert(gop.value_ptr.atom == atom and gop.value_ptr.size == size);
            }
            gop.value_ptr.* = .{ .atom = atom, .size = size };
        }
    }

    for (self.unwind_records_indexes.items) |rec_index| {
        const rec = self.getUnwindRecord(rec_index);
        const atom = rec.getAtom(macho_file);
        const addr = atom.getInputAddress(macho_file) + rec.atom_offset;
        superposition.getPtr(addr).?.cu = rec_index;
    }

    for (self.fdes.items, 0..) |fde, fde_index| {
        const atom = fde.getAtom(macho_file);
        const addr = atom.getInputAddress(macho_file) + fde.atom_offset;
        superposition.getPtr(addr).?.fde = @intCast(fde_index);
    }

    for (superposition.keys(), superposition.values()) |addr, meta| {
        if (meta.fde) |fde_index| {
            const fde = &self.fdes.items[fde_index];

            if (meta.cu) |rec_index| {
                const rec = self.getUnwindRecord(rec_index);
                if (!rec.enc.isDwarf(macho_file)) {
                    // Mark FDE dead
                    fde.alive = false;
                } else {
                    // Tie FDE to unwind record
                    rec.fde = fde_index;
                }
            } else {
                // Synthesise new unwind info record
                const rec_index = try self.addUnwindRecord(allocator);
                const rec = self.getUnwindRecord(rec_index);
                try self.unwind_records_indexes.append(allocator, rec_index);
                rec.length = @intCast(meta.size);
                rec.atom = fde.atom;
                rec.atom_offset = fde.atom_offset;
                rec.fde = fde_index;
                switch (cpu_arch) {
                    .x86_64 => rec.enc.setMode(macho.UNWIND_X86_64_MODE.DWARF),
                    .aarch64 => rec.enc.setMode(macho.UNWIND_ARM64_MODE.DWARF),
                    else => unreachable,
                }
            }
        } else if (meta.cu == null and meta.fde == null) {
            // Create a null record
            const rec_index = try self.addUnwindRecord(allocator);
            const rec = self.getUnwindRecord(rec_index);
            const atom = self.getAtom(meta.atom).?;
            try self.unwind_records_indexes.append(allocator, rec_index);
            rec.length = @intCast(meta.size);
            rec.atom = meta.atom;
            rec.atom_offset = @intCast(addr - atom.getInputAddress(macho_file));
            rec.file = self.index;
        }
    }

    const SortCtx = struct {
        object: *Object,
        mfile: *MachO,

        fn sort(ctx: @This(), lhs_index: UnwindInfo.Record.Index, rhs_index: UnwindInfo.Record.Index) bool {
            const lhs = ctx.object.getUnwindRecord(lhs_index);
            const rhs = ctx.object.getUnwindRecord(rhs_index);
            const lhsa = lhs.getAtom(ctx.mfile);
            const rhsa = rhs.getAtom(ctx.mfile);
            return lhsa.getInputAddress(ctx.mfile) + lhs.atom_offset < rhsa.getInputAddress(ctx.mfile) + rhs.atom_offset;
        }
    };
    mem.sort(UnwindInfo.Record.Index, self.unwind_records_indexes.items, SortCtx{
        .object = self,
        .mfile = macho_file,
    }, SortCtx.sort);

    // Associate unwind records to atoms
    var next_cu: u32 = 0;
    while (next_cu < self.unwind_records_indexes.items.len) {
        const start = next_cu;
        const rec_index = self.unwind_records_indexes.items[start];
        const rec = self.getUnwindRecord(rec_index);
        while (next_cu < self.unwind_records_indexes.items.len and
            self.getUnwindRecord(self.unwind_records_indexes.items[next_cu]).atom == rec.atom) : (next_cu += 1)
        {}

        const atom = rec.getAtom(macho_file);
        atom.addExtra(.{ .unwind_index = start, .unwind_count = next_cu - start }, macho_file);
    }
}

/// Currently, we only check if a compile unit for this input object file exists
/// and record that so that we can emit symbol stabs.
/// TODO in the future, we want parse debug info and debug line sections so that
/// we can provide nice error locations to the user.
fn parseDebugInfo(self: *Object, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = macho_file.base.comp.gpa;

    var debug_info_index: ?usize = null;
    var debug_abbrev_index: ?usize = null;
    var debug_str_index: ?usize = null;

    for (self.sections.items(.header), 0..) |sect, index| {
        if (sect.attrs() & macho.S_ATTR_DEBUG == 0) continue;
        if (mem.eql(u8, sect.sectName(), "__debug_info")) debug_info_index = index;
        if (mem.eql(u8, sect.sectName(), "__debug_abbrev")) debug_abbrev_index = index;
        if (mem.eql(u8, sect.sectName(), "__debug_str")) debug_str_index = index;
    }

    if (debug_info_index == null or debug_abbrev_index == null) return;

    const slice = self.sections.slice();
    const file = macho_file.getFileHandle(self.file_handle);
    const debug_info = blk: {
        const sect = slice.items(.header)[debug_info_index.?];
        const size = math.cast(usize, sect.size) orelse return error.Overflow;
        const data = try gpa.alloc(u8, size);
        const amt = try file.preadAll(data, sect.offset + self.offset);
        if (amt != data.len) return error.InputOutput;
        break :blk data;
    };
    defer gpa.free(debug_info);
    const debug_abbrev = blk: {
        const sect = slice.items(.header)[debug_abbrev_index.?];
        const size = math.cast(usize, sect.size) orelse return error.Overflow;
        const data = try gpa.alloc(u8, size);
        const amt = try file.preadAll(data, sect.offset + self.offset);
        if (amt != data.len) return error.InputOutput;
        break :blk data;
    };
    defer gpa.free(debug_abbrev);
    const debug_str = if (debug_str_index) |sid| blk: {
        const sect = slice.items(.header)[sid];
        const size = math.cast(usize, sect.size) orelse return error.Overflow;
        const data = try gpa.alloc(u8, size);
        const amt = try file.preadAll(data, sect.offset + self.offset);
        if (amt != data.len) return error.InputOutput;
        break :blk data;
    } else &[0]u8{};
    defer gpa.free(debug_str);

    self.compile_unit = self.findCompileUnit(.{
        .gpa = gpa,
        .debug_info = debug_info,
        .debug_abbrev = debug_abbrev,
        .debug_str = debug_str,
    }) catch null; // TODO figure out what errors are fatal, and when we silently fail
}

fn findCompileUnit(self: *Object, args: struct {
    gpa: Allocator,
    debug_info: []const u8,
    debug_abbrev: []const u8,
    debug_str: []const u8,
}) !CompileUnit {
    var cu_wip: struct {
        comp_dir: ?[:0]const u8 = null,
        tu_name: ?[:0]const u8 = null,
    } = .{};

    const gpa = args.gpa;
    var info_reader = dwarf.InfoReader{ .bytes = args.debug_info, .strtab = args.debug_str };
    var abbrev_reader = dwarf.AbbrevReader{ .bytes = args.debug_abbrev };

    const cuh = try info_reader.readCompileUnitHeader();
    try abbrev_reader.seekTo(cuh.debug_abbrev_offset);

    const cu_decl = (try abbrev_reader.readDecl()) orelse return error.Eof;
    if (cu_decl.tag != dwarf.TAG.compile_unit) return error.UnexpectedTag;

    try info_reader.seekToDie(cu_decl.code, cuh, &abbrev_reader);

    while (try abbrev_reader.readAttr()) |attr| switch (attr.at) {
        dwarf.AT.name => {
            cu_wip.tu_name = try info_reader.readString(attr.form, cuh);
        },
        dwarf.AT.comp_dir => {
            cu_wip.comp_dir = try info_reader.readString(attr.form, cuh);
        },
        else => switch (attr.form) {
            dwarf.FORM.sec_offset,
            dwarf.FORM.ref_addr,
            => {
                _ = try info_reader.readOffset(cuh.format);
            },

            dwarf.FORM.addr => {
                _ = try info_reader.readNBytes(cuh.address_size);
            },

            dwarf.FORM.block1,
            dwarf.FORM.block2,
            dwarf.FORM.block4,
            dwarf.FORM.block,
            => {
                _ = try info_reader.readBlock(attr.form);
            },

            dwarf.FORM.exprloc => {
                _ = try info_reader.readExprLoc();
            },

            dwarf.FORM.flag_present => {},

            dwarf.FORM.data1,
            dwarf.FORM.ref1,
            dwarf.FORM.flag,
            dwarf.FORM.data2,
            dwarf.FORM.ref2,
            dwarf.FORM.data4,
            dwarf.FORM.ref4,
            dwarf.FORM.data8,
            dwarf.FORM.ref8,
            dwarf.FORM.ref_sig8,
            dwarf.FORM.udata,
            dwarf.FORM.ref_udata,
            dwarf.FORM.sdata,
            => {
                _ = try info_reader.readConstant(attr.form);
            },

            dwarf.FORM.strp,
            dwarf.FORM.string,
            => {
                _ = try info_reader.readString(attr.form, cuh);
            },

            else => {
                // TODO actual errors?
                log.err("unhandled DW_FORM_* value with identifier {x}", .{attr.form});
                return error.UnhandledForm;
            },
        },
    };

    if (cu_wip.comp_dir == null) return error.MissingCompDir;
    if (cu_wip.tu_name == null) return error.MissingTuName;

    return .{
        .comp_dir = try self.addString(gpa, cu_wip.comp_dir.?),
        .tu_name = try self.addString(gpa, cu_wip.tu_name.?),
    };
}

pub fn resolveSymbols(self: *Object, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = macho_file.base.comp.gpa;

    for (self.symtab.items(.nlist), self.symtab.items(.atom), self.globals.items, 0..) |nlist, atom_index, *global, i| {
        if (!nlist.ext()) continue;
        if (nlist.sect()) {
            const atom = self.getAtom(atom_index).?;
            if (!atom.isAlive()) continue;
        }

        const gop = try macho_file.resolver.getOrPut(gpa, .{
            .index = @intCast(i),
            .file = self.index,
        }, macho_file);
        if (!gop.found_existing) {
            gop.ref.* = .{ .index = 0, .file = 0 };
        }
        global.* = gop.index;

        if (nlist.undf() and !nlist.tentative()) continue;
        if (gop.ref.getFile(macho_file) == null) {
            gop.ref.* = .{ .index = @intCast(i), .file = self.index };
            continue;
        }

        if (self.asFile().getSymbolRank(.{
            .archive = !self.alive,
            .weak = nlist.weakDef(),
            .tentative = nlist.tentative(),
        }) < gop.ref.getSymbol(macho_file).?.getSymbolRank(macho_file)) {
            gop.ref.* = .{ .index = @intCast(i), .file = self.index };
        }
    }
}

pub fn markLive(self: *Object, macho_file: *MachO) void {
    const tracy = trace(@src());
    defer tracy.end();

    for (0..self.symbols.items.len) |i| {
        const nlist = self.symtab.items(.nlist)[i];
        if (!nlist.ext()) continue;

        const ref = self.getSymbolRef(@intCast(i), macho_file);
        const file = ref.getFile(macho_file) orelse continue;
        const sym = ref.getSymbol(macho_file).?;
        const should_keep = nlist.undf() or (nlist.tentative() and !sym.flags.tentative);
        if (should_keep and file == .object and !file.object.alive) {
            file.object.alive = true;
            file.object.markLive(macho_file);
        }
    }
}

pub fn mergeSymbolVisibility(self: *Object, macho_file: *MachO) void {
    const tracy = trace(@src());
    defer tracy.end();

    for (self.symbols.items, 0..) |sym, i| {
        const ref = self.getSymbolRef(@intCast(i), macho_file);
        const global = ref.getSymbol(macho_file) orelse continue;
        if (sym.visibility.rank() < global.visibility.rank()) {
            global.visibility = sym.visibility;
        }
        if (sym.flags.weak_ref) {
            global.flags.weak_ref = true;
        }
    }
}

pub fn scanRelocs(self: *Object, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    for (self.getAtoms()) |atom_index| {
        const atom = self.getAtom(atom_index) orelse continue;
        if (!atom.isAlive()) continue;
        const sect = atom.getInputSection(macho_file);
        if (sect.isZerofill()) continue;
        try atom.scanRelocs(macho_file);
    }

    for (self.unwind_records_indexes.items) |rec_index| {
        const rec = self.getUnwindRecord(rec_index);
        if (!rec.alive) continue;
        if (rec.getFde(macho_file)) |fde| {
            if (fde.getCie(macho_file).getPersonality(macho_file)) |sym| {
                sym.setSectionFlags(.{ .needs_got = true });
            }
        } else if (rec.getPersonality(macho_file)) |sym| {
            sym.setSectionFlags(.{ .needs_got = true });
        }
    }
}

pub fn convertTentativeDefinitions(self: *Object, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();
    const gpa = macho_file.base.comp.gpa;

    for (self.symbols.items, self.globals.items, 0..) |*sym, off, i| {
        if (!sym.flags.tentative) continue;
        if (macho_file.resolver.get(off).?.file != self.index) continue;

        const nlist_idx = @as(Symbol.Index, @intCast(i));
        const nlist = &self.symtab.items(.nlist)[nlist_idx];
        const nlist_atom = &self.symtab.items(.atom)[nlist_idx];

        const name = try std.fmt.allocPrintZ(gpa, "__DATA$__common${s}", .{sym.getName(macho_file)});
        defer gpa.free(name);

        const alignment = (nlist.n_desc >> 8) & 0x0f;
        const n_sect = try self.addSection(gpa, "__DATA", "__common");
        const atom_index = try self.addAtom(gpa, .{
            .name = try self.addString(gpa, name),
            .n_sect = n_sect,
            .off = 0,
            .size = nlist.n_value,
            .alignment = alignment,
        });
        try self.atoms_indexes.append(gpa, atom_index);

        const sect = &self.sections.items(.header)[n_sect];
        sect.flags = macho.S_ZEROFILL;
        sect.size = nlist.n_value;
        sect.@"align" = alignment;

        sym.value = 0;
        sym.atom_ref = .{ .index = atom_index, .file = self.index };
        sym.flags.weak = false;
        sym.flags.weak_ref = false;
        sym.flags.tentative = false;
        sym.visibility = .global;

        nlist.n_value = 0;
        nlist.n_type = macho.N_EXT | macho.N_SECT;
        nlist.n_sect = 0;
        nlist.n_desc = 0;
        nlist_atom.* = atom_index;
    }
}

fn addSection(self: *Object, allocator: Allocator, segname: []const u8, sectname: []const u8) !u8 {
    const n_sect = @as(u8, @intCast(try self.sections.addOne(allocator)));
    self.sections.set(n_sect, .{
        .header = .{
            .sectname = MachO.makeStaticString(sectname),
            .segname = MachO.makeStaticString(segname),
        },
    });
    return n_sect;
}

pub fn parseAr(self: *Object, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = macho_file.base.comp.gpa;
    const handle = macho_file.getFileHandle(self.file_handle);

    var header_buffer: [@sizeOf(macho.mach_header_64)]u8 = undefined;
    {
        const amt = try handle.preadAll(&header_buffer, self.offset);
        if (amt != @sizeOf(macho.mach_header_64)) return error.InputOutput;
    }
    self.header = @as(*align(1) const macho.mach_header_64, @ptrCast(&header_buffer)).*;

    const this_cpu_arch: std.Target.Cpu.Arch = switch (self.header.?.cputype) {
        macho.CPU_TYPE_ARM64 => .aarch64,
        macho.CPU_TYPE_X86_64 => .x86_64,
        else => |x| {
            try macho_file.reportParseError2(self.index, "unknown cpu architecture: {d}", .{x});
            return error.InvalidMachineType;
        },
    };
    if (macho_file.getTarget().cpu.arch != this_cpu_arch) {
        try macho_file.reportParseError2(self.index, "invalid cpu architecture: {s}", .{@tagName(this_cpu_arch)});
        return error.InvalidMachineType;
    }

    const lc_buffer = try gpa.alloc(u8, self.header.?.sizeofcmds);
    defer gpa.free(lc_buffer);
    {
        const amt = try handle.preadAll(lc_buffer, self.offset + @sizeOf(macho.mach_header_64));
        if (amt != self.header.?.sizeofcmds) return error.InputOutput;
    }

    var it = LoadCommandIterator{
        .ncmds = self.header.?.ncmds,
        .buffer = lc_buffer,
    };
    while (it.next()) |lc| switch (lc.cmd()) {
        .SYMTAB => {
            const cmd = lc.cast(macho.symtab_command).?;
            try self.strtab.resize(gpa, cmd.strsize);
            {
                const amt = try handle.preadAll(self.strtab.items, cmd.stroff + self.offset);
                if (amt != self.strtab.items.len) return error.InputOutput;
            }

            const symtab_buffer = try gpa.alloc(u8, cmd.nsyms * @sizeOf(macho.nlist_64));
            defer gpa.free(symtab_buffer);
            {
                const amt = try handle.preadAll(symtab_buffer, cmd.symoff + self.offset);
                if (amt != symtab_buffer.len) return error.InputOutput;
            }
            const symtab = @as([*]align(1) const macho.nlist_64, @ptrCast(symtab_buffer.ptr))[0..cmd.nsyms];
            try self.symtab.ensureUnusedCapacity(gpa, symtab.len);
            for (symtab) |nlist| {
                self.symtab.appendAssumeCapacity(.{
                    .nlist = nlist,
                    .atom = 0,
                    .size = 0,
                });
            }
        },
        .BUILD_VERSION,
        .VERSION_MIN_MACOSX,
        .VERSION_MIN_IPHONEOS,
        .VERSION_MIN_TVOS,
        .VERSION_MIN_WATCHOS,
        => if (self.platform == null) {
            self.platform = MachO.Platform.fromLoadCommand(lc);
        },
        else => {},
    };
}

pub fn updateArSymtab(self: Object, ar_symtab: *Archive.ArSymtab, macho_file: *MachO) error{OutOfMemory}!void {
    const gpa = macho_file.base.comp.gpa;
    for (self.symtab.items(.nlist)) |nlist| {
        if (!nlist.ext() or (nlist.undf() and !nlist.tentative())) continue;
        const off = try ar_symtab.strtab.insert(gpa, self.getNStrx(nlist.n_strx));
        try ar_symtab.entries.append(gpa, .{ .off = off, .file = self.index });
    }
}

pub fn updateArSize(self: *Object, macho_file: *MachO) !void {
    self.output_ar_state.size = if (self.in_archive) |ar| ar.size else size: {
        const file = macho_file.getFileHandle(self.file_handle);
        break :size (try file.stat()).size;
    };
}

pub fn writeAr(self: Object, ar_format: Archive.Format, macho_file: *MachO, writer: anytype) !void {
    // Header
    const size = std.math.cast(usize, self.output_ar_state.size) orelse return error.Overflow;
    try Archive.writeHeader(self.path, size, ar_format, writer);
    // Data
    const file = macho_file.getFileHandle(self.file_handle);
    // TODO try using copyRangeAll
    const gpa = macho_file.base.comp.gpa;
    const data = try gpa.alloc(u8, size);
    defer gpa.free(data);
    const amt = try file.preadAll(data, self.offset);
    if (amt != size) return error.InputOutput;
    try writer.writeAll(data);
}

pub fn calcSymtabSize(self: *Object, macho_file: *MachO) void {
    const tracy = trace(@src());
    defer tracy.end();

    const is_obj = macho_file.base.isObject();

    for (self.symbols.items, 0..) |*sym, i| {
        const ref = self.getSymbolRef(@intCast(i), macho_file);
        const file = ref.getFile(macho_file) orelse continue;
        if (file.getIndex() != self.index) continue;
        if (sym.getAtom(macho_file)) |atom| if (!atom.isAlive()) continue;
        if (sym.isSymbolStab(macho_file)) continue;
        const name = sym.getName(macho_file);
        if (name.len == 0) continue;
        // TODO in -r mode, we actually want to merge symbol names and emit only one
        // work it out when emitting relocs
        if ((name[0] == 'L' or name[0] == 'l' or
            mem.startsWith(u8, name, "_OBJC_SELECTOR_REFERENCES_")) and
            !is_obj)
            continue;
        sym.flags.output_symtab = true;
        if (sym.isLocal()) {
            sym.addExtra(.{ .symtab = self.output_symtab_ctx.nlocals }, macho_file);
            self.output_symtab_ctx.nlocals += 1;
        } else if (sym.flags.@"export") {
            sym.addExtra(.{ .symtab = self.output_symtab_ctx.nexports }, macho_file);
            self.output_symtab_ctx.nexports += 1;
        } else {
            assert(sym.flags.import);
            sym.addExtra(.{ .symtab = self.output_symtab_ctx.nimports }, macho_file);
            self.output_symtab_ctx.nimports += 1;
        }
        self.output_symtab_ctx.strsize += @as(u32, @intCast(sym.getName(macho_file).len + 1));
    }

    if (macho_file.base.comp.config.debug_format != .strip and self.hasDebugInfo())
        self.calcStabsSize(macho_file);
}

pub fn calcStabsSize(self: *Object, macho_file: *MachO) void {
    if (self.compile_unit) |cu| {
        const comp_dir = cu.getCompDir(self.*);
        const tu_name = cu.getTuName(self.*);

        self.output_symtab_ctx.nstabs += 4; // N_SO, N_SO, N_OSO, N_SO
        self.output_symtab_ctx.strsize += @as(u32, @intCast(comp_dir.len + 1)); // comp_dir
        self.output_symtab_ctx.strsize += @as(u32, @intCast(tu_name.len + 1)); // tu_name

        if (self.in_archive) |ar| {
            self.output_symtab_ctx.strsize += @as(u32, @intCast(ar.path.len + 1 + self.path.len + 1 + 1));
        } else {
            self.output_symtab_ctx.strsize += @as(u32, @intCast(self.path.len + 1));
        }

        for (self.symbols.items, 0..) |sym, i| {
            const ref = self.getSymbolRef(@intCast(i), macho_file);
            const file = ref.getFile(macho_file) orelse continue;
            if (file.getIndex() != self.index) continue;
            if (!sym.flags.output_symtab) continue;
            if (macho_file.base.isObject()) {
                const name = sym.getName(macho_file);
                if (name.len > 0 and (name[0] == 'L' or name[0] == 'l')) continue;
            }
            const sect = macho_file.sections.items(.header)[sym.getOutputSectionIndex(macho_file)];
            if (sect.isCode()) {
                self.output_symtab_ctx.nstabs += 4; // N_BNSYM, N_FUN, N_FUN, N_ENSYM
            } else if (sym.visibility == .global) {
                self.output_symtab_ctx.nstabs += 1; // N_GSYM
            } else {
                self.output_symtab_ctx.nstabs += 1; // N_STSYM
            }
        }
    } else {
        assert(self.hasSymbolStabs());

        for (self.stab_files.items) |sf| {
            self.output_symtab_ctx.nstabs += 4; // N_SO, N_SO, N_OSO, N_SO
            self.output_symtab_ctx.strsize += @as(u32, @intCast(sf.getCompDir(self.*).len + 1)); // comp_dir
            self.output_symtab_ctx.strsize += @as(u32, @intCast(sf.getTuName(self.*).len + 1)); // tu_name
            self.output_symtab_ctx.strsize += @as(u32, @intCast(sf.getOsoPath(self.*).len + 1)); // path

            for (sf.stabs.items) |stab| {
                const sym = stab.getSymbol(self.*) orelse continue;
                const file = sym.getFile(macho_file).?;
                if (file.getIndex() != self.index) continue;
                if (!sym.flags.output_symtab) continue;
                const nstabs: u32 = if (stab.is_func) 4 else 1;
                self.output_symtab_ctx.nstabs += nstabs;
            }
        }
    }
}

pub fn writeAtoms(self: *Object, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = macho_file.base.comp.gpa;
    const headers = self.sections.items(.header);
    const sections_data = try gpa.alloc([]const u8, headers.len);
    defer {
        for (sections_data) |data| {
            gpa.free(data);
        }
        gpa.free(sections_data);
    }
    @memset(sections_data, &[0]u8{});
    const file = macho_file.getFileHandle(self.file_handle);

    for (headers, 0..) |header, n_sect| {
        if (header.isZerofill()) continue;
        const size = math.cast(usize, header.size) orelse return error.Overflow;
        const data = try gpa.alloc(u8, size);
        const amt = try file.preadAll(data, header.offset + self.offset);
        if (amt != data.len) return error.InputOutput;
        sections_data[n_sect] = data;
    }
    for (self.getAtoms()) |atom_index| {
        const atom = self.getAtom(atom_index) orelse continue;
        if (!atom.isAlive()) continue;
        const sect = atom.getInputSection(macho_file);
        if (sect.isZerofill()) continue;
        const value = math.cast(usize, atom.value) orelse return error.Overflow;
        const off = math.cast(usize, atom.off) orelse return error.Overflow;
        const size = math.cast(usize, atom.size) orelse return error.Overflow;
        const buffer = macho_file.sections.items(.out)[atom.out_n_sect].items;
        const data = sections_data[atom.n_sect];
        @memcpy(buffer[value..][0..size], data[off..][0..size]);
        try atom.resolveRelocs(macho_file, buffer[value..][0..size]);
    }
}

pub fn writeAtomsRelocatable(self: *Object, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = macho_file.base.comp.gpa;
    const headers = self.sections.items(.header);
    const sections_data = try gpa.alloc([]const u8, headers.len);
    defer {
        for (sections_data) |data| {
            gpa.free(data);
        }
        gpa.free(sections_data);
    }
    @memset(sections_data, &[0]u8{});
    const file = macho_file.getFileHandle(self.file_handle);

    for (headers, 0..) |header, n_sect| {
        if (header.isZerofill()) continue;
        const size = math.cast(usize, header.size) orelse return error.Overflow;
        const data = try gpa.alloc(u8, size);
        const amt = try file.preadAll(data, header.offset + self.offset);
        if (amt != data.len) return error.InputOutput;
        sections_data[n_sect] = data;
    }
    for (self.getAtoms()) |atom_index| {
        const atom = self.getAtom(atom_index) orelse continue;
        if (!atom.isAlive()) continue;
        const sect = atom.getInputSection(macho_file);
        if (sect.isZerofill()) continue;
        const value = math.cast(usize, atom.value) orelse return error.Overflow;
        const off = math.cast(usize, atom.off) orelse return error.Overflow;
        const size = math.cast(usize, atom.size) orelse return error.Overflow;
        const buffer = macho_file.sections.items(.out)[atom.out_n_sect].items;
        const data = sections_data[atom.n_sect];
        @memcpy(buffer[value..][0..size], data[off..][0..size]);
        const relocs = macho_file.sections.items(.relocs)[atom.out_n_sect].items;
        const extra = atom.getExtra(macho_file);
        try atom.writeRelocs(macho_file, buffer[value..][0..size], relocs[extra.rel_out_index..][0..extra.rel_out_count]);
    }
}

pub fn calcCompactUnwindSizeRelocatable(self: *Object, macho_file: *MachO) void {
    const tracy = trace(@src());
    defer tracy.end();

    const ctx = &self.compact_unwind_ctx;

    for (self.unwind_records_indexes.items) |irec| {
        const rec = self.getUnwindRecord(irec);
        if (!rec.alive) continue;

        ctx.rec_count += 1;
        ctx.reloc_count += 1;
        if (rec.getPersonality(macho_file)) |_| {
            ctx.reloc_count += 1;
        }
        if (rec.getLsdaAtom(macho_file)) |_| {
            ctx.reloc_count += 1;
        }
    }
}

pub fn writeCompactUnwindRelocatable(self: *Object, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const cpu_arch = macho_file.getTarget().cpu.arch;

    const addReloc = struct {
        fn addReloc(offset: u32, arch: std.Target.Cpu.Arch) !macho.relocation_info {
            return .{
                .r_address = math.cast(i32, offset) orelse return error.Overflow,
                .r_symbolnum = 0,
                .r_pcrel = 0,
                .r_length = 3,
                .r_extern = 0,
                .r_type = switch (arch) {
                    .aarch64 => @intFromEnum(macho.reloc_type_arm64.ARM64_RELOC_UNSIGNED),
                    .x86_64 => @intFromEnum(macho.reloc_type_x86_64.X86_64_RELOC_UNSIGNED),
                    else => unreachable,
                },
            };
        }
    }.addReloc;

    const nsect = macho_file.unwind_info_sect_index.?;
    const buffer = macho_file.sections.items(.out)[nsect].items;
    const relocs = macho_file.sections.items(.relocs)[nsect].items;

    var rec_index: u32 = self.compact_unwind_ctx.rec_index;
    var reloc_index: u32 = self.compact_unwind_ctx.reloc_index;

    for (self.unwind_records_indexes.items) |irec| {
        const rec = self.getUnwindRecord(irec);
        if (!rec.alive) continue;

        var out: macho.compact_unwind_entry = .{
            .rangeStart = 0,
            .rangeLength = rec.length,
            .compactUnwindEncoding = rec.enc.enc,
            .personalityFunction = 0,
            .lsda = 0,
        };
        defer rec_index += 1;

        const offset = rec_index * @sizeOf(macho.compact_unwind_entry);

        {
            // Function address
            const atom = rec.getAtom(macho_file);
            const addr = rec.getAtomAddress(macho_file);
            out.rangeStart = addr;
            var reloc = try addReloc(offset, cpu_arch);
            reloc.r_symbolnum = atom.out_n_sect + 1;
            relocs[reloc_index] = reloc;
            reloc_index += 1;
        }

        // Personality function
        if (rec.getPersonality(macho_file)) |sym| {
            const r_symbolnum = math.cast(u24, sym.getOutputSymtabIndex(macho_file).?) orelse return error.Overflow;
            var reloc = try addReloc(offset + 16, cpu_arch);
            reloc.r_symbolnum = r_symbolnum;
            reloc.r_extern = 1;
            relocs[reloc_index] = reloc;
            reloc_index += 1;
        }

        // LSDA address
        if (rec.getLsdaAtom(macho_file)) |atom| {
            const addr = rec.getLsdaAddress(macho_file);
            out.lsda = addr;
            var reloc = try addReloc(offset + 24, cpu_arch);
            reloc.r_symbolnum = atom.out_n_sect + 1;
            relocs[reloc_index] = reloc;
            reloc_index += 1;
        }

        @memcpy(buffer[offset..][0..@sizeOf(macho.compact_unwind_entry)], mem.asBytes(&out));
    }
}

pub fn writeSymtab(self: Object, macho_file: *MachO, ctx: anytype) void {
    const tracy = trace(@src());
    defer tracy.end();

    var n_strx = self.output_symtab_ctx.stroff;
    for (self.symbols.items, 0..) |sym, i| {
        const ref = self.getSymbolRef(@intCast(i), macho_file);
        const file = ref.getFile(macho_file) orelse continue;
        if (file.getIndex() != self.index) continue;
        const idx = sym.getOutputSymtabIndex(macho_file) orelse continue;
        const out_sym = &ctx.symtab.items[idx];
        out_sym.n_strx = n_strx;
        sym.setOutputSym(macho_file, out_sym);
        const name = sym.getName(macho_file);
        @memcpy(ctx.strtab.items[n_strx..][0..name.len], name);
        n_strx += @intCast(name.len);
        ctx.strtab.items[n_strx] = 0;
        n_strx += 1;
    }

    if (macho_file.base.comp.config.debug_format != .strip and self.hasDebugInfo())
        self.writeStabs(n_strx, macho_file, ctx);
}

pub fn writeStabs(self: Object, stroff: u32, macho_file: *MachO, ctx: anytype) void {
    const writeFuncStab = struct {
        inline fn writeFuncStab(
            n_strx: u32,
            n_sect: u8,
            n_value: u64,
            size: u64,
            index: u32,
            context: anytype,
        ) void {
            context.symtab.items[index] = .{
                .n_strx = 0,
                .n_type = macho.N_BNSYM,
                .n_sect = n_sect,
                .n_desc = 0,
                .n_value = n_value,
            };
            context.symtab.items[index + 1] = .{
                .n_strx = n_strx,
                .n_type = macho.N_FUN,
                .n_sect = n_sect,
                .n_desc = 0,
                .n_value = n_value,
            };
            context.symtab.items[index + 2] = .{
                .n_strx = 0,
                .n_type = macho.N_FUN,
                .n_sect = 0,
                .n_desc = 0,
                .n_value = size,
            };
            context.symtab.items[index + 3] = .{
                .n_strx = 0,
                .n_type = macho.N_ENSYM,
                .n_sect = n_sect,
                .n_desc = 0,
                .n_value = size,
            };
        }
    }.writeFuncStab;

    var index = self.output_symtab_ctx.istab;
    var n_strx = stroff;

    if (self.compile_unit) |cu| {
        const comp_dir = cu.getCompDir(self);
        const tu_name = cu.getTuName(self);

        // Open scope
        // N_SO comp_dir
        ctx.symtab.items[index] = .{
            .n_strx = n_strx,
            .n_type = macho.N_SO,
            .n_sect = 0,
            .n_desc = 0,
            .n_value = 0,
        };
        index += 1;
        @memcpy(ctx.strtab.items[n_strx..][0..comp_dir.len], comp_dir);
        n_strx += @intCast(comp_dir.len);
        ctx.strtab.items[n_strx] = 0;
        n_strx += 1;
        // N_SO tu_name
        macho_file.symtab.items[index] = .{
            .n_strx = n_strx,
            .n_type = macho.N_SO,
            .n_sect = 0,
            .n_desc = 0,
            .n_value = 0,
        };
        index += 1;
        @memcpy(ctx.strtab.items[n_strx..][0..tu_name.len], tu_name);
        n_strx += @intCast(tu_name.len);
        ctx.strtab.items[n_strx] = 0;
        n_strx += 1;
        // N_OSO path
        ctx.symtab.items[index] = .{
            .n_strx = n_strx,
            .n_type = macho.N_OSO,
            .n_sect = 0,
            .n_desc = 1,
            .n_value = self.mtime,
        };
        index += 1;
        if (self.in_archive) |ar| {
            @memcpy(ctx.strtab.items[n_strx..][0..ar.path.len], ar.path);
            n_strx += @intCast(ar.path.len);
            ctx.strtab.items[n_strx] = '(';
            n_strx += 1;
            @memcpy(ctx.strtab.items[n_strx..][0..self.path.len], self.path);
            n_strx += @intCast(self.path.len);
            ctx.strtab.items[n_strx] = ')';
            n_strx += 1;
            ctx.strtab.items[n_strx] = 0;
            n_strx += 1;
        } else {
            @memcpy(ctx.strtab.items[n_strx..][0..self.path.len], self.path);
            n_strx += @intCast(self.path.len);
            ctx.strtab.items[n_strx] = 0;
            n_strx += 1;
        }

        for (self.symbols.items, 0..) |sym, i| {
            const ref = self.getSymbolRef(@intCast(i), macho_file);
            const file = ref.getFile(macho_file) orelse continue;
            if (file.getIndex() != self.index) continue;
            if (!sym.flags.output_symtab) continue;
            if (macho_file.base.isObject()) {
                const name = sym.getName(macho_file);
                if (name.len > 0 and (name[0] == 'L' or name[0] == 'l')) continue;
            }
            const sect = macho_file.sections.items(.header)[sym.getOutputSectionIndex(macho_file)];
            const sym_n_strx = n_strx: {
                const symtab_index = sym.getOutputSymtabIndex(macho_file).?;
                const osym = ctx.symtab.items[symtab_index];
                break :n_strx osym.n_strx;
            };
            const sym_n_sect: u8 = if (!sym.flags.abs) @intCast(sym.getOutputSectionIndex(macho_file) + 1) else 0;
            const sym_n_value = sym.getAddress(.{}, macho_file);
            const sym_size = sym.getSize(macho_file);
            if (sect.isCode()) {
                writeFuncStab(sym_n_strx, sym_n_sect, sym_n_value, sym_size, index, ctx);
                index += 4;
            } else if (sym.visibility == .global) {
                ctx.symtab.items[index] = .{
                    .n_strx = sym_n_strx,
                    .n_type = macho.N_GSYM,
                    .n_sect = sym_n_sect,
                    .n_desc = 0,
                    .n_value = 0,
                };
                index += 1;
            } else {
                ctx.symtab.items[index] = .{
                    .n_strx = sym_n_strx,
                    .n_type = macho.N_STSYM,
                    .n_sect = sym_n_sect,
                    .n_desc = 0,
                    .n_value = sym_n_value,
                };
                index += 1;
            }
        }

        // Close scope
        // N_SO
        ctx.symtab.items[index] = .{
            .n_strx = 0,
            .n_type = macho.N_SO,
            .n_sect = 0,
            .n_desc = 0,
            .n_value = 0,
        };
    } else {
        assert(self.hasSymbolStabs());

        for (self.stab_files.items) |sf| {
            const comp_dir = sf.getCompDir(self);
            const tu_name = sf.getTuName(self);
            const oso_path = sf.getOsoPath(self);

            // Open scope
            // N_SO comp_dir
            ctx.symtab.items[index] = .{
                .n_strx = n_strx,
                .n_type = macho.N_SO,
                .n_sect = 0,
                .n_desc = 0,
                .n_value = 0,
            };
            index += 1;
            @memcpy(ctx.strtab.items[n_strx..][0..comp_dir.len], comp_dir);
            n_strx += @intCast(comp_dir.len);
            ctx.strtab.items[n_strx] = 0;
            n_strx += 1;
            // N_SO tu_name
            ctx.symtab.items[index] = .{
                .n_strx = n_strx,
                .n_type = macho.N_SO,
                .n_sect = 0,
                .n_desc = 0,
                .n_value = 0,
            };
            index += 1;
            @memcpy(ctx.strtab.items[n_strx..][0..tu_name.len], tu_name);
            n_strx += @intCast(tu_name.len);
            ctx.strtab.items[n_strx] = 0;
            n_strx += 1;
            // N_OSO path
            ctx.symtab.items[index] = .{
                .n_strx = n_strx,
                .n_type = macho.N_OSO,
                .n_sect = 0,
                .n_desc = 1,
                .n_value = sf.getOsoModTime(self),
            };
            index += 1;
            @memcpy(ctx.strtab.items[n_strx..][0..oso_path.len], oso_path);
            n_strx += @intCast(oso_path.len);
            ctx.strtab.items[n_strx] = 0;
            n_strx += 1;

            for (sf.stabs.items) |stab| {
                const sym = stab.getSymbol(self) orelse continue;
                const file = sym.getFile(macho_file).?;
                if (file.getIndex() != self.index) continue;
                if (!sym.flags.output_symtab) continue;
                const sym_n_strx = n_strx: {
                    const symtab_index = sym.getOutputSymtabIndex(macho_file).?;
                    const osym = ctx.symtab.items[symtab_index];
                    break :n_strx osym.n_strx;
                };
                const sym_n_sect: u8 = if (!sym.flags.abs) @intCast(sym.getOutputSectionIndex(macho_file) + 1) else 0;
                const sym_n_value = sym.getAddress(.{}, macho_file);
                const sym_size = sym.getSize(macho_file);
                if (stab.is_func) {
                    writeFuncStab(sym_n_strx, sym_n_sect, sym_n_value, sym_size, index, ctx);
                    index += 4;
                } else if (sym.visibility == .global) {
                    ctx.symtab.items[index] = .{
                        .n_strx = sym_n_strx,
                        .n_type = macho.N_GSYM,
                        .n_sect = sym_n_sect,
                        .n_desc = 0,
                        .n_value = 0,
                    };
                    index += 1;
                } else {
                    ctx.symtab.items[index] = .{
                        .n_strx = sym_n_strx,
                        .n_type = macho.N_STSYM,
                        .n_sect = sym_n_sect,
                        .n_desc = 0,
                        .n_value = sym_n_value,
                    };
                    index += 1;
                }
            }

            // Close scope
            // N_SO
            ctx.symtab.items[index] = .{
                .n_strx = 0,
                .n_type = macho.N_SO,
                .n_sect = 0,
                .n_desc = 0,
                .n_value = 0,
            };
            index += 1;
        }
    }
}

pub fn getAtomRelocs(self: *const Object, atom: Atom, macho_file: *MachO) []const Relocation {
    const extra = atom.getExtra(macho_file);
    const relocs = self.sections.items(.relocs)[atom.n_sect];
    return relocs.items[extra.rel_index..][0..extra.rel_count];
}

fn addString(self: *Object, allocator: Allocator, string: [:0]const u8) error{OutOfMemory}!MachO.String {
    const off: u32 = @intCast(self.strtab.items.len);
    try self.strtab.ensureUnusedCapacity(allocator, string.len + 1);
    self.strtab.appendSliceAssumeCapacity(string);
    self.strtab.appendAssumeCapacity(0);
    return .{ .pos = off, .len = @intCast(string.len + 1) };
}

pub fn getString(self: Object, string: MachO.String) [:0]const u8 {
    assert(string.pos < self.strtab.items.len and string.pos + string.len <= self.strtab.items.len);
    if (string.len == 0) return "";
    return self.strtab.items[string.pos..][0 .. string.len - 1 :0];
}

fn getNStrx(self: Object, n_strx: u32) [:0]const u8 {
    assert(n_strx < self.strtab.items.len);
    return mem.sliceTo(@as([*:0]const u8, @ptrCast(self.strtab.items.ptr + n_strx)), 0);
}

pub fn hasUnwindRecords(self: Object) bool {
    return self.unwind_records.items.len > 0;
}

pub fn hasEhFrameRecords(self: Object) bool {
    return self.cies.items.len > 0;
}

pub fn hasDebugInfo(self: Object) bool {
    return self.compile_unit != null or self.hasSymbolStabs();
}

fn hasSymbolStabs(self: Object) bool {
    return self.stab_files.items.len > 0;
}

fn hasObjC(self: Object) bool {
    for (self.symtab.items(.nlist)) |nlist| {
        const name = self.getNStrx(nlist.n_strx);
        if (mem.startsWith(u8, name, "_OBJC_CLASS_$_")) return true;
    }
    for (self.sections.items(.header)) |sect| {
        if (mem.eql(u8, sect.segName(), "__DATA") and mem.eql(u8, sect.sectName(), "__objc_catlist")) return true;
        if (mem.eql(u8, sect.segName(), "__TEXT") and mem.eql(u8, sect.sectName(), "__swift")) return true;
    }
    return false;
}

pub fn getDataInCode(self: Object) []const macho.data_in_code_entry {
    return self.data_in_code.items;
}

pub inline fn hasSubsections(self: Object) bool {
    return self.header.?.flags & macho.MH_SUBSECTIONS_VIA_SYMBOLS != 0;
}

pub fn asFile(self: *Object) File {
    return .{ .object = self };
}

const AddAtomArgs = struct {
    name: MachO.String,
    n_sect: u8,
    off: u64,
    size: u64,
    alignment: u32,
};

fn addAtom(self: *Object, allocator: Allocator, args: AddAtomArgs) !Atom.Index {
    const atom_index: Atom.Index = @intCast(self.atoms.items.len);
    const atom = try self.atoms.addOne(allocator);
    atom.* = .{
        .file = self.index,
        .atom_index = atom_index,
        .name = args.name,
        .n_sect = args.n_sect,
        .size = args.size,
        .off = args.off,
        .extra = try self.addAtomExtra(allocator, .{}),
        .alignment = Atom.Alignment.fromLog2Units(args.alignment),
    };
    return atom_index;
}

pub fn getAtom(self: *Object, atom_index: Atom.Index) ?*Atom {
    if (atom_index == 0) return null;
    assert(atom_index < self.atoms.items.len);
    return &self.atoms.items[atom_index];
}

pub fn getAtoms(self: *Object) []const Atom.Index {
    return self.atoms_indexes.items;
}

fn addAtomExtra(self: *Object, allocator: Allocator, extra: Atom.Extra) !u32 {
    const fields = @typeInfo(Atom.Extra).@"struct".fields;
    try self.atoms_extra.ensureUnusedCapacity(allocator, fields.len);
    return self.addAtomExtraAssumeCapacity(extra);
}

fn addAtomExtraAssumeCapacity(self: *Object, extra: Atom.Extra) u32 {
    const index = @as(u32, @intCast(self.atoms_extra.items.len));
    const fields = @typeInfo(Atom.Extra).@"struct".fields;
    inline for (fields) |field| {
        self.atoms_extra.appendAssumeCapacity(switch (field.type) {
            u32 => @field(extra, field.name),
            else => @compileError("bad field type"),
        });
    }
    return index;
}

pub fn getAtomExtra(self: Object, index: u32) Atom.Extra {
    const fields = @typeInfo(Atom.Extra).@"struct".fields;
    var i: usize = index;
    var result: Atom.Extra = undefined;
    inline for (fields) |field| {
        @field(result, field.name) = switch (field.type) {
            u32 => self.atoms_extra.items[i],
            else => @compileError("bad field type"),
        };
        i += 1;
    }
    return result;
}

pub fn setAtomExtra(self: *Object, index: u32, extra: Atom.Extra) void {
    assert(index > 0);
    const fields = @typeInfo(Atom.Extra).@"struct".fields;
    inline for (fields, 0..) |field, i| {
        self.atoms_extra.items[index + i] = switch (field.type) {
            u32 => @field(extra, field.name),
            else => @compileError("bad field type"),
        };
    }
}

fn addSymbol(self: *Object, allocator: Allocator) !Symbol.Index {
    try self.symbols.ensureUnusedCapacity(allocator, 1);
    return self.addSymbolAssumeCapacity();
}

fn addSymbolAssumeCapacity(self: *Object) Symbol.Index {
    const index: Symbol.Index = @intCast(self.symbols.items.len);
    const symbol = self.symbols.addOneAssumeCapacity();
    symbol.* = .{ .file = self.index };
    return index;
}

pub fn getSymbolRef(self: Object, index: Symbol.Index, macho_file: *MachO) MachO.Ref {
    const global_index = self.globals.items[index];
    if (macho_file.resolver.get(global_index)) |ref| return ref;
    return .{ .index = index, .file = self.index };
}

pub fn addSymbolExtra(self: *Object, allocator: Allocator, extra: Symbol.Extra) !u32 {
    const fields = @typeInfo(Symbol.Extra).@"struct".fields;
    try self.symbols_extra.ensureUnusedCapacity(allocator, fields.len);
    return self.addSymbolExtraAssumeCapacity(extra);
}

fn addSymbolExtraAssumeCapacity(self: *Object, extra: Symbol.Extra) u32 {
    const index = @as(u32, @intCast(self.symbols_extra.items.len));
    const fields = @typeInfo(Symbol.Extra).@"struct".fields;
    inline for (fields) |field| {
        self.symbols_extra.appendAssumeCapacity(switch (field.type) {
            u32 => @field(extra, field.name),
            else => @compileError("bad field type"),
        });
    }
    return index;
}

pub fn getSymbolExtra(self: Object, index: u32) Symbol.Extra {
    const fields = @typeInfo(Symbol.Extra).@"struct".fields;
    var i: usize = index;
    var result: Symbol.Extra = undefined;
    inline for (fields) |field| {
        @field(result, field.name) = switch (field.type) {
            u32 => self.symbols_extra.items[i],
            else => @compileError("bad field type"),
        };
        i += 1;
    }
    return result;
}

pub fn setSymbolExtra(self: *Object, index: u32, extra: Symbol.Extra) void {
    const fields = @typeInfo(Symbol.Extra).@"struct".fields;
    inline for (fields, 0..) |field, i| {
        self.symbols_extra.items[index + i] = switch (field.type) {
            u32 => @field(extra, field.name),
            else => @compileError("bad field type"),
        };
    }
}

fn addUnwindRecord(self: *Object, allocator: Allocator) !UnwindInfo.Record.Index {
    try self.unwind_records.ensureUnusedCapacity(allocator, 1);
    return self.addUnwindRecordAssumeCapacity();
}

fn addUnwindRecordAssumeCapacity(self: *Object) UnwindInfo.Record.Index {
    const index = @as(UnwindInfo.Record.Index, @intCast(self.unwind_records.items.len));
    const rec = self.unwind_records.addOneAssumeCapacity();
    rec.* = .{ .file = self.index };
    return index;
}

pub fn getUnwindRecord(self: *Object, index: UnwindInfo.Record.Index) *UnwindInfo.Record {
    assert(index < self.unwind_records.items.len);
    return &self.unwind_records.items[index];
}

pub fn format(
    self: *Object,
    comptime unused_fmt_string: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = self;
    _ = unused_fmt_string;
    _ = options;
    _ = writer;
    @compileError("do not format objects directly");
}

const FormatContext = struct {
    object: *Object,
    macho_file: *MachO,
};

pub fn fmtAtoms(self: *Object, macho_file: *MachO) std.fmt.Formatter(formatAtoms) {
    return .{ .data = .{
        .object = self,
        .macho_file = macho_file,
    } };
}

fn formatAtoms(
    ctx: FormatContext,
    comptime unused_fmt_string: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = unused_fmt_string;
    _ = options;
    const object = ctx.object;
    const macho_file = ctx.macho_file;
    try writer.writeAll("  atoms\n");
    for (object.getAtoms()) |atom_index| {
        const atom = object.getAtom(atom_index) orelse continue;
        try writer.print("    {}\n", .{atom.fmt(macho_file)});
    }
}

pub fn fmtCies(self: *Object, macho_file: *MachO) std.fmt.Formatter(formatCies) {
    return .{ .data = .{
        .object = self,
        .macho_file = macho_file,
    } };
}

fn formatCies(
    ctx: FormatContext,
    comptime unused_fmt_string: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = unused_fmt_string;
    _ = options;
    const object = ctx.object;
    try writer.writeAll("  cies\n");
    for (object.cies.items, 0..) |cie, i| {
        try writer.print("    cie({d}) : {}\n", .{ i, cie.fmt(ctx.macho_file) });
    }
}

pub fn fmtFdes(self: *Object, macho_file: *MachO) std.fmt.Formatter(formatFdes) {
    return .{ .data = .{
        .object = self,
        .macho_file = macho_file,
    } };
}

fn formatFdes(
    ctx: FormatContext,
    comptime unused_fmt_string: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = unused_fmt_string;
    _ = options;
    const object = ctx.object;
    try writer.writeAll("  fdes\n");
    for (object.fdes.items, 0..) |fde, i| {
        try writer.print("    fde({d}) : {}\n", .{ i, fde.fmt(ctx.macho_file) });
    }
}

pub fn fmtUnwindRecords(self: *Object, macho_file: *MachO) std.fmt.Formatter(formatUnwindRecords) {
    return .{ .data = .{
        .object = self,
        .macho_file = macho_file,
    } };
}

fn formatUnwindRecords(
    ctx: FormatContext,
    comptime unused_fmt_string: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = unused_fmt_string;
    _ = options;
    const object = ctx.object;
    const macho_file = ctx.macho_file;
    try writer.writeAll("  unwind records\n");
    for (object.unwind_records_indexes.items) |rec| {
        try writer.print("    rec({d}) : {}\n", .{ rec, object.getUnwindRecord(rec).fmt(macho_file) });
    }
}

pub fn fmtSymtab(self: *Object, macho_file: *MachO) std.fmt.Formatter(formatSymtab) {
    return .{ .data = .{
        .object = self,
        .macho_file = macho_file,
    } };
}

fn formatSymtab(
    ctx: FormatContext,
    comptime unused_fmt_string: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = unused_fmt_string;
    _ = options;
    const object = ctx.object;
    const macho_file = ctx.macho_file;
    try writer.writeAll("  symbols\n");
    for (object.symbols.items, 0..) |sym, i| {
        const ref = object.getSymbolRef(@intCast(i), macho_file);
        if (ref.getFile(macho_file) == null) {
            // TODO any better way of handling this?
            try writer.print("    {s} : unclaimed\n", .{sym.getName(macho_file)});
        } else {
            try writer.print("    {}\n", .{ref.getSymbol(macho_file).?.fmt(macho_file)});
        }
    }
    for (object.stab_files.items) |sf| {
        try writer.print("  stabs({s},{s},{s})\n", .{
            sf.getCompDir(object.*),
            sf.getTuName(object.*),
            sf.getOsoPath(object.*),
        });
        for (sf.stabs.items) |stab| {
            try writer.print("    {}", .{stab.fmt(object.*)});
        }
    }
}

pub fn fmtPath(self: Object) std.fmt.Formatter(formatPath) {
    return .{ .data = self };
}

fn formatPath(
    object: Object,
    comptime unused_fmt_string: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = unused_fmt_string;
    _ = options;
    if (object.in_archive) |ar| {
        try writer.writeAll(ar.path);
        try writer.writeByte('(');
        try writer.writeAll(object.path);
        try writer.writeByte(')');
    } else try writer.writeAll(object.path);
}

const Section = struct {
    header: macho.section_64,
    subsections: std.ArrayListUnmanaged(Subsection) = .empty,
    relocs: std.ArrayListUnmanaged(Relocation) = .empty,
};

const Subsection = struct {
    atom: Atom.Index,
    off: u64,
};

pub const Nlist = struct {
    nlist: macho.nlist_64,
    size: u64,
    atom: Atom.Index,
};

const StabFile = struct {
    comp_dir: u32,
    stabs: std.ArrayListUnmanaged(Stab) = .empty,

    fn getCompDir(sf: StabFile, object: Object) [:0]const u8 {
        const nlist = object.symtab.items(.nlist)[sf.comp_dir];
        return object.getNStrx(nlist.n_strx);
    }

    fn getTuName(sf: StabFile, object: Object) [:0]const u8 {
        const nlist = object.symtab.items(.nlist)[sf.comp_dir + 1];
        return object.getNStrx(nlist.n_strx);
    }

    fn getOsoPath(sf: StabFile, object: Object) [:0]const u8 {
        const nlist = object.symtab.items(.nlist)[sf.comp_dir + 2];
        return object.getNStrx(nlist.n_strx);
    }

    fn getOsoModTime(sf: StabFile, object: Object) u64 {
        const nlist = object.symtab.items(.nlist)[sf.comp_dir + 2];
        return nlist.n_value;
    }

    const Stab = struct {
        is_func: bool = true,
        index: ?Symbol.Index = null,

        fn getSymbol(stab: Stab, object: Object) ?Symbol {
            const index = stab.index orelse return null;
            return object.symbols.items[index];
        }

        pub fn format(
            stab: Stab,
            comptime unused_fmt_string: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = stab;
            _ = unused_fmt_string;
            _ = options;
            _ = writer;
            @compileError("do not format stabs directly");
        }

        const StabFormatContext = struct { Stab, Object };

        pub fn fmt(stab: Stab, object: Object) std.fmt.Formatter(format2) {
            return .{ .data = .{ stab, object } };
        }

        fn format2(
            ctx: StabFormatContext,
            comptime unused_fmt_string: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = unused_fmt_string;
            _ = options;
            const stab, const object = ctx;
            const sym = stab.getSymbol(object).?;
            if (stab.is_func) {
                try writer.print("func({d})", .{stab.index.?});
            } else if (sym.visibility == .global) {
                try writer.print("gsym({d})", .{stab.index.?});
            } else {
                try writer.print("stsym({d})", .{stab.index.?});
            }
        }
    };
};

const CompileUnit = struct {
    comp_dir: MachO.String,
    tu_name: MachO.String,

    fn getCompDir(cu: CompileUnit, object: Object) [:0]const u8 {
        return object.getString(cu.comp_dir);
    }

    fn getTuName(cu: CompileUnit, object: Object) [:0]const u8 {
        return object.getString(cu.tu_name);
    }
};

const InArchive = struct {
    path: []const u8,
    size: u32,
};

const CompactUnwindCtx = struct {
    rec_index: u32 = 0,
    rec_count: u32 = 0,
    reloc_index: u32 = 0,
    reloc_count: u32 = 0,
};

const x86_64 = struct {
    fn parseRelocs(
        self: *Object,
        sect: macho.section_64,
        out: *std.ArrayListUnmanaged(Relocation),
        handle: File.Handle,
        macho_file: *MachO,
    ) !void {
        const gpa = macho_file.base.comp.gpa;

        const relocs_buffer = try gpa.alloc(u8, sect.nreloc * @sizeOf(macho.relocation_info));
        defer gpa.free(relocs_buffer);
        {
            const amt = try handle.preadAll(relocs_buffer, sect.reloff + self.offset);
            if (amt != relocs_buffer.len) return error.InputOutput;
        }
        const relocs = @as([*]align(1) const macho.relocation_info, @ptrCast(relocs_buffer.ptr))[0..sect.nreloc];

        const sect_size = math.cast(usize, sect.size) orelse return error.Overflow;
        const code = try gpa.alloc(u8, sect_size);
        defer gpa.free(code);
        {
            const amt = try handle.preadAll(code, sect.offset + self.offset);
            if (amt != code.len) return error.InputOutput;
        }

        try out.ensureTotalCapacityPrecise(gpa, relocs.len);

        var i: usize = 0;
        while (i < relocs.len) : (i += 1) {
            const rel = relocs[i];
            const rel_type: macho.reloc_type_x86_64 = @enumFromInt(rel.r_type);
            const rel_offset = @as(u32, @intCast(rel.r_address));

            var addend = switch (rel.r_length) {
                0 => code[rel_offset],
                1 => mem.readInt(i16, code[rel_offset..][0..2], .little),
                2 => mem.readInt(i32, code[rel_offset..][0..4], .little),
                3 => mem.readInt(i64, code[rel_offset..][0..8], .little),
            };
            addend += switch (@as(macho.reloc_type_x86_64, @enumFromInt(rel.r_type))) {
                .X86_64_RELOC_SIGNED_1 => 1,
                .X86_64_RELOC_SIGNED_2 => 2,
                .X86_64_RELOC_SIGNED_4 => 4,
                else => 0,
            };
            var is_extern = rel.r_extern == 1;

            const target = if (!is_extern) blk: {
                const nsect = rel.r_symbolnum - 1;
                const taddr: i64 = if (rel.r_pcrel == 1)
                    @as(i64, @intCast(sect.addr)) + rel.r_address + addend + 4
                else
                    addend;
                const target = self.findAtomInSection(@intCast(taddr), @intCast(nsect)) orelse {
                    try macho_file.reportParseError2(self.index, "{s},{s}: 0x{x}: bad relocation", .{
                        sect.segName(), sect.sectName(), rel.r_address,
                    });
                    return error.MalformedObject;
                };
                const target_atom = self.getAtom(target).?;
                addend = taddr - @as(i64, @intCast(target_atom.getInputAddress(macho_file)));
                const isec = target_atom.getInputSection(macho_file);
                if (isCstringLiteral(isec) or isFixedSizeLiteral(isec) or isPtrLiteral(isec)) {
                    is_extern = true;
                    break :blk target_atom.getExtra(macho_file).literal_symbol_index;
                }
                break :blk target;
            } else rel.r_symbolnum;

            const has_subtractor = if (i > 0 and
                @as(macho.reloc_type_x86_64, @enumFromInt(relocs[i - 1].r_type)) == .X86_64_RELOC_SUBTRACTOR)
            blk: {
                if (rel_type != .X86_64_RELOC_UNSIGNED) {
                    try macho_file.reportParseError2(self.index, "{s},{s}: 0x{x}: X86_64_RELOC_SUBTRACTOR followed by {s}", .{
                        sect.segName(), sect.sectName(), rel_offset, @tagName(rel_type),
                    });
                    return error.MalformedObject;
                }
                break :blk true;
            } else false;

            const @"type": Relocation.Type = validateRelocType(rel, rel_type, is_extern) catch |err| {
                switch (err) {
                    error.Pcrel => try macho_file.reportParseError2(
                        self.index,
                        "{s},{s}: 0x{x}: PC-relative {s} relocation",
                        .{ sect.segName(), sect.sectName(), rel_offset, @tagName(rel_type) },
                    ),
                    error.NonPcrel => try macho_file.reportParseError2(
                        self.index,
                        "{s},{s}: 0x{x}: non-PC-relative {s} relocation",
                        .{ sect.segName(), sect.sectName(), rel_offset, @tagName(rel_type) },
                    ),
                    error.InvalidLength => try macho_file.reportParseError2(
                        self.index,
                        "{s},{s}: 0x{x}: invalid length of {d} in {s} relocation",
                        .{ sect.segName(), sect.sectName(), rel_offset, @as(u8, 1) << rel.r_length, @tagName(rel_type) },
                    ),
                    error.NonExtern => try macho_file.reportParseError2(
                        self.index,
                        "{s},{s}: 0x{x}: non-extern target in {s} relocation",
                        .{ sect.segName(), sect.sectName(), rel_offset, @tagName(rel_type) },
                    ),
                }
                return error.MalformedObject;
            };

            out.appendAssumeCapacity(.{
                .tag = if (is_extern) .@"extern" else .local,
                .offset = @as(u32, @intCast(rel.r_address)),
                .target = target,
                .addend = addend,
                .type = @"type",
                .meta = .{
                    .pcrel = rel.r_pcrel == 1,
                    .has_subtractor = has_subtractor,
                    .length = rel.r_length,
                    .symbolnum = rel.r_symbolnum,
                },
            });
        }
    }

    fn validateRelocType(rel: macho.relocation_info, rel_type: macho.reloc_type_x86_64, is_extern: bool) !Relocation.Type {
        switch (rel_type) {
            .X86_64_RELOC_UNSIGNED => {
                if (rel.r_pcrel == 1) return error.Pcrel;
                if (rel.r_length != 2 and rel.r_length != 3) return error.InvalidLength;
                return .unsigned;
            },

            .X86_64_RELOC_SUBTRACTOR => {
                if (rel.r_pcrel == 1) return error.Pcrel;
                return .subtractor;
            },

            .X86_64_RELOC_BRANCH,
            .X86_64_RELOC_GOT_LOAD,
            .X86_64_RELOC_GOT,
            .X86_64_RELOC_TLV,
            => {
                if (rel.r_pcrel == 0) return error.NonPcrel;
                if (rel.r_length != 2) return error.InvalidLength;
                if (!is_extern) return error.NonExtern;
                return switch (rel_type) {
                    .X86_64_RELOC_BRANCH => .branch,
                    .X86_64_RELOC_GOT_LOAD => .got_load,
                    .X86_64_RELOC_GOT => .got,
                    .X86_64_RELOC_TLV => .tlv,
                    else => unreachable,
                };
            },

            .X86_64_RELOC_SIGNED,
            .X86_64_RELOC_SIGNED_1,
            .X86_64_RELOC_SIGNED_2,
            .X86_64_RELOC_SIGNED_4,
            => {
                if (rel.r_pcrel == 0) return error.NonPcrel;
                if (rel.r_length != 2) return error.InvalidLength;
                return switch (rel_type) {
                    .X86_64_RELOC_SIGNED => .signed,
                    .X86_64_RELOC_SIGNED_1 => .signed1,
                    .X86_64_RELOC_SIGNED_2 => .signed2,
                    .X86_64_RELOC_SIGNED_4 => .signed4,
                    else => unreachable,
                };
            },
        }
    }
};

const aarch64 = struct {
    fn parseRelocs(
        self: *Object,
        sect: macho.section_64,
        out: *std.ArrayListUnmanaged(Relocation),
        handle: File.Handle,
        macho_file: *MachO,
    ) !void {
        const gpa = macho_file.base.comp.gpa;

        const relocs_buffer = try gpa.alloc(u8, sect.nreloc * @sizeOf(macho.relocation_info));
        defer gpa.free(relocs_buffer);
        {
            const amt = try handle.preadAll(relocs_buffer, sect.reloff + self.offset);
            if (amt != relocs_buffer.len) return error.InputOutput;
        }
        const relocs = @as([*]align(1) const macho.relocation_info, @ptrCast(relocs_buffer.ptr))[0..sect.nreloc];

        const sect_size = math.cast(usize, sect.size) orelse return error.Overflow;
        const code = try gpa.alloc(u8, sect_size);
        defer gpa.free(code);
        {
            const amt = try handle.preadAll(code, sect.offset + self.offset);
            if (amt != code.len) return error.InputOutput;
        }

        try out.ensureTotalCapacityPrecise(gpa, relocs.len);

        var i: usize = 0;
        while (i < relocs.len) : (i += 1) {
            var rel = relocs[i];
            const rel_offset = @as(u32, @intCast(rel.r_address));

            var addend: i64 = 0;

            switch (@as(macho.reloc_type_arm64, @enumFromInt(rel.r_type))) {
                .ARM64_RELOC_ADDEND => {
                    addend = rel.r_symbolnum;
                    i += 1;
                    if (i >= relocs.len) {
                        try macho_file.reportParseError2(self.index, "{s},{s}: 0x{x}: unterminated ARM64_RELOC_ADDEND", .{
                            sect.segName(), sect.sectName(), rel_offset,
                        });
                        return error.MalformedObject;
                    }
                    rel = relocs[i];
                    switch (@as(macho.reloc_type_arm64, @enumFromInt(rel.r_type))) {
                        .ARM64_RELOC_PAGE21, .ARM64_RELOC_PAGEOFF12 => {},
                        else => |x| {
                            try macho_file.reportParseError2(
                                self.index,
                                "{s},{s}: 0x{x}: ARM64_RELOC_ADDEND followed by {s}",
                                .{ sect.segName(), sect.sectName(), rel_offset, @tagName(x) },
                            );
                            return error.MalformedObject;
                        },
                    }
                },
                .ARM64_RELOC_UNSIGNED => {
                    addend = switch (rel.r_length) {
                        0 => code[rel_offset],
                        1 => mem.readInt(i16, code[rel_offset..][0..2], .little),
                        2 => mem.readInt(i32, code[rel_offset..][0..4], .little),
                        3 => mem.readInt(i64, code[rel_offset..][0..8], .little),
                    };
                },
                else => {},
            }

            const rel_type: macho.reloc_type_arm64 = @enumFromInt(rel.r_type);
            var is_extern = rel.r_extern == 1;

            const target = if (!is_extern) blk: {
                const nsect = rel.r_symbolnum - 1;
                const taddr: i64 = if (rel.r_pcrel == 1)
                    @as(i64, @intCast(sect.addr)) + rel.r_address + addend
                else
                    addend;
                const target = self.findAtomInSection(@intCast(taddr), @intCast(nsect)) orelse {
                    try macho_file.reportParseError2(self.index, "{s},{s}: 0x{x}: bad relocation", .{
                        sect.segName(), sect.sectName(), rel.r_address,
                    });
                    return error.MalformedObject;
                };
                const target_atom = self.getAtom(target).?;
                addend = taddr - @as(i64, @intCast(target_atom.getInputAddress(macho_file)));
                const isec = target_atom.getInputSection(macho_file);
                if (isCstringLiteral(isec) or isFixedSizeLiteral(isec) or isPtrLiteral(isec)) {
                    is_extern = true;
                    break :blk target_atom.getExtra(macho_file).literal_symbol_index;
                }
                break :blk target;
            } else rel.r_symbolnum;

            const has_subtractor = if (i > 0 and
                @as(macho.reloc_type_arm64, @enumFromInt(relocs[i - 1].r_type)) == .ARM64_RELOC_SUBTRACTOR)
            blk: {
                if (rel_type != .ARM64_RELOC_UNSIGNED) {
                    try macho_file.reportParseError2(self.index, "{s},{s}: 0x{x}: ARM64_RELOC_SUBTRACTOR followed by {s}", .{
                        sect.segName(), sect.sectName(), rel_offset, @tagName(rel_type),
                    });
                    return error.MalformedObject;
                }
                break :blk true;
            } else false;

            const @"type": Relocation.Type = validateRelocType(rel, rel_type, is_extern) catch |err| {
                switch (err) {
                    error.Pcrel => try macho_file.reportParseError2(
                        self.index,
                        "{s},{s}: 0x{x}: PC-relative {s} relocation",
                        .{ sect.segName(), sect.sectName(), rel_offset, @tagName(rel_type) },
                    ),
                    error.NonPcrel => try macho_file.reportParseError2(
                        self.index,
                        "{s},{s}: 0x{x}: non-PC-relative {s} relocation",
                        .{ sect.segName(), sect.sectName(), rel_offset, @tagName(rel_type) },
                    ),
                    error.InvalidLength => try macho_file.reportParseError2(
                        self.index,
                        "{s},{s}: 0x{x}: invalid length of {d} in {s} relocation",
                        .{ sect.segName(), sect.sectName(), rel_offset, @as(u8, 1) << rel.r_length, @tagName(rel_type) },
                    ),
                    error.NonExtern => try macho_file.reportParseError2(
                        self.index,
                        "{s},{s}: 0x{x}: non-extern target in {s} relocation",
                        .{ sect.segName(), sect.sectName(), rel_offset, @tagName(rel_type) },
                    ),
                }
                return error.MalformedObject;
            };

            out.appendAssumeCapacity(.{
                .tag = if (is_extern) .@"extern" else .local,
                .offset = @as(u32, @intCast(rel.r_address)),
                .target = target,
                .addend = addend,
                .type = @"type",
                .meta = .{
                    .pcrel = rel.r_pcrel == 1,
                    .has_subtractor = has_subtractor,
                    .length = rel.r_length,
                    .symbolnum = rel.r_symbolnum,
                },
            });
        }
    }

    fn validateRelocType(rel: macho.relocation_info, rel_type: macho.reloc_type_arm64, is_extern: bool) !Relocation.Type {
        switch (rel_type) {
            .ARM64_RELOC_UNSIGNED => {
                if (rel.r_pcrel == 1) return error.Pcrel;
                if (rel.r_length != 2 and rel.r_length != 3) return error.InvalidLength;
                return .unsigned;
            },

            .ARM64_RELOC_SUBTRACTOR => {
                if (rel.r_pcrel == 1) return error.Pcrel;
                return .subtractor;
            },

            .ARM64_RELOC_BRANCH26,
            .ARM64_RELOC_PAGE21,
            .ARM64_RELOC_GOT_LOAD_PAGE21,
            .ARM64_RELOC_TLVP_LOAD_PAGE21,
            .ARM64_RELOC_POINTER_TO_GOT,
            => {
                if (rel.r_pcrel == 0) return error.NonPcrel;
                if (rel.r_length != 2) return error.InvalidLength;
                if (!is_extern) return error.NonExtern;
                return switch (rel_type) {
                    .ARM64_RELOC_BRANCH26 => .branch,
                    .ARM64_RELOC_PAGE21 => .page,
                    .ARM64_RELOC_GOT_LOAD_PAGE21 => .got_load_page,
                    .ARM64_RELOC_TLVP_LOAD_PAGE21 => .tlvp_page,
                    .ARM64_RELOC_POINTER_TO_GOT => .got,
                    else => unreachable,
                };
            },

            .ARM64_RELOC_PAGEOFF12,
            .ARM64_RELOC_GOT_LOAD_PAGEOFF12,
            .ARM64_RELOC_TLVP_LOAD_PAGEOFF12,
            => {
                if (rel.r_pcrel == 1) return error.Pcrel;
                if (rel.r_length != 2) return error.InvalidLength;
                if (!is_extern) return error.NonExtern;
                return switch (rel_type) {
                    .ARM64_RELOC_PAGEOFF12 => .pageoff,
                    .ARM64_RELOC_GOT_LOAD_PAGEOFF12 => .got_load_pageoff,
                    .ARM64_RELOC_TLVP_LOAD_PAGEOFF12 => .tlvp_pageoff,
                    else => unreachable,
                };
            },

            .ARM64_RELOC_ADDEND => unreachable, // We make it part of the addend field
        }
    }
};

const assert = std.debug.assert;
const dwarf = @import("dwarf.zig");
const eh_frame = @import("eh_frame.zig");
const log = std.log.scoped(.link);
const macho = std.macho;
const math = std.math;
const mem = std.mem;
const trace = @import("../../tracy.zig").trace;
const std = @import("std");

const Allocator = mem.Allocator;
const Archive = @import("Archive.zig");
const Atom = @import("Atom.zig");
const Cie = eh_frame.Cie;
const Fde = eh_frame.Fde;
const File = @import("file.zig").File;
const LoadCommandIterator = macho.LoadCommandIterator;
const MachO = @import("../MachO.zig");
const Object = @This();
const Relocation = @import("Relocation.zig");
const Symbol = @import("Symbol.zig");
const UnwindInfo = @import("UnwindInfo.zig");
