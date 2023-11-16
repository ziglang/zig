archive: ?[]const u8 = null,
path: []const u8,
data: []const u8,
index: File.Index,

header: ?elf.Elf64_Ehdr = null,
shdrs: std.ArrayListUnmanaged(ElfShdr) = .{},

symtab: std.ArrayListUnmanaged(elf.Elf64_Sym) = .{},
strtab: std.ArrayListUnmanaged(u8) = .{},
first_global: ?Symbol.Index = null,
symbols: std.ArrayListUnmanaged(Symbol.Index) = .{},
atoms: std.ArrayListUnmanaged(Atom.Index) = .{},
comdat_groups: std.ArrayListUnmanaged(Elf.ComdatGroup.Index) = .{},

fdes: std.ArrayListUnmanaged(Fde) = .{},
cies: std.ArrayListUnmanaged(Cie) = .{},

alive: bool = true,
num_dynrelocs: u32 = 0,

output_symtab_ctx: Elf.SymtabCtx = .{},
output_ar_state: Archive.ArState = .{},

pub fn isObject(path: []const u8) !bool {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const reader = file.reader();
    const header = reader.readStruct(elf.Elf64_Ehdr) catch return false;
    if (!mem.eql(u8, header.e_ident[0..4], "\x7fELF")) return false;
    if (header.e_ident[elf.EI_VERSION] != 1) return false;
    if (header.e_type != elf.ET.REL) return false;
    if (header.e_version != 1) return false;
    return true;
}

pub fn deinit(self: *Object, allocator: Allocator) void {
    if (self.archive) |path| allocator.free(path);
    allocator.free(self.path);
    allocator.free(self.data);
    self.shdrs.deinit(allocator);
    self.symtab.deinit(allocator);
    self.strtab.deinit(allocator);
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
    try self.shdrs.ensureTotalCapacityPrecise(gpa, shdrs.len);

    for (shdrs) |shdr| {
        self.shdrs.appendAssumeCapacity(try ElfShdr.fromElf64Shdr(shdr));
    }

    try self.strtab.appendSlice(gpa, self.shdrContents(self.header.?.e_shstrndx));

    const symtab_index = for (self.shdrs.items, 0..) |shdr, i| switch (shdr.sh_type) {
        elf.SHT_SYMTAB => break @as(u16, @intCast(i)),
        else => {},
    } else null;

    if (symtab_index) |index| {
        const shdr = shdrs[index];
        self.first_global = shdr.sh_info;

        const raw_symtab = self.shdrContents(index);
        const nsyms = @divExact(raw_symtab.len, @sizeOf(elf.Elf64_Sym));
        const symtab = @as([*]align(1) const elf.Elf64_Sym, @ptrCast(raw_symtab.ptr))[0..nsyms];

        const strtab_bias = @as(u32, @intCast(self.strtab.items.len));
        try self.strtab.appendSlice(gpa, self.shdrContents(@as(u16, @intCast(shdr.sh_link))));

        try self.symtab.ensureUnusedCapacity(gpa, symtab.len);
        for (symtab) |sym| {
            const out_sym = self.symtab.addOneAssumeCapacity();
            out_sym.* = sym;
            out_sym.st_name = if (sym.st_name == 0 and sym.st_type() == elf.STT_SECTION)
                shdrs[sym.st_shndx].sh_name
            else
                sym.st_name + strtab_bias;
        }
    }
}

