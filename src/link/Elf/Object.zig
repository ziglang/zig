archive: ?[]const u8 = null,
path: []const u8,
data: []const u8,
index: File.Index,

header: ?elf.Elf64_Ehdr = null,
shdrs: std.ArrayListUnmanaged(elf.Elf64_Shdr) = .{},
strings: StringTable(.object_strings) = .{},
symtab: []align(1) const elf.Elf64_Sym = &[0]elf.Elf64_Sym{},
strtab: []const u8 = &[0]u8{},
first_global: ?Symbol.Index = null,

symbols: std.ArrayListUnmanaged(Symbol.Index) = .{},
atoms: std.ArrayListUnmanaged(Atom.Index) = .{},
comdat_groups: std.ArrayListUnmanaged(Elf.ComdatGroup.Index) = .{},

fdes: std.ArrayListUnmanaged(Fde) = .{},
cies: std.ArrayListUnmanaged(Cie) = .{},

alive: bool = true,
num_dynrelocs: u32 = 0,

output_symtab_size: Elf.SymtabSize = .{},

pub fn isObject(file: std.fs.File) bool {
    const reader = file.reader();
    const header = reader.readStruct(elf.Elf64_Ehdr) catch return false;
    defer file.seekTo(0) catch {};
    if (!mem.eql(u8, header.e_ident[0..4], "\x7fELF")) return false;
    if (header.e_ident[elf.EI_VERSION] != 1) return false;
    if (header.e_type != elf.ET.REL) return false;
    if (header.e_version != 1) return false;
    return true;
}

pub fn deinit(self: *Object, allocator: Allocator) void {
    allocator.free(self.data);
    self.shdrs.deinit(allocator);
    self.strings.deinit(allocator);
    self.symbols.deinit(allocator);
    self.atoms.deinit(allocator);
    self.comdat_groups.deinit(allocator);
    self.fdes.deinit(allocator);
    self.cies.deinit(allocator);
}

pub fn parse(self: *Object, elf_file: *Elf) !void {
    var stream = std.io.fixedBufferStream(self.data);
    const reader = stream.reader();

    self.header = try reader.readStruct(elf.Elf64_Ehdr);

    if (self.header.?.e_shnum == 0) return;

    const gpa = elf_file.base.allocator;

    const shoff = math.cast(usize, self.header.?.e_shoff) orelse return error.Overflow;
    const shdrs = @as(
        [*]align(1) const elf.Elf64_Shdr,
        @ptrCast(self.data.ptr + shoff),
    )[0..self.header.?.e_shnum];
    try self.shdrs.appendUnalignedSlice(gpa, shdrs);
    try self.strings.buffer.appendSlice(gpa, try self.shdrContents(self.header.?.e_shstrndx));

    const symtab_index = for (self.shdrs.items, 0..) |shdr, i| switch (shdr.sh_type) {
        elf.SHT_SYMTAB => break @as(u16, @intCast(i)),
        else => {},
    } else null;

    if (symtab_index) |index| {
        const shdr = shdrs[index];
        self.first_global = shdr.sh_info;

        const symtab = try self.shdrContents(index);
        const nsyms = @divExact(symtab.len, @sizeOf(elf.Elf64_Sym));
        self.symtab = @as([*]align(1) const elf.Elf64_Sym, @ptrCast(symtab.ptr))[0..nsyms];
        self.strtab = try self.shdrContents(@as(u16, @intCast(shdr.sh_link)));
    }

    try self.initAtoms(elf_file);
    try self.initSymtab(elf_file);

    // for (self.shdrs.items, 0..) |shdr, i| {
    //     const atom = elf_file.atom(self.atoms.items[i]) orelse continue;
    //     if (!atom.alive) continue;
    //     if (shdr.sh_type == elf.SHT_X86_64_UNWIND or mem.eql(u8, atom.name(elf_file), ".eh_frame"))
    //         try self.parseEhFrame(@as(u16, @intCast(i)), elf_file);
    // }
}

