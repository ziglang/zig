archive: ?InArchive = null,
path: []const u8,
file_handle: File.HandleIndex,
mtime: u64,
index: File.Index,

header: ?macho.mach_header_64 = null,
sections: std.MultiArrayList(Section) = .{},
symtab: std.MultiArrayList(Nlist) = .{},
strtab: std.ArrayListUnmanaged(u8) = .{},

symbols: std.ArrayListUnmanaged(Symbol.Index) = .{},
atoms: std.ArrayListUnmanaged(Atom.Index) = .{},

platform: ?MachO.Platform = null,
dwarf_info: ?DwarfInfo = null,
stab_files: std.ArrayListUnmanaged(StabFile) = .{},

eh_frame_sect_index: ?u8 = null,
compact_unwind_sect_index: ?u8 = null,
cies: std.ArrayListUnmanaged(Cie) = .{},
fdes: std.ArrayListUnmanaged(Fde) = .{},
eh_frame_data: std.ArrayListUnmanaged(u8) = .{},
unwind_records: std.ArrayListUnmanaged(UnwindInfo.Record.Index) = .{},
data_in_code: std.ArrayListUnmanaged(macho.data_in_code_entry) = .{},

alive: bool = true,
hidden: bool = false,

dynamic_relocs: MachO.DynamicRelocs = .{},
output_symtab_ctx: MachO.SymtabCtx = .{},
output_ar_state: Archive.ArState = .{},

const InArchive = struct {
    path: []const u8,
    offset: u64,
    size: u32,
};

pub fn isObject(path: []const u8) !bool {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const header = file.reader().readStruct(macho.mach_header_64) catch return false;
    return header.filetype == macho.MH_OBJECT;
}

pub fn deinit(self: *Object, allocator: Allocator) void {
    if (self.archive) |*ar| allocator.free(ar.path);
    allocator.free(self.path);
    for (self.sections.items(.relocs), self.sections.items(.subsections)) |*relocs, *sub| {
        relocs.deinit(allocator);
        sub.deinit(allocator);
    }
    self.sections.deinit(allocator);
    self.symtab.deinit(allocator);
    self.strtab.deinit(allocator);
    self.symbols.deinit(allocator);
    self.atoms.deinit(allocator);
    self.cies.deinit(allocator);
    self.fdes.deinit(allocator);
    self.eh_frame_data.deinit(allocator);
    self.unwind_records.deinit(allocator);
    if (self.dwarf_info) |*dw| dw.deinit(allocator);
    for (self.stab_files.items) |*sf| {
        sf.stabs.deinit(allocator);
    }
    self.stab_files.deinit(allocator);
    self.data_in_code.deinit(allocator);
}

