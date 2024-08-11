//! ZigObject encapsulates the state of the incrementally compiled Zig module.
//! It stores the associated input local and global symbols, allocated atoms,
//! and any relocations that may have been emitted.
//! Think about this as fake in-memory Object file for the Zig module.

data: std.ArrayListUnmanaged(u8) = .{},
/// Externally owned memory.
path: []const u8,
index: File.Index,

symtab: std.MultiArrayList(ElfSym) = .{},
strtab: StringTable = .{},
symbols: std.ArrayListUnmanaged(Symbol) = .{},
symbols_extra: std.ArrayListUnmanaged(u32) = .{},
symbols_resolver: std.ArrayListUnmanaged(Elf.SymbolResolver.Index) = .{},
local_symbols: std.ArrayListUnmanaged(Symbol.Index) = .{},
global_symbols: std.ArrayListUnmanaged(Symbol.Index) = .{},
globals_lookup: std.AutoHashMapUnmanaged(u32, Symbol.Index) = .{},

atoms: std.ArrayListUnmanaged(Atom) = .{},
atoms_indexes: std.ArrayListUnmanaged(Atom.Index) = .{},
atoms_extra: std.ArrayListUnmanaged(u32) = .{},
relocs: std.ArrayListUnmanaged(std.ArrayListUnmanaged(elf.Elf64_Rela)) = .{},

num_dynrelocs: u32 = 0,

output_symtab_ctx: Elf.SymtabCtx = .{},
output_ar_state: Archive.ArState = .{},

dwarf: ?Dwarf = null,

/// Table of tracked LazySymbols.
lazy_syms: LazySymbolTable = .{},

/// Table of tracked Decls.
decls: DeclTable = .{},

/// TLS variables indexed by Atom.Index.
tls_variables: TlsTable = .{},

/// Table of unnamed constants associated with a parent `Decl`.
/// We store them here so that we can free the constants whenever the `Decl`
/// needs updating or is freed.
///
/// For example,
///
/// ```zig
/// const Foo = struct{
///     a: u8,
/// };
///
/// pub fn main() void {
///     var foo = Foo{ .a = 1 };
///     _ = foo;
/// }
/// ```
///
/// value assigned to label `foo` is an unnamed constant belonging/associated
/// with `Decl` `main`, and lives as long as that `Decl`.
unnamed_consts: UnnamedConstTable = .{},

/// Table of tracked AnonDecls.
anon_decls: AnonDeclTable = .{},

debug_strtab_dirty: bool = false,
debug_abbrev_section_dirty: bool = false,
debug_aranges_section_dirty: bool = false,
debug_info_header_dirty: bool = false,
debug_line_header_dirty: bool = false,

/// Size contribution of Zig's metadata to each debug section.
/// Used to track start of metadata from input object files.
debug_info_section_zig_size: u64 = 0,
debug_abbrev_section_zig_size: u64 = 0,
debug_str_section_zig_size: u64 = 0,
debug_aranges_section_zig_size: u64 = 0,
debug_line_section_zig_size: u64 = 0,

pub const global_symbol_bit: u32 = 0x80000000;
pub const symbol_mask: u32 = 0x7fffffff;
pub const SHN_ATOM: u16 = 0x100;

pub fn init(self: *ZigObject, elf_file: *Elf) !void {
    const comp = elf_file.base.comp;
    const gpa = comp.gpa;

    try self.atoms.append(gpa, .{ .extra_index = try self.addAtomExtra(gpa, .{}) }); // null input section
    try self.relocs.append(gpa, .{}); // null relocs section
    try self.strtab.buffer.append(gpa, 0);

    const name_off = try self.strtab.insert(gpa, self.path);
    const symbol_index = try self.newLocalSymbol(gpa, name_off);
    const sym = self.symbol(symbol_index);
    const esym = &self.symtab.items(.elf_sym)[sym.esym_index];
    esym.st_info = elf.STT_FILE;
    esym.st_shndx = elf.SHN_ABS;

    switch (comp.config.debug_format) {
        .strip => {},
        .dwarf => |v| {
            assert(v == .@"32");
            self.dwarf = Dwarf.init(&elf_file.base, .dwarf32);
        },
        .code_view => unreachable,
    }
}

pub fn deinit(self: *ZigObject, allocator: Allocator) void {
    self.data.deinit(allocator);
    self.symtab.deinit(allocator);
    self.strtab.deinit(allocator);
    self.symbols.deinit(allocator);
    self.symbols_extra.deinit(allocator);
    self.symbols_resolver.deinit(allocator);
    self.local_symbols.deinit(allocator);
    self.global_symbols.deinit(allocator);
    self.globals_lookup.deinit(allocator);
    self.atoms.deinit(allocator);
    self.atoms_indexes.deinit(allocator);
    self.atoms_extra.deinit(allocator);
    for (self.relocs.items) |*list| {
        list.deinit(allocator);
    }
    self.relocs.deinit(allocator);

    {
        var it = self.decls.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.exports.deinit(allocator);
        }
        self.decls.deinit(allocator);
    }

    self.lazy_syms.deinit(allocator);

    {
        var it = self.unnamed_consts.valueIterator();
        while (it.next()) |syms| {
            syms.deinit(allocator);
        }
        self.unnamed_consts.deinit(allocator);
    }

    {
        var it = self.anon_decls.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.exports.deinit(allocator);
        }
        self.anon_decls.deinit(allocator);
    }

    for (self.tls_variables.values()) |*tlv| {
        tlv.deinit(allocator);
    }
    self.tls_variables.deinit(allocator);

    if (self.dwarf) |*dw| {
        dw.deinit();
    }
}

pub fn flushModule(self: *ZigObject, elf_file: *Elf, tid: Zcu.PerThread.Id) !void {
    // Handle any lazy symbols that were emitted by incremental compilation.
    if (self.lazy_syms.getPtr(.none)) |metadata| {
        const pt: Zcu.PerThread = .{ .zcu = elf_file.base.comp.module.?, .tid = tid };

        // Most lazy symbols can be updated on first use, but
        // anyerror needs to wait for everything to be flushed.
        if (metadata.text_state != .unused) self.updateLazySymbol(
            elf_file,
            pt,
            link.File.LazySymbol.initDecl(.code, null, pt.zcu),
            metadata.text_symbol_index,
        ) catch |err| return switch (err) {
            error.CodegenFail => error.FlushFailure,
            else => |e| e,
        };
        if (metadata.rodata_state != .unused) self.updateLazySymbol(
            elf_file,
            pt,
            link.File.LazySymbol.initDecl(.const_data, null, pt.zcu),
            metadata.rodata_symbol_index,
        ) catch |err| return switch (err) {
            error.CodegenFail => error.FlushFailure,
            else => |e| e,
        };
    }
    for (self.lazy_syms.values()) |*metadata| {
        if (metadata.text_state != .unused) metadata.text_state = .flushed;
        if (metadata.rodata_state != .unused) metadata.rodata_state = .flushed;
    }

    if (self.dwarf) |*dw| {
        const pt: Zcu.PerThread = .{ .zcu = elf_file.base.comp.module.?, .tid = tid };
        try dw.flushModule(pt);

        // TODO I need to re-think how to handle ZigObject's debug sections AND debug sections
        // extracted from input object files correctly.
        if (self.debug_abbrev_section_dirty) {
            try dw.writeDbgAbbrev();
            self.debug_abbrev_section_dirty = false;
        }

        if (self.debug_info_header_dirty) {
            const text_shdr = elf_file.shdrs.items[elf_file.zig_text_section_index.?];
            const low_pc = text_shdr.sh_addr;
            const high_pc = text_shdr.sh_addr + text_shdr.sh_size;
            try dw.writeDbgInfoHeader(pt.zcu, low_pc, high_pc);
            self.debug_info_header_dirty = false;
        }

        if (self.debug_aranges_section_dirty) {
            const text_shdr = elf_file.shdrs.items[elf_file.zig_text_section_index.?];
            try dw.writeDbgAranges(text_shdr.sh_addr, text_shdr.sh_size);
            self.debug_aranges_section_dirty = false;
        }

        if (self.debug_line_header_dirty) {
            try dw.writeDbgLineHeader();
            self.debug_line_header_dirty = false;
        }

        if (elf_file.debug_str_section_index) |shndx| {
            if (self.debug_strtab_dirty or dw.strtab.buffer.items.len != elf_file.shdrs.items[shndx].sh_size) {
                try elf_file.growNonAllocSection(shndx, dw.strtab.buffer.items.len, 1, false);
                const shdr = elf_file.shdrs.items[shndx];
                try elf_file.base.file.?.pwriteAll(dw.strtab.buffer.items, shdr.sh_offset);
                self.debug_strtab_dirty = false;
            }
        }

        self.saveDebugSectionsSizes(elf_file);
    }

    // The point of flushModule() is to commit changes, so in theory, nothing should
    // be dirty after this. However, it is possible for some things to remain
    // dirty because they fail to be written in the event of compile errors,
    // such as debug_line_header_dirty and debug_info_header_dirty.
    assert(!self.debug_abbrev_section_dirty);
    assert(!self.debug_aranges_section_dirty);
    assert(!self.debug_strtab_dirty);
}

