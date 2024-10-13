archive: ?InArchive = null,
/// Archive files cannot contain subdirectories, so only the basename is needed
/// for output. However, the full path is kept for error reporting.
path: Path,
file_handle: File.HandleIndex,
index: File.Index,

header: ?elf.Elf64_Ehdr = null,
shdrs: std.ArrayListUnmanaged(elf.Elf64_Shdr) = .empty,

symtab: std.ArrayListUnmanaged(elf.Elf64_Sym) = .empty,
strtab: std.ArrayListUnmanaged(u8) = .empty,
first_global: ?Symbol.Index = null,
symbols: std.ArrayListUnmanaged(Symbol) = .empty,
symbols_extra: std.ArrayListUnmanaged(u32) = .empty,
symbols_resolver: std.ArrayListUnmanaged(Elf.SymbolResolver.Index) = .empty,
relocs: std.ArrayListUnmanaged(elf.Elf64_Rela) = .empty,

atoms: std.ArrayListUnmanaged(Atom) = .empty,
atoms_indexes: std.ArrayListUnmanaged(Atom.Index) = .empty,
atoms_extra: std.ArrayListUnmanaged(u32) = .empty,

comdat_groups: std.ArrayListUnmanaged(Elf.ComdatGroup) = .empty,
comdat_group_data: std.ArrayListUnmanaged(u32) = .empty,

input_merge_sections: std.ArrayListUnmanaged(Merge.InputSection) = .empty,
input_merge_sections_indexes: std.ArrayListUnmanaged(Merge.InputSection.Index) = .empty,

fdes: std.ArrayListUnmanaged(Fde) = .empty,
cies: std.ArrayListUnmanaged(Cie) = .empty,
eh_frame_data: std.ArrayListUnmanaged(u8) = .empty,

alive: bool = true,
dirty: bool = true,
num_dynrelocs: u32 = 0,

output_symtab_ctx: Elf.SymtabCtx = .{},
output_ar_state: Archive.ArState = .{},

pub fn deinit(self: *Object, allocator: Allocator) void {
    if (self.archive) |*ar| allocator.free(ar.path.sub_path);
    allocator.free(self.path.sub_path);
    self.shdrs.deinit(allocator);
    self.symtab.deinit(allocator);
    self.strtab.deinit(allocator);
    self.symbols.deinit(allocator);
    self.symbols_extra.deinit(allocator);
    self.symbols_resolver.deinit(allocator);
    self.atoms.deinit(allocator);
    self.atoms_indexes.deinit(allocator);
    self.atoms_extra.deinit(allocator);
    self.comdat_groups.deinit(allocator);
    self.comdat_group_data.deinit(allocator);
    self.relocs.deinit(allocator);
    self.fdes.deinit(allocator);
    self.cies.deinit(allocator);
    self.eh_frame_data.deinit(allocator);
    for (self.input_merge_sections.items) |*isec| {
        isec.deinit(allocator);
    }
    self.input_merge_sections.deinit(allocator);
    self.input_merge_sections_indexes.deinit(allocator);
}

pub fn parse(self: *Object, elf_file: *Elf) !void {
    const gpa = elf_file.base.comp.gpa;
    const cpu_arch = elf_file.getTarget().cpu.arch;
    const handle = elf_file.fileHandle(self.file_handle);

    try self.parseCommon(gpa, handle, elf_file);

    // Append null input merge section
    try self.input_merge_sections.append(gpa, .{});
    // Allocate atom index 0 to null atom
    try self.atoms.append(gpa, .{ .extra_index = try self.addAtomExtra(gpa, .{}) });

    try self.initAtoms(gpa, handle, elf_file);
    try self.initSymbols(gpa, elf_file);

    for (self.shdrs.items, 0..) |shdr, i| {
        const atom_ptr = self.atom(self.atoms_indexes.items[i]) orelse continue;
        if (!atom_ptr.alive) continue;
        if ((cpu_arch == .x86_64 and shdr.sh_type == elf.SHT_X86_64_UNWIND) or
            mem.eql(u8, atom_ptr.name(elf_file), ".eh_frame"))
        {
            try self.parseEhFrame(gpa, handle, @as(u32, @intCast(i)), elf_file);
        }
    }
}