fn initAtoms(self: *Object, elf_file: *Elf) !void {
    const shdrs = self.shdrs.items;
    try self.atoms.resize(elf_file.base.allocator, shdrs.len);
    @memset(self.atoms.items, 0);

    for (shdrs, 0..) |shdr, i| {
        if (shdr.sh_flags & elf.SHF_EXCLUDE != 0 and
            shdr.sh_flags & elf.SHF_ALLOC == 0 and
            shdr.sh_type != elf.SHT_LLVM_ADDRSIG) continue;

        switch (shdr.sh_type) {
            elf.SHT_GROUP => {
                if (shdr.sh_info >= self.symtab.len) {
                    // TODO convert into an error
                    log.debug("{}: invalid symbol index in sh_info", .{self.fmtPath()});
                    continue;
                }
                const group_info_sym = self.symtab[shdr.sh_info];
                const group_signature = blk: {
                    if (group_info_sym.st_name == 0 and group_info_sym.st_type() == elf.STT_SECTION) {
                        const sym_shdr = shdrs[group_info_sym.st_shndx];
                        break :blk self.strings.getAssumeExists(sym_shdr.sh_name);
                    }
                    break :blk self.getString(group_info_sym.st_name);
                };

                const shndx = @as(u16, @intCast(i));
                const group_raw_data = try self.shdrContents(shndx);
                const group_nmembers = @divExact(group_raw_data.len, @sizeOf(u32));
                const group_members = @as([*]align(1) const u32, @ptrCast(group_raw_data.ptr))[0..group_nmembers];

                if (group_members[0] != 0x1) { // GRP_COMDAT
                    // TODO convert into an error
                    log.debug("{}: unknown SHT_GROUP format", .{self.fmtPath()});
                    continue;
                }

                const group_signature_off = try self.strings.insert(elf_file.base.allocator, group_signature);
                const gop = try elf_file.getOrCreateComdatGroupOwner(group_signature_off);
                const comdat_group_index = try elf_file.addComdatGroup();
                const comdat_group = elf_file.comdatGroup(comdat_group_index);
                comdat_group.* = .{
                    .owner = gop.index,
                    .shndx = shndx,
                };
                try self.comdat_groups.append(elf_file.base.allocator, comdat_group_index);
            },

            elf.SHT_SYMTAB_SHNDX => @panic("TODO SHT_SYMTAB_SHNDX"),

            elf.SHT_NULL,
            elf.SHT_REL,
            elf.SHT_RELA,
            elf.SHT_SYMTAB,
            elf.SHT_STRTAB,
            => {},

            else => {
                const name = self.strings.getAssumeExists(shdr.sh_name);
                const shndx = @as(u16, @intCast(i));
                if (self.skipShdr(shndx, elf_file)) continue;
                try self.addAtom(shdr, shndx, name, elf_file);
            },
        }
    }

    // Parse relocs sections if any.
    for (shdrs, 0..) |shdr, i| switch (shdr.sh_type) {
        elf.SHT_REL, elf.SHT_RELA => {
            const atom_index = self.atoms.items[shdr.sh_info];
            if (elf_file.atom(atom_index)) |atom| {
                atom.relocs_section_index = @as(u16, @intCast(i));
            }
        },
        else => {},
    };
}

fn addAtom(
    self: *Object,
    shdr: elf.Elf64_Shdr,
    shndx: u16,
    name: [:0]const u8,
    elf_file: *Elf,
) error{ OutOfMemory, Overflow }!void {
    const atom_index = try elf_file.addAtom();
    const atom = elf_file.atom(atom_index).?;
    atom.atom_index = atom_index;
    atom.name_offset = try elf_file.strtab.insert(elf_file.base.allocator, name);
    atom.file_index = self.index;
    atom.input_section_index = shndx;
    atom.output_section_index = try self.getOutputSectionIndex(elf_file, shdr);
    atom.flags.alive = true;
    self.atoms.items[shndx] = atom_index;

    if (shdr.sh_flags & elf.SHF_COMPRESSED != 0) {
        const data = try self.shdrContents(shndx);
        const chdr = @as(*align(1) const elf.Elf64_Chdr, @ptrCast(data.ptr)).*;
        atom.size = chdr.ch_size;
        atom.alignment = Alignment.fromNonzeroByteUnits(chdr.ch_addralign);
    } else {
        atom.size = shdr.sh_size;
        atom.alignment = Alignment.fromNonzeroByteUnits(shdr.sh_addralign);
    }
}