fn saveDebugSectionsSizes(self: *ZigObject, elf_file: *Elf) void {
    if (elf_file.debug_info_section_index) |shndx| {
        self.debug_info_section_zig_size = elf_file.shdrs.items[shndx].sh_size;
    }
    if (elf_file.debug_abbrev_section_index) |shndx| {
        self.debug_abbrev_section_zig_size = elf_file.shdrs.items[shndx].sh_size;
    }
    if (elf_file.debug_str_section_index) |shndx| {
        self.debug_str_section_zig_size = elf_file.shdrs.items[shndx].sh_size;
    }
    if (elf_file.debug_aranges_section_index) |shndx| {
        self.debug_aranges_section_zig_size = elf_file.shdrs.items[shndx].sh_size;
    }
    if (elf_file.debug_line_section_index) |shndx| {
        self.debug_line_section_zig_size = elf_file.shdrs.items[shndx].sh_size;
    }
}

fn newSymbol(self: *ZigObject, allocator: Allocator, name_off: u32, st_bind: u4) !Symbol.Index {
    try self.symtab.ensureUnusedCapacity(allocator, 1);
    try self.symbols.ensureUnusedCapacity(allocator, 1);
    try self.symbols_extra.ensureUnusedCapacity(allocator, @sizeOf(Symbol.Extra));

    const index = self.addSymbolAssumeCapacity();
    const sym = &self.symbols.items[index];
    sym.name_offset = name_off;
    sym.extra_index = self.addSymbolExtraAssumeCapacity(.{});

    const esym_idx: u32 = @intCast(self.symtab.addOneAssumeCapacity());
    const esym = ElfSym{ .elf_sym = .{
        .st_value = 0,
        .st_name = name_off,
        .st_info = @as(u8, @intCast(st_bind)) << 4,
        .st_other = 0,
        .st_size = 0,
        .st_shndx = 0,
    } };
    self.symtab.set(index, esym);
    sym.esym_index = esym_idx;

    return index;
}

fn newLocalSymbol(self: *ZigObject, allocator: Allocator, name_off: u32) !Symbol.Index {
    try self.local_symbols.ensureUnusedCapacity(allocator, 1);
    const fake_index: Symbol.Index = @intCast(self.local_symbols.items.len);
    const index = try self.newSymbol(allocator, name_off, elf.STB_LOCAL);
    self.local_symbols.appendAssumeCapacity(index);
    return fake_index;
}

fn newGlobalSymbol(self: *ZigObject, allocator: Allocator, name_off: u32) !Symbol.Index {
    try self.global_symbols.ensureUnusedCapacity(allocator, 1);
    try self.symbols_resolver.ensureUnusedCapacity(allocator, 1);
    const fake_index: Symbol.Index = @intCast(self.global_symbols.items.len);
    const index = try self.newSymbol(allocator, name_off, elf.STB_GLOBAL);
    self.global_symbols.appendAssumeCapacity(index);
    self.symbols_resolver.addOneAssumeCapacity().* = 0;
    return fake_index | global_symbol_bit;
}

fn newAtom(self: *ZigObject, allocator: Allocator, name_off: u32) !Atom.Index {
    try self.atoms.ensureUnusedCapacity(allocator, 1);
    try self.atoms_extra.ensureUnusedCapacity(allocator, @sizeOf(Atom.Extra));
    try self.atoms_indexes.ensureUnusedCapacity(allocator, 1);
    try self.relocs.ensureUnusedCapacity(allocator, 1);

    const index = self.addAtomAssumeCapacity();
    self.atoms_indexes.appendAssumeCapacity(index);
    const atom_ptr = self.atom(index).?;
    atom_ptr.name_offset = name_off;

    const relocs_index: u32 = @intCast(self.relocs.items.len);
    self.relocs.addOneAssumeCapacity().* = .{};
    atom_ptr.relocs_section_index = relocs_index;

    return index;
}

fn newSymbolWithAtom(self: *ZigObject, allocator: Allocator, name_off: u32) !Symbol.Index {
    const atom_index = try self.newAtom(allocator, name_off);
    const sym_index = try self.newLocalSymbol(allocator, name_off);
    const sym = self.symbol(sym_index);
    sym.ref = .{ .index = atom_index, .file = self.index };
    self.symtab.items(.shndx)[sym.esym_index] = atom_index;
    self.symtab.items(.elf_sym)[sym.esym_index].st_shndx = SHN_ATOM;
    return sym_index;
}

/// TODO actually create fake input shdrs and return that instead.
pub fn inputShdr(self: *ZigObject, atom_index: Atom.Index, elf_file: *Elf) elf.Elf64_Shdr {
    const atom_ptr = self.atom(atom_index) orelse return Elf.null_shdr;
    const shndx = atom_ptr.output_section_index;
    var shdr = elf_file.shdrs.items[shndx];
    shdr.sh_addr = 0;
    shdr.sh_offset = 0;
    shdr.sh_size = atom_ptr.size;
    shdr.sh_addralign = atom_ptr.alignment.toByteUnits() orelse 1;
    return shdr;
}

pub fn resolveSymbols(self: *ZigObject, elf_file: *Elf) !void {
    const gpa = elf_file.base.comp.gpa;

    for (self.global_symbols.items, 0..) |index, i| {
        const global = &self.symbols.items[index];
        const esym = global.elfSym(elf_file);
        const shndx = self.symtab.items(.shndx)[global.esym_index];
        if (esym.st_shndx != elf.SHN_ABS and esym.st_shndx != elf.SHN_COMMON and esym.st_shndx != elf.SHN_UNDEF) {
            assert(esym.st_shndx == SHN_ATOM);
            const atom_ptr = self.atom(shndx) orelse continue;
            if (!atom_ptr.alive) continue;
        }

        const resolv = &self.symbols_resolver.items[i];
        const gop = try elf_file.resolver.getOrPut(gpa, .{
            .index = @intCast(i | global_symbol_bit),
            .file = self.index,
        }, elf_file);
        if (!gop.found_existing) {
            gop.ref.* = .{ .index = 0, .file = 0 };
        }
        resolv.* = gop.index;

        if (esym.st_shndx == elf.SHN_UNDEF) continue;
        if (elf_file.symbol(gop.ref.*) == null) {
            gop.ref.* = .{ .index = @intCast(i | global_symbol_bit), .file = self.index };
            continue;
        }

        if (self.asFile().symbolRank(esym, false) < elf_file.symbol(gop.ref.*).?.symbolRank(elf_file)) {
            gop.ref.* = .{ .index = @intCast(i | global_symbol_bit), .file = self.index };
        }
    }
}

pub fn claimUnresolved(self: *ZigObject, elf_file: *Elf) void {
    for (self.global_symbols.items, 0..) |index, i| {
        const global = &self.symbols.items[index];
        const esym = self.symtab.items(.elf_sym)[index];
        if (esym.st_shndx != elf.SHN_UNDEF) continue;
        if (elf_file.symbol(self.resolveSymbol(@intCast(i | global_symbol_bit), elf_file)) != null) continue;

        const is_import = blk: {
            if (!elf_file.isEffectivelyDynLib()) break :blk false;
            const vis = @as(elf.STV, @enumFromInt(esym.st_other));
            if (vis == .HIDDEN) break :blk false;
            break :blk true;
        };

        global.value = 0;
        global.ref = .{ .index = 0, .file = 0 };
        global.esym_index = @intCast(index);
        global.file_index = self.index;
        global.version_index = if (is_import) elf.VER_NDX_LOCAL else elf_file.default_sym_version;
        global.flags.import = is_import;

        const idx = self.symbols_resolver.items[i];
        elf_file.resolver.values.items[idx - 1] = .{ .index = @intCast(i | global_symbol_bit), .file = self.index };
    }
}

pub fn claimUnresolvedObject(self: ZigObject, elf_file: *Elf) void {
    for (self.global_symbols.items, 0..) |index, i| {
        const global = &self.symbols.items[index];
        const esym = self.symtab.items(.elf_sym)[index];
        if (esym.st_shndx != elf.SHN_UNDEF) continue;
        if (elf_file.symbol(self.resolveSymbol(@intCast(i | global_symbol_bit), elf_file)) != null) continue;

        global.value = 0;
        global.ref = .{ .index = 0, .file = 0 };
        global.esym_index = @intCast(index);
        global.file_index = self.index;

        const idx = self.symbols_resolver.items[i];
        elf_file.resolver.values.items[idx - 1] = .{ .index = @intCast(i | global_symbol_bit), .file = self.index };
    }
}