pub fn init(self: *Object, elf_file: *Elf) !void {
    try self.initAtoms(elf_file);
    try self.initSymtab(elf_file);

    for (self.shdrs.items, 0..) |shdr, i| {
        const atom = elf_file.atom(self.atoms.items[i]) orelse continue;
        if (!atom.flags.alive) continue;
        if (shdr.sh_type == elf.SHT_X86_64_UNWIND or mem.eql(u8, atom.name(elf_file), ".eh_frame"))
            try self.parseEhFrame(@as(u16, @intCast(i)), elf_file);
    }
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
                if (shdr.sh_info >= self.symtab.items.len) {
                    // TODO convert into an error
                    log.debug("{}: invalid symbol index in sh_info", .{self.fmtPath()});
                    continue;
                }
                const group_info_sym = self.symtab.items[shdr.sh_info];
                const group_signature = blk: {
                    if (group_info_sym.st_name == 0 and group_info_sym.st_type() == elf.STT_SECTION) {
                        const sym_shdr = shdrs[group_info_sym.st_shndx];
                        break :blk self.getString(sym_shdr.sh_name);
                    }
                    break :blk self.getString(group_info_sym.st_name);
                };

                const shndx = @as(u16, @intCast(i));
                const group_raw_data = self.shdrContents(shndx);
                const group_nmembers = @divExact(group_raw_data.len, @sizeOf(u32));
                const group_members = @as([*]align(1) const u32, @ptrCast(group_raw_data.ptr))[0..group_nmembers];

                if (group_members[0] != elf.GRP_COMDAT) {
                    // TODO convert into an error
                    log.debug("{}: unknown SHT_GROUP format", .{self.fmtPath()});
                    continue;
                }

                const gpa = elf_file.base.allocator;
                const gop = try elf_file.getOrCreateComdatGroupOwner(group_signature);
                const comdat_group_index = try elf_file.addComdatGroup();
                const comdat_group = elf_file.comdatGroup(comdat_group_index);
                comdat_group.* = .{
                    .owner = gop.index,
                    .shndx = shndx,
                };
                try self.comdat_groups.append(gpa, comdat_group_index);
            },

            elf.SHT_SYMTAB_SHNDX => @panic("TODO SHT_SYMTAB_SHNDX"),

            elf.SHT_NULL,
            elf.SHT_REL,
            elf.SHT_RELA,
            elf.SHT_SYMTAB,
            elf.SHT_STRTAB,
            => {},

            else => {
                const shndx = @as(u16, @intCast(i));
                if (self.skipShdr(shndx, elf_file)) continue;
                try self.addAtom(shdr, shndx, elf_file);
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

fn addAtom(self: *Object, shdr: ElfShdr, shndx: u16, elf_file: *Elf) error{OutOfMemory}!void {
    const atom_index = try elf_file.addAtom();
    const atom = elf_file.atom(atom_index).?;
    atom.atom_index = atom_index;
    atom.name_offset = shdr.sh_name;
    atom.file_index = self.index;
    atom.input_section_index = shndx;
    self.atoms.items[shndx] = atom_index;

    if (shdr.sh_flags & elf.SHF_COMPRESSED != 0) {
        const data = self.shdrContents(shndx);
        const chdr = @as(*align(1) const elf.Elf64_Chdr, @ptrCast(data.ptr)).*;
        atom.size = chdr.ch_size;
        atom.alignment = Alignment.fromNonzeroByteUnits(chdr.ch_addralign);
    } else {
        atom.size = shdr.sh_size;
        atom.alignment = Alignment.fromNonzeroByteUnits(shdr.sh_addralign);
    }
}

fn initOutputSection(self: Object, elf_file: *Elf, shdr: ElfShdr) error{OutOfMemory}!u16 {
    const name = blk: {
        const name = self.getString(shdr.sh_name);
        if (elf_file.isRelocatable()) break :blk name;
        if (shdr.sh_flags & elf.SHF_MERGE != 0) break :blk name;
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
        var flags = shdr.sh_flags;
        if (!elf_file.isRelocatable()) {
            flags &= ~@as(u64, elf.SHF_COMPRESSED | elf.SHF_GROUP | elf.SHF_GNU_RETAIN);
        }
        break :blk switch (@"type") {
            elf.SHT_INIT_ARRAY, elf.SHT_FINI_ARRAY => flags | elf.SHF_WRITE,
            else => flags,
        };
    };
    const out_shndx = elf_file.sectionByName(name) orelse try elf_file.addSection(.{
        .type = @"type",
        .flags = flags,
        .name = name,
    });
    return out_shndx;
}

fn skipShdr(self: *Object, index: u16, elf_file: *Elf) bool {
    const shdr = self.shdrs.items[index];
    const name = self.getString(shdr.sh_name);
    const ignore = blk: {
        if (mem.startsWith(u8, name, ".note")) break :blk true;
        if (mem.startsWith(u8, name, ".comment")) break :blk true;
        if (mem.startsWith(u8, name, ".llvm_addrsig")) break :blk true;
        if (elf_file.base.options.strip and shdr.sh_flags & elf.SHF_ALLOC == 0 and
            mem.startsWith(u8, name, ".debug")) break :blk true;
        break :blk false;
    };
    return ignore;
}

fn initSymtab(self: *Object, elf_file: *Elf) !void {
    const gpa = elf_file.base.allocator;
    const first_global = self.first_global orelse self.symtab.items.len;

    try self.symbols.ensureTotalCapacityPrecise(gpa, self.symtab.items.len);

    for (self.symtab.items[0..first_global], 0..) |sym, i| {
        const index = try elf_file.addSymbol();
        self.symbols.appendAssumeCapacity(index);
        const sym_ptr = elf_file.symbol(index);
        sym_ptr.value = sym.st_value;
        sym_ptr.name_offset = sym.st_name;
        sym_ptr.esym_index = @as(u32, @intCast(i));
        sym_ptr.atom_index = if (sym.st_shndx == elf.SHN_ABS) 0 else self.atoms.items[sym.st_shndx];
        sym_ptr.file_index = self.index;
    }

    for (self.symtab.items[first_global..]) |sym| {
        const name = self.getString(sym.st_name);
        const gop = try elf_file.getOrPutGlobal(name);
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
    const raw = self.shdrContents(shndx);
    const relocs = self.getRelocs(relocs_shndx);
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
        if (atom.scanRelocsRequiresCode(elf_file)) {
            // TODO ideally, we don't have to decompress at this stage (should already be done)
            // and we just fetch the code slice.
            const code = try self.codeDecompressAlloc(elf_file, atom_index);
            defer elf_file.base.allocator.free(code);
            try atom.scanRelocs(elf_file, code, undefs);
        } else try atom.scanRelocs(elf_file, null, undefs);
    }

    for (self.cies.items) |cie| {
        for (cie.relocs(elf_file)) |rel| {
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
        const esym = self.symtab.items[esym_index];

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
            global.value = esym.st_value;
            global.atom_index = atom_index;
            global.esym_index = esym_index;
            global.file_index = self.index;
            global.version_index = elf_file.default_sym_version;
            if (esym.st_bind() == elf.STB_WEAK) global.flags.weak = true;
        }
    }
}

pub fn claimUnresolved(self: *Object, elf_file: *Elf) void {
    const first_global = self.first_global orelse return;
    for (self.globals(), 0..) |index, i| {
        const esym_index = @as(u32, @intCast(first_global + i));
        const esym = self.symtab.items[esym_index];
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

pub fn claimUnresolvedObject(self: *Object, elf_file: *Elf) void {
    const first_global = self.first_global orelse return;
    for (self.globals(), 0..) |index, i| {
        const esym_index = @as(u32, @intCast(first_global + i));
        const esym = self.symtab.items[esym_index];
        if (esym.st_shndx != elf.SHN_UNDEF) continue;

        const global = elf_file.symbol(index);
        if (global.file(elf_file)) |file| {
            if (global.elfSym(elf_file).st_shndx != elf.SHN_UNDEF or file.index() <= self.index) continue;
        }

        global.value = 0;
        global.atom_index = 0;
        global.esym_index = esym_index;
        global.file_index = self.index;
    }
}

pub fn markLive(self: *Object, elf_file: *Elf) void {
    const first_global = self.first_global orelse return;
    for (self.globals(), 0..) |index, i| {
        const sym_idx = first_global + i;
        const sym = self.symtab.items[sym_idx];
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

pub fn markEhFrameAtomsDead(self: Object, elf_file: *Elf) void {
    for (self.atoms.items) |atom_index| {
        const atom = elf_file.atom(atom_index) orelse continue;
        const is_eh_frame = atom.inputShdr(elf_file).sh_type == elf.SHT_X86_64_UNWIND or
            mem.eql(u8, atom.name(elf_file), ".eh_frame");
        if (atom.flags.alive and is_eh_frame) atom.flags.alive = false;
    }
}

pub fn checkDuplicates(self: *Object, elf_file: *Elf) void {
    const first_global = self.first_global orelse return;
    for (self.globals(), 0..) |index, i| {
        const sym_idx = @as(u32, @intCast(first_global + i));
        const this_sym = self.symtab.items[sym_idx];
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
        const this_sym = self.symtab.items[sym_idx];
        if (this_sym.st_shndx != elf.SHN_COMMON) continue;

        const global = elf_file.symbol(index);
        const global_file = global.file(elf_file).?;
        if (global_file.index() != self.index) {
            // if (elf_file.options.warn_common) {
            //     elf_file.base.warn("{}: multiple common symbols: {s}", .{
            //         self.fmtPath(),
            //         global.getName(elf_file),
            //     });
            // }
            continue;
        }

        const gpa = elf_file.base.allocator;

        const atom_index = try elf_file.addAtom();
        try self.atoms.append(gpa, atom_index);

        const is_tls = global.type(elf_file) == elf.STT_TLS;
        const name = if (is_tls) ".tls_common" else ".common";

        const atom = elf_file.atom(atom_index).?;
        const name_offset = @as(u32, @intCast(self.strtab.items.len));
        try self.strtab.writer(gpa).print("{s}\x00", .{name});
        atom.atom_index = atom_index;
        atom.name_offset = name_offset;
        atom.file_index = self.index;
        atom.size = this_sym.st_size;
        const alignment = this_sym.st_value;
        atom.alignment = Alignment.fromNonzeroByteUnits(alignment);

        var sh_flags: u32 = elf.SHF_ALLOC | elf.SHF_WRITE;
        if (is_tls) sh_flags |= elf.SHF_TLS;
        const shndx = @as(u16, @intCast(self.shdrs.items.len));
        const shdr = try self.shdrs.addOne(gpa);
        const sh_size = math.cast(usize, this_sym.st_size) orelse return error.Overflow;
        shdr.* = .{
            .sh_name = name_offset,
            .sh_type = elf.SHT_NOBITS,
            .sh_flags = sh_flags,
            .sh_addr = 0,
            .sh_offset = 0,
            .sh_size = sh_size,
            .sh_link = 0,
            .sh_info = 0,
            .sh_addralign = alignment,
            .sh_entsize = 0,
        };
        atom.input_section_index = shndx;

        global.value = 0;
        global.atom_index = atom_index;
        global.flags.weak = false;
    }
}

pub fn initOutputSections(self: Object, elf_file: *Elf) !void {
    for (self.atoms.items) |atom_index| {
        const atom = elf_file.atom(atom_index) orelse continue;
        if (!atom.flags.alive) continue;
        const shdr = atom.inputShdr(elf_file);
        _ = try self.initOutputSection(elf_file, shdr);
    }
}

pub fn addAtomsToOutputSections(self: *Object, elf_file: *Elf) !void {
    for (self.atoms.items) |atom_index| {
        const atom = elf_file.atom(atom_index) orelse continue;
        if (!atom.flags.alive) continue;
        const shdr = atom.inputShdr(elf_file);
        atom.output_section_index = self.initOutputSection(elf_file, shdr) catch unreachable;

        const gpa = elf_file.base.allocator;
        const gop = try elf_file.output_sections.getOrPut(gpa, atom.output_section_index);
        if (!gop.found_existing) gop.value_ptr.* = .{};
        try gop.value_ptr.append(gpa, atom_index);
    }
}

pub fn allocateAtoms(self: Object, elf_file: *Elf) void {
    for (self.atoms.items) |atom_index| {
        const atom = elf_file.atom(atom_index) orelse continue;
        if (!atom.flags.alive) continue;
        const shdr = elf_file.shdrs.items[atom.output_section_index];
        atom.value += shdr.sh_addr;
    }

    for (self.locals()) |local_index| {
        const local = elf_file.symbol(local_index);
        const atom = local.atom(elf_file) orelse continue;
        if (!atom.flags.alive) continue;
        local.value += atom.value;
        local.output_section_index = atom.output_section_index;
    }

    for (self.globals()) |global_index| {
        const global = elf_file.symbol(global_index);
        const atom = global.atom(elf_file) orelse continue;
        if (!atom.flags.alive) continue;
        if (global.file(elf_file).?.index() != self.index) continue;
        global.value += atom.value;
        global.output_section_index = atom.output_section_index;
    }
}

pub fn initRelaSections(self: Object, elf_file: *Elf) !void {
    for (self.atoms.items) |atom_index| {
        const atom = elf_file.atom(atom_index) orelse continue;
        if (!atom.flags.alive) continue;
        const shndx = atom.relocsShndx() orelse continue;
        const shdr = self.shdrs.items[shndx];
        const out_shndx = try self.initOutputSection(elf_file, shdr);
        const out_shdr = &elf_file.shdrs.items[out_shndx];
        out_shdr.sh_addralign = @alignOf(elf.Elf64_Rela);
        out_shdr.sh_entsize = @sizeOf(elf.Elf64_Rela);
        out_shdr.sh_flags |= elf.SHF_INFO_LINK;
    }
}

pub fn addAtomsToRelaSections(self: Object, elf_file: *Elf) !void {
    for (self.atoms.items) |atom_index| {
        const atom = elf_file.atom(atom_index) orelse continue;
        if (!atom.flags.alive) continue;
        const shndx = blk: {
            const shndx = atom.relocsShndx() orelse continue;
            const shdr = self.shdrs.items[shndx];
            break :blk self.initOutputSection(elf_file, shdr) catch unreachable;
        };
        const shdr = &elf_file.shdrs.items[shndx];
        shdr.sh_info = atom.outputShndx().?;
        shdr.sh_link = elf_file.symtab_section_index.?;

        const gpa = elf_file.base.allocator;
        const gop = try elf_file.output_rela_sections.getOrPut(gpa, atom.outputShndx().?);
        if (!gop.found_existing) gop.value_ptr.* = .{ .shndx = shndx };
        try gop.value_ptr.atom_list.append(gpa, atom_index);
    }
}

pub fn updateArSymtab(self: Object, ar_symtab: *Archive.ArSymtab, elf_file: *Elf) !void {
    const gpa = elf_file.base.allocator;
    const start = self.first_global orelse self.symtab.items.len;

    try ar_symtab.symtab.ensureUnusedCapacity(gpa, self.symtab.items.len - start);

    for (self.symtab.items[start..]) |sym| {
        if (sym.st_shndx == elf.SHN_UNDEF) continue;
        const off = try ar_symtab.strtab.insert(gpa, self.getString(sym.st_name));
        ar_symtab.symtab.appendAssumeCapacity(.{ .off = off, .file_index = self.index });
    }
}

pub fn updateArSize(self: *Object) void {
    self.output_ar_state.size = self.data.len;
}

pub fn writeAr(self: Object, writer: anytype) !void {
    const name = self.path;
    const hdr = Archive.setArHdr(.{
        .name = if (name.len <= Archive.max_member_name_len)
            .{ .name = name }
        else
            .{ .name_off = self.output_ar_state.name_off },
        .size = @intCast(self.data.len),
    });
    try writer.writeAll(mem.asBytes(&hdr));
    try writer.writeAll(self.data);
}

pub fn updateSymtabSize(self: *Object, elf_file: *Elf) !void {
    for (self.locals()) |local_index| {
        const local = elf_file.symbol(local_index);
        if (local.atom(elf_file)) |atom| if (!atom.flags.alive) continue;
        const esym = local.elfSym(elf_file);
        switch (esym.st_type()) {
            elf.STT_SECTION, elf.STT_NOTYPE => continue,
            else => {},
        }
        local.flags.output_symtab = true;
        try local.setOutputSymtabIndex(self.output_symtab_ctx.nlocals, elf_file);
        self.output_symtab_ctx.nlocals += 1;
        self.output_symtab_ctx.strsize += @as(u32, @intCast(local.name(elf_file).len)) + 1;
    }

    for (self.globals()) |global_index| {
        const global = elf_file.symbol(global_index);
        const file_ptr = global.file(elf_file) orelse continue;
        if (file_ptr.index() != self.index) continue;
        if (global.atom(elf_file)) |atom| if (!atom.flags.alive) continue;
        global.flags.output_symtab = true;
        if (global.isLocal(elf_file)) {
            try global.setOutputSymtabIndex(self.output_symtab_ctx.nlocals, elf_file);
            self.output_symtab_ctx.nlocals += 1;
        } else {
            try global.setOutputSymtabIndex(self.output_symtab_ctx.nglobals, elf_file);
            self.output_symtab_ctx.nglobals += 1;
        }
        self.output_symtab_ctx.strsize += @as(u32, @intCast(global.name(elf_file).len)) + 1;
    }
}

pub fn writeSymtab(self: Object, elf_file: *Elf) void {
    for (self.locals()) |local_index| {
        const local = elf_file.symbol(local_index);
        const idx = local.outputSymtabIndex(elf_file) orelse continue;
        const out_sym = &elf_file.symtab.items[idx];
        out_sym.st_name = @intCast(elf_file.strtab.items.len);
        elf_file.strtab.appendSliceAssumeCapacity(local.name(elf_file));
        elf_file.strtab.appendAssumeCapacity(0);
        local.setOutputSym(elf_file, out_sym);
    }

    for (self.globals()) |global_index| {
        const global = elf_file.symbol(global_index);
        const file_ptr = global.file(elf_file) orelse continue;
        if (file_ptr.index() != self.index) continue;
        const idx = global.outputSymtabIndex(elf_file) orelse continue;
        const st_name = @as(u32, @intCast(elf_file.strtab.items.len));
        elf_file.strtab.appendSliceAssumeCapacity(global.name(elf_file));
        elf_file.strtab.appendAssumeCapacity(0);
        const out_sym = &elf_file.symtab.items[idx];
        out_sym.st_name = st_name;
        global.setOutputSym(elf_file, out_sym);
    }
}

pub fn locals(self: Object) []const Symbol.Index {
    if (self.symbols.items.len == 0) return &[0]Symbol.Index{};
    const end = self.first_global orelse self.symbols.items.len;
    return self.symbols.items[0..end];
}

pub fn globals(self: Object) []const Symbol.Index {
    if (self.symbols.items.len == 0) return &[0]Symbol.Index{};
    const start = self.first_global orelse self.symbols.items.len;
    return self.symbols.items[start..];
}

pub fn shdrContents(self: Object, index: u32) []const u8 {
    assert(index < self.shdrs.items.len);
    const shdr = self.shdrs.items[index];
    return self.data[shdr.sh_offset..][0..shdr.sh_size];
}

/// Returns atom's code and optionally uncompresses data if required (for compressed sections).
/// Caller owns the memory.
pub fn codeDecompressAlloc(self: Object, elf_file: *Elf, atom_index: Atom.Index) ![]u8 {
    const gpa = elf_file.base.allocator;
    const atom_ptr = elf_file.atom(atom_index).?;
    assert(atom_ptr.file_index == self.index);
    const data = self.shdrContents(atom_ptr.input_section_index);
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

pub fn comdatGroupMembers(self: *Object, index: u16) []align(1) const u32 {
    const raw = self.shdrContents(index);
    const nmembers = @divExact(raw.len, @sizeOf(u32));
    const members = @as([*]align(1) const u32, @ptrCast(raw.ptr))[1..nmembers];
    return members;
}

pub fn asFile(self: *Object) File {
    return .{ .object = self };
}

pub fn getRelocs(self: *Object, shndx: u32) []align(1) const elf.Elf64_Rela {
    const raw = self.shdrContents(shndx);
    const num = @divExact(raw.len, @sizeOf(elf.Elf64_Rela));
    return @as([*]align(1) const elf.Elf64_Rela, @ptrCast(raw.ptr))[0..num];
}

pub fn getString(self: Object, off: u32) [:0]const u8 {
    assert(off < self.strtab.items.len);
    return mem.sliceTo(@as([*:0]const u8, @ptrCast(self.strtab.items.ptr + off)), 0);
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
    try writer.writeAll("  COMDAT groups\n");
    for (object.comdat_groups.items) |cg_index| {
        const cg = elf_file.comdatGroup(cg_index);
        const cg_owner = elf_file.comdatGroupOwner(cg.owner);
        if (cg_owner.file != object.index) continue;
        try writer.print("    COMDAT({d})\n", .{cg_index});
        const cg_members = object.comdatGroupMembers(cg.shndx);
        for (cg_members) |shndx| {
            const atom_index = object.atoms.items[shndx];
            const atom = elf_file.atom(atom_index) orelse continue;
            try writer.print("      atom({d}) : {s}\n", .{ atom_index, atom.name(elf_file) });
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

pub const ElfShdr = struct {
    sh_name: u32,
    sh_type: u32,
    sh_flags: u64,
    sh_addr: u64,
    sh_offset: usize,
    sh_size: usize,
    sh_link: u32,
    sh_info: u32,
    sh_addralign: u64,
    sh_entsize: u64,

    pub fn fromElf64Shdr(shdr: elf.Elf64_Shdr) error{Overflow}!ElfShdr {
        return .{
            .sh_name = shdr.sh_name,
            .sh_type = shdr.sh_type,
            .sh_flags = shdr.sh_flags,
            .sh_addr = shdr.sh_addr,
            .sh_offset = math.cast(usize, shdr.sh_offset) orelse return error.Overflow,
            .sh_size = math.cast(usize, shdr.sh_size) orelse return error.Overflow,
            .sh_link = shdr.sh_link,
            .sh_info = shdr.sh_info,
            .sh_addralign = shdr.sh_addralign,
            .sh_entsize = shdr.sh_entsize,
        };
    }
};

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
const Archive = @import("Archive.zig");
const Atom = @import("Atom.zig");
const Cie = eh_frame.Cie;
const Elf = @import("../Elf.zig");
const Fde = eh_frame.Fde;
const File = @import("file.zig").File;
const Symbol = @import("Symbol.zig");
const Alignment = Atom.Alignment;