fn getOutputSectionIndex(self: *Object, elf_file: *Elf, shdr: elf.Elf64_Shdr) error{OutOfMemory}!u16 {
    const name = blk: {
        const name = self.strings.getAssumeExists(shdr.sh_name);
        // if (shdr.sh_flags & elf.SHF_MERGE != 0) break :blk name;
        const sh_name_prefixes: []const [:0]const u8 = &.{
            ".text",       ".data.rel.ro", ".data", ".rodata", ".bss.rel.ro",       ".bss",
            ".init_array", ".fini_array",  ".tbss", ".tdata",  ".gcc_except_table", ".ctors",
            ".dtors",      ".gnu.warning",
        };
        inline for (sh_name_prefixes) |prefix| {
            if (std.mem.eql(u8, name, prefix) or std.mem.startsWith(u8, name, prefix ++ ".")) {
                break :blk prefix;
            }
        }
        if (std.mem.eql(u8, name, ".tcommon")) break :blk ".tbss";
        if (std.mem.eql(u8, name, ".common")) break :blk ".bss";
        break :blk name;
    };
    const @"type" = switch (shdr.sh_type) {
        elf.SHT_NULL => unreachable,
        elf.SHT_PROGBITS => blk: {
            if (std.mem.eql(u8, name, ".init_array") or std.mem.startsWith(u8, name, ".init_array."))
                break :blk elf.SHT_INIT_ARRAY;
            if (std.mem.eql(u8, name, ".fini_array") or std.mem.startsWith(u8, name, ".fini_array."))
                break :blk elf.SHT_FINI_ARRAY;
            break :blk shdr.sh_type;
        },
        elf.SHT_X86_64_UNWIND => elf.SHT_PROGBITS,
        else => shdr.sh_type,
    };
    const flags = blk: {
        const flags = shdr.sh_flags & ~@as(u64, elf.SHF_COMPRESSED | elf.SHF_GROUP | elf.SHF_GNU_RETAIN);
        break :blk switch (@"type") {
            elf.SHT_INIT_ARRAY, elf.SHT_FINI_ARRAY => flags | elf.SHF_WRITE,
            else => flags,
        };
    };
    const out_shndx = elf_file.sectionByName(name) orelse blk: {
        const is_alloc = flags & elf.SHF_ALLOC != 0;
        const is_write = flags & elf.SHF_WRITE != 0;
        const is_exec = flags & elf.SHF_EXECINSTR != 0;
        if (!is_alloc) {
            log.err("{}: output section {s} not found", .{ self.fmtPath(), name });
            @panic("TODO: missing output section!");
        }
        var phdr_flags: u32 = elf.PF_R;
        if (is_write) phdr_flags |= elf.PF_W;
        if (is_exec) phdr_flags |= elf.PF_X;
        const phdr_index = try elf_file.allocateSegment(.{
            .size = Elf.padToIdeal(shdr.sh_size),
            .alignment = elf_file.page_size,
            .flags = phdr_flags,
        });
        const shndx = try elf_file.allocateAllocSection(.{
            .name = name,
            .phdr_index = phdr_index,
            .alignment = shdr.sh_addralign,
            .flags = flags,
            .type = @"type",
        });
        try elf_file.last_atom_and_free_list_table.putNoClobber(elf_file.base.allocator, shndx, .{});
        break :blk shndx;
    };
    return out_shndx;
}

fn skipShdr(self: *Object, index: u16, elf_file: *Elf) bool {
    _ = elf_file;
    const shdr = self.shdrs.items[index];
    const name = self.strings.getAssumeExists(shdr.sh_name);
    const ignore = blk: {
        if (mem.startsWith(u8, name, ".note")) break :blk true;
        if (mem.startsWith(u8, name, ".comment")) break :blk true;
        if (mem.startsWith(u8, name, ".llvm_addrsig")) break :blk true;
        if (mem.startsWith(u8, name, ".eh_frame")) break :blk true;
        // if (elf_file.base.options.strip and shdr.sh_flags & elf.SHF_ALLOC == 0 and
        //     mem.startsWith(u8, name, ".debug")) break :blk true;
        if (shdr.sh_flags & elf.SHF_ALLOC == 0 and mem.startsWith(u8, name, ".debug")) break :blk true;
        break :blk false;
    };
    return ignore;
}