pub fn scanRelocs(self: *ZigObject, elf_file: *Elf, undefs: anytype) !void {
    const gpa = elf_file.base.comp.gpa;
    for (self.atoms_indexes.items) |atom_index| {
        const atom_ptr = self.atom(atom_index) orelse continue;
        if (!atom_ptr.alive) continue;
        const shdr = atom_ptr.inputShdr(elf_file);
        if (shdr.sh_type == elf.SHT_NOBITS) continue;
        if (atom_ptr.scanRelocsRequiresCode(elf_file)) {
            // TODO ideally we don't have to fetch the code here.
            // Perhaps it would make sense to save the code until flushModule where we
            // would free all of generated code?
            const code = try self.codeAlloc(elf_file, atom_index);
            defer gpa.free(code);
            try atom_ptr.scanRelocs(elf_file, code, undefs);
        } else try atom_ptr.scanRelocs(elf_file, null, undefs);
    }
}

pub fn markLive(self: *ZigObject, elf_file: *Elf) void {
    for (self.global_symbols.items, 0..) |index, i| {
        const global = self.symbols.items[index];
        const esym = self.symtab.items(.elf_sym)[index];
        if (esym.st_bind() == elf.STB_WEAK) continue;

        const ref = self.resolveSymbol(@intCast(i | global_symbol_bit), elf_file);
        const sym = elf_file.symbol(ref) orelse continue;
        const file = sym.file(elf_file).?;
        const should_keep = esym.st_shndx == elf.SHN_UNDEF or
            (esym.st_shndx == elf.SHN_COMMON and global.elfSym(elf_file).st_shndx != elf.SHN_COMMON);
        if (should_keep and !file.isAlive()) {
            file.setAlive();
            file.markLive(elf_file);
        }
    }
}