fn parseCommon(self: *Object, allocator: Allocator, handle: std.fs.File, elf_file: *Elf) !void {
    const offset = if (self.archive) |ar| ar.offset else 0;
    const file_size = (try handle.stat()).size;

    const header_buffer = try Elf.preadAllAlloc(allocator, handle, offset, @sizeOf(elf.Elf64_Ehdr));
    defer allocator.free(header_buffer);
    self.header = @as(*align(1) const elf.Elf64_Ehdr, @ptrCast(header_buffer)).*;

    const em = elf_file.base.comp.root_mod.resolved_target.result.toElfMachine();
    if (em != self.header.?.e_machine) {
        return elf_file.failFile(self.index, "invalid ELF machine type: {s}", .{
            @tagName(self.header.?.e_machine),
        });
    }
    try elf_file.validateEFlags(self.index, self.header.?.e_flags);

    if (self.header.?.e_shnum == 0) return;

    const shoff = math.cast(usize, self.header.?.e_shoff) orelse return error.Overflow;
    const shnum = math.cast(usize, self.header.?.e_shnum) orelse return error.Overflow;
    const shsize = shnum * @sizeOf(elf.Elf64_Shdr);
    if (file_size < offset + shoff or file_size < offset + shoff + shsize) {
        return elf_file.failFile(self.index, "corrupt header: section header table extends past the end of file", .{});
    }

    const shdrs_buffer = try Elf.preadAllAlloc(allocator, handle, offset + shoff, shsize);
    defer allocator.free(shdrs_buffer);
    const shdrs = @as([*]align(1) const elf.Elf64_Shdr, @ptrCast(shdrs_buffer.ptr))[0..shnum];
    try self.shdrs.appendUnalignedSlice(allocator, shdrs);

    for (self.shdrs.items) |shdr| {
        if (shdr.sh_type != elf.SHT_NOBITS) {
            if (file_size < offset + shdr.sh_offset or file_size < offset + shdr.sh_offset + shdr.sh_size) {
                return elf_file.failFile(self.index, "corrupt section: extends past the end of file", .{});
            }
        }
    }

    const shstrtab = try self.preadShdrContentsAlloc(allocator, handle, self.header.?.e_shstrndx);
    defer allocator.free(shstrtab);
    for (self.shdrs.items) |shdr| {
        if (shdr.sh_name >= shstrtab.len) {
            return elf_file.failFile(self.index, "corrupt section name offset", .{});
        }
    }
    try self.strtab.appendSlice(allocator, shstrtab);

    const symtab_index = for (self.shdrs.items, 0..) |shdr, i| switch (shdr.sh_type) {
        elf.SHT_SYMTAB => break @as(u32, @intCast(i)),
        else => {},
    } else null;

    if (symtab_index) |index| {
        const shdr = self.shdrs.items[index];
        self.first_global = shdr.sh_info;

        const raw_symtab = try self.preadShdrContentsAlloc(allocator, handle, index);
        defer allocator.free(raw_symtab);
        const nsyms = math.divExact(usize, raw_symtab.len, @sizeOf(elf.Elf64_Sym)) catch {
            return elf_file.failFile(self.index, "symbol table not evenly divisible", .{});
        };
        const symtab = @as([*]align(1) const elf.Elf64_Sym, @ptrCast(raw_symtab.ptr))[0..nsyms];

        const strtab_bias = @as(u32, @intCast(self.strtab.items.len));
        const strtab = try self.preadShdrContentsAlloc(allocator, handle, shdr.sh_link);
        defer allocator.free(strtab);
        try self.strtab.appendSlice(allocator, strtab);

        try self.symtab.ensureUnusedCapacity(allocator, symtab.len);
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

fn initAtoms(self: *Object, allocator: Allocator, handle: std.fs.File, elf_file: *Elf) !void {
    const comp = elf_file.base.comp;
    const debug_fmt_strip = comp.config.debug_format == .strip;
    const target = comp.root_mod.resolved_target.result;
    const shdrs = self.shdrs.items;
    try self.atoms.ensureTotalCapacityPrecise(allocator, shdrs.len);
    try self.atoms_extra.ensureTotalCapacityPrecise(allocator, shdrs.len * @sizeOf(Atom.Extra));
    try self.atoms_indexes.ensureTotalCapacityPrecise(allocator, shdrs.len);
    try self.atoms_indexes.resize(allocator, shdrs.len);
    @memset(self.atoms_indexes.items, 0);

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
                        break :blk sym_shdr.sh_name;
                    }
                    break :blk group_info_sym.st_name;
                };

                const shndx: u32 = @intCast(i);
                const group_raw_data = try self.preadShdrContentsAlloc(allocator, handle, shndx);
                defer allocator.free(group_raw_data);
                const group_nmembers = math.divExact(usize, group_raw_data.len, @sizeOf(u32)) catch {
                    return elf_file.failFile(self.index, "corrupt section group: not evenly divisible ", .{});
                };
                if (group_nmembers == 0) {
                    return elf_file.failFile(self.index, "corrupt section group: empty section", .{});
                }
                const group_members = @as([*]align(1) const u32, @ptrCast(group_raw_data.ptr))[0..group_nmembers];

                if (group_members[0] != elf.GRP_COMDAT) {
                    return elf_file.failFile(self.index, "corrupt section group: unknown SHT_GROUP format", .{});
                }

                const group_start: u32 = @intCast(self.comdat_group_data.items.len);
                try self.comdat_group_data.appendUnalignedSlice(allocator, group_members[1..]);

                const comdat_group_index = try self.addComdatGroup(allocator);
                const comdat_group = self.comdatGroup(comdat_group_index);
                comdat_group.* = .{
                    .signature_off = group_signature,
                    .file_index = self.index,
                    .shndx = shndx,
                    .members_start = group_start,
                    .members_len = @intCast(group_nmembers - 1),
                };
            },

            elf.SHT_SYMTAB_SHNDX => @panic("TODO SHT_SYMTAB_SHNDX"),

            elf.SHT_NULL,
            elf.SHT_REL,
            elf.SHT_RELA,
            elf.SHT_SYMTAB,
            elf.SHT_STRTAB,
            => {},

            else => {
                const shndx: u32 = @intCast(i);
                if (self.skipShdr(shndx, debug_fmt_strip)) continue;
                const size, const alignment = if (shdr.sh_flags & elf.SHF_COMPRESSED != 0) blk: {
                    const data = try self.preadShdrContentsAlloc(allocator, handle, shndx);
                    defer allocator.free(data);
                    const chdr = @as(*align(1) const elf.Elf64_Chdr, @ptrCast(data.ptr)).*;
                    break :blk .{ chdr.ch_size, Alignment.fromNonzeroByteUnits(chdr.ch_addralign) };
                } else .{ shdr.sh_size, Alignment.fromNonzeroByteUnits(shdr.sh_addralign) };
                const atom_index = self.addAtomAssumeCapacity(.{
                    .name = shdr.sh_name,
                    .shndx = shndx,
                    .size = size,
                    .alignment = alignment,
                });
                self.atoms_indexes.items[shndx] = atom_index;
            },
        }
    }

    // Parse relocs sections if any.
    for (shdrs, 0..) |shdr, i| switch (shdr.sh_type) {
        elf.SHT_REL, elf.SHT_RELA => {
            const atom_index = self.atoms_indexes.items[shdr.sh_info];
            if (self.atom(atom_index)) |atom_ptr| {
                const relocs = try self.preadRelocsAlloc(allocator, handle, @intCast(i));
                defer allocator.free(relocs);
                atom_ptr.relocs_section_index = @intCast(i);
                const rel_index: u32 = @intCast(self.relocs.items.len);
                const rel_count: u32 = @intCast(relocs.len);
                self.setAtomFields(atom_ptr, .{ .rel_index = rel_index, .rel_count = rel_count });
                try self.relocs.appendUnalignedSlice(allocator, relocs);
                if (target.cpu.arch == .riscv64) {
                    sortRelocs(self.relocs.items[rel_index..][0..rel_count]);
                }
            }
        },
        else => {},
    };
}

fn skipShdr(self: *Object, index: u32, debug_fmt_strip: bool) bool {
    const shdr = self.shdrs.items[index];
    const name = self.getString(shdr.sh_name);
    const ignore = blk: {
        if (mem.startsWith(u8, name, ".note")) break :blk true;
        if (mem.startsWith(u8, name, ".llvm_addrsig")) break :blk true;
        if (mem.startsWith(u8, name, ".riscv.attributes")) break :blk true; // TODO: riscv attributes
        if (debug_fmt_strip and shdr.sh_flags & elf.SHF_ALLOC == 0 and
            mem.startsWith(u8, name, ".debug")) break :blk true;
        break :blk false;
    };
    return ignore;
}

fn initSymbols(self: *Object, allocator: Allocator, elf_file: *Elf) !void {
    const first_global = self.first_global orelse self.symtab.items.len;
    const nglobals = self.symtab.items.len - first_global;

    try self.symbols.ensureTotalCapacityPrecise(allocator, self.symtab.items.len);
    try self.symbols_extra.ensureTotalCapacityPrecise(allocator, self.symtab.items.len * @sizeOf(Symbol.Extra));
    try self.symbols_resolver.ensureTotalCapacityPrecise(allocator, nglobals);
    self.symbols_resolver.resize(allocator, nglobals) catch unreachable;
    @memset(self.symbols_resolver.items, 0);

    for (self.symtab.items, 0..) |sym, i| {
        const index = self.addSymbolAssumeCapacity();
        const sym_ptr = &self.symbols.items[index];
        sym_ptr.value = @intCast(sym.st_value);
        sym_ptr.name_offset = sym.st_name;
        sym_ptr.esym_index = @intCast(i);
        sym_ptr.extra_index = self.addSymbolExtraAssumeCapacity(.{});
        sym_ptr.version_index = if (i >= first_global) elf_file.default_sym_version else .LOCAL;
        sym_ptr.flags.weak = sym.st_bind() == elf.STB_WEAK;
        if (sym.st_shndx != elf.SHN_ABS and sym.st_shndx != elf.SHN_COMMON) {
            sym_ptr.ref = .{ .index = self.atoms_indexes.items[sym.st_shndx], .file = self.index };
        }
    }
}