fn initSymtab(self: *Object, elf_file: *Elf) !void {
    const gpa = elf_file.base.allocator;
    const first_global = self.first_global orelse self.symtab.len;
    const shdrs = self.shdrs.items;

    try self.symbols.ensureTotalCapacityPrecise(gpa, self.symtab.len);

    for (self.symtab[0..first_global], 0..) |sym, i| {
        const index = try elf_file.addSymbol();
        self.symbols.appendAssumeCapacity(index);
        const sym_ptr = elf_file.symbol(index);
        const name = blk: {
            if (sym.st_name == 0 and sym.st_type() == elf.STT_SECTION) {
                const shdr = shdrs[sym.st_shndx];
                break :blk self.strings.getAssumeExists(shdr.sh_name);
            }
            break :blk self.getString(sym.st_name);
        };
        sym_ptr.value = sym.st_value;
        sym_ptr.name_offset = try elf_file.strtab.insert(gpa, name);
        sym_ptr.esym_index = @as(u32, @intCast(i));
        sym_ptr.atom_index = if (sym.st_shndx == elf.SHN_ABS) 0 else self.atoms.items[sym.st_shndx];
        sym_ptr.file_index = self.index;
        sym_ptr.output_section_index = if (sym_ptr.atom(elf_file)) |atom_ptr|
            atom_ptr.outputShndx().?
        else
            elf.SHN_UNDEF;
    }

    for (self.symtab[first_global..]) |sym| {
        const name = self.getString(sym.st_name);
        const off = try elf_file.strtab.insert(gpa, name);
        const gop = try elf_file.getOrPutGlobal(off);
        self.symbols.addOneAssumeCapacity().* = gop.index;
    }
}

fn parseEhFrame(self: *Object, shndx: u16, elf_file: *Elf) !void {
    const relocs_shndx = for (self.shdrs.items, 0..) |shdr, i| switch (shdr.sh_type) {
        elf.SHT_RELA => if (shdr.sh_info == shndx) break @as(u16, @intCast(i)),
        else => {},
    } else {
        log.debug("{s}: missing reloc section for unwind info section", .{self.fmtPath()});
        return;
    };

    const gpa = elf_file.base.allocator;
    const raw = try self.shdrContents(shndx);
    const relocs = try self.getRelocs(relocs_shndx);
    const fdes_start = self.fdes.items.len;
    const cies_start = self.cies.items.len;

    var it = eh_frame.Iterator{ .data = raw };
    while (try it.next()) |rec| {
        const rel_range = filterRelocs(relocs, rec.offset, rec.size + 4);
        switch (rec.tag) {
            .cie => try self.cies.append(gpa, .{
                .offset = rec.offset,
                .size = rec.size,
                .rel_index = @as(u32, @intCast(rel_range.start)),
                .rel_num = @as(u32, @intCast(rel_range.len)),
                .rel_section_index = relocs_shndx,
                .input_section_index = shndx,
                .file_index = self.index,
            }),
            .fde => try self.fdes.append(gpa, .{
                .offset = rec.offset,
                .size = rec.size,
                .cie_index = undefined,
                .rel_index = @as(u32, @intCast(rel_range.start)),
                .rel_num = @as(u32, @intCast(rel_range.len)),
                .rel_section_index = relocs_shndx,
                .input_section_index = shndx,
                .file_index = self.index,
            }),
        }
    }

    // Tie each FDE to its CIE
    for (self.fdes.items[fdes_start..]) |*fde| {
        const cie_ptr = fde.offset + 4 - fde.ciePointer(elf_file);
        const cie_index = for (self.cies.items[cies_start..], cies_start..) |cie, cie_index| {
            if (cie.offset == cie_ptr) break @as(u32, @intCast(cie_index));
        } else {
            // TODO convert into an error
            log.debug("{s}: no matching CIE found for FDE at offset {x}", .{
                self.fmtPath(),
                fde.offset,
            });
            continue;
        };
        fde.cie_index = cie_index;
    }

    // Tie each FDE record to its matching atom
    const SortFdes = struct {
        pub fn lessThan(ctx: *Elf, lhs: Fde, rhs: Fde) bool {
            const lhs_atom = lhs.atom(ctx);
            const rhs_atom = rhs.atom(ctx);
            return lhs_atom.priority(ctx) < rhs_atom.priority(ctx);
        }
    };
    mem.sort(Fde, self.fdes.items[fdes_start..], elf_file, SortFdes.lessThan);

    // Create a back-link from atom to FDEs
    var i: u32 = @as(u32, @intCast(fdes_start));
    while (i < self.fdes.items.len) {
        const fde = self.fdes.items[i];
        const atom = fde.atom(elf_file);
        atom.fde_start = i;
        i += 1;
        while (i < self.fdes.items.len) : (i += 1) {
            const next_fde = self.fdes.items[i];
            if (atom.atom_index != next_fde.atom(elf_file).atom_index) break;
        }
        atom.fde_end = i;
    }
}