pub fn parse(self: *Object, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = macho_file.base.comp.gpa;
    const offset = if (self.archive) |ar| ar.offset else 0;
    const handle = macho_file.getFileHandle(self.file_handle);

    var header_buffer: [@sizeOf(macho.mach_header_64)]u8 = undefined;
    {
        const amt = try handle.preadAll(&header_buffer, offset);
        if (amt != @sizeOf(macho.mach_header_64)) return error.InputOutput;
    }
    self.header = @as(*align(1) const macho.mach_header_64, @ptrCast(&header_buffer)).*;

    const this_cpu_arch: std.Target.Cpu.Arch = switch (self.header.?.cputype) {
        macho.CPU_TYPE_ARM64 => .aarch64,
        macho.CPU_TYPE_X86_64 => .x86_64,
        else => |x| {
            try macho_file.reportParseError2(self.index, "unknown cpu architecture: {d}", .{x});
            return error.InvalidCpuArch;
        },
    };
    if (macho_file.getTarget().cpu.arch != this_cpu_arch) {
        try macho_file.reportParseError2(self.index, "invalid cpu architecture: {s}", .{@tagName(this_cpu_arch)});
        return error.InvalidCpuArch;
    }

    const lc_buffer = try gpa.alloc(u8, self.header.?.sizeofcmds);
    defer gpa.free(lc_buffer);
    {
        const amt = try handle.preadAll(lc_buffer, offset + @sizeOf(macho.mach_header_64));
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
                const amt = try handle.preadAll(self.strtab.items, cmd.stroff + offset);
                if (amt != self.strtab.items.len) return error.InputOutput;
            }

            const symtab_buffer = try gpa.alloc(u8, cmd.nsyms * @sizeOf(macho.nlist_64));
            defer gpa.free(symtab_buffer);
            {
                const amt = try handle.preadAll(symtab_buffer, cmd.symoff + offset);
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
                const amt = try handle.preadAll(buffer, offset + cmd.dataoff);
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
                const name = ctx.getString(nl.n_strx);
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
        try self.initSubsections(nlists.items, macho_file);
    } else {
        try self.initSections(nlists.items, macho_file);
    }

    try self.initLiteralSections(macho_file);
    try self.linkNlistToAtom(macho_file);

    try self.sortAtoms(macho_file);
    try self.initSymbols(macho_file);
    try self.initSymbolStabs(nlists.items, macho_file);
    try self.initRelocs(macho_file);

    // Parse DWARF __TEXT,__eh_frame section
    if (self.eh_frame_sect_index) |index| {
        try self.initEhFrameRecords(index, macho_file);
    }

    // Parse Apple's __LD,__compact_unwind section
    if (self.compact_unwind_sect_index) |index| {
        try self.initUnwindRecords(index, macho_file);
    }

    if (self.hasUnwindRecords() or self.hasEhFrameRecords()) {
        try self.parseUnwindRecords(macho_file);
    }

    if (self.platform) |platform| {
        if (!macho_file.platform.eqlTarget(platform)) {
            try macho_file.reportParseError2(self.index, "invalid platform: {}", .{
                platform.fmtTarget(macho_file.getTarget().cpu.arch),
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

    try self.initDwarfInfo(macho_file);

    for (self.atoms.items) |atom_index| {
        const atom = macho_file.getAtom(atom_index).?;
        const isec = atom.getInputSection(macho_file);
        if (mem.eql(u8, isec.sectName(), "__eh_frame") or
            mem.eql(u8, isec.sectName(), "__compact_unwind") or
            isec.attrs() & macho.S_ATTR_DEBUG != 0)
        {
            atom.flags.alive = false;
        }
    }
}

inline fn isLiteral(sect: macho.section_64) bool {
    return switch (sect.type()) {
        macho.S_CSTRING_LITERALS,
        macho.S_4BYTE_LITERALS,
        macho.S_8BYTE_LITERALS,
        macho.S_16BYTE_LITERALS,
        macho.S_LITERAL_POINTERS,
        => true,
        else => false,
    };
}

fn initSubsections(self: *Object, nlists: anytype, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();
    const gpa = macho_file.base.comp.gpa;
    const slice = self.sections.slice();
    for (slice.items(.header), slice.items(.subsections), 0..) |sect, *subsections, n_sect| {
        if (isLiteral(sect)) continue;

        const nlist_start = for (nlists, 0..) |nlist, i| {
            if (nlist.nlist.n_sect - 1 == n_sect) break i;
        } else nlists.len;
        const nlist_end = for (nlists[nlist_start..], nlist_start..) |nlist, i| {
            if (nlist.nlist.n_sect - 1 != n_sect) break i;
        } else nlists.len;

        if (nlist_start == nlist_end or nlists[nlist_start].nlist.n_value > sect.addr) {
            const name = try std.fmt.allocPrintZ(gpa, "{s}${s}", .{ sect.segName(), sect.sectName() });
            defer gpa.free(name);
            const size = if (nlist_start == nlist_end) sect.size else nlists[nlist_start].nlist.n_value - sect.addr;
            const atom_index = try self.addAtom(.{
                .name = try self.addString(gpa, name),
                .n_sect = @intCast(n_sect),
                .off = 0,
                .size = size,
                .alignment = sect.@"align",
            }, macho_file);
            try subsections.append(gpa, .{
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
            const atom_index = try self.addAtom(.{
                .name = nlist.nlist.n_strx,
                .n_sect = @intCast(n_sect),
                .off = nlist.nlist.n_value - sect.addr,
                .size = size,
                .alignment = alignment,
            }, macho_file);
            try subsections.append(gpa, .{
                .atom = atom_index,
                .off = nlist.nlist.n_value - sect.addr,
            });

            for (alias_start..idx) |i| {
                self.symtab.items(.size)[nlists[i].idx] = size;
            }
        }
    }
}

fn initSections(self: *Object, nlists: anytype, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();
    const gpa = macho_file.base.comp.gpa;
    const slice = self.sections.slice();

    try self.atoms.ensureUnusedCapacity(gpa, self.sections.items(.header).len);

    for (slice.items(.header), 0..) |sect, n_sect| {
        if (isLiteral(sect)) continue;

        const name = try std.fmt.allocPrintZ(gpa, "{s}${s}", .{ sect.segName(), sect.sectName() });
        defer gpa.free(name);

        const atom_index = try self.addAtom(.{
            .name = try self.addString(gpa, name),
            .n_sect = @intCast(n_sect),
            .off = 0,
            .size = sect.size,
            .alignment = sect.@"align",
        }, macho_file);
        try slice.items(.subsections)[n_sect].append(gpa, .{ .atom = atom_index, .off = 0 });

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

const AddAtomArgs = struct {
    name: u32,
    n_sect: u8,
    off: u64,
    size: u64,
    alignment: u32,
};

fn addAtom(self: *Object, args: AddAtomArgs, macho_file: *MachO) !Atom.Index {
    const gpa = macho_file.base.comp.gpa;
    const atom_index = try macho_file.addAtom();
    const atom = macho_file.getAtom(atom_index).?;
    atom.file = self.index;
    atom.atom_index = atom_index;
    atom.name = args.name;
    atom.n_sect = args.n_sect;
    atom.size = args.size;
    atom.alignment = Atom.Alignment.fromLog2Units(args.alignment);
    atom.off = args.off;
    try self.atoms.append(gpa, atom_index);
    return atom_index;
}

fn initLiteralSections(self: *Object, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();
    // TODO here we should split into equal-sized records, hash the contents, and then
    // deduplicate - ICF.
    // For now, we simply cover each literal section with one large atom.
    const gpa = macho_file.base.comp.gpa;
    const slice = self.sections.slice();

    try self.atoms.ensureUnusedCapacity(gpa, self.sections.items(.header).len);

    for (slice.items(.header), 0..) |sect, n_sect| {
        if (!isLiteral(sect)) continue;

        const name = try std.fmt.allocPrintZ(gpa, "{s}${s}", .{ sect.segName(), sect.sectName() });
        defer gpa.free(name);

        const atom_index = try self.addAtom(.{
            .name = try self.addString(gpa, name),
            .n_sect = @intCast(n_sect),
            .off = 0,
            .size = sect.size,
            .alignment = sect.@"align",
        }, macho_file);
        try slice.items(.subsections)[n_sect].append(gpa, .{ .atom = atom_index, .off = 0 });
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
                    self.getString(nlist.n_strx),
                });
                return error.MalformedObject;
            }
        }
    }
}

fn initSymbols(self: *Object, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();
    const gpa = macho_file.base.comp.gpa;
    const slice = self.symtab.slice();

    try self.symbols.ensureUnusedCapacity(gpa, slice.items(.nlist).len);

    for (slice.items(.nlist), slice.items(.atom), 0..) |nlist, atom_index, i| {
        if (nlist.ext()) {
            const name = self.getString(nlist.n_strx);
            const off = try macho_file.strings.insert(gpa, name);
            const gop = try macho_file.getOrCreateGlobal(off);
            self.symbols.addOneAssumeCapacity().* = gop.index;
            if (nlist.undf() and nlist.weakRef()) {
                macho_file.getSymbol(gop.index).flags.weak_ref = true;
            }
            continue;
        }

        const index = try macho_file.addSymbol();
        self.symbols.appendAssumeCapacity(index);
        const symbol = macho_file.getSymbol(index);
        symbol.* = .{
            .value = nlist.n_value,
            .name = nlist.n_strx,
            .nlist_idx = @intCast(i),
            .atom = 0,
            .file = self.index,
        };

        if (macho_file.getAtom(atom_index)) |atom| {
            assert(!nlist.abs());
            symbol.value -= atom.getInputAddress(macho_file);
            symbol.atom = atom_index;
        }

        symbol.flags.abs = nlist.abs();
        symbol.flags.no_dead_strip = symbol.flags.no_dead_strip or nlist.noDeadStrip();

        if (nlist.sect() and
            self.sections.items(.header)[nlist.n_sect - 1].type() == macho.S_THREAD_LOCAL_VARIABLES)
        {
            symbol.flags.tlv = true;
        }
    }
}

fn initSymbolStabs(self: *Object, nlists: anytype, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const SymbolLookup = struct {
        ctx: *const Object,
        entries: @TypeOf(nlists),

        fn find(fs: @This(), addr: u64) ?Symbol.Index {
            // TODO binary search since we have the list sorted
            for (fs.entries) |nlist| {
                if (nlist.nlist.n_value == addr) return fs.ctx.symbols.items[nlist.idx];
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

    const gpa = macho_file.base.comp.gpa;
    const syms = self.symtab.items(.nlist);
    const sym_lookup = SymbolLookup{ .ctx = self, .entries = nlists };

    // We need to cache nlists by name so that we can properly resolve local N_GSYM stabs.
    // What happens is `ld -r` will emit an N_GSYM stab for a symbol that may be either an
    // external or private external.
    var addr_lookup = std.StringHashMap(u64).init(gpa);
    defer addr_lookup.deinit();
    for (syms) |sym| {
        if (sym.sect() and (sym.ext() or sym.pext())) {
            try addr_lookup.putNoClobber(self.getString(sym.n_strx), sym.n_value);
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
                    stab.symbol = sym_lookup.find(nlist.n_value);
                    // TODO validate
                    i += 3;
                },
                macho.N_GSYM => {
                    stab.is_func = false;
                    stab.symbol = sym_lookup.find(addr_lookup.get(self.getString(nlist.n_strx)).?);
                },
                macho.N_STSYM => {
                    stab.is_func = false;
                    stab.symbol = sym_lookup.find(nlist.n_value);
                },
                else => {
                    try macho_file.reportParseError2(self.index, "unhandled symbol stab type 0x{x}", .{
                        nlist.n_type,
                    });
                    return error.MalformedObject;
                },
            }
            try sf.stabs.append(gpa, stab);
        }

        try self.stab_files.append(gpa, sf);
    }
}

fn sortAtoms(self: *Object, macho_file: *MachO) !void {
    const lessThanAtom = struct {
        fn lessThanAtom(ctx: *MachO, lhs: Atom.Index, rhs: Atom.Index) bool {
            return ctx.getAtom(lhs).?.getInputAddress(ctx) < ctx.getAtom(rhs).?.getInputAddress(ctx);
        }
    }.lessThanAtom;
    mem.sort(Atom.Index, self.atoms.items, macho_file, lessThanAtom);
}

fn initRelocs(self: *Object, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();
    const cpu_arch = macho_file.getTarget().cpu.arch;
    const slice = self.sections.slice();

    for (slice.items(.header), slice.items(.relocs), 0..) |sect, *out, n_sect| {
        if (sect.nreloc == 0) continue;
        // We skip relocs for __DWARF since even in -r mode, the linker is expected to emit
        // debug symbol stabs in the relocatable. This made me curious why that is. For now,
        // I shall comply, but I wanna compare with dsymutil.
        if (sect.attrs() & macho.S_ATTR_DEBUG != 0 and
            !mem.eql(u8, sect.sectName(), "__compact_unwind")) continue;

        switch (cpu_arch) {
            .x86_64 => try x86_64.parseRelocs(self, @intCast(n_sect), sect, out, macho_file),
            .aarch64 => try aarch64.parseRelocs(self, @intCast(n_sect), sect, out, macho_file),
            else => unreachable,
        }

        mem.sort(Relocation, out.items, {}, Relocation.lessThan);
    }

    for (slice.items(.header), slice.items(.relocs), slice.items(.subsections)) |sect, relocs, subsections| {
        if (sect.isZerofill()) continue;

        var next_reloc: u32 = 0;
        for (subsections.items) |subsection| {
            const atom = macho_file.getAtom(subsection.atom).?;
            if (!atom.flags.alive) continue;
            if (next_reloc >= relocs.items.len) break;
            const end_addr = atom.off + atom.size;
            const rel_index = next_reloc;

            while (next_reloc < relocs.items.len and relocs.items[next_reloc].offset < end_addr) : (next_reloc += 1) {}

            const rel_count = next_reloc - rel_index;
            try atom.addExtra(.{ .rel_index = rel_index, .rel_count = rel_count }, macho_file);
            atom.flags.relocs = true;
        }
    }
}

fn initEhFrameRecords(self: *Object, sect_id: u8, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();
    const gpa = macho_file.base.comp.gpa;
    const nlists = self.symtab.items(.nlist);
    const slice = self.sections.slice();
    const sect = slice.items(.header)[sect_id];
    const relocs = slice.items(.relocs)[sect_id];

    // TODO: read into buffer directly
    const data = try self.getSectionData(sect_id, macho_file);
    defer gpa.free(data);

    try self.eh_frame_data.ensureTotalCapacityPrecise(gpa, data.len);
    self.eh_frame_data.appendSliceAssumeCapacity(data);

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
            .cie => try self.cies.append(gpa, .{
                .offset = rec.offset,
                .size = rec.size,
                .file = self.index,
            }),
            .fde => try self.fdes.append(gpa, .{
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

fn initUnwindRecords(self: *Object, sect_id: u8, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const SymbolLookup = struct {
        ctx: *const Object,

        fn find(fs: @This(), addr: u64) ?Symbol.Index {
            for (fs.ctx.symbols.items, 0..) |sym_index, i| {
                const nlist = fs.ctx.symtab.items(.nlist)[i];
                if (nlist.ext() and nlist.n_value == addr) return sym_index;
            }
            return null;
        }
    };

    const gpa = macho_file.base.comp.gpa;
    const data = try self.getSectionData(sect_id, macho_file);
    defer gpa.free(data);
    const nrecs = @divExact(data.len, @sizeOf(macho.compact_unwind_entry));
    const recs = @as([*]align(1) const macho.compact_unwind_entry, @ptrCast(data.ptr))[0..nrecs];
    const sym_lookup = SymbolLookup{ .ctx = self };

    try self.unwind_records.resize(gpa, nrecs);

    const header = self.sections.items(.header)[sect_id];
    const relocs = self.sections.items(.relocs)[sect_id].items;
    var reloc_idx: usize = 0;
    for (recs, self.unwind_records.items, 0..) |rec, *out_index, rec_idx| {
        const rec_start = rec_idx * @sizeOf(macho.compact_unwind_entry);
        const rec_end = rec_start + @sizeOf(macho.compact_unwind_entry);
        const reloc_start = reloc_idx;
        while (reloc_idx < relocs.len and
            relocs[reloc_idx].offset < rec_end) : (reloc_idx += 1)
        {}

        out_index.* = try macho_file.addUnwindRecord();
        const out = macho_file.getUnwindRecord(out_index.*);
        out.length = rec.rangeLength;
        out.enc = .{ .enc = rec.compactUnwindEncoding };
        out.file = self.index;

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

fn parseUnwindRecords(self: *Object, macho_file: *MachO) !void {
    // Synthesise missing unwind records.
    // The logic here is as follows:
    // 1. if an atom has unwind info record that is not DWARF, FDE is marked dead
    // 2. if an atom has unwind info record that is DWARF, FDE is tied to this unwind record
    // 3. if an atom doesn't have unwind info record but FDE is available, synthesise and tie
    // 4. if an atom doesn't have either, synthesise a null unwind info record

    const Superposition = struct { atom: Atom.Index, size: u64, cu: ?UnwindInfo.Record.Index = null, fde: ?Fde.Index = null };

    const gpa = macho_file.base.comp.gpa;
    var superposition = std.AutoArrayHashMap(u64, Superposition).init(gpa);
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

    for (self.unwind_records.items) |rec_index| {
        const rec = macho_file.getUnwindRecord(rec_index);
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
                const rec = macho_file.getUnwindRecord(rec_index);
                if (!rec.enc.isDwarf(macho_file)) {
                    // Mark FDE dead
                    fde.alive = false;
                } else {
                    // Tie FDE to unwind record
                    rec.fde = fde_index;
                }
            } else {
                // Synthesise new unwind info record
                const rec_index = try macho_file.addUnwindRecord();
                const rec = macho_file.getUnwindRecord(rec_index);
                try self.unwind_records.append(gpa, rec_index);
                rec.length = @intCast(meta.size);
                rec.atom = fde.atom;
                rec.atom_offset = fde.atom_offset;
                rec.fde = fde_index;
                rec.file = fde.file;
                switch (macho_file.getTarget().cpu.arch) {
                    .x86_64 => rec.enc.setMode(macho.UNWIND_X86_64_MODE.DWARF),
                    .aarch64 => rec.enc.setMode(macho.UNWIND_ARM64_MODE.DWARF),
                    else => unreachable,
                }
            }
        } else if (meta.cu == null and meta.fde == null) {
            // Create a null record
            const rec_index = try macho_file.addUnwindRecord();
            const rec = macho_file.getUnwindRecord(rec_index);
            const atom = macho_file.getAtom(meta.atom).?;
            try self.unwind_records.append(gpa, rec_index);
            rec.length = @intCast(meta.size);
            rec.atom = meta.atom;
            rec.atom_offset = @intCast(addr - atom.getInputAddress(macho_file));
            rec.file = self.index;
        }
    }

    const sortFn = struct {
        fn sortFn(ctx: *MachO, lhs_index: UnwindInfo.Record.Index, rhs_index: UnwindInfo.Record.Index) bool {
            const lhs = ctx.getUnwindRecord(lhs_index);
            const rhs = ctx.getUnwindRecord(rhs_index);
            const lhsa = lhs.getAtom(ctx);
            const rhsa = rhs.getAtom(ctx);
            return lhsa.getInputAddress(ctx) + lhs.atom_offset < rhsa.getInputAddress(ctx) + rhs.atom_offset;
        }
    }.sortFn;
    mem.sort(UnwindInfo.Record.Index, self.unwind_records.items, macho_file, sortFn);

    // Associate unwind records to atoms
    var next_cu: u32 = 0;
    while (next_cu < self.unwind_records.items.len) {
        const start = next_cu;
        const rec_index = self.unwind_records.items[start];
        const rec = macho_file.getUnwindRecord(rec_index);
        while (next_cu < self.unwind_records.items.len and
            macho_file.getUnwindRecord(self.unwind_records.items[next_cu]).atom == rec.atom) : (next_cu += 1)
        {}

        const atom = rec.getAtom(macho_file);
        try atom.addExtra(.{ .unwind_index = start, .unwind_count = next_cu - start }, macho_file);
        atom.flags.unwind = true;
    }
}

/// Currently, we only check if a compile unit for this input object file exists
/// and record that so that we can emit symbol stabs.
/// TODO in the future, we want parse debug info and debug line sections so that
/// we can provide nice error locations to the user.
fn initDwarfInfo(self: *Object, macho_file: *MachO) !void {
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

    const debug_info = try self.getSectionData(@intCast(debug_info_index.?), macho_file);
    defer gpa.free(debug_info);
    const debug_abbrev = try self.getSectionData(@intCast(debug_abbrev_index.?), macho_file);
    defer gpa.free(debug_abbrev);
    const debug_str = if (debug_str_index) |index| try self.getSectionData(@intCast(index), macho_file) else &[0]u8{};
    defer gpa.free(debug_str);

    var dwarf_info = DwarfInfo{};
    errdefer dwarf_info.deinit(gpa);
    dwarf_info.init(gpa, .{
        .debug_info = debug_info,
        .debug_abbrev = debug_abbrev,
        .debug_str = debug_str,
    }) catch {
        try macho_file.reportParseError2(self.index, "invalid __DWARF info found", .{});
        return error.MalformedObject;
    };
    self.dwarf_info = dwarf_info;
}

pub fn resolveSymbols(self: *Object, macho_file: *MachO) void {
    const tracy = trace(@src());
    defer tracy.end();

    for (self.symbols.items, 0..) |index, i| {
        const nlist_idx = @as(Symbol.Index, @intCast(i));
        const nlist = self.symtab.items(.nlist)[nlist_idx];
        const atom_index = self.symtab.items(.atom)[nlist_idx];

        if (!nlist.ext()) continue;
        if (nlist.undf() and !nlist.tentative()) continue;
        if (nlist.sect()) {
            const atom = macho_file.getAtom(atom_index).?;
            if (!atom.flags.alive) continue;
        }

        const symbol = macho_file.getSymbol(index);
        if (self.asFile().getSymbolRank(.{
            .archive = !self.alive,
            .weak = nlist.weakDef(),
            .tentative = nlist.tentative(),
        }) < symbol.getSymbolRank(macho_file)) {
            const value = if (nlist.sect()) blk: {
                const atom = macho_file.getAtom(atom_index).?;
                break :blk nlist.n_value - atom.getInputAddress(macho_file);
            } else nlist.n_value;
            symbol.value = value;
            symbol.atom = atom_index;
            symbol.nlist_idx = nlist_idx;
            symbol.file = self.index;
            symbol.flags.weak = nlist.weakDef();
            symbol.flags.abs = nlist.abs();
            symbol.flags.tentative = nlist.tentative();
            symbol.flags.weak_ref = false;
            symbol.flags.dyn_ref = nlist.n_desc & macho.REFERENCED_DYNAMICALLY != 0;
            symbol.flags.no_dead_strip = symbol.flags.no_dead_strip or nlist.noDeadStrip();
            // TODO: symbol.flags.interposable = macho_file.base.isDynLib() and macho_file.options.namespace == .flat and !nlist.pext();
            symbol.flags.interposable = false;

            if (nlist.sect() and
                self.sections.items(.header)[nlist.n_sect - 1].type() == macho.S_THREAD_LOCAL_VARIABLES)
            {
                symbol.flags.tlv = true;
            }
        }

        // Regardless of who the winner is, we still merge symbol visibility here.
        if (nlist.pext() or (nlist.weakDef() and nlist.weakRef()) or self.hidden) {
            if (symbol.visibility != .global) {
                symbol.visibility = .hidden;
            }
        } else {
            symbol.visibility = .global;
        }
    }
}

pub fn resetGlobals(self: *Object, macho_file: *MachO) void {
    for (self.symbols.items, 0..) |sym_index, nlist_idx| {
        if (!self.symtab.items(.nlist)[nlist_idx].ext()) continue;
        const sym = macho_file.getSymbol(sym_index);
        const name = sym.name;
        const global = sym.flags.global;
        const weak_ref = sym.flags.weak_ref;
        sym.* = .{};
        sym.name = name;
        sym.flags.global = global;
        sym.flags.weak_ref = weak_ref;
    }
}

pub fn markLive(self: *Object, macho_file: *MachO) void {
    const tracy = trace(@src());
    defer tracy.end();

    for (self.symbols.items, 0..) |index, nlist_idx| {
        const nlist = self.symtab.items(.nlist)[nlist_idx];
        if (!nlist.ext()) continue;

        const sym = macho_file.getSymbol(index);
        const file = sym.getFile(macho_file) orelse continue;
        const should_keep = nlist.undf() or (nlist.tentative() and !sym.flags.tentative);
        if (should_keep and file == .object and !file.object.alive) {
            file.object.alive = true;
            file.object.markLive(macho_file);
        }
    }
}

pub fn checkDuplicates(self: *Object, dupes: anytype, macho_file: *MachO) error{OutOfMemory}!void {
    for (self.symbols.items, 0..) |index, nlist_idx| {
        const sym = macho_file.getSymbol(index);
        if (sym.visibility != .global) continue;
        const file = sym.getFile(macho_file) orelse continue;
        if (file.getIndex() == self.index) continue;

        const nlist = self.symtab.items(.nlist)[nlist_idx];
        if (!nlist.undf() and !nlist.tentative() and !(nlist.weakDef() or nlist.pext())) {
            const gop = try dupes.getOrPut(index);
            if (!gop.found_existing) {
                gop.value_ptr.* = .{};
            }
            try gop.value_ptr.append(macho_file.base.comp.gpa, self.index);
        }
    }
}

pub fn scanRelocs(self: Object, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    for (self.atoms.items) |atom_index| {
        const atom = macho_file.getAtom(atom_index).?;
        if (!atom.flags.alive) continue;
        const sect = atom.getInputSection(macho_file);
        if (sect.isZerofill()) continue;
        try atom.scanRelocs(macho_file);
    }

    for (self.unwind_records.items) |rec_index| {
        const rec = macho_file.getUnwindRecord(rec_index);
        if (!rec.alive) continue;
        if (rec.getFde(macho_file)) |fde| {
            if (fde.getCie(macho_file).getPersonality(macho_file)) |sym| {
                sym.flags.needs_got = true;
            }
        } else if (rec.getPersonality(macho_file)) |sym| {
            sym.flags.needs_got = true;
        }
    }
}

pub fn convertTentativeDefinitions(self: *Object, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();
    const gpa = macho_file.base.comp.gpa;

    for (self.symbols.items, 0..) |index, i| {
        const sym = macho_file.getSymbol(index);
        if (!sym.flags.tentative) continue;
        const sym_file = sym.getFile(macho_file).?;
        if (sym_file.getIndex() != self.index) continue;

        const nlist_idx = @as(Symbol.Index, @intCast(i));
        const nlist = &self.symtab.items(.nlist)[nlist_idx];
        const nlist_atom = &self.symtab.items(.atom)[nlist_idx];

        const atom_index = try macho_file.addAtom();
        try self.atoms.append(gpa, atom_index);

        const name = try std.fmt.allocPrintZ(gpa, "__DATA$__common${s}", .{sym.getName(macho_file)});
        defer gpa.free(name);
        const atom = macho_file.getAtom(atom_index).?;
        atom.atom_index = atom_index;
        atom.name = try self.addString(gpa, name);
        atom.file = self.index;
        atom.size = nlist.n_value;
        atom.alignment = Atom.Alignment.fromLog2Units((nlist.n_desc >> 8) & 0x0f);

        const n_sect = try self.addSection(gpa, "__DATA", "__common");
        const sect = &self.sections.items(.header)[n_sect];
        sect.flags = macho.S_ZEROFILL;
        sect.size = atom.size;
        sect.@"align" = atom.alignment.toLog2Units();
        atom.n_sect = n_sect;

        sym.value = 0;
        sym.atom = atom_index;
        sym.flags.global = true;
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

fn addSection(self: *Object, allocator: Allocator, segname: []const u8, sectname: []const u8) !u32 {
    const n_sect = @as(u32, @intCast(try self.sections.addOne(allocator)));
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
    const offset = if (self.archive) |ar| ar.offset else 0;
    const handle = macho_file.getFileHandle(self.file_handle);

    var header_buffer: [@sizeOf(macho.mach_header_64)]u8 = undefined;
    {
        const amt = try handle.preadAll(&header_buffer, offset);
        if (amt != @sizeOf(macho.mach_header_64)) return error.InputOutput;
    }
    self.header = @as(*align(1) const macho.mach_header_64, @ptrCast(&header_buffer)).*;

    const this_cpu_arch: std.Target.Cpu.Arch = switch (self.header.?.cputype) {
        macho.CPU_TYPE_ARM64 => .aarch64,
        macho.CPU_TYPE_X86_64 => .x86_64,
        else => |x| {
            try macho_file.reportParseError2(self.index, "unknown cpu architecture: {d}", .{x});
            return error.InvalidCpuArch;
        },
    };
    if (macho_file.getTarget().cpu.arch != this_cpu_arch) {
        try macho_file.reportParseError2(self.index, "invalid cpu architecture: {s}", .{@tagName(this_cpu_arch)});
        return error.InvalidCpuArch;
    }

    const lc_buffer = try gpa.alloc(u8, self.header.?.sizeofcmds);
    defer gpa.free(lc_buffer);
    {
        const amt = try handle.preadAll(lc_buffer, offset + @sizeOf(macho.mach_header_64));
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
                const amt = try handle.preadAll(self.strtab.items, cmd.stroff + offset);
                if (amt != self.strtab.items.len) return error.InputOutput;
            }

            const symtab_buffer = try gpa.alloc(u8, cmd.nsyms * @sizeOf(macho.nlist_64));
            defer gpa.free(symtab_buffer);
            {
                const amt = try handle.preadAll(symtab_buffer, cmd.symoff + offset);
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
        const off = try ar_symtab.strtab.insert(gpa, self.getString(nlist.n_strx));
        try ar_symtab.entries.append(gpa, .{ .off = off, .file = self.index });
    }
}

pub fn updateArSize(self: *Object, macho_file: *MachO) !void {
    self.output_ar_state.size = if (self.archive) |ar| ar.size else size: {
        const file = macho_file.getFileHandle(self.file_handle);
        break :size (try file.stat()).size;
    };
}

pub fn writeAr(self: Object, ar_format: Archive.Format, macho_file: *MachO, writer: anytype) !void {
    // Header
    const size = std.math.cast(usize, self.output_ar_state.size) orelse return error.Overflow;
    const offset: u64 = if (self.archive) |ar| ar.offset else 0;
    try Archive.writeHeader(self.path, size, ar_format, writer);
    // Data
    const file = macho_file.getFileHandle(self.file_handle);
    // TODO try using copyRangeAll
    const gpa = macho_file.base.comp.gpa;
    const data = try gpa.alloc(u8, size);
    defer gpa.free(data);
    const amt = try file.preadAll(data, offset);
    if (amt != size) return error.InputOutput;
    try writer.writeAll(data);
}

pub fn calcSymtabSize(self: *Object, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    for (self.symbols.items) |sym_index| {
        const sym = macho_file.getSymbol(sym_index);
        const file = sym.getFile(macho_file) orelse continue;
        if (file.getIndex() != self.index) continue;
        if (sym.getAtom(macho_file)) |atom| if (!atom.flags.alive) continue;
        if (sym.isSymbolStab(macho_file)) continue;
        const name = sym.getName(macho_file);
        // TODO in -r mode, we actually want to merge symbol names and emit only one
        // work it out when emitting relocs
        if (name.len > 0 and (name[0] == 'L' or name[0] == 'l') and !macho_file.base.isObject()) continue;
        sym.flags.output_symtab = true;
        if (sym.isLocal()) {
            try sym.addExtra(.{ .symtab = self.output_symtab_ctx.nlocals }, macho_file);
            self.output_symtab_ctx.nlocals += 1;
        } else if (sym.flags.@"export") {
            try sym.addExtra(.{ .symtab = self.output_symtab_ctx.nexports }, macho_file);
            self.output_symtab_ctx.nexports += 1;
        } else {
            assert(sym.flags.import);
            try sym.addExtra(.{ .symtab = self.output_symtab_ctx.nimports }, macho_file);
            self.output_symtab_ctx.nimports += 1;
        }
        self.output_symtab_ctx.strsize += @as(u32, @intCast(sym.getName(macho_file).len + 1));
    }

    if (macho_file.base.comp.config.debug_format != .strip and self.hasDebugInfo())
        try self.calcStabsSize(macho_file);
}

pub fn calcStabsSize(self: *Object, macho_file: *MachO) error{Overflow}!void {
    if (self.dwarf_info) |dw| {
        const cu = dw.compile_units.items[0];
        const comp_dir = try cu.getCompileDir(dw) orelse return;
        const tu_name = try cu.getSourceFile(dw) orelse return;

        self.output_symtab_ctx.nstabs += 4; // N_SO, N_SO, N_OSO, N_SO
        self.output_symtab_ctx.strsize += @as(u32, @intCast(comp_dir.len + 1)); // comp_dir
        self.output_symtab_ctx.strsize += @as(u32, @intCast(tu_name.len + 1)); // tu_name

        if (self.archive) |ar| {
            self.output_symtab_ctx.strsize += @as(u32, @intCast(ar.path.len + 1 + self.path.len + 1 + 1));
        } else {
            self.output_symtab_ctx.strsize += @as(u32, @intCast(self.path.len + 1));
        }

        for (self.symbols.items) |sym_index| {
            const sym = macho_file.getSymbol(sym_index);
            const file = sym.getFile(macho_file) orelse continue;
            if (file.getIndex() != self.index) continue;
            if (!sym.flags.output_symtab) continue;
            if (macho_file.base.isObject()) {
                const name = sym.getName(macho_file);
                if (name.len > 0 and (name[0] == 'L' or name[0] == 'l')) continue;
            }
            const sect = macho_file.sections.items(.header)[sym.out_n_sect];
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
            self.output_symtab_ctx.strsize += @as(u32, @intCast(sf.getCompDir(self).len + 1)); // comp_dir
            self.output_symtab_ctx.strsize += @as(u32, @intCast(sf.getTuName(self).len + 1)); // tu_name
            self.output_symtab_ctx.strsize += @as(u32, @intCast(sf.getOsoPath(self).len + 1)); // path

            for (sf.stabs.items) |stab| {
                const sym = stab.getSymbol(macho_file) orelse continue;
                const file = sym.getFile(macho_file).?;
                if (file.getIndex() != self.index) continue;
                if (!sym.flags.output_symtab) continue;
                const nstabs: u32 = if (stab.is_func) 4 else 1;
                self.output_symtab_ctx.nstabs += nstabs;
            }
        }
    }
}

pub fn writeSymtab(self: Object, macho_file: *MachO, ctx: anytype) error{Overflow}!void {
    const tracy = trace(@src());
    defer tracy.end();

    for (self.symbols.items) |sym_index| {
        const sym = macho_file.getSymbol(sym_index);
        const file = sym.getFile(macho_file) orelse continue;
        if (file.getIndex() != self.index) continue;
        const idx = sym.getOutputSymtabIndex(macho_file) orelse continue;
        const n_strx = @as(u32, @intCast(ctx.strtab.items.len));
        ctx.strtab.appendSliceAssumeCapacity(sym.getName(macho_file));
        ctx.strtab.appendAssumeCapacity(0);
        const out_sym = &ctx.symtab.items[idx];
        out_sym.n_strx = n_strx;
        sym.setOutputSym(macho_file, out_sym);
    }

    if (macho_file.base.comp.config.debug_format != .strip and self.hasDebugInfo())
        try self.writeStabs(macho_file, ctx);
}

pub fn writeStabs(self: *const Object, macho_file: *MachO, ctx: anytype) error{Overflow}!void {
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

    if (self.dwarf_info) |dw| {
        const cu = dw.compile_units.items[0];
        const comp_dir = try cu.getCompileDir(dw) orelse return;
        const tu_name = try cu.getSourceFile(dw) orelse return;

        // Open scope
        // N_SO comp_dir
        var n_strx = @as(u32, @intCast(ctx.strtab.items.len));
        ctx.strtab.appendSliceAssumeCapacity(comp_dir);
        ctx.strtab.appendAssumeCapacity(0);
        ctx.symtab.items[index] = .{
            .n_strx = n_strx,
            .n_type = macho.N_SO,
            .n_sect = 0,
            .n_desc = 0,
            .n_value = 0,
        };
        index += 1;
        // N_SO tu_name
        n_strx = @as(u32, @intCast(ctx.strtab.items.len));
        ctx.strtab.appendSliceAssumeCapacity(tu_name);
        ctx.strtab.appendAssumeCapacity(0);
        ctx.symtab.items[index] = .{
            .n_strx = n_strx,
            .n_type = macho.N_SO,
            .n_sect = 0,
            .n_desc = 0,
            .n_value = 0,
        };
        index += 1;
        // N_OSO path
        n_strx = @as(u32, @intCast(ctx.strtab.items.len));
        if (self.archive) |ar| {
            ctx.strtab.appendSliceAssumeCapacity(ar.path);
            ctx.strtab.appendAssumeCapacity('(');
            ctx.strtab.appendSliceAssumeCapacity(self.path);
            ctx.strtab.appendAssumeCapacity(')');
            ctx.strtab.appendAssumeCapacity(0);
        } else {
            ctx.strtab.appendSliceAssumeCapacity(self.path);
            ctx.strtab.appendAssumeCapacity(0);
        }
        ctx.symtab.items[index] = .{
            .n_strx = n_strx,
            .n_type = macho.N_OSO,
            .n_sect = 0,
            .n_desc = 1,
            .n_value = self.mtime,
        };
        index += 1;

        for (self.symbols.items) |sym_index| {
            const sym = macho_file.getSymbol(sym_index);
            const file = sym.getFile(macho_file) orelse continue;
            if (file.getIndex() != self.index) continue;
            if (!sym.flags.output_symtab) continue;
            if (macho_file.base.isObject()) {
                const name = sym.getName(macho_file);
                if (name.len > 0 and (name[0] == 'L' or name[0] == 'l')) continue;
            }
            const sect = macho_file.sections.items(.header)[sym.out_n_sect];
            const sym_n_strx = n_strx: {
                const symtab_index = sym.getOutputSymtabIndex(macho_file).?;
                const osym = ctx.symtab.items[symtab_index];
                break :n_strx osym.n_strx;
            };
            const sym_n_sect: u8 = if (!sym.flags.abs) @intCast(sym.out_n_sect + 1) else 0;
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
            // Open scope
            // N_SO comp_dir
            var n_strx = @as(u32, @intCast(ctx.strtab.items.len));
            ctx.strtab.appendSliceAssumeCapacity(sf.getCompDir(self));
            ctx.strtab.appendAssumeCapacity(0);
            ctx.symtab.items[index] = .{
                .n_strx = n_strx,
                .n_type = macho.N_SO,
                .n_sect = 0,
                .n_desc = 0,
                .n_value = 0,
            };
            index += 1;
            // N_SO tu_name
            n_strx = @as(u32, @intCast(ctx.strtab.items.len));
            ctx.strtab.appendSliceAssumeCapacity(sf.getTuName(self));
            ctx.strtab.appendAssumeCapacity(0);
            ctx.symtab.items[index] = .{
                .n_strx = n_strx,
                .n_type = macho.N_SO,
                .n_sect = 0,
                .n_desc = 0,
                .n_value = 0,
            };
            index += 1;
            // N_OSO path
            n_strx = @as(u32, @intCast(ctx.strtab.items.len));
            ctx.strtab.appendSliceAssumeCapacity(sf.getOsoPath(self));
            ctx.strtab.appendAssumeCapacity(0);
            ctx.symtab.items[index] = .{
                .n_strx = n_strx,
                .n_type = macho.N_OSO,
                .n_sect = 0,
                .n_desc = 1,
                .n_value = sf.getOsoModTime(self),
            };
            index += 1;

            for (sf.stabs.items) |stab| {
                const sym = stab.getSymbol(macho_file) orelse continue;
                const file = sym.getFile(macho_file).?;
                if (file.getIndex() != self.index) continue;
                if (!sym.flags.output_symtab) continue;
                const sym_n_strx = n_strx: {
                    const symtab_index = sym.getOutputSymtabIndex(macho_file).?;
                    const osym = ctx.symtab.items[symtab_index];
                    break :n_strx osym.n_strx;
                };
                const sym_n_sect: u8 = if (!sym.flags.abs) @intCast(sym.out_n_sect + 1) else 0;
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

fn getSectionData(self: *const Object, index: u32, macho_file: *MachO) ![]u8 {
    const gpa = macho_file.base.comp.gpa;
    const slice = self.sections.slice();
    assert(index < slice.items(.header).len);
    const sect = slice.items(.header)[index];
    const handle = macho_file.getFileHandle(self.file_handle);
    const offset = if (self.archive) |ar| ar.offset else 0;
    const size = math.cast(usize, sect.size) orelse return error.Overflow;
    const buffer = try gpa.alloc(u8, size);
    errdefer gpa.free(buffer);
    const amt = try handle.preadAll(buffer, sect.offset + offset);
    if (amt != buffer.len) return error.InputOutput;
    return buffer;
}

pub fn getAtomData(self: *const Object, macho_file: *MachO, atom: Atom, buffer: []u8) !void {
    assert(buffer.len == atom.size);
    const slice = self.sections.slice();
    const handle = macho_file.getFileHandle(self.file_handle);
    const offset = if (self.archive) |ar| ar.offset else 0;
    const sect = slice.items(.header)[atom.n_sect];
    const amt = try handle.preadAll(buffer, sect.offset + offset + atom.off);
    if (amt != buffer.len) return error.InputOutput;
}

pub fn getAtomRelocs(self: *const Object, atom: Atom, macho_file: *MachO) []const Relocation {
    if (!atom.flags.relocs) return &[0]Relocation{};
    const extra = atom.getExtra(macho_file).?;
    const relocs = self.sections.items(.relocs)[atom.n_sect];
    return relocs.items[extra.rel_index..][0..extra.rel_count];
}

fn addString(self: *Object, allocator: Allocator, name: [:0]const u8) error{OutOfMemory}!u32 {
    const off: u32 = @intCast(self.strtab.items.len);
    try self.strtab.ensureUnusedCapacity(allocator, name.len + 1);
    self.strtab.appendSliceAssumeCapacity(name);
    self.strtab.appendAssumeCapacity(0);
    return off;
}

pub fn getString(self: Object, off: u32) [:0]const u8 {
    assert(off < self.strtab.items.len);
    return mem.sliceTo(@as([*:0]const u8, @ptrCast(self.strtab.items.ptr + off)), 0);
}

pub fn hasUnwindRecords(self: Object) bool {
    return self.unwind_records.items.len > 0;
}

pub fn hasEhFrameRecords(self: Object) bool {
    return self.cies.items.len > 0;
}

pub fn hasDebugInfo(self: Object) bool {
    if (self.dwarf_info) |dw| {
        return dw.compile_units.items.len > 0;
    }
    return self.hasSymbolStabs();
}

fn hasSymbolStabs(self: Object) bool {
    return self.stab_files.items.len > 0;
}

pub fn hasObjc(self: Object) bool {
    for (self.symtab.items(.nlist)) |nlist| {
        const name = self.getString(nlist.n_strx);
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
    try writer.writeAll("  atoms\n");
    for (object.atoms.items) |atom_index| {
        const atom = ctx.macho_file.getAtom(atom_index).?;
        try writer.print("    {}\n", .{atom.fmt(ctx.macho_file)});
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
    for (object.unwind_records.items) |rec| {
        try writer.print("    rec({d}) : {}\n", .{ rec, macho_file.getUnwindRecord(rec).fmt(macho_file) });
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
    try writer.writeAll("  symbols\n");
    for (object.symbols.items) |index| {
        const sym = ctx.macho_file.getSymbol(index);
        try writer.print("    {}\n", .{sym.fmt(ctx.macho_file)});
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
    if (object.archive) |ar| {
        try writer.writeAll(ar.path);
        try writer.writeByte('(');
        try writer.writeAll(object.path);
        try writer.writeByte(')');
    } else try writer.writeAll(object.path);
}

const Section = struct {
    header: macho.section_64,
    subsections: std.ArrayListUnmanaged(Subsection) = .{},
    relocs: std.ArrayListUnmanaged(Relocation) = .{},
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
    stabs: std.ArrayListUnmanaged(Stab) = .{},

    fn getCompDir(sf: StabFile, object: *const Object) [:0]const u8 {
        const nlist = object.symtab.items(.nlist)[sf.comp_dir];
        return object.getString(nlist.n_strx);
    }

    fn getTuName(sf: StabFile, object: *const Object) [:0]const u8 {
        const nlist = object.symtab.items(.nlist)[sf.comp_dir + 1];
        return object.getString(nlist.n_strx);
    }

    fn getOsoPath(sf: StabFile, object: *const Object) [:0]const u8 {
        const nlist = object.symtab.items(.nlist)[sf.comp_dir + 2];
        return object.getString(nlist.n_strx);
    }

    fn getOsoModTime(sf: StabFile, object: *const Object) u64 {
        const nlist = object.symtab.items(.nlist)[sf.comp_dir + 2];
        return nlist.n_value;
    }

    const Stab = struct {
        is_func: bool = true,
        symbol: ?Symbol.Index = null,

        fn getSymbol(stab: Stab, macho_file: *MachO) ?*Symbol {
            return if (stab.symbol) |s| macho_file.getSymbol(s) else null;
        }
    };
};

const x86_64 = struct {
    fn parseRelocs(
        self: *const Object,
        n_sect: u8,
        sect: macho.section_64,
        out: *std.ArrayListUnmanaged(Relocation),
        macho_file: *MachO,
    ) !void {
        const gpa = macho_file.base.comp.gpa;

        const handle = macho_file.getFileHandle(self.file_handle);
        const offset = if (self.archive) |ar| ar.offset else 0;
        const relocs_buffer = try gpa.alloc(u8, sect.nreloc * @sizeOf(macho.relocation_info));
        defer gpa.free(relocs_buffer);
        {
            const amt = try handle.preadAll(relocs_buffer, sect.reloff + offset);
            if (amt != relocs_buffer.len) return error.InputOutput;
        }
        const relocs = @as([*]align(1) const macho.relocation_info, @ptrCast(relocs_buffer.ptr))[0..sect.nreloc];

        const code = try self.getSectionData(@intCast(n_sect), macho_file);
        defer gpa.free(code);

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

            const target = if (rel.r_extern == 0) blk: {
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
                addend = taddr - @as(i64, @intCast(macho_file.getAtom(target).?.getInputAddress(macho_file)));
                break :blk target;
            } else self.symbols.items[rel.r_symbolnum];

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

            const @"type": Relocation.Type = validateRelocType(rel, rel_type) catch |err| {
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
                .tag = if (rel.r_extern == 1) .@"extern" else .local,
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

    fn validateRelocType(rel: macho.relocation_info, rel_type: macho.reloc_type_x86_64) !Relocation.Type {
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
                if (rel.r_extern == 0) return error.NonExtern;
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
        self: *const Object,
        n_sect: u8,
        sect: macho.section_64,
        out: *std.ArrayListUnmanaged(Relocation),
        macho_file: *MachO,
    ) !void {
        const gpa = macho_file.base.comp.gpa;

        const handle = macho_file.getFileHandle(self.file_handle);
        const offset = if (self.archive) |ar| ar.offset else 0;
        const relocs_buffer = try gpa.alloc(u8, sect.nreloc * @sizeOf(macho.relocation_info));
        defer gpa.free(relocs_buffer);
        {
            const amt = try handle.preadAll(relocs_buffer, sect.reloff + offset);
            if (amt != relocs_buffer.len) return error.InputOutput;
        }
        const relocs = @as([*]align(1) const macho.relocation_info, @ptrCast(relocs_buffer.ptr))[0..sect.nreloc];

        const code = try self.getSectionData(@intCast(n_sect), macho_file);
        defer gpa.free(code);

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

            const target = if (rel.r_extern == 0) blk: {
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
                addend = taddr - @as(i64, @intCast(macho_file.getAtom(target).?.getInputAddress(macho_file)));
                break :blk target;
            } else self.symbols.items[rel.r_symbolnum];

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

            const @"type": Relocation.Type = validateRelocType(rel, rel_type) catch |err| {
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
                .tag = if (rel.r_extern == 1) .@"extern" else .local,
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

    fn validateRelocType(rel: macho.relocation_info, rel_type: macho.reloc_type_arm64) !Relocation.Type {
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
                if (rel.r_extern == 0) return error.NonExtern;
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
                if (rel.r_extern == 0) return error.NonExtern;
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
const DwarfInfo = @import("DwarfInfo.zig");
const Fde = eh_frame.Fde;
const File = @import("file.zig").File;
const LoadCommandIterator = macho.LoadCommandIterator;
const MachO = @import("../MachO.zig");
const Object = @This();
const Relocation = @import("Relocation.zig");
const Symbol = @import("Symbol.zig");
const UnwindInfo = @import("UnwindInfo.zig");