fn parseEhFrame(self: *Object, allocator: Allocator, handle: std.fs.File, shndx: u32, elf_file: *Elf) !void {
    const relocs_shndx = for (self.shdrs.items, 0..) |shdr, i| switch (shdr.sh_type) {
        elf.SHT_RELA => if (shdr.sh_info == shndx) break @as(u32, @intCast(i)),
        else => {},
    } else null;

    const raw = try self.preadShdrContentsAlloc(allocator, handle, shndx);
    defer allocator.free(raw);
    const data_start = @as(u32, @intCast(self.eh_frame_data.items.len));
    try self.eh_frame_data.appendSlice(allocator, raw);
    const relocs = if (relocs_shndx) |index|
        try self.preadRelocsAlloc(allocator, handle, index)
    else
        &[0]elf.Elf64_Rela{};
    defer allocator.free(relocs);
    const rel_start = @as(u32, @intCast(self.relocs.items.len));
    try self.relocs.appendUnalignedSlice(allocator, relocs);
    if (elf_file.getTarget().cpu.arch == .riscv64) {
        sortRelocs(self.relocs.items[rel_start..][0..relocs.len]);
    }
    const fdes_start = self.fdes.items.len;
    const cies_start = self.cies.items.len;

    var it = eh_frame.Iterator{ .data = raw };
    while (try it.next()) |rec| {
        const rel_range = filterRelocs(self.relocs.items[rel_start..][0..relocs.len], rec.offset, rec.size + 4);
        switch (rec.tag) {
            .cie => try self.cies.append(allocator, .{
                .offset = data_start + rec.offset,
                .size = rec.size,
                .rel_index = rel_start + @as(u32, @intCast(rel_range.start)),
                .rel_num = @as(u32, @intCast(rel_range.len)),
                .input_section_index = shndx,
                .file_index = self.index,
            }),
            .fde => {
                if (rel_range.len == 0) {
                    // No relocs for an FDE means we cannot associate this FDE to an Atom
                    // so we skip it. According to mold source code
                    // (https://github.com/rui314/mold/blob/a3e69502b0eaf1126d6093e8ea5e6fdb95219811/src/input-files.cc#L525-L528)
                    // this can happen for object files built with -r flag by the linker.
                    continue;
                }
                try self.fdes.append(allocator, .{
                    .offset = data_start + rec.offset,
                    .size = rec.size,
                    .cie_index = undefined,
                    .rel_index = rel_start + @as(u32, @intCast(rel_range.start)),
                    .rel_num = @as(u32, @intCast(rel_range.len)),
                    .input_section_index = shndx,
                    .file_index = self.index,
                });
            },
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
        const atom_ptr = fde.atom(elf_file);
        const start = i;
        i += 1;
        while (i < self.fdes.items.len) : (i += 1) {
            const next_fde = self.fdes.items[i];
            if (atom_ptr.atom_index != next_fde.atom(elf_file).atom_index) break;
        }
        atom_ptr.addExtra(.{ .fde_start = start, .fde_count = i - start }, elf_file);
    }
}

fn sortRelocs(relocs: []elf.Elf64_Rela) void {
    const sortFn = struct {
        fn lessThan(c: void, lhs: elf.Elf64_Rela, rhs: elf.Elf64_Rela) bool {
            _ = c;
            return lhs.r_offset < rhs.r_offset;
        }
    }.lessThan;
    mem.sort(elf.Elf64_Rela, relocs, {}, sortFn);
}

fn filterRelocs(
    relocs: []const elf.Elf64_Rela,
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
    const comp = elf_file.base.comp;
    const gpa = comp.gpa;
    for (self.atoms_indexes.items) |atom_index| {
        const atom_ptr = self.atom(atom_index) orelse continue;
        if (!atom_ptr.alive) continue;
        const shdr = atom_ptr.inputShdr(elf_file);
        if (shdr.sh_flags & elf.SHF_ALLOC == 0) continue;
        if (shdr.sh_type == elf.SHT_NOBITS) continue;
        if (atom_ptr.scanRelocsRequiresCode(elf_file)) {
            // TODO ideally, we don't have to decompress at this stage (should already be done)
            // and we just fetch the code slice.
            const code = try self.codeDecompressAlloc(elf_file, atom_index);
            defer gpa.free(code);
            try atom_ptr.scanRelocs(elf_file, code, undefs);
        } else try atom_ptr.scanRelocs(elf_file, null, undefs);
    }

    for (self.cies.items) |cie| {
        for (cie.relocs(elf_file)) |rel| {
            const sym = elf_file.symbol(self.resolveSymbol(rel.r_sym(), elf_file)).?;
            if (sym.flags.import) {
                if (sym.type(elf_file) != elf.STT_FUNC)
                    // TODO convert into an error
                    log.debug("{s}: {s}: CIE referencing external data reference", .{
                        self.fmtPath(), sym.name(elf_file),
                    });
                sym.flags.needs_plt = true;
            }
        }
    }
}

pub fn resolveSymbols(self: *Object, elf_file: *Elf) !void {
    const gpa = elf_file.base.comp.gpa;

    const first_global = self.first_global orelse return;
    for (self.globals(), first_global..) |_, i| {
        const esym = self.symtab.items[i];
        const resolv = &self.symbols_resolver.items[i - first_global];
        const gop = try elf_file.resolver.getOrPut(gpa, .{
            .index = @intCast(i),
            .file = self.index,
        }, elf_file);
        if (!gop.found_existing) {
            gop.ref.* = .{ .index = 0, .file = 0 };
        }
        resolv.* = gop.index;

        if (esym.st_shndx == elf.SHN_UNDEF) continue;
        if (esym.st_shndx != elf.SHN_ABS and esym.st_shndx != elf.SHN_COMMON) {
            const atom_index = self.atoms_indexes.items[esym.st_shndx];
            const atom_ptr = self.atom(atom_index) orelse continue;
            if (!atom_ptr.alive) continue;
        }
        if (elf_file.symbol(gop.ref.*) == null) {
            gop.ref.* = .{ .index = @intCast(i), .file = self.index };
            continue;
        }

        if (self.asFile().symbolRank(esym, !self.alive) < elf_file.symbol(gop.ref.*).?.symbolRank(elf_file)) {
            gop.ref.* = .{ .index = @intCast(i), .file = self.index };
        }
    }
}

pub fn claimUnresolved(self: *Object, elf_file: *Elf) void {
    const first_global = self.first_global orelse return;
    for (self.globals(), 0..) |*sym, i| {
        const esym_index = @as(u32, @intCast(first_global + i));
        const esym = self.symtab.items[esym_index];
        if (esym.st_shndx != elf.SHN_UNDEF) continue;
        if (elf_file.symbol(self.resolveSymbol(esym_index, elf_file)) != null) continue;

        const is_import = blk: {
            if (!elf_file.isEffectivelyDynLib()) break :blk false;
            const vis = @as(elf.STV, @enumFromInt(esym.st_other));
            if (vis == .HIDDEN) break :blk false;
            break :blk true;
        };

        sym.value = 0;
        sym.ref = .{ .index = 0, .file = 0 };
        sym.esym_index = esym_index;
        sym.file_index = self.index;
        sym.version_index = if (is_import) .LOCAL else elf_file.default_sym_version;
        sym.flags.import = is_import;

        const idx = self.symbols_resolver.items[i];
        elf_file.resolver.values.items[idx - 1] = .{ .index = esym_index, .file = self.index };
    }
}

pub fn claimUnresolvedRelocatable(self: *Object, elf_file: *Elf) void {
    const first_global = self.first_global orelse return;
    for (self.globals(), 0..) |*sym, i| {
        const esym_index = @as(u32, @intCast(first_global + i));
        const esym = self.symtab.items[esym_index];
        if (esym.st_shndx != elf.SHN_UNDEF) continue;
        if (elf_file.symbol(self.resolveSymbol(esym_index, elf_file)) != null) continue;

        sym.value = 0;
        sym.ref = .{ .index = 0, .file = 0 };
        sym.esym_index = esym_index;
        sym.file_index = self.index;

        const idx = self.symbols_resolver.items[i];
        elf_file.resolver.values.items[idx - 1] = .{ .index = esym_index, .file = self.index };
    }
}

pub fn markLive(self: *Object, elf_file: *Elf) void {
    const first_global = self.first_global orelse return;
    for (0..self.globals().len) |i| {
        const esym_idx = first_global + i;
        const esym = self.symtab.items[esym_idx];
        if (esym.st_bind() == elf.STB_WEAK) continue;

        const ref = self.resolveSymbol(@intCast(esym_idx), elf_file);
        const sym = elf_file.symbol(ref) orelse continue;
        const file = sym.file(elf_file).?;
        const should_keep = esym.st_shndx == elf.SHN_UNDEF or
            (esym.st_shndx == elf.SHN_COMMON and sym.elfSym(elf_file).st_shndx != elf.SHN_COMMON);
        if (should_keep and !file.isAlive()) {
            file.setAlive();
            file.markLive(elf_file);
        }
    }
}

pub fn markEhFrameAtomsDead(self: *Object, elf_file: *Elf) void {
    const cpu_arch = elf_file.getTarget().cpu.arch;
    for (self.atoms_indexes.items) |atom_index| {
        const atom_ptr = self.atom(atom_index) orelse continue;
        const is_eh_frame = (cpu_arch == .x86_64 and atom_ptr.inputShdr(elf_file).sh_type == elf.SHT_X86_64_UNWIND) or
            mem.eql(u8, atom_ptr.name(elf_file), ".eh_frame");
        if (atom_ptr.alive and is_eh_frame) atom_ptr.alive = false;
    }
}

pub fn markImportsExports(self: *Object, elf_file: *Elf) void {
    const first_global = self.first_global orelse return;
    for (0..self.globals().len) |i| {
        const idx = first_global + i;
        const ref = self.resolveSymbol(@intCast(idx), elf_file);
        const sym = elf_file.symbol(ref) orelse continue;
        const file = sym.file(elf_file).?;
        // https://github.com/ziglang/zig/issues/21678
        if (@as(u16, @bitCast(sym.version_index)) == @as(u16, @bitCast(elf.Versym.LOCAL))) continue;
        const vis: elf.STV = @enumFromInt(sym.elfSym(elf_file).st_other);
        if (vis == .HIDDEN) continue;
        if (file == .shared_object and !sym.isAbs(elf_file)) {
            sym.flags.import = true;
            continue;
        }
        if (file.index() == self.index) {
            sym.flags.@"export" = true;
            if (elf_file.isEffectivelyDynLib() and vis != .PROTECTED) {
                sym.flags.import = true;
            }
        }
    }
}

pub fn checkDuplicates(self: *Object, dupes: anytype, elf_file: *Elf) error{OutOfMemory}!void {
    const first_global = self.first_global orelse return;
    for (0..self.globals().len) |i| {
        const esym_idx = first_global + i;
        const esym = self.symtab.items[esym_idx];
        const ref = self.resolveSymbol(@intCast(esym_idx), elf_file);
        const ref_sym = elf_file.symbol(ref) orelse continue;
        const ref_file = ref_sym.file(elf_file).?;

        if (self.index == ref_file.index() or
            esym.st_shndx == elf.SHN_UNDEF or
            esym.st_bind() == elf.STB_WEAK or
            esym.st_shndx == elf.SHN_COMMON) continue;

        if (esym.st_shndx != elf.SHN_ABS) {
            const atom_index = self.atoms_indexes.items[esym.st_shndx];
            const atom_ptr = self.atom(atom_index) orelse continue;
            if (!atom_ptr.alive) continue;
        }

        const gop = try dupes.getOrPut(self.symbols_resolver.items[i]);
        if (!gop.found_existing) {
            gop.value_ptr.* = .{};
        }
        try gop.value_ptr.append(elf_file.base.comp.gpa, self.index);
    }
}

pub fn initInputMergeSections(self: *Object, elf_file: *Elf) !void {
    const gpa = elf_file.base.comp.gpa;
    const diags = &elf_file.base.comp.link_diags;

    try self.input_merge_sections.ensureUnusedCapacity(gpa, self.shdrs.items.len);
    try self.input_merge_sections_indexes.resize(gpa, self.shdrs.items.len);
    @memset(self.input_merge_sections_indexes.items, 0);

    for (self.shdrs.items, 0..) |shdr, shndx| {
        if (shdr.sh_flags & elf.SHF_MERGE == 0) continue;

        const atom_index = self.atoms_indexes.items[shndx];
        const atom_ptr = self.atom(atom_index) orelse continue;
        if (!atom_ptr.alive) continue;
        if (atom_ptr.relocs(elf_file).len > 0) continue;

        const imsec_idx = try self.addInputMergeSection(gpa);
        const imsec = self.inputMergeSection(imsec_idx).?;
        self.input_merge_sections_indexes.items[shndx] = imsec_idx;
        imsec.atom_index = atom_index;

        const data = try self.codeDecompressAlloc(elf_file, atom_index);
        defer gpa.free(data);

        if (shdr.sh_flags & elf.SHF_STRINGS != 0) {
            const sh_entsize: u32 = switch (shdr.sh_entsize) {
                // According to mold's source code, GHC emits MS sections with sh_entsize = 0.
                // This actually can also happen for output created with `-r` mode.
                0 => 1,
                else => |x| @intCast(x),
            };

            const isNull = struct {
                fn isNull(slice: []u8) bool {
                    for (slice) |x| if (x != 0) return false;
                    return true;
                }
            }.isNull;

            var start: u32 = 0;
            while (start < data.len) {
                var end = start;
                while (end < data.len - sh_entsize and !isNull(data[end .. end + sh_entsize])) : (end += sh_entsize) {}
                if (!isNull(data[end .. end + sh_entsize])) {
                    var err = try diags.addErrorWithNotes(1);
                    try err.addMsg("string not null terminated", .{});
                    try err.addNote("in {}:{s}", .{ self.fmtPath(), atom_ptr.name(elf_file) });
                    return error.LinkFailure;
                }
                end += sh_entsize;
                const string = data[start..end];
                try imsec.insert(gpa, string);
                try imsec.offsets.append(gpa, start);
                start = end;
            }
        } else {
            const sh_entsize: u32 = @intCast(shdr.sh_entsize);
            if (sh_entsize == 0) continue; // Malformed, don't split but don't error out
            if (shdr.sh_size % sh_entsize != 0) {
                var err = try diags.addErrorWithNotes(1);
                try err.addMsg("size not a multiple of sh_entsize", .{});
                try err.addNote("in {}:{s}", .{ self.fmtPath(), atom_ptr.name(elf_file) });
                return error.LinkFailure;
            }

            var pos: u32 = 0;
            while (pos < data.len) : (pos += sh_entsize) {
                const string = data.ptr[pos..][0..sh_entsize];
                try imsec.insert(gpa, string);
                try imsec.offsets.append(gpa, pos);
            }
        }

        atom_ptr.alive = false;
    }
}

pub fn initOutputMergeSections(self: *Object, elf_file: *Elf) !void {
    for (self.input_merge_sections_indexes.items) |index| {
        const imsec = self.inputMergeSection(index) orelse continue;
        const atom_ptr = self.atom(imsec.atom_index).?;
        const shdr = atom_ptr.inputShdr(elf_file);
        imsec.merge_section_index = try elf_file.getOrCreateMergeSection(
            atom_ptr.name(elf_file),
            shdr.sh_flags,
            shdr.sh_type,
        );
    }
}

pub fn resolveMergeSubsections(self: *Object, elf_file: *Elf) error{
    LinkFailure,
    OutOfMemory,
    /// TODO report the error and remove this
    Overflow,
}!void {
    const gpa = elf_file.base.comp.gpa;
    const diags = &elf_file.base.comp.link_diags;

    for (self.input_merge_sections_indexes.items) |index| {
        const imsec = self.inputMergeSection(index) orelse continue;
        if (imsec.offsets.items.len == 0) continue;
        const msec = elf_file.mergeSection(imsec.merge_section_index);
        const atom_ptr = self.atom(imsec.atom_index).?;
        const isec = atom_ptr.inputShdr(elf_file);

        try imsec.subsections.resize(gpa, imsec.strings.items.len);

        for (imsec.strings.items, imsec.subsections.items) |str, *imsec_msub| {
            const string = imsec.bytes.items[str.pos..][0..str.len];
            const res = try msec.insert(gpa, string);
            if (!res.found_existing) {
                const msub_index = try msec.addMergeSubsection(gpa);
                const msub = msec.mergeSubsection(msub_index);
                msub.merge_section_index = imsec.merge_section_index;
                msub.string_index = res.key.pos;
                msub.alignment = atom_ptr.alignment;
                msub.size = res.key.len;
                msub.entsize = math.cast(u32, isec.sh_entsize) orelse return error.Overflow;
                msub.alive = !elf_file.base.gc_sections or isec.sh_flags & elf.SHF_ALLOC == 0;
                res.sub.* = msub_index;
            }
            imsec_msub.* = res.sub.*;
        }

        imsec.clearAndFree(gpa);
    }

    for (self.symtab.items, 0..) |*esym, idx| {
        const sym = &self.symbols.items[idx];
        if (esym.st_shndx == elf.SHN_COMMON or esym.st_shndx == elf.SHN_UNDEF or esym.st_shndx == elf.SHN_ABS) continue;

        const imsec_index = self.input_merge_sections_indexes.items[esym.st_shndx];
        const imsec = self.inputMergeSection(imsec_index) orelse continue;
        if (imsec.offsets.items.len == 0) continue;
        const res = imsec.findSubsection(@intCast(esym.st_value)) orelse {
            var err = try diags.addErrorWithNotes(2);
            try err.addMsg("invalid symbol value: {x}", .{esym.st_value});
            try err.addNote("for symbol {s}", .{sym.name(elf_file)});
            try err.addNote("in {}", .{self.fmtPath()});
            return error.LinkFailure;
        };

        sym.ref = .{ .index = res.msub_index, .file = imsec.merge_section_index };
        sym.flags.merge_subsection = true;
        sym.value = res.offset;
    }

    for (self.atoms_indexes.items) |atom_index| {
        const atom_ptr = self.atom(atom_index) orelse continue;
        if (!atom_ptr.alive) continue;
        const extras = atom_ptr.extra(elf_file);
        const relocs = self.relocs.items[extras.rel_index..][0..extras.rel_count];
        for (relocs) |*rel| {
            const esym = self.symtab.items[rel.r_sym()];
            if (esym.st_type() != elf.STT_SECTION) continue;

            const imsec_index = self.input_merge_sections_indexes.items[esym.st_shndx];
            const imsec = self.inputMergeSection(imsec_index) orelse continue;
            if (imsec.offsets.items.len == 0) continue;
            const msec = elf_file.mergeSection(imsec.merge_section_index);
            const res = imsec.findSubsection(@intCast(@as(i64, @intCast(esym.st_value)) + rel.r_addend)) orelse {
                var err = try diags.addErrorWithNotes(1);
                try err.addMsg("invalid relocation at offset 0x{x}", .{rel.r_offset});
                try err.addNote("in {}:{s}", .{ self.fmtPath(), atom_ptr.name(elf_file) });
                return error.LinkFailure;
            };

            const sym_index = try self.addSymbol(gpa);
            const sym = &self.symbols.items[sym_index];
            const name = try std.fmt.allocPrint(gpa, "{s}$subsection{d}", .{ msec.name(elf_file), res.msub_index });
            defer gpa.free(name);
            sym.* = .{
                .value = @bitCast(@as(i64, @intCast(res.offset)) - rel.r_addend),
                .name_offset = try self.addString(gpa, name),
                .esym_index = rel.r_sym(),
                .file_index = self.index,
                .extra_index = try self.addSymbolExtra(gpa, .{}),
            };
            sym.ref = .{ .index = res.msub_index, .file = imsec.merge_section_index };
            sym.flags.merge_subsection = true;
            rel.r_info = (@as(u64, @intCast(sym_index)) << 32) | rel.r_type();
        }
    }
}

/// We will create dummy shdrs per each resolved common symbols to make it
/// play nicely with the rest of the system.
pub fn convertCommonSymbols(self: *Object, elf_file: *Elf) !void {
    const first_global = self.first_global orelse return;
    for (self.globals(), self.symbols_resolver.items, 0..) |*sym, resolv, i| {
        const esym_idx = @as(u32, @intCast(first_global + i));
        const esym = self.symtab.items[esym_idx];
        if (esym.st_shndx != elf.SHN_COMMON) continue;
        if (elf_file.resolver.get(resolv).?.file != self.index) continue;

        const comp = elf_file.base.comp;
        const gpa = comp.gpa;

        const is_tls = sym.type(elf_file) == elf.STT_TLS;
        const name = if (is_tls) ".tls_common" else ".common";
        const name_offset = @as(u32, @intCast(self.strtab.items.len));
        try self.strtab.writer(gpa).print("{s}\x00", .{name});

        var sh_flags: u32 = elf.SHF_ALLOC | elf.SHF_WRITE;
        if (is_tls) sh_flags |= elf.SHF_TLS;
        const shndx = @as(u32, @intCast(self.shdrs.items.len));
        const shdr = try self.shdrs.addOne(gpa);
        const sh_size = math.cast(usize, esym.st_size) orelse return error.Overflow;
        shdr.* = .{
            .sh_name = name_offset,
            .sh_type = elf.SHT_NOBITS,
            .sh_flags = sh_flags,
            .sh_addr = 0,
            .sh_offset = 0,
            .sh_size = sh_size,
            .sh_link = 0,
            .sh_info = 0,
            .sh_addralign = esym.st_value,
            .sh_entsize = 0,
        };

        const atom_index = try self.addAtom(gpa, .{
            .name = name_offset,
            .shndx = shndx,
            .size = esym.st_size,
            .alignment = Alignment.fromNonzeroByteUnits(esym.st_value),
        });
        try self.atoms_indexes.append(gpa, atom_index);

        sym.value = 0;
        sym.ref = .{ .index = atom_index, .file = self.index };
        sym.flags.weak = false;
    }
}

pub fn resolveComdatGroups(self: *Object, elf_file: *Elf, table: anytype) !void {
    for (self.comdat_groups.items, 0..) |*cg, cgi| {
        const signature = cg.signature(elf_file);
        const gop = try table.getOrPut(signature);
        if (!gop.found_existing) {
            gop.value_ptr.* = .{ .index = @intCast(cgi), .file = self.index };
            continue;
        }
        const current = elf_file.comdatGroup(gop.value_ptr.*);
        cg.alive = false;
        if (self.index < current.file_index) {
            current.alive = false;
            cg.alive = true;
            gop.value_ptr.* = .{ .index = @intCast(cgi), .file = self.index };
        }
    }
}

pub fn markComdatGroupsDead(self: *Object, elf_file: *Elf) void {
    for (self.comdat_groups.items) |cg| {
        if (cg.alive) continue;
        for (cg.comdatGroupMembers(elf_file)) |shndx| {
            const atom_index = self.atoms_indexes.items[shndx];
            if (self.atom(atom_index)) |atom_ptr| {
                atom_ptr.alive = false;
                atom_ptr.markFdesDead(elf_file);
            }
        }
    }
}

pub fn initOutputSections(self: *Object, elf_file: *Elf) !void {
    for (self.atoms_indexes.items) |atom_index| {
        const atom_ptr = self.atom(atom_index) orelse continue;
        if (!atom_ptr.alive) continue;
        const shdr = atom_ptr.inputShdr(elf_file);
        const osec = try elf_file.initOutputSection(.{
            .name = self.getString(shdr.sh_name),
            .flags = shdr.sh_flags,
            .type = shdr.sh_type,
        });
        const atom_list = &elf_file.sections.items(.atom_list_2)[osec];
        atom_list.output_section_index = osec;
        _ = try atom_list.atoms.getOrPut(elf_file.base.comp.gpa, atom_ptr.ref());
    }
}

pub fn initRelaSections(self: *Object, elf_file: *Elf) !void {
    for (self.atoms_indexes.items) |atom_index| {
        const atom_ptr = self.atom(atom_index) orelse continue;
        if (!atom_ptr.alive) continue;
        if (atom_ptr.output_section_index == elf_file.section_indexes.eh_frame) continue;
        const shndx = atom_ptr.relocsShndx() orelse continue;
        const shdr = self.shdrs.items[shndx];
        const out_shndx = try elf_file.initOutputSection(.{
            .name = self.getString(shdr.sh_name),
            .flags = shdr.sh_flags,
            .type = shdr.sh_type,
        });
        const out_shdr = &elf_file.sections.items(.shdr)[out_shndx];
        out_shdr.sh_type = elf.SHT_RELA;
        out_shdr.sh_addralign = @alignOf(elf.Elf64_Rela);
        out_shdr.sh_entsize = @sizeOf(elf.Elf64_Rela);
        out_shdr.sh_flags |= elf.SHF_INFO_LINK;
    }
}

pub fn addAtomsToRelaSections(self: *Object, elf_file: *Elf) !void {
    for (self.atoms_indexes.items) |atom_index| {
        const atom_ptr = self.atom(atom_index) orelse continue;
        if (!atom_ptr.alive) continue;
        if (atom_ptr.output_section_index == elf_file.section_indexes.eh_frame) continue;
        const shndx = blk: {
            const shndx = atom_ptr.relocsShndx() orelse continue;
            const shdr = self.shdrs.items[shndx];
            break :blk elf_file.initOutputSection(.{
                .name = self.getString(shdr.sh_name),
                .flags = shdr.sh_flags,
                .type = shdr.sh_type,
            }) catch unreachable;
        };
        const slice = elf_file.sections.slice();
        const shdr = &slice.items(.shdr)[shndx];
        shdr.sh_info = atom_ptr.output_section_index;
        shdr.sh_link = elf_file.section_indexes.symtab.?;
        const gpa = elf_file.base.comp.gpa;
        const atom_list = &elf_file.sections.items(.atom_list)[shndx];
        try atom_list.append(gpa, .{ .index = atom_index, .file = self.index });
    }
}

pub fn parseAr(self: *Object, elf_file: *Elf) !void {
    const gpa = elf_file.base.comp.gpa;
    const handle = elf_file.fileHandle(self.file_handle);
    try self.parseCommon(gpa, handle, elf_file);
}

pub fn updateArSymtab(self: Object, ar_symtab: *Archive.ArSymtab, elf_file: *Elf) !void {
    const comp = elf_file.base.comp;
    const gpa = comp.gpa;
    const start = self.first_global orelse self.symtab.items.len;

    try ar_symtab.symtab.ensureUnusedCapacity(gpa, self.symtab.items.len - start);

    for (self.symtab.items[start..]) |sym| {
        if (sym.st_shndx == elf.SHN_UNDEF) continue;
        const off = try ar_symtab.strtab.insert(gpa, self.getString(sym.st_name));
        ar_symtab.symtab.appendAssumeCapacity(.{ .off = off, .file_index = self.index });
    }
}

pub fn updateArSize(self: *Object, elf_file: *Elf) !void {
    self.output_ar_state.size = if (self.archive) |ar| ar.size else size: {
        const handle = elf_file.fileHandle(self.file_handle);
        break :size (try handle.stat()).size;
    };
}

pub fn writeAr(self: Object, elf_file: *Elf, writer: anytype) !void {
    const size = std.math.cast(usize, self.output_ar_state.size) orelse return error.Overflow;
    const offset: u64 = if (self.archive) |ar| ar.offset else 0;
    const name = std.fs.path.basename(self.path.sub_path);
    const hdr = Archive.setArHdr(.{
        .name = if (name.len <= Archive.max_member_name_len)
            .{ .name = name }
        else
            .{ .name_off = self.output_ar_state.name_off },
        .size = size,
    });
    try writer.writeAll(mem.asBytes(&hdr));
    const handle = elf_file.fileHandle(self.file_handle);
    const gpa = elf_file.base.comp.gpa;
    const data = try gpa.alloc(u8, size);
    defer gpa.free(data);
    const amt = try handle.preadAll(data, offset);
    if (amt != size) return error.InputOutput;
    try writer.writeAll(data);
}

pub fn updateSymtabSize(self: *Object, elf_file: *Elf) void {
    const isAlive = struct {
        fn isAlive(sym: *const Symbol, ctx: *Elf) bool {
            if (sym.mergeSubsection(ctx)) |msub| return msub.alive;
            if (sym.atom(ctx)) |atom_ptr| return atom_ptr.alive;
            return true;
        }
    }.isAlive;

    for (self.locals()) |*local| {
        if (!isAlive(local, elf_file)) continue;
        const esym = local.elfSym(elf_file);
        switch (esym.st_type()) {
            elf.STT_SECTION => continue,
            elf.STT_NOTYPE => if (esym.st_shndx == elf.SHN_UNDEF) continue,
            else => {},
        }
        local.flags.output_symtab = true;
        local.addExtra(.{ .symtab = self.output_symtab_ctx.nlocals }, elf_file);
        self.output_symtab_ctx.nlocals += 1;
        self.output_symtab_ctx.strsize += @as(u32, @intCast(local.name(elf_file).len)) + 1;
    }

    for (self.globals(), self.symbols_resolver.items) |*global, resolv| {
        const ref = elf_file.resolver.values.items[resolv - 1];
        const ref_sym = elf_file.symbol(ref) orelse continue;
        if (ref_sym.file(elf_file).?.index() != self.index) continue;
        if (!isAlive(global, elf_file)) continue;
        global.flags.output_symtab = true;
        if (global.isLocal(elf_file)) {
            global.addExtra(.{ .symtab = self.output_symtab_ctx.nlocals }, elf_file);
            self.output_symtab_ctx.nlocals += 1;
        } else {
            global.addExtra(.{ .symtab = self.output_symtab_ctx.nglobals }, elf_file);
            self.output_symtab_ctx.nglobals += 1;
        }
        self.output_symtab_ctx.strsize += @as(u32, @intCast(global.name(elf_file).len)) + 1;
    }
}

pub fn writeSymtab(self: *Object, elf_file: *Elf) void {
    for (self.locals()) |local| {
        const idx = local.outputSymtabIndex(elf_file) orelse continue;
        const out_sym = &elf_file.symtab.items[idx];
        out_sym.st_name = @intCast(elf_file.strtab.items.len);
        elf_file.strtab.appendSliceAssumeCapacity(local.name(elf_file));
        elf_file.strtab.appendAssumeCapacity(0);
        local.setOutputSym(elf_file, out_sym);
    }

    for (self.globals(), self.symbols_resolver.items) |global, resolv| {
        const ref = elf_file.resolver.values.items[resolv - 1];
        const ref_sym = elf_file.symbol(ref) orelse continue;
        if (ref_sym.file(elf_file).?.index() != self.index) continue;
        const idx = global.outputSymtabIndex(elf_file) orelse continue;
        const st_name = @as(u32, @intCast(elf_file.strtab.items.len));
        elf_file.strtab.appendSliceAssumeCapacity(global.name(elf_file));
        elf_file.strtab.appendAssumeCapacity(0);
        const out_sym = &elf_file.symtab.items[idx];
        out_sym.st_name = st_name;
        global.setOutputSym(elf_file, out_sym);
    }
}

/// Returns atom's code and optionally uncompresses data if required (for compressed sections).
/// Caller owns the memory.
pub fn codeDecompressAlloc(self: *Object, elf_file: *Elf, atom_index: Atom.Index) ![]u8 {
    const comp = elf_file.base.comp;
    const gpa = comp.gpa;
    const atom_ptr = self.atom(atom_index).?;
    const shdr = atom_ptr.inputShdr(elf_file);
    const handle = elf_file.fileHandle(self.file_handle);
    const data = try self.preadShdrContentsAlloc(gpa, handle, atom_ptr.input_section_index);
    defer if (shdr.sh_flags & elf.SHF_COMPRESSED != 0) gpa.free(data);

    if (shdr.sh_flags & elf.SHF_COMPRESSED != 0) {
        const chdr = @as(*align(1) const elf.Elf64_Chdr, @ptrCast(data.ptr)).*;
        switch (chdr.ch_type) {
            .ZLIB => {
                var stream = std.io.fixedBufferStream(data[@sizeOf(elf.Elf64_Chdr)..]);
                var zlib_stream = std.compress.zlib.decompressor(stream.reader());
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
    }

    return data;
}

fn locals(self: *Object) []Symbol {
    if (self.symbols.items.len == 0) return &[0]Symbol{};
    assert(self.symbols.items.len >= self.symtab.items.len);
    const end = self.first_global orelse self.symtab.items.len;
    return self.symbols.items[0..end];
}

pub fn globals(self: *Object) []Symbol {
    if (self.symbols.items.len == 0) return &[0]Symbol{};
    assert(self.symbols.items.len >= self.symtab.items.len);
    const start = self.first_global orelse self.symtab.items.len;
    return self.symbols.items[start..self.symtab.items.len];
}

pub fn resolveSymbol(self: Object, index: Symbol.Index, elf_file: *Elf) Elf.Ref {
    const start = self.first_global orelse self.symtab.items.len;
    const end = self.symtab.items.len;
    if (index < start or index >= end) return .{ .index = index, .file = self.index };
    const resolv = self.symbols_resolver.items[index - start];
    return elf_file.resolver.get(resolv).?;
}

fn addSymbol(self: *Object, allocator: Allocator) !Symbol.Index {
    try self.symbols.ensureUnusedCapacity(allocator, 1);
    return self.addSymbolAssumeCapacity();
}

fn addSymbolAssumeCapacity(self: *Object) Symbol.Index {
    const index: Symbol.Index = @intCast(self.symbols.items.len);
    self.symbols.appendAssumeCapacity(.{ .file_index = self.index });
    return index;
}

pub fn addSymbolExtra(self: *Object, allocator: Allocator, extra: Symbol.Extra) !u32 {
    const fields = @typeInfo(Symbol.Extra).@"struct".fields;
    try self.symbols_extra.ensureUnusedCapacity(allocator, fields.len);
    return self.addSymbolExtraAssumeCapacity(extra);
}

pub fn addSymbolExtraAssumeCapacity(self: *Object, extra: Symbol.Extra) u32 {
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

pub fn symbolExtra(self: *Object, index: u32) Symbol.Extra {
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

pub fn asFile(self: *Object) File {
    return .{ .object = self };
}

pub fn getString(self: Object, off: u32) [:0]const u8 {
    assert(off < self.strtab.items.len);
    return mem.sliceTo(@as([*:0]const u8, @ptrCast(self.strtab.items.ptr + off)), 0);
}

fn addString(self: *Object, allocator: Allocator, str: []const u8) !u32 {
    const off: u32 = @intCast(self.strtab.items.len);
    try self.strtab.ensureUnusedCapacity(allocator, str.len + 1);
    self.strtab.appendSliceAssumeCapacity(str);
    self.strtab.appendAssumeCapacity(0);
    return off;
}

/// Caller owns the memory.
fn preadShdrContentsAlloc(self: Object, allocator: Allocator, handle: std.fs.File, index: u32) ![]u8 {
    assert(index < self.shdrs.items.len);
    const offset = if (self.archive) |ar| ar.offset else 0;
    const shdr = self.shdrs.items[index];
    const sh_offset = math.cast(u64, shdr.sh_offset) orelse return error.Overflow;
    const sh_size = math.cast(u64, shdr.sh_size) orelse return error.Overflow;
    return Elf.preadAllAlloc(allocator, handle, offset + sh_offset, sh_size);
}

/// Caller owns the memory.
fn preadRelocsAlloc(self: Object, allocator: Allocator, handle: std.fs.File, shndx: u32) ![]align(1) const elf.Elf64_Rela {
    const raw = try self.preadShdrContentsAlloc(allocator, handle, shndx);
    const num = @divExact(raw.len, @sizeOf(elf.Elf64_Rela));
    return @as([*]align(1) const elf.Elf64_Rela, @ptrCast(raw.ptr))[0..num];
}

const AddAtomArgs = struct {
    name: u32,
    shndx: u32,
    size: u64,
    alignment: Alignment,
};

fn addAtom(self: *Object, allocator: Allocator, args: AddAtomArgs) !Atom.Index {
    try self.atoms.ensureUnusedCapacity(allocator, 1);
    try self.atoms_extra.ensureUnusedCapacity(allocator, @sizeOf(Atom.Extra));
    return self.addAtomAssumeCapacity(args);
}

fn addAtomAssumeCapacity(self: *Object, args: AddAtomArgs) Atom.Index {
    const atom_index: Atom.Index = @intCast(self.atoms.items.len);
    const atom_ptr = self.atoms.addOneAssumeCapacity();
    atom_ptr.* = .{
        .atom_index = atom_index,
        .name_offset = args.name,
        .file_index = self.index,
        .input_section_index = args.shndx,
        .extra_index = self.addAtomExtraAssumeCapacity(.{}),
        .size = args.size,
        .alignment = args.alignment,
    };
    return atom_index;
}

pub fn atom(self: *Object, atom_index: Atom.Index) ?*Atom {
    if (atom_index == 0) return null;
    assert(atom_index < self.atoms.items.len);
    return &self.atoms.items[atom_index];
}

pub fn addAtomExtra(self: *Object, allocator: Allocator, extra: Atom.Extra) !u32 {
    const fields = @typeInfo(Atom.Extra).@"struct".fields;
    try self.atoms_extra.ensureUnusedCapacity(allocator, fields.len);
    return self.addAtomExtraAssumeCapacity(extra);
}

pub fn addAtomExtraAssumeCapacity(self: *Object, extra: Atom.Extra) u32 {
    const index: u32 = @intCast(self.atoms_extra.items.len);
    const fields = @typeInfo(Atom.Extra).@"struct".fields;
    inline for (fields) |field| {
        self.atoms_extra.appendAssumeCapacity(switch (field.type) {
            u32 => @field(extra, field.name),
            else => @compileError("bad field type"),
        });
    }
    return index;
}

pub fn atomExtra(self: *Object, index: u32) Atom.Extra {
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
    const fields = @typeInfo(Atom.Extra).@"struct".fields;
    inline for (fields, 0..) |field, i| {
        self.atoms_extra.items[index + i] = switch (field.type) {
            u32 => @field(extra, field.name),
            else => @compileError("bad field type"),
        };
    }
}

fn setAtomFields(o: *Object, atom_ptr: *Atom, opts: Atom.Extra.AsOptionals) void {
    assert(o.index == atom_ptr.file_index);
    var extras = o.atomExtra(atom_ptr.extra_index);
    inline for (@typeInfo(@TypeOf(opts)).@"struct".fields) |field| {
        if (@field(opts, field.name)) |x| @field(extras, field.name) = x;
    }
    o.setAtomExtra(atom_ptr.extra_index, extras);
}

fn addInputMergeSection(self: *Object, allocator: Allocator) !Merge.InputSection.Index {
    const index: Merge.InputSection.Index = @intCast(self.input_merge_sections.items.len);
    const msec = try self.input_merge_sections.addOne(allocator);
    msec.* = .{};
    return index;
}

fn inputMergeSection(self: *Object, index: Merge.InputSection.Index) ?*Merge.InputSection {
    if (index == 0) return null;
    return &self.input_merge_sections.items[index];
}

fn addComdatGroup(self: *Object, allocator: Allocator) !Elf.ComdatGroup.Index {
    const index = @as(Elf.ComdatGroup.Index, @intCast(self.comdat_groups.items.len));
    _ = try self.comdat_groups.addOne(allocator);
    return index;
}

pub fn comdatGroup(self: *Object, index: Elf.ComdatGroup.Index) *Elf.ComdatGroup {
    assert(index < self.comdat_groups.items.len);
    return &self.comdat_groups.items[index];
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
    const elf_file = ctx.elf_file;
    try writer.writeAll("  locals\n");
    for (object.locals()) |sym| {
        try writer.print("    {}\n", .{sym.fmt(elf_file)});
    }
    try writer.writeAll("  globals\n");
    for (object.globals(), 0..) |sym, i| {
        const first_global = object.first_global.?;
        const ref = object.resolveSymbol(@intCast(i + first_global), elf_file);
        if (elf_file.symbol(ref)) |ref_sym| {
            try writer.print("    {}\n", .{ref_sym.fmt(elf_file)});
        } else {
            try writer.print("    {s} : unclaimed\n", .{sym.name(elf_file)});
        }
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
    for (object.atoms_indexes.items) |atom_index| {
        const atom_ptr = object.atom(atom_index) orelse continue;
        try writer.print("    {}\n", .{atom_ptr.fmt(ctx.elf_file)});
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
    for (object.comdat_groups.items, 0..) |cg, cg_index| {
        try writer.print("    COMDAT({d})", .{cg_index});
        if (!cg.alive) try writer.writeAll(" : [*]");
        try writer.writeByte('\n');
        const cg_members = cg.comdatGroupMembers(elf_file);
        for (cg_members) |shndx| {
            const atom_index = object.atoms_indexes.items[shndx];
            const atom_ptr = object.atom(atom_index) orelse continue;
            try writer.print("      atom({d}) : {s}\n", .{ atom_index, atom_ptr.name(elf_file) });
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
    if (object.archive) |ar| {
        try writer.print("{}({})", .{ ar.path, object.path });
    } else {
        try writer.print("{}", .{object.path});
    }
}

const InArchive = struct {
    path: Path,
    offset: u64,
    size: u32,
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
const Path = std.Build.Cache.Path;
const Allocator = mem.Allocator;

const Archive = @import("Archive.zig");
const Atom = @import("Atom.zig");
const AtomList = @import("AtomList.zig");
const Cie = eh_frame.Cie;
const Elf = @import("../Elf.zig");
const Fde = eh_frame.Fde;
const File = @import("file.zig").File;
const Merge = @import("Merge.zig");
const Symbol = @import("Symbol.zig");
const Alignment = Atom.Alignment;