fn filterRelocs(
    relocs: []align(1) const elf.Elf64_Rela,
    start: u64,
    len: u64,
) struct { start: u64, len: u64 } {
    const Predicate = struct {
        value: u64,

        pub fn predicate(self: @This(), rel: elf.Elf64_Rela) bool {
            return rel.r_offset < self.value;
        }
    };
    const LPredicate = struct {
        value: u64,

        pub fn predicate(self: @This(), rel: elf.Elf64_Rela) bool {
            return rel.r_offset >= self.value;
        }
    };

    const f_start = Elf.bsearch(elf.Elf64_Rela, relocs, Predicate{ .value = start });
    const f_len = Elf.lsearch(elf.Elf64_Rela, relocs[f_start..], LPredicate{ .value = start + len });

    return .{ .start = f_start, .len = f_len };
}

pub fn scanRelocs(self: *Object, elf_file: *Elf, undefs: anytype) !void {
    for (self.atoms.items) |atom_index| {
        const atom = elf_file.atom(atom_index) orelse continue;
        if (!atom.flags.alive) continue;
        const shdr = atom.inputShdr(elf_file);
        if (shdr.sh_flags & elf.SHF_ALLOC == 0) continue;
        if (shdr.sh_type == elf.SHT_NOBITS) continue;
        if (try atom.scanRelocsRequiresCode(elf_file)) {
            // TODO ideally, we don't have to decompress at this stage (should already be done)
            // and we just fetch the code slice.
            const code = try self.codeDecompressAlloc(elf_file, atom_index);
            defer elf_file.base.allocator.free(code);
            try atom.scanRelocs(elf_file, code, undefs);
        } else try atom.scanRelocs(elf_file, null, undefs);
    }

    for (self.cies.items) |cie| {
        for (try cie.relocs(elf_file)) |rel| {
            const sym = elf_file.symbol(self.symbols.items[rel.r_sym()]);
            if (sym.flags.import) {
                if (sym.type(elf_file) != elf.STT_FUNC)
                    // TODO convert into an error
                    log.debug("{s}: {s}: CIE referencing external data reference", .{
                        self.fmtPath(),
                        sym.name(elf_file),
                    });
                sym.flags.needs_plt = true;
            }
        }
    }
}

pub fn resolveSymbols(self: *Object, elf_file: *Elf) void {
    const first_global = self.first_global orelse return;
    for (self.globals(), 0..) |index, i| {
        const esym_index = @as(Symbol.Index, @intCast(first_global + i));
        const esym = self.symtab[esym_index];

        if (esym.st_shndx == elf.SHN_UNDEF) continue;

        if (esym.st_shndx != elf.SHN_ABS and esym.st_shndx != elf.SHN_COMMON) {
            const atom_index = self.atoms.items[esym.st_shndx];
            const atom = elf_file.atom(atom_index) orelse continue;
            if (!atom.flags.alive) continue;
        }

        const global = elf_file.symbol(index);
        if (self.asFile().symbolRank(esym, !self.alive) < global.symbolRank(elf_file)) {
            const atom_index = switch (esym.st_shndx) {
                elf.SHN_ABS, elf.SHN_COMMON => 0,
                else => self.atoms.items[esym.st_shndx],
            };
            const output_section_index = if (elf_file.atom(atom_index)) |atom|
                atom.outputShndx().?
            else
                elf.SHN_UNDEF;
            global.value = esym.st_value;
            global.atom_index = atom_index;
            global.esym_index = esym_index;
            global.file_index = self.index;
            global.output_section_index = output_section_index;
            global.version_index = elf_file.default_sym_version;
            if (esym.st_bind() == elf.STB_WEAK) global.flags.weak = true;
        }
    }
}

pub fn claimUnresolved(self: *Object, elf_file: *Elf) void {
    const first_global = self.first_global orelse return;
    for (self.globals(), 0..) |index, i| {
        const esym_index = @as(u32, @intCast(first_global + i));
        const esym = self.symtab[esym_index];
        if (esym.st_shndx != elf.SHN_UNDEF) continue;

        const global = elf_file.symbol(index);
        if (global.file(elf_file)) |_| {
            if (global.elfSym(elf_file).st_shndx != elf.SHN_UNDEF) continue;
        }

        const is_import = blk: {
            if (!elf_file.isDynLib()) break :blk false;
            const vis = @as(elf.STV, @enumFromInt(esym.st_other));
            if (vis == .HIDDEN) break :blk false;
            break :blk true;
        };

        global.value = 0;
        global.atom_index = 0;
        global.esym_index = esym_index;
        global.file_index = self.index;
        global.version_index = if (is_import) elf.VER_NDX_LOCAL else elf_file.default_sym_version;
        global.flags.import = is_import;
    }
}