pub fn markImportsExports(self: *ZigObject, elf_file: *Elf) void {
    for (0..self.global_symbols.items.len) |i| {
        const ref = self.resolveSymbol(@intCast(i | global_symbol_bit), elf_file);
        const sym = elf_file.symbol(ref) orelse continue;
        const file = sym.file(elf_file).?;
        if (sym.version_index == elf.VER_NDX_LOCAL) continue;
        const vis = @as(elf.STV, @enumFromInt(sym.elfSym(elf_file).st_other));
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

pub fn checkDuplicates(self: *ZigObject, dupes: anytype, elf_file: *Elf) error{OutOfMemory}!void {
    for (self.global_symbols.items, 0..) |index, i| {
        const esym = self.symtab.items(.elf_sym)[index];
        const shndx = self.symtab.items(.shndx)[index];
        const ref = self.resolveSymbol(@intCast(i | global_symbol_bit), elf_file);
        const ref_sym = elf_file.symbol(ref) orelse continue;
        const ref_file = ref_sym.file(elf_file).?;

        if (self.index == ref_file.index() or
            esym.st_shndx == elf.SHN_UNDEF or
            esym.st_bind() == elf.STB_WEAK or
            esym.st_shndx == elf.SHN_COMMON) continue;

        if (esym.st_shndx == SHN_ATOM) {
            const atom_ptr = self.atom(shndx) orelse continue;
            if (!atom_ptr.alive) continue;
        }

        const gop = try dupes.getOrPut(self.symbols_resolver.items[i]);
        if (!gop.found_existing) {
            gop.value_ptr.* = .{};
        }
        try gop.value_ptr.append(elf_file.base.comp.gpa, self.index);
    }
}

/// This is just a temporary helper function that allows us to re-read what we wrote to file into a buffer.
/// We need this so that we can write to an archive.
/// TODO implement writing ZigObject data directly to a buffer instead.
pub fn readFileContents(self: *ZigObject, elf_file: *Elf) !void {
    const gpa = elf_file.base.comp.gpa;
    const shsize: u64 = switch (elf_file.ptr_width) {
        .p32 => @sizeOf(elf.Elf32_Shdr),
        .p64 => @sizeOf(elf.Elf64_Shdr),
    };
    var end_pos: u64 = elf_file.shdr_table_offset.? + elf_file.shdrs.items.len * shsize;
    for (elf_file.shdrs.items) |shdr| {
        if (shdr.sh_type == elf.SHT_NOBITS) continue;
        end_pos = @max(end_pos, shdr.sh_offset + shdr.sh_size);
    }
    const size = std.math.cast(usize, end_pos) orelse return error.Overflow;
    try self.data.resize(gpa, size);

    const amt = try elf_file.base.file.?.preadAll(self.data.items, 0);
    if (amt != size) return error.InputOutput;
}

pub fn updateArSymtab(self: ZigObject, ar_symtab: *Archive.ArSymtab, elf_file: *Elf) error{OutOfMemory}!void {
    const gpa = elf_file.base.comp.gpa;

    try ar_symtab.symtab.ensureUnusedCapacity(gpa, self.global_symbols.items.len);

    for (self.global_symbols.items, 0..) |index, i| {
        const global = self.symbols.items[index];
        const ref = self.resolveSymbol(@intCast(i | global_symbol_bit), elf_file);
        const sym = elf_file.symbol(ref).?;
        assert(sym.file(elf_file).?.index() == self.index);
        if (global.outputShndx(elf_file) == null) continue;

        const off = try ar_symtab.strtab.insert(gpa, global.name(elf_file));
        ar_symtab.symtab.appendAssumeCapacity(.{ .off = off, .file_index = self.index });
    }
}

pub fn updateArSize(self: *ZigObject) void {
    self.output_ar_state.size = self.data.items.len;
}

pub fn writeAr(self: ZigObject, writer: anytype) !void {
    const name = self.path;
    const hdr = Archive.setArHdr(.{
        .name = if (name.len <= Archive.max_member_name_len)
            .{ .name = name }
        else
            .{ .name_off = self.output_ar_state.name_off },
        .size = self.data.items.len,
    });
    try writer.writeAll(mem.asBytes(&hdr));
    try writer.writeAll(self.data.items);
}

pub fn addAtomsToRelaSections(self: *ZigObject, elf_file: *Elf) !void {
    for (self.atoms_indexes.items) |atom_index| {
        const atom_ptr = self.atom(atom_index) orelse continue;
        if (!atom_ptr.alive) continue;
        const rela_shndx = atom_ptr.relocsShndx() orelse continue;
        // TODO this check will become obsolete when we rework our relocs mechanism at the ZigObject level
        if (self.relocs.items[rela_shndx].items.len == 0) continue;
        const out_shndx = atom_ptr.output_section_index;
        const out_shdr = elf_file.shdrs.items[out_shndx];
        if (out_shdr.sh_type == elf.SHT_NOBITS) continue;

        const gpa = elf_file.base.comp.gpa;
        const sec = elf_file.output_rela_sections.getPtr(out_shndx).?;
        try sec.atom_list.append(gpa, .{ .index = atom_index, .file = self.index });
    }
}

pub fn updateSymtabSize(self: *ZigObject, elf_file: *Elf) !void {
    for (self.local_symbols.items) |index| {
        const local = &self.symbols.items[index];
        if (local.atom(elf_file)) |atom_ptr| if (!atom_ptr.alive) continue;
        const name = local.name(elf_file);
        assert(name.len > 0);
        const esym = local.elfSym(elf_file);
        switch (esym.st_type()) {
            elf.STT_SECTION, elf.STT_NOTYPE => continue,
            else => {},
        }
        local.flags.output_symtab = true;
        local.addExtra(.{ .symtab = self.output_symtab_ctx.nlocals }, elf_file);
        self.output_symtab_ctx.nlocals += 1;
        self.output_symtab_ctx.strsize += @as(u32, @intCast(name.len)) + 1;
    }

    for (self.global_symbols.items, self.symbols_resolver.items) |index, resolv| {
        const global = &self.symbols.items[index];
        const ref = elf_file.resolver.values.items[resolv - 1];
        const ref_sym = elf_file.symbol(ref) orelse continue;
        if (ref_sym.file(elf_file).?.index() != self.index) continue;
        if (global.atom(elf_file)) |atom_ptr| if (!atom_ptr.alive) continue;
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

pub fn writeSymtab(self: ZigObject, elf_file: *Elf) void {
    for (self.local_symbols.items) |index| {
        const local = &self.symbols.items[index];
        const idx = local.outputSymtabIndex(elf_file) orelse continue;
        const out_sym = &elf_file.symtab.items[idx];
        out_sym.st_name = @intCast(elf_file.strtab.items.len);
        elf_file.strtab.appendSliceAssumeCapacity(local.name(elf_file));
        elf_file.strtab.appendAssumeCapacity(0);
        local.setOutputSym(elf_file, out_sym);
    }

    for (self.global_symbols.items, self.symbols_resolver.items) |index, resolv| {
        const global = self.symbols.items[index];
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

/// Returns atom's code.
/// Caller owns the memory.
pub fn codeAlloc(self: *ZigObject, elf_file: *Elf, atom_index: Atom.Index) ![]u8 {
    const gpa = elf_file.base.comp.gpa;
    const atom_ptr = self.atom(atom_index).?;
    const shdr = &elf_file.shdrs.items[atom_ptr.output_section_index];

    if (shdr.sh_flags & elf.SHF_TLS != 0) {
        const tlv = self.tls_variables.get(atom_index).?;
        const code = try gpa.dupe(u8, tlv.code);
        return code;
    }

    const file_offset = shdr.sh_offset + @as(u64, @intCast(atom_ptr.value));
    const size = std.math.cast(usize, atom_ptr.size) orelse return error.Overflow;
    const code = try gpa.alloc(u8, size);
    errdefer gpa.free(code);
    const amt = try elf_file.base.file.?.preadAll(code, file_offset);
    if (amt != code.len) {
        log.err("fetching code for {s} failed", .{atom_ptr.name(elf_file)});
        return error.InputOutput;
    }
    return code;
}

pub fn getDeclVAddr(
    self: *ZigObject,
    elf_file: *Elf,
    pt: Zcu.PerThread,
    decl_index: InternPool.DeclIndex,
    reloc_info: link.File.RelocInfo,
) !u64 {
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const decl = zcu.declPtr(decl_index);
    log.debug("getDeclVAddr {}({d})", .{ decl.fqn.fmt(ip), decl_index });
    const this_sym_index = if (decl.isExtern(zcu)) blk: {
        const name = decl.name.toSlice(ip);
        const lib_name = if (decl.getOwnedExternFunc(zcu)) |ext_fn|
            ext_fn.lib_name.toSlice(ip)
        else
            decl.getOwnedVariable(zcu).?.lib_name.toSlice(ip);
        break :blk try self.getGlobalSymbol(elf_file, name, lib_name);
    } else try self.getOrCreateMetadataForDecl(elf_file, decl_index);
    const this_sym = self.symbol(this_sym_index);
    const vaddr = this_sym.address(.{}, elf_file);
    const parent_atom = self.symbol(reloc_info.parent_atom_index).atom(elf_file).?;
    const r_type = relocation.encode(.abs, elf_file.getTarget().cpu.arch);
    try parent_atom.addReloc(elf_file, .{
        .r_offset = reloc_info.offset,
        .r_info = (@as(u64, @intCast(this_sym_index)) << 32) | r_type,
        .r_addend = reloc_info.addend,
    });
    return @intCast(vaddr);
}

pub fn getAnonDeclVAddr(
    self: *ZigObject,
    elf_file: *Elf,
    decl_val: InternPool.Index,
    reloc_info: link.File.RelocInfo,
) !u64 {
    const sym_index = self.anon_decls.get(decl_val).?.symbol_index;
    const sym = self.symbol(sym_index);
    const vaddr = sym.address(.{}, elf_file);
    const parent_atom = self.symbol(reloc_info.parent_atom_index).atom(elf_file).?;
    const r_type = relocation.encode(.abs, elf_file.getTarget().cpu.arch);
    try parent_atom.addReloc(elf_file, .{
        .r_offset = reloc_info.offset,
        .r_info = (@as(u64, @intCast(sym_index)) << 32) | r_type,
        .r_addend = reloc_info.addend,
    });
    return @intCast(vaddr);
}

pub fn lowerAnonDecl(
    self: *ZigObject,
    elf_file: *Elf,
    pt: Zcu.PerThread,
    decl_val: InternPool.Index,
    explicit_alignment: InternPool.Alignment,
    src_loc: Module.LazySrcLoc,
) !codegen.Result {
    const gpa = elf_file.base.comp.gpa;
    const mod = elf_file.base.comp.module.?;
    const ty = Type.fromInterned(mod.intern_pool.typeOf(decl_val));
    const decl_alignment = switch (explicit_alignment) {
        .none => ty.abiAlignment(pt),
        else => explicit_alignment,
    };
    if (self.anon_decls.get(decl_val)) |metadata| {
        const existing_alignment = self.symbol(metadata.symbol_index).atom(elf_file).?.alignment;
        if (decl_alignment.order(existing_alignment).compare(.lte))
            return .ok;
    }

    const val = Value.fromInterned(decl_val);
    var name_buf: [32]u8 = undefined;
    const name = std.fmt.bufPrint(&name_buf, "__anon_{d}", .{
        @intFromEnum(decl_val),
    }) catch unreachable;
    const res = self.lowerConst(
        elf_file,
        pt,
        name,
        val,
        decl_alignment,
        elf_file.zig_data_rel_ro_section_index.?,
        src_loc,
    ) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => |e| return .{ .fail = try Module.ErrorMsg.create(
            gpa,
            src_loc,
            "unable to lower constant value: {s}",
            .{@errorName(e)},
        ) },
    };
    const sym_index = switch (res) {
        .ok => |sym_index| sym_index,
        .fail => |em| return .{ .fail = em },
    };
    try self.anon_decls.put(gpa, decl_val, .{ .symbol_index = sym_index });
    return .ok;
}

pub fn getOrCreateMetadataForLazySymbol(
    self: *ZigObject,
    elf_file: *Elf,
    pt: Zcu.PerThread,
    lazy_sym: link.File.LazySymbol,
) !Symbol.Index {
    const mod = pt.zcu;
    const gpa = mod.gpa;
    const gop = try self.lazy_syms.getOrPut(gpa, lazy_sym.getDecl(mod));
    errdefer _ = if (!gop.found_existing) self.lazy_syms.pop();
    if (!gop.found_existing) gop.value_ptr.* = .{};
    const metadata: struct {
        symbol_index: *Symbol.Index,
        state: *LazySymbolMetadata.State,
    } = switch (lazy_sym.kind) {
        .code => .{
            .symbol_index = &gop.value_ptr.text_symbol_index,
            .state = &gop.value_ptr.text_state,
        },
        .const_data => .{
            .symbol_index = &gop.value_ptr.rodata_symbol_index,
            .state = &gop.value_ptr.rodata_state,
        },
    };
    switch (metadata.state.*) {
        .unused => {
            const symbol_index = try self.newSymbolWithAtom(gpa, 0);
            const sym = self.symbol(symbol_index);
            sym.flags.needs_zig_got = true;
            metadata.symbol_index.* = symbol_index;
        },
        .pending_flush => return metadata.symbol_index.*,
        .flushed => {},
    }
    metadata.state.* = .pending_flush;
    const symbol_index = metadata.symbol_index.*;
    // anyerror needs to be deferred until flushModule
    if (lazy_sym.getDecl(mod) != .none) try self.updateLazySymbol(elf_file, pt, lazy_sym, symbol_index);
    return symbol_index;
}

fn freeUnnamedConsts(self: *ZigObject, elf_file: *Elf, decl_index: InternPool.DeclIndex) void {
    const gpa = elf_file.base.comp.gpa;
    const unnamed_consts = self.unnamed_consts.getPtr(decl_index) orelse return;
    for (unnamed_consts.items) |sym_index| {
        self.freeDeclMetadata(elf_file, sym_index);
    }
    unnamed_consts.clearAndFree(gpa);
}

fn freeDeclMetadata(self: *ZigObject, elf_file: *Elf, sym_index: Symbol.Index) void {
    const sym = self.symbol(sym_index);
    sym.atom(elf_file).?.free(elf_file);
    log.debug("adding %{d} to local symbols free list", .{sym_index});
    self.symbols.items[sym_index] = .{};
    // TODO free GOT entry here
}

pub fn freeDecl(self: *ZigObject, elf_file: *Elf, decl_index: InternPool.DeclIndex) void {
    const gpa = elf_file.base.comp.gpa;

    log.debug("freeDecl ({d})", .{decl_index});

    if (self.decls.fetchRemove(decl_index)) |const_kv| {
        var kv = const_kv;
        const sym_index = kv.value.symbol_index;
        self.freeDeclMetadata(elf_file, sym_index);
        self.freeUnnamedConsts(elf_file, decl_index);
        kv.value.exports.deinit(gpa);
    }

    if (self.dwarf) |*dw| {
        dw.freeDecl(decl_index);
    }
}

pub fn getOrCreateMetadataForDecl(
    self: *ZigObject,
    elf_file: *Elf,
    decl_index: InternPool.DeclIndex,
) !Symbol.Index {
    const gpa = elf_file.base.comp.gpa;
    const gop = try self.decls.getOrPut(gpa, decl_index);
    if (!gop.found_existing) {
        const any_non_single_threaded = elf_file.base.comp.config.any_non_single_threaded;
        const symbol_index = try self.newSymbolWithAtom(gpa, 0);
        const mod = elf_file.base.comp.module.?;
        const decl = mod.declPtr(decl_index);
        const sym = self.symbol(symbol_index);
        if (decl.getOwnedVariable(mod)) |variable| {
            if (variable.is_threadlocal and any_non_single_threaded) {
                sym.flags.is_tls = true;
            }
        }
        if (!sym.flags.is_tls) {
            sym.flags.needs_zig_got = true;
        }
        gop.value_ptr.* = .{ .symbol_index = symbol_index };
    }
    return gop.value_ptr.symbol_index;
}

fn getDeclShdrIndex(
    self: *ZigObject,
    elf_file: *Elf,
    decl: *const Module.Decl,
    code: []const u8,
) error{OutOfMemory}!u32 {
    _ = self;
    const mod = elf_file.base.comp.module.?;
    const any_non_single_threaded = elf_file.base.comp.config.any_non_single_threaded;
    const shdr_index = switch (decl.typeOf(mod).zigTypeTag(mod)) {
        .Fn => elf_file.zig_text_section_index.?,
        else => blk: {
            if (decl.getOwnedVariable(mod)) |variable| {
                if (variable.is_threadlocal and any_non_single_threaded) {
                    const is_all_zeroes = for (code) |byte| {
                        if (byte != 0) break false;
                    } else true;
                    if (is_all_zeroes) break :blk elf_file.sectionByName(".tbss") orelse try elf_file.addSection(.{
                        .type = elf.SHT_NOBITS,
                        .flags = elf.SHF_ALLOC | elf.SHF_WRITE | elf.SHF_TLS,
                        .name = try elf_file.insertShString(".tbss"),
                        .offset = std.math.maxInt(u64),
                    });

                    break :blk elf_file.sectionByName(".tdata") orelse try elf_file.addSection(.{
                        .type = elf.SHT_PROGBITS,
                        .flags = elf.SHF_ALLOC | elf.SHF_WRITE | elf.SHF_TLS,
                        .name = try elf_file.insertShString(".tdata"),
                        .offset = std.math.maxInt(u64),
                    });
                }
                if (variable.is_const) break :blk elf_file.zig_data_rel_ro_section_index.?;
                if (Value.fromInterned(variable.init).isUndefDeep(mod)) {
                    // TODO: get the optimize_mode from the Module that owns the decl instead
                    // of using the root module here.
                    break :blk switch (elf_file.base.comp.root_mod.optimize_mode) {
                        .Debug, .ReleaseSafe => elf_file.zig_data_section_index.?,
                        .ReleaseFast, .ReleaseSmall => elf_file.zig_bss_section_index.?,
                    };
                }
                // TODO I blatantly copied the logic from the Wasm linker, but is there a less
                // intrusive check for all zeroes than this?
                const is_all_zeroes = for (code) |byte| {
                    if (byte != 0) break false;
                } else true;
                if (is_all_zeroes) break :blk elf_file.zig_bss_section_index.?;
                break :blk elf_file.zig_data_section_index.?;
            }
            break :blk elf_file.zig_data_rel_ro_section_index.?;
        },
    };
    return shdr_index;
}

fn updateDeclCode(
    self: *ZigObject,
    elf_file: *Elf,
    pt: Zcu.PerThread,
    decl_index: InternPool.DeclIndex,
    sym_index: Symbol.Index,
    shdr_index: u32,
    code: []const u8,
    stt_bits: u8,
) !void {
    const gpa = elf_file.base.comp.gpa;
    const mod = pt.zcu;
    const ip = &mod.intern_pool;
    const decl = mod.declPtr(decl_index);

    log.debug("updateDeclCode {}({d})", .{ decl.fqn.fmt(ip), decl_index });

    const required_alignment = decl.getAlignment(pt).max(
        target_util.minFunctionAlignment(mod.getTarget()),
    );

    const sym = self.symbol(sym_index);
    const esym = &self.symtab.items(.elf_sym)[sym.esym_index];
    const atom_ptr = sym.atom(elf_file).?;
    const name_offset = try self.strtab.insert(gpa, decl.fqn.toSlice(ip));

    atom_ptr.alive = true;
    atom_ptr.name_offset = name_offset;
    atom_ptr.output_section_index = shdr_index;
    sym.name_offset = name_offset;
    esym.st_name = name_offset;
    esym.st_info |= stt_bits;
    esym.st_size = code.len;

    const old_size = atom_ptr.size;
    const old_vaddr = atom_ptr.value;
    atom_ptr.alignment = required_alignment;
    atom_ptr.size = code.len;

    if (old_size > 0 and elf_file.base.child_pid == null) {
        const capacity = atom_ptr.capacity(elf_file);
        const need_realloc = code.len > capacity or !required_alignment.check(@intCast(atom_ptr.value));
        if (need_realloc) {
            try atom_ptr.grow(elf_file);
            log.debug("growing {} from 0x{x} to 0x{x}", .{ decl.fqn.fmt(ip), old_vaddr, atom_ptr.value });
            if (old_vaddr != atom_ptr.value) {
                sym.value = 0;
                esym.st_value = 0;

                if (!elf_file.base.isRelocatable()) {
                    log.debug("  (writing new offset table entry)", .{});
                    assert(sym.flags.has_zig_got);
                    const extra = sym.extra(elf_file);
                    try elf_file.zig_got.writeOne(elf_file, extra.zig_got);
                }
            }
        } else if (code.len < old_size) {
            atom_ptr.shrink(elf_file);
        }
    } else {
        try atom_ptr.allocate(elf_file);
        errdefer self.freeDeclMetadata(elf_file, sym_index);

        sym.value = 0;
        sym.flags.needs_zig_got = true;
        esym.st_value = 0;

        if (!elf_file.base.isRelocatable()) {
            const gop = try sym.getOrCreateZigGotEntry(sym_index, elf_file);
            try elf_file.zig_got.writeOne(elf_file, gop.index);
        }
    }

    if (elf_file.base.child_pid) |pid| {
        switch (builtin.os.tag) {
            .linux => {
                var code_vec: [1]std.posix.iovec_const = .{.{
                    .base = code.ptr,
                    .len = code.len,
                }};
                var remote_vec: [1]std.posix.iovec_const = .{.{
                    .base = @as([*]u8, @ptrFromInt(@as(usize, @intCast(sym.address(.{}, elf_file))))),
                    .len = code.len,
                }};
                const rc = std.os.linux.process_vm_writev(pid, &code_vec, &remote_vec, 0);
                switch (std.os.linux.E.init(rc)) {
                    .SUCCESS => assert(rc == code.len),
                    else => |errno| log.warn("process_vm_writev failure: {s}", .{@tagName(errno)}),
                }
            },
            else => return error.HotSwapUnavailableOnHostOperatingSystem,
        }
    }

    const shdr = elf_file.shdrs.items[shdr_index];
    if (shdr.sh_type != elf.SHT_NOBITS) {
        const file_offset = shdr.sh_offset + @as(u64, @intCast(atom_ptr.value));
        try elf_file.base.file.?.pwriteAll(code, file_offset);
    }
}

fn updateTlv(
    self: *ZigObject,
    elf_file: *Elf,
    pt: Zcu.PerThread,
    decl_index: InternPool.DeclIndex,
    sym_index: Symbol.Index,
    shndx: u32,
    code: []const u8,
) !void {
    const mod = pt.zcu;
    const ip = &mod.intern_pool;
    const gpa = mod.gpa;
    const decl = mod.declPtr(decl_index);

    log.debug("updateTlv {}({d})", .{ decl.fqn.fmt(ip), decl_index });

    const required_alignment = decl.getAlignment(pt);

    const sym = self.symbol(sym_index);
    const esym = &self.symtab.items(.elf_sym)[sym.esym_index];
    const atom_ptr = sym.atom(elf_file).?;
    const name_offset = try self.strtab.insert(gpa, decl.fqn.toSlice(ip));

    sym.value = 0;
    sym.name_offset = name_offset;

    atom_ptr.output_section_index = shndx;
    atom_ptr.alive = true;
    atom_ptr.name_offset = name_offset;

    esym.st_value = 0;
    esym.st_name = name_offset;
    esym.st_info = elf.STT_TLS;
    esym.st_size = code.len;

    atom_ptr.alignment = required_alignment;
    atom_ptr.size = code.len;

    {
        const gop = try self.tls_variables.getOrPut(gpa, atom_ptr.atom_index);
        assert(!gop.found_existing); // TODO incremental updates
        gop.value_ptr.* = .{ .symbol_index = sym_index };

        // We only store the data for the TLV if it's non-zerofill.
        if (elf_file.shdrs.items[shndx].sh_type != elf.SHT_NOBITS) {
            gop.value_ptr.code = try gpa.dupe(u8, code);
        }
    }

    {
        const gop = try elf_file.output_sections.getOrPut(gpa, atom_ptr.output_section_index);
        if (!gop.found_existing) gop.value_ptr.* = .{};
        try gop.value_ptr.append(gpa, .{ .index = atom_ptr.atom_index, .file = self.index });
    }
}

pub fn updateFunc(
    self: *ZigObject,
    elf_file: *Elf,
    pt: Zcu.PerThread,
    func_index: InternPool.Index,
    air: Air,
    liveness: Liveness,
) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const mod = pt.zcu;
    const ip = &mod.intern_pool;
    const gpa = elf_file.base.comp.gpa;
    const func = mod.funcInfo(func_index);
    const decl_index = func.owner_decl;
    const decl = mod.declPtr(decl_index);

    log.debug("updateFunc {}({d})", .{ decl.fqn.fmt(ip), decl_index });

    const sym_index = try self.getOrCreateMetadataForDecl(elf_file, decl_index);
    self.freeUnnamedConsts(elf_file, decl_index);
    self.symbol(sym_index).atom(elf_file).?.freeRelocs(elf_file);

    var code_buffer = std.ArrayList(u8).init(gpa);
    defer code_buffer.deinit();

    var decl_state: ?Dwarf.DeclState = if (self.dwarf) |*dw| try dw.initDeclState(pt, decl_index) else null;
    defer if (decl_state) |*ds| ds.deinit();

    const res = try codegen.generateFunction(
        &elf_file.base,
        pt,
        decl.navSrcLoc(mod),
        func_index,
        air,
        liveness,
        &code_buffer,
        if (decl_state) |*ds| .{ .dwarf = ds } else .none,
    );

    const code = switch (res) {
        .ok => code_buffer.items,
        .fail => |em| {
            func.setAnalysisState(&mod.intern_pool, .codegen_failure);
            try mod.failed_analysis.put(mod.gpa, AnalUnit.wrap(.{ .decl = decl_index }), em);
            return;
        },
    };

    const shndx = try self.getDeclShdrIndex(elf_file, decl, code);
    try self.updateDeclCode(elf_file, pt, decl_index, sym_index, shndx, code, elf.STT_FUNC);

    if (decl_state) |*ds| {
        const sym = self.symbol(sym_index);
        try self.dwarf.?.commitDeclState(
            pt,
            decl_index,
            @intCast(sym.address(.{}, elf_file)),
            sym.atom(elf_file).?.size,
            ds,
        );
    }

    // Exports will be updated by `Zcu.processExports` after the update.
}

pub fn updateDecl(
    self: *ZigObject,
    elf_file: *Elf,
    pt: Zcu.PerThread,
    decl_index: InternPool.DeclIndex,
) link.File.UpdateDeclError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const mod = pt.zcu;
    const ip = &mod.intern_pool;
    const decl = mod.declPtr(decl_index);

    log.debug("updateDecl {}({d})", .{ decl.fqn.fmt(ip), decl_index });

    if (decl.val.getExternFunc(mod)) |_| return;
    if (decl.isExtern(mod)) {
        // Extern variable gets a .got entry only.
        const variable = decl.getOwnedVariable(mod).?;
        const name = decl.name.toSlice(&mod.intern_pool);
        const lib_name = variable.lib_name.toSlice(&mod.intern_pool);
        const sym_index = try self.getGlobalSymbol(elf_file, name, lib_name);
        self.symbol(sym_index).flags.needs_got = true;
        return;
    }

    const sym_index = try self.getOrCreateMetadataForDecl(elf_file, decl_index);
    self.symbol(sym_index).atom(elf_file).?.freeRelocs(elf_file);

    const gpa = elf_file.base.comp.gpa;
    var code_buffer = std.ArrayList(u8).init(gpa);
    defer code_buffer.deinit();

    var decl_state: ?Dwarf.DeclState = if (self.dwarf) |*dw| try dw.initDeclState(pt, decl_index) else null;
    defer if (decl_state) |*ds| ds.deinit();

    // TODO implement .debug_info for global variables
    const decl_val = if (decl.val.getVariable(mod)) |variable| Value.fromInterned(variable.init) else decl.val;
    const res = if (decl_state) |*ds|
        try codegen.generateSymbol(&elf_file.base, pt, decl.navSrcLoc(mod), decl_val, &code_buffer, .{
            .dwarf = ds,
        }, .{
            .parent_atom_index = sym_index,
        })
    else
        try codegen.generateSymbol(&elf_file.base, pt, decl.navSrcLoc(mod), decl_val, &code_buffer, .none, .{
            .parent_atom_index = sym_index,
        });

    const code = switch (res) {
        .ok => code_buffer.items,
        .fail => |em| {
            decl.analysis = .codegen_failure;
            try mod.failed_analysis.put(mod.gpa, AnalUnit.wrap(.{ .decl = decl_index }), em);
            return;
        },
    };

    const shndx = try self.getDeclShdrIndex(elf_file, decl, code);
    if (elf_file.shdrs.items[shndx].sh_flags & elf.SHF_TLS != 0)
        try self.updateTlv(elf_file, pt, decl_index, sym_index, shndx, code)
    else
        try self.updateDeclCode(elf_file, pt, decl_index, sym_index, shndx, code, elf.STT_OBJECT);

    if (decl_state) |*ds| {
        const sym = self.symbol(sym_index);
        try self.dwarf.?.commitDeclState(
            pt,
            decl_index,
            @intCast(sym.address(.{}, elf_file)),
            sym.atom(elf_file).?.size,
            ds,
        );
    }

    // Exports will be updated by `Zcu.processExports` after the update.
}

fn updateLazySymbol(
    self: *ZigObject,
    elf_file: *Elf,
    pt: Zcu.PerThread,
    sym: link.File.LazySymbol,
    symbol_index: Symbol.Index,
) !void {
    const mod = pt.zcu;
    const gpa = mod.gpa;

    var required_alignment: InternPool.Alignment = .none;
    var code_buffer = std.ArrayList(u8).init(gpa);
    defer code_buffer.deinit();

    const name_str_index = blk: {
        const name = try std.fmt.allocPrint(gpa, "__lazy_{s}_{}", .{
            @tagName(sym.kind),
            sym.ty.fmt(pt),
        });
        defer gpa.free(name);
        break :blk try self.strtab.insert(gpa, name);
    };

    const src = sym.ty.srcLocOrNull(mod) orelse Module.LazySrcLoc.unneeded;
    const res = try codegen.generateLazySymbol(
        &elf_file.base,
        pt,
        src,
        sym,
        &required_alignment,
        &code_buffer,
        .none,
        .{ .parent_atom_index = symbol_index },
    );
    const code = switch (res) {
        .ok => code_buffer.items,
        .fail => |em| {
            log.err("{s}", .{em.msg});
            return error.CodegenFail;
        },
    };

    const output_section_index = switch (sym.kind) {
        .code => elf_file.zig_text_section_index.?,
        .const_data => elf_file.zig_data_rel_ro_section_index.?,
    };
    const local_sym = self.symbol(symbol_index);
    local_sym.name_offset = name_str_index;
    const local_esym = &self.symtab.items(.elf_sym)[local_sym.esym_index];
    local_esym.st_name = name_str_index;
    local_esym.st_info |= elf.STT_OBJECT;
    local_esym.st_size = code.len;
    const atom_ptr = local_sym.atom(elf_file).?;
    atom_ptr.alive = true;
    atom_ptr.name_offset = name_str_index;
    atom_ptr.alignment = required_alignment;
    atom_ptr.size = code.len;
    atom_ptr.output_section_index = output_section_index;

    try atom_ptr.allocate(elf_file);
    errdefer self.freeDeclMetadata(elf_file, symbol_index);

    local_sym.value = 0;
    local_sym.flags.needs_zig_got = true;
    local_esym.st_value = 0;

    if (!elf_file.base.isRelocatable()) {
        const gop = try local_sym.getOrCreateZigGotEntry(symbol_index, elf_file);
        try elf_file.zig_got.writeOne(elf_file, gop.index);
    }

    const shdr = elf_file.shdrs.items[output_section_index];
    const file_offset = shdr.sh_offset + @as(u64, @intCast(atom_ptr.value));
    try elf_file.base.file.?.pwriteAll(code, file_offset);
}

pub fn lowerUnnamedConst(
    self: *ZigObject,
    elf_file: *Elf,
    pt: Zcu.PerThread,
    val: Value,
    decl_index: InternPool.DeclIndex,
) !u32 {
    const gpa = elf_file.base.comp.gpa;
    const mod = elf_file.base.comp.module.?;
    const gop = try self.unnamed_consts.getOrPut(gpa, decl_index);
    if (!gop.found_existing) {
        gop.value_ptr.* = .{};
    }
    const unnamed_consts = gop.value_ptr;
    const decl = mod.declPtr(decl_index);
    const index = unnamed_consts.items.len;
    const name = try std.fmt.allocPrint(gpa, "__unnamed_{}_{d}", .{ decl.fqn.fmt(&mod.intern_pool), index });
    defer gpa.free(name);
    const ty = val.typeOf(mod);
    const sym_index = switch (try self.lowerConst(
        elf_file,
        pt,
        name,
        val,
        ty.abiAlignment(pt),
        elf_file.zig_data_rel_ro_section_index.?,
        decl.navSrcLoc(mod),
    )) {
        .ok => |sym_index| sym_index,
        .fail => |em| {
            decl.analysis = .codegen_failure;
            try mod.failed_analysis.put(mod.gpa, AnalUnit.wrap(.{ .decl = decl_index }), em);
            log.err("{s}", .{em.msg});
            return error.CodegenFail;
        },
    };
    try unnamed_consts.append(gpa, sym_index);
    return sym_index;
}

const LowerConstResult = union(enum) {
    ok: Symbol.Index,
    fail: *Module.ErrorMsg,
};

fn lowerConst(
    self: *ZigObject,
    elf_file: *Elf,
    pt: Zcu.PerThread,
    name: []const u8,
    val: Value,
    required_alignment: InternPool.Alignment,
    output_section_index: u32,
    src_loc: Module.LazySrcLoc,
) !LowerConstResult {
    const gpa = pt.zcu.gpa;

    var code_buffer = std.ArrayList(u8).init(gpa);
    defer code_buffer.deinit();

    const name_off = try self.addString(gpa, name);
    const sym_index = try self.newSymbolWithAtom(gpa, name_off);

    const res = try codegen.generateSymbol(
        &elf_file.base,
        pt,
        src_loc,
        val,
        &code_buffer,
        .{ .none = {} },
        .{ .parent_atom_index = sym_index },
    );
    const code = switch (res) {
        .ok => code_buffer.items,
        .fail => |em| return .{ .fail = em },
    };

    const local_sym = self.symbol(sym_index);
    const local_esym = &self.symtab.items(.elf_sym)[local_sym.esym_index];
    local_esym.st_info |= elf.STT_OBJECT;
    local_esym.st_size = code.len;
    const atom_ptr = local_sym.atom(elf_file).?;
    atom_ptr.alive = true;
    atom_ptr.alignment = required_alignment;
    atom_ptr.size = code.len;
    atom_ptr.output_section_index = output_section_index;

    try atom_ptr.allocate(elf_file);
    errdefer self.freeDeclMetadata(elf_file, sym_index);

    const shdr = elf_file.shdrs.items[output_section_index];
    const file_offset = shdr.sh_offset + @as(u64, @intCast(atom_ptr.value));
    try elf_file.base.file.?.pwriteAll(code, file_offset);

    return .{ .ok = sym_index };
}

pub fn updateExports(
    self: *ZigObject,
    elf_file: *Elf,
    pt: Zcu.PerThread,
    exported: Module.Exported,
    export_indices: []const u32,
) link.File.UpdateExportsError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const mod = pt.zcu;
    const gpa = elf_file.base.comp.gpa;
    const metadata = switch (exported) {
        .decl_index => |decl_index| blk: {
            _ = try self.getOrCreateMetadataForDecl(elf_file, decl_index);
            break :blk self.decls.getPtr(decl_index).?;
        },
        .value => |value| self.anon_decls.getPtr(value) orelse blk: {
            const first_exp = mod.all_exports.items[export_indices[0]];
            const res = try self.lowerAnonDecl(elf_file, pt, value, .none, first_exp.src);
            switch (res) {
                .ok => {},
                .fail => |em| {
                    // TODO maybe it's enough to return an error here and let Module.processExportsInner
                    // handle the error?
                    try mod.failed_exports.ensureUnusedCapacity(mod.gpa, 1);
                    mod.failed_exports.putAssumeCapacityNoClobber(export_indices[0], em);
                    return;
                },
            }
            break :blk self.anon_decls.getPtr(value).?;
        },
    };
    const sym_index = metadata.symbol_index;
    const esym_index = self.symbol(sym_index).esym_index;
    const esym = self.symtab.items(.elf_sym)[esym_index];
    const esym_shndx = self.symtab.items(.shndx)[esym_index];

    for (export_indices) |export_idx| {
        const exp = mod.all_exports.items[export_idx];
        if (exp.opts.section.unwrap()) |section_name| {
            if (!section_name.eqlSlice(".text", &mod.intern_pool)) {
                try mod.failed_exports.ensureUnusedCapacity(mod.gpa, 1);
                mod.failed_exports.putAssumeCapacityNoClobber(export_idx, try Module.ErrorMsg.create(
                    gpa,
                    exp.src,
                    "Unimplemented: ExportOptions.section",
                    .{},
                ));
                continue;
            }
        }
        const stb_bits: u8 = switch (exp.opts.linkage) {
            .internal => elf.STB_LOCAL,
            .strong => elf.STB_GLOBAL,
            .weak => elf.STB_WEAK,
            .link_once => {
                try mod.failed_exports.ensureUnusedCapacity(mod.gpa, 1);
                mod.failed_exports.putAssumeCapacityNoClobber(export_idx, try Module.ErrorMsg.create(
                    gpa,
                    exp.src,
                    "Unimplemented: GlobalLinkage.LinkOnce",
                    .{},
                ));
                continue;
            },
        };
        const stt_bits: u8 = @as(u4, @truncate(esym.st_info));
        const exp_name = exp.opts.name.toSlice(&mod.intern_pool);
        const name_off = try self.strtab.insert(gpa, exp_name);
        const global_sym_index = if (metadata.@"export"(self, exp_name)) |exp_index|
            exp_index.*
        else blk: {
            const global_sym_index = try self.getGlobalSymbol(elf_file, exp_name, null);
            try metadata.exports.append(gpa, global_sym_index);
            break :blk global_sym_index;
        };

        const value = self.symbol(sym_index).value;
        const global_sym = self.symbol(global_sym_index);
        global_sym.value = value;
        global_sym.flags.weak = exp.opts.linkage == .weak;
        global_sym.version_index = elf_file.default_sym_version;
        global_sym.ref = .{ .index = esym_shndx, .file = self.index };
        const global_esym = &self.symtab.items(.elf_sym)[global_sym.esym_index];
        global_esym.st_value = @intCast(value);
        global_esym.st_shndx = esym.st_shndx;
        global_esym.st_info = (stb_bits << 4) | stt_bits;
        global_esym.st_name = name_off;
        global_esym.st_size = esym.st_size;
        self.symtab.items(.shndx)[global_sym.esym_index] = esym_shndx;
    }
}

/// Must be called only after a successful call to `updateDecl`.
pub fn updateDeclLineNumber(
    self: *ZigObject,
    pt: Zcu.PerThread,
    decl_index: InternPool.DeclIndex,
) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const decl = pt.zcu.declPtr(decl_index);

    log.debug("updateDeclLineNumber {}({d})", .{ decl.fqn.fmt(&pt.zcu.intern_pool), decl_index });

    if (self.dwarf) |*dw| {
        try dw.updateDeclLineNumber(pt.zcu, decl_index);
    }
}

pub fn deleteExport(
    self: *ZigObject,
    elf_file: *Elf,
    exported: Zcu.Exported,
    name: InternPool.NullTerminatedString,
) void {
    const metadata = switch (exported) {
        .decl_index => |decl_index| self.decls.getPtr(decl_index) orelse return,
        .value => |value| self.anon_decls.getPtr(value) orelse return,
    };
    const mod = elf_file.base.comp.module.?;
    const exp_name = name.toSlice(&mod.intern_pool);
    const esym_index = metadata.@"export"(self, exp_name) orelse return;
    log.debug("deleting export '{s}'", .{exp_name});
    const esym = &self.symtab.items(.elf_sym)[esym_index.*];
    _ = self.globals_lookup.remove(esym.st_name);
    esym.* = Elf.null_sym;
    self.symtab.items(.shndx)[esym_index.*] = elf.SHN_UNDEF;
}

pub fn getGlobalSymbol(self: *ZigObject, elf_file: *Elf, name: []const u8, lib_name: ?[]const u8) !u32 {
    _ = lib_name;
    const gpa = elf_file.base.comp.gpa;
    const off = try self.strtab.insert(gpa, name);
    const lookup_gop = try self.globals_lookup.getOrPut(gpa, off);
    if (!lookup_gop.found_existing) {
        lookup_gop.value_ptr.* = try self.newGlobalSymbol(gpa, off);
    }
    return lookup_gop.value_ptr.*;
}

pub fn asFile(self: *ZigObject) File {
    return .{ .zig_object = self };
}

fn addString(self: *ZigObject, allocator: Allocator, string: []const u8) !u32 {
    return self.strtab.insert(allocator, string);
}

pub fn getString(self: ZigObject, off: u32) [:0]const u8 {
    return self.strtab.getAssumeExists(off);
}

fn addAtom(self: *ZigObject, allocator: Allocator) !Atom.Index {
    try self.atoms.ensureUnusedCapacity(allocator, 1);
    try self.atoms_extra.ensureUnusedCapacity(allocator, @sizeOf(Atom.Extra));
    return self.addAtomAssumeCapacity();
}

fn addAtomAssumeCapacity(self: *ZigObject) Atom.Index {
    const atom_index: Atom.Index = @intCast(self.atoms.items.len);
    const atom_ptr = self.atoms.addOneAssumeCapacity();
    atom_ptr.* = .{
        .file_index = self.index,
        .atom_index = atom_index,
        .extra_index = self.addAtomExtraAssumeCapacity(.{}),
    };
    return atom_index;
}

pub fn atom(self: *ZigObject, atom_index: Atom.Index) ?*Atom {
    if (atom_index == 0) return null;
    assert(atom_index < self.atoms.items.len);
    return &self.atoms.items[atom_index];
}

fn addAtomExtra(self: *ZigObject, allocator: Allocator, extra: Atom.Extra) !u32 {
    const fields = @typeInfo(Atom.Extra).Struct.fields;
    try self.atoms_extra.ensureUnusedCapacity(allocator, fields.len);
    return self.addAtomExtraAssumeCapacity(extra);
}

fn addAtomExtraAssumeCapacity(self: *ZigObject, extra: Atom.Extra) u32 {
    const index = @as(u32, @intCast(self.atoms_extra.items.len));
    const fields = @typeInfo(Atom.Extra).Struct.fields;
    inline for (fields) |field| {
        self.atoms_extra.appendAssumeCapacity(switch (field.type) {
            u32 => @field(extra, field.name),
            else => @compileError("bad field type"),
        });
    }
    return index;
}

pub fn atomExtra(self: ZigObject, index: u32) Atom.Extra {
    const fields = @typeInfo(Atom.Extra).Struct.fields;
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

pub fn setAtomExtra(self: *ZigObject, index: u32, extra: Atom.Extra) void {
    assert(index > 0);
    const fields = @typeInfo(Atom.Extra).Struct.fields;
    inline for (fields, 0..) |field, i| {
        self.atoms_extra.items[index + i] = switch (field.type) {
            u32 => @field(extra, field.name),
            else => @compileError("bad field type"),
        };
    }
}

inline fn isGlobal(index: Symbol.Index) bool {
    return index & global_symbol_bit != 0;
}

pub fn symbol(self: *ZigObject, index: Symbol.Index) *Symbol {
    const actual_index = index & symbol_mask;
    if (isGlobal(index)) return &self.symbols.items[self.global_symbols.items[actual_index]];
    return &self.symbols.items[self.local_symbols.items[actual_index]];
}

pub fn resolveSymbol(self: ZigObject, index: Symbol.Index, elf_file: *Elf) Elf.Ref {
    if (isGlobal(index)) {
        const resolv = self.symbols_resolver.items[index & symbol_mask];
        return elf_file.resolver.get(resolv).?;
    }
    return .{ .index = index, .file = self.index };
}

fn addSymbol(self: *ZigObject, allocator: Allocator) !Symbol.Index {
    try self.symbols.ensureUnusedCapacity(allocator, 1);
    return self.addSymbolAssumeCapacity();
}

fn addSymbolAssumeCapacity(self: *ZigObject) Symbol.Index {
    const index: Symbol.Index = @intCast(self.symbols.items.len);
    self.symbols.appendAssumeCapacity(.{ .file_index = self.index });
    return index;
}

pub fn addSymbolExtra(self: *ZigObject, allocator: Allocator, extra: Symbol.Extra) !u32 {
    const fields = @typeInfo(Symbol.Extra).Struct.fields;
    try self.symbols_extra.ensureUnusedCapacity(allocator, fields.len);
    return self.addSymbolExtraAssumeCapacity(extra);
}

pub fn addSymbolExtraAssumeCapacity(self: *ZigObject, extra: Symbol.Extra) u32 {
    const index = @as(u32, @intCast(self.symbols_extra.items.len));
    const fields = @typeInfo(Symbol.Extra).Struct.fields;
    inline for (fields) |field| {
        self.symbols_extra.appendAssumeCapacity(switch (field.type) {
            u32 => @field(extra, field.name),
            else => @compileError("bad field type"),
        });
    }
    return index;
}

pub fn symbolExtra(self: *ZigObject, index: u32) Symbol.Extra {
    const fields = @typeInfo(Symbol.Extra).Struct.fields;
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

pub fn setSymbolExtra(self: *ZigObject, index: u32, extra: Symbol.Extra) void {
    const fields = @typeInfo(Symbol.Extra).Struct.fields;
    inline for (fields, 0..) |field, i| {
        self.symbols_extra.items[index + i] = switch (field.type) {
            u32 => @field(extra, field.name),
            else => @compileError("bad field type"),
        };
    }
}

pub fn fmtSymtab(self: *ZigObject, elf_file: *Elf) std.fmt.Formatter(formatSymtab) {
    return .{ .data = .{
        .self = self,
        .elf_file = elf_file,
    } };
}

const FormatContext = struct {
    self: *ZigObject,
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
    const self = ctx.self;
    const elf_file = ctx.elf_file;
    try writer.writeAll("  locals\n");
    for (self.local_symbols.items) |index| {
        const local = self.symbols.items[index];
        try writer.print("    {}\n", .{local.fmt(elf_file)});
    }
    try writer.writeAll("  globals\n");
    for (ctx.self.global_symbols.items) |index| {
        const global = self.symbols.items[index];
        try writer.print("    {}\n", .{global.fmt(elf_file)});
    }
}

pub fn fmtAtoms(self: *ZigObject, elf_file: *Elf) std.fmt.Formatter(formatAtoms) {
    return .{ .data = .{
        .self = self,
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
    try writer.writeAll("  atoms\n");
    for (ctx.self.atoms_indexes.items) |atom_index| {
        const atom_ptr = ctx.self.atom(atom_index) orelse continue;
        try writer.print("    {}\n", .{atom_ptr.fmt(ctx.elf_file)});
    }
}

const ElfSym = struct {
    elf_sym: elf.Elf64_Sym,
    shndx: u32 = elf.SHN_UNDEF,
};

const LazySymbolMetadata = struct {
    const State = enum { unused, pending_flush, flushed };
    text_symbol_index: Symbol.Index = undefined,
    rodata_symbol_index: Symbol.Index = undefined,
    text_state: State = .unused,
    rodata_state: State = .unused,
};

const DeclMetadata = struct {
    symbol_index: Symbol.Index,
    /// A list of all exports aliases of this Decl.
    exports: std.ArrayListUnmanaged(Symbol.Index) = .{},

    fn @"export"(m: DeclMetadata, zo: *ZigObject, name: []const u8) ?*u32 {
        for (m.exports.items) |*exp| {
            const exp_name = zo.getString(zo.symbol(exp.*).name_offset);
            if (mem.eql(u8, name, exp_name)) return exp;
        }
        return null;
    }
};

const TlsVariable = struct {
    symbol_index: Symbol.Index,
    code: []const u8 = &[0]u8{},

    fn deinit(tlv: *TlsVariable, allocator: Allocator) void {
        allocator.free(tlv.code);
    }
};

const AtomList = std.ArrayListUnmanaged(Atom.Index);
const UnnamedConstTable = std.AutoHashMapUnmanaged(InternPool.DeclIndex, std.ArrayListUnmanaged(Symbol.Index));
const DeclTable = std.AutoHashMapUnmanaged(InternPool.DeclIndex, DeclMetadata);
const AnonDeclTable = std.AutoHashMapUnmanaged(InternPool.Index, DeclMetadata);
const LazySymbolTable = std.AutoArrayHashMapUnmanaged(InternPool.OptionalDeclIndex, LazySymbolMetadata);
const TlsTable = std.AutoArrayHashMapUnmanaged(Atom.Index, TlsVariable);

const assert = std.debug.assert;
const builtin = @import("builtin");
const codegen = @import("../../codegen.zig");
const elf = std.elf;
const link = @import("../../link.zig");
const log = std.log.scoped(.link);
const mem = std.mem;
const relocation = @import("relocation.zig");
const trace = @import("../../tracy.zig").trace;
const target_util = @import("../../target.zig");
const std = @import("std");

const Air = @import("../../Air.zig");
const Allocator = std.mem.Allocator;
const Archive = @import("Archive.zig");
const Atom = @import("Atom.zig");
const Dwarf = @import("../Dwarf.zig");
const Elf = @import("../Elf.zig");
const File = @import("file.zig").File;
const InternPool = @import("../../InternPool.zig");
const Liveness = @import("../../Liveness.zig");
const Zcu = @import("../../Zcu.zig");
/// Deprecated.
const Module = Zcu;
const Object = @import("Object.zig");
const Symbol = @import("Symbol.zig");
const StringTable = @import("../StringTable.zig");
const Type = @import("../../Type.zig");
const Value = @import("../../Value.zig");
const AnalUnit = InternPool.AnalUnit;
const ZigObject = @This();