pub fn resetGlobals(self: *Object, elf_file: *Elf) void {
    for (self.globals()) |index| {
        const global = elf_file.symbol(index);
        const off = global.name_offset;
        global.* = .{};
        global.name_offset = off;
    }
}

pub fn markLive(self: *Object, elf_file: *Elf) void {
    const first_global = self.first_global orelse return;
    for (self.globals(), 0..) |index, i| {
        const sym_idx = first_global + i;
        const sym = self.symtab[sym_idx];
        if (sym.st_bind() == elf.STB_WEAK) continue;

        const global = elf_file.symbol(index);
        const file = global.file(elf_file) orelse continue;
        const should_keep = sym.st_shndx == elf.SHN_UNDEF or
            (sym.st_shndx == elf.SHN_COMMON and global.elfSym(elf_file).st_shndx != elf.SHN_COMMON);
        if (should_keep and !file.isAlive()) {
            file.setAlive();
            file.markLive(elf_file);
        }
    }
}

pub fn checkDuplicates(self: *Object, elf_file: *Elf) void {
    const first_global = self.first_global orelse return;
    for (self.globals(), 0..) |index, i| {
        const sym_idx = @as(u32, @intCast(first_global + i));
        const this_sym = self.symtab[sym_idx];
        const global = elf_file.symbol(index);
        const global_file = global.getFile(elf_file) orelse continue;

        if (self.index == global_file.getIndex() or
            this_sym.st_shndx == elf.SHN_UNDEF or
            this_sym.st_bind() == elf.STB_WEAK or
            this_sym.st_shndx == elf.SHN_COMMON) continue;

        if (this_sym.st_shndx != elf.SHN_ABS) {
            const atom_index = self.atoms.items[this_sym.st_shndx];
            const atom = elf_file.atom(atom_index) orelse continue;
            if (!atom.flags.alive) continue;
        }

        elf_file.base.fatal("multiple definition: {}: {}: {s}", .{
            self.fmtPath(),
            global_file.fmtPath(),
            global.getName(elf_file),
        });
    }
}

/// We will create dummy shdrs per each resolved common symbols to make it
/// play nicely with the rest of the system.
pub fn convertCommonSymbols(self: *Object, elf_file: *Elf) !void {
    const first_global = self.first_global orelse return;
    for (self.globals(), 0..) |index, i| {
        const sym_idx = @as(u32, @intCast(first_global + i));
        const this_sym = self.symtab[sym_idx];
        if (this_sym.st_shndx != elf.SHN_COMMON) continue;

        const global = elf_file.symbol(index);
        const global_file = global.getFile(elf_file).?;
        if (global_file.getIndex() != self.index) {
            if (elf_file.options.warn_common) {
                elf_file.base.warn("{}: multiple common symbols: {s}", .{
                    self.fmtPath(),
                    global.getName(elf_file),
                });
            }
            continue;
        }

        const gpa = elf_file.base.allocator;

        const atom_index = try elf_file.addAtom();
        try self.atoms.append(gpa, atom_index);

        const is_tls = global.getType(elf_file) == elf.STT_TLS;
        const name = if (is_tls) ".tbss" else ".bss";

        const atom = elf_file.atom(atom_index).?;
        atom.atom_index = atom_index;
        atom.name = try elf_file.strtab.insert(gpa, name);
        atom.file = self.index;
        atom.size = this_sym.st_size;
        const alignment = this_sym.st_value;
        atom.alignment = Alignment.fromNonzeroByteUnits(alignment);

        var sh_flags: u32 = elf.SHF_ALLOC | elf.SHF_WRITE;
        if (is_tls) sh_flags |= elf.SHF_TLS;
        const shndx = @as(u16, @intCast(self.shdrs.items.len));
        const shdr = try self.shdrs.addOne(gpa);
        shdr.* = .{
            .sh_name = try self.strings.insert(gpa, name),
            .sh_type = elf.SHT_NOBITS,
            .sh_flags = sh_flags,
            .sh_addr = 0,
            .sh_offset = 0,
            .sh_size = this_sym.st_size,
            .sh_link = 0,
            .sh_info = 0,
            .sh_addralign = alignment,
            .sh_entsize = 0,
        };
        atom.shndx = shndx;

        global.value = 0;
        global.atom = atom_index;
        global.flags.weak = false;
    }
}

pub fn updateSymtabSize(self: *Object, elf_file: *Elf) void {
    for (self.locals()) |local_index| {
        const local = elf_file.symbol(local_index);
        if (local.atom(elf_file)) |atom| if (!atom.flags.alive) continue;
        const esym = local.elfSym(elf_file);
        switch (esym.st_type()) {
            elf.STT_SECTION, elf.STT_NOTYPE => continue,
            else => {},
        }
        local.flags.output_symtab = true;
        self.output_symtab_size.nlocals += 1;
    }

    for (self.globals()) |global_index| {
        const global = elf_file.symbol(global_index);
        if (global.file(elf_file)) |file| if (file.index() != self.index) continue;
        if (global.atom(elf_file)) |atom| if (!atom.flags.alive) continue;
        global.flags.output_symtab = true;
        if (global.isLocal()) {
            self.output_symtab_size.nlocals += 1;
        } else {
            self.output_symtab_size.nglobals += 1;
        }
    }
}

pub fn writeSymtab(self: *Object, elf_file: *Elf, ctx: anytype) void {
    var ilocal = ctx.ilocal;
    for (self.locals()) |local_index| {
        const local = elf_file.symbol(local_index);
        if (!local.flags.output_symtab) continue;
        local.setOutputSym(elf_file, &ctx.symtab[ilocal]);
        ilocal += 1;
    }

    var iglobal = ctx.iglobal;
    for (self.globals()) |global_index| {
        const global = elf_file.symbol(global_index);
        if (global.file(elf_file)) |file| if (file.index() != self.index) continue;
        if (!global.flags.output_symtab) continue;
        if (global.isLocal()) {
            global.setOutputSym(elf_file, &ctx.symtab[ilocal]);
            ilocal += 1;
        } else {
            global.setOutputSym(elf_file, &ctx.symtab[iglobal]);
            iglobal += 1;
        }
    }
}

pub fn locals(self: *Object) []const Symbol.Index {
    const end = self.first_global orelse self.symbols.items.len;
    return self.symbols.items[0..end];
}

pub fn globals(self: *Object) []const Symbol.Index {
    const start = self.first_global orelse self.symbols.items.len;
    return self.symbols.items[start..];
}

fn shdrContents(self: Object, index: u32) error{Overflow}![]const u8 {
    assert(index < self.shdrs.items.len);
    const shdr = self.shdrs.items[index];
    const offset = math.cast(usize, shdr.sh_offset) orelse return error.Overflow;
    const size = math.cast(usize, shdr.sh_size) orelse return error.Overflow;
    return self.data[offset..][0..size];
}

/// Returns atom's code and optionally uncompresses data if required (for compressed sections).
/// Caller owns the memory.
pub fn codeDecompressAlloc(self: Object, elf_file: *Elf, atom_index: Atom.Index) ![]u8 {
    const gpa = elf_file.base.allocator;
    const atom_ptr = elf_file.atom(atom_index).?;
    assert(atom_ptr.file_index == self.index);
    const data = try self.shdrContents(atom_ptr.input_section_index);
    const shdr = atom_ptr.inputShdr(elf_file);
    if (shdr.sh_flags & elf.SHF_COMPRESSED != 0) {
        const chdr = @as(*align(1) const elf.Elf64_Chdr, @ptrCast(data.ptr)).*;
        switch (chdr.ch_type) {
            .ZLIB => {
                var stream = std.io.fixedBufferStream(data[@sizeOf(elf.Elf64_Chdr)..]);
                var zlib_stream = std.compress.zlib.decompressStream(gpa, stream.reader()) catch
                    return error.InputOutput;
                defer zlib_stream.deinit();
                const size = std.math.cast(usize, chdr.ch_size) orelse return error.Overflow;
                const decomp = try gpa.alloc(u8, size);
                const nread = zlib_stream.reader().readAll(decomp) catch return error.InputOutput;
                if (nread != decomp.len) {
                    return error.InputOutput;
                }
                return decomp;
            },
            else => @panic("TODO unhandled compression scheme"),
        }
    } else return gpa.dupe(u8, data);
}

fn getString(self: *Object, off: u32) [:0]const u8 {
    assert(off < self.strtab.len);
    return mem.sliceTo(@as([*:0]const u8, @ptrCast(self.strtab.ptr + off)), 0);
}

pub fn comdatGroupMembers(self: *Object, index: u16) error{Overflow}![]align(1) const u32 {
    const raw = try self.shdrContents(index);
    const nmembers = @divExact(raw.len, @sizeOf(u32));
    const members = @as([*]align(1) const u32, @ptrCast(raw.ptr))[1..nmembers];
    return members;
}

pub fn asFile(self: *Object) File {
    return .{ .object = self };
}

pub fn getRelocs(self: *Object, shndx: u32) error{Overflow}![]align(1) const elf.Elf64_Rela {
    const raw = try self.shdrContents(shndx);
    const num = @divExact(raw.len, @sizeOf(elf.Elf64_Rela));
    return @as([*]align(1) const elf.Elf64_Rela, @ptrCast(raw.ptr))[0..num];
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

pub fn fmtSymtab(self: *Object, elf_file: *Elf) std.fmt.Formatter(formatSymtab) {
    return .{ .data = .{
        .object = self,
        .elf_file = elf_file,
    } };
}

const FormatContext = struct {
    object: *Object,
    elf_file: *Elf,
};

fn formatSymtab(
    ctx: FormatContext,
    comptime unused_fmt_string: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = unused_fmt_string;
    _ = options;
    const object = ctx.object;
    try writer.writeAll("  locals\n");
    for (object.locals()) |index| {
        const local = ctx.elf_file.symbol(index);
        try writer.print("    {}\n", .{local.fmt(ctx.elf_file)});
    }
    try writer.writeAll("  globals\n");
    for (object.globals()) |index| {
        const global = ctx.elf_file.symbol(index);
        try writer.print("    {}\n", .{global.fmt(ctx.elf_file)});
    }
}

pub fn fmtAtoms(self: *Object, elf_file: *Elf) std.fmt.Formatter(formatAtoms) {
    return .{ .data = .{
        .object = self,
        .elf_file = elf_file,
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
        const atom = ctx.elf_file.atom(atom_index) orelse continue;
        try writer.print("    {}\n", .{atom.fmt(ctx.elf_file)});
    }
}

pub fn fmtCies(self: *Object, elf_file: *Elf) std.fmt.Formatter(formatCies) {
    return .{ .data = .{
        .object = self,
        .elf_file = elf_file,
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
        try writer.print("    cie({d}) : {}\n", .{ i, cie.fmt(ctx.elf_file) });
    }
}

pub fn fmtFdes(self: *Object, elf_file: *Elf) std.fmt.Formatter(formatFdes) {
    return .{ .data = .{
        .object = self,
        .elf_file = elf_file,
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
        try writer.print("    fde({d}) : {}\n", .{ i, fde.fmt(ctx.elf_file) });
    }
}

pub fn fmtComdatGroups(self: *Object, elf_file: *Elf) std.fmt.Formatter(formatComdatGroups) {
    return .{ .data = .{
        .object = self,
        .elf_file = elf_file,
    } };
}

fn formatComdatGroups(
    ctx: FormatContext,
    comptime unused_fmt_string: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = unused_fmt_string;
    _ = options;
    const object = ctx.object;
    const elf_file = ctx.elf_file;
    try writer.writeAll("  comdat groups\n");
    for (object.comdat_groups.items) |cg_index| {
        const cg = elf_file.comdatGroup(cg_index);
        const cg_owner = elf_file.comdatGroupOwner(cg.owner);
        if (cg_owner.file != object.index) continue;
        const cg_members = object.comdatGroupMembers(cg.shndx) catch continue;
        for (cg_members) |shndx| {
            const atom_index = object.atoms.items[shndx];
            const atom = elf_file.atom(atom_index) orelse continue;
            try writer.print("    atom({d}) : {s}\n", .{ atom_index, atom.name(elf_file) });
        }
    }
}

pub fn fmtPath(self: *Object) std.fmt.Formatter(formatPath) {
    return .{ .data = self };
}

fn formatPath(
    object: *Object,
    comptime unused_fmt_string: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = unused_fmt_string;
    _ = options;
    if (object.archive) |path| {
        try writer.writeAll(path);
        try writer.writeByte('(');
        try writer.writeAll(object.path);
        try writer.writeByte(')');
    } else try writer.writeAll(object.path);
}

const Object = @This();

const std = @import("std");
const assert = std.debug.assert;
const eh_frame = @import("eh_frame.zig");
const elf = std.elf;
const fs = std.fs;
const log = std.log.scoped(.link);
const math = std.math;
const mem = std.mem;

const Allocator = mem.Allocator;
const Atom = @import("Atom.zig");
const Cie = eh_frame.Cie;
const Elf = @import("../Elf.zig");
const Fde = eh_frame.Fde;
const File = @import("file.zig").File;
const StringTable = @import("../strtab.zig").StringTable;
const Symbol = @import("Symbol.zig");
const Alignment = Atom.Alignment;
