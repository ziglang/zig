data: std.ArrayListUnmanaged(u8) = .empty,
/// Externally owned memory.
basename: []const u8,
index: File.Index,

symtab: std.MultiArrayList(Nlist) = .{},
strtab: StringTable = .{},

symbols: std.ArrayListUnmanaged(Symbol) = .empty,
symbols_extra: std.ArrayListUnmanaged(u32) = .empty,
globals: std.ArrayListUnmanaged(MachO.SymbolResolver.Index) = .empty,
/// Maps string index (so name) into nlist index for the global symbol defined within this
/// module.
globals_lookup: std.AutoHashMapUnmanaged(u32, u32) = .empty,
atoms: std.ArrayListUnmanaged(Atom) = .empty,
atoms_indexes: std.ArrayListUnmanaged(Atom.Index) = .empty,
atoms_extra: std.ArrayListUnmanaged(u32) = .empty,

/// Table of tracked LazySymbols.
lazy_syms: LazySymbolTable = .{},

/// Table of tracked Navs.
navs: NavTable = .{},

/// Table of tracked Uavs.
uavs: UavTable = .{},

/// TLV initializers indexed by Atom.Index.
tlv_initializers: TlvInitializerTable = .{},

/// A table of relocations.
relocs: RelocationTable = .{},

dwarf: ?Dwarf = null,

output_symtab_ctx: MachO.SymtabCtx = .{},
output_ar_state: Archive.ArState = .{},

debug_strtab_dirty: bool = false,
debug_abbrev_dirty: bool = false,
debug_aranges_dirty: bool = false,
debug_info_header_dirty: bool = false,
debug_line_header_dirty: bool = false,

pub fn init(self: *ZigObject, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const comp = macho_file.base.comp;
    const gpa = comp.gpa;

    try self.atoms.append(gpa, .{ .extra = try self.addAtomExtra(gpa, .{}) }); // null input section
    try self.strtab.buffer.append(gpa, 0);

    switch (comp.config.debug_format) {
        .strip => {},
        .dwarf => |v| {
            self.dwarf = Dwarf.init(&macho_file.base, v);
            self.debug_strtab_dirty = true;
            self.debug_abbrev_dirty = true;
            self.debug_aranges_dirty = true;
            self.debug_info_header_dirty = true;
            self.debug_line_header_dirty = true;
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
    self.globals.deinit(allocator);
    self.globals_lookup.deinit(allocator);
    self.atoms.deinit(allocator);
    self.atoms_indexes.deinit(allocator);
    self.atoms_extra.deinit(allocator);

    for (self.navs.values()) |*meta| {
        meta.exports.deinit(allocator);
    }
    self.navs.deinit(allocator);

    self.lazy_syms.deinit(allocator);

    for (self.uavs.values()) |*meta| {
        meta.exports.deinit(allocator);
    }
    self.uavs.deinit(allocator);

    for (self.relocs.items) |*list| {
        list.deinit(allocator);
    }
    self.relocs.deinit(allocator);

    for (self.tlv_initializers.values()) |*tlv_init| {
        tlv_init.deinit(allocator);
    }
    self.tlv_initializers.deinit(allocator);

    if (self.dwarf) |*dwarf| {
        dwarf.deinit();
    }
}

fn newSymbol(self: *ZigObject, allocator: Allocator, name: MachO.String, args: struct {
    type: u8 = macho.N_UNDF | macho.N_EXT,
    desc: u16 = 0,
}) !Symbol.Index {
    try self.symtab.ensureUnusedCapacity(allocator, 1);
    try self.symbols.ensureUnusedCapacity(allocator, 1);
    try self.symbols_extra.ensureUnusedCapacity(allocator, @sizeOf(Symbol.Extra));
    try self.globals.ensureUnusedCapacity(allocator, 1);

    const index = self.addSymbolAssumeCapacity();
    const symbol = &self.symbols.items[index];
    symbol.name = name;
    symbol.extra = self.addSymbolExtraAssumeCapacity(.{});

    const nlist_idx: u32 = @intCast(self.symtab.addOneAssumeCapacity());
    self.symtab.set(nlist_idx, .{
        .nlist = .{
            .n_strx = name.pos,
            .n_type = args.type,
            .n_sect = 0,
            .n_desc = args.desc,
            .n_value = 0,
        },
        .size = 0,
        .atom = 0,
    });
    symbol.nlist_idx = nlist_idx;

    self.globals.appendAssumeCapacity(0);

    return index;
}

fn newAtom(self: *ZigObject, allocator: Allocator, name: MachO.String, macho_file: *MachO) !Atom.Index {
    try self.atoms.ensureUnusedCapacity(allocator, 1);
    try self.atoms_extra.ensureUnusedCapacity(allocator, @sizeOf(Atom.Extra));
    try self.atoms_indexes.ensureUnusedCapacity(allocator, 1);
    try self.relocs.ensureUnusedCapacity(allocator, 1);

    const index = self.addAtomAssumeCapacity();
    self.atoms_indexes.appendAssumeCapacity(index);
    const atom = self.getAtom(index).?;
    atom.name = name;

    const relocs_index = @as(u32, @intCast(self.relocs.items.len));
    self.relocs.addOneAssumeCapacity().* = .{};
    atom.addExtra(.{ .rel_index = relocs_index, .rel_count = 0 }, macho_file);

    return index;
}

fn newSymbolWithAtom(self: *ZigObject, allocator: Allocator, name: MachO.String, macho_file: *MachO) !Symbol.Index {
    const atom_index = try self.newAtom(allocator, name, macho_file);
    const sym_index = try self.newSymbol(allocator, name, .{ .type = macho.N_SECT });
    const sym = &self.symbols.items[sym_index];
    sym.atom_ref = .{ .index = atom_index, .file = self.index };
    self.symtab.items(.atom)[sym.nlist_idx] = atom_index;
    return sym_index;
}

pub fn getAtomData(self: ZigObject, macho_file: *MachO, atom: Atom, buffer: []u8) !void {
    assert(atom.file == self.index);
    assert(atom.size == buffer.len);
    const isec = atom.getInputSection(macho_file);
    assert(!isec.isZerofill());

    switch (isec.type()) {
        macho.S_THREAD_LOCAL_REGULAR => {
            const tlv = self.tlv_initializers.get(atom.atom_index).?;
            @memcpy(buffer, tlv.data);
        },
        macho.S_THREAD_LOCAL_VARIABLES => {
            @memset(buffer, 0);
        },
        else => {
            const sect = macho_file.sections.items(.header)[atom.out_n_sect];
            const file_offset = sect.offset + atom.value;
            const amt = try macho_file.base.file.?.preadAll(buffer, file_offset);
            if (amt != buffer.len) return error.InputOutput;
        },
    }
}

pub fn getAtomRelocs(self: *ZigObject, atom: Atom, macho_file: *MachO) []const Relocation {
    const extra = atom.getExtra(macho_file);
    const relocs = self.relocs.items[extra.rel_index];
    return relocs.items[0..extra.rel_count];
}

pub fn freeAtomRelocs(self: *ZigObject, atom: Atom, macho_file: *MachO) void {
    const extra = atom.getExtra(macho_file);
    self.relocs.items[extra.rel_index].clearRetainingCapacity();
}

pub fn resolveSymbols(self: *ZigObject, macho_file: *MachO) !void {
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
            .archive = false,
            .weak = nlist.weakDef(),
            .tentative = nlist.tentative(),
        }) < gop.ref.getSymbol(macho_file).?.getSymbolRank(macho_file)) {
            gop.ref.* = .{ .index = @intCast(i), .file = self.index };
        }
    }
}

pub fn markLive(self: *ZigObject, macho_file: *MachO) void {
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

pub fn mergeSymbolVisibility(self: *ZigObject, macho_file: *MachO) void {
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

pub fn resolveLiterals(self: *ZigObject, lp: *MachO.LiteralPool, macho_file: *MachO) !void {
    _ = self;
    _ = lp;
    _ = macho_file;
    // TODO
}

pub fn dedupLiterals(self: *ZigObject, lp: MachO.LiteralPool, macho_file: *MachO) void {
    _ = self;
    _ = lp;
    _ = macho_file;
    // TODO
}

/// This is just a temporary helper function that allows us to re-read what we wrote to file into a buffer.
/// We need this so that we can write to an archive.
/// TODO implement writing ZigObject data directly to a buffer instead.
pub fn readFileContents(self: *ZigObject, macho_file: *MachO) !void {
    // Size of the output object file is always the offset + size of the strtab
    const size = macho_file.symtab_cmd.stroff + macho_file.symtab_cmd.strsize;
    const gpa = macho_file.base.comp.gpa;
    try self.data.resize(gpa, size);
    const amt = try macho_file.base.file.?.preadAll(self.data.items, 0);
    if (amt != size) return error.InputOutput;
}

pub fn updateArSymtab(self: ZigObject, ar_symtab: *Archive.ArSymtab, macho_file: *MachO) error{OutOfMemory}!void {
    const gpa = macho_file.base.comp.gpa;
    for (self.symbols.items, 0..) |sym, i| {
        const ref = self.getSymbolRef(@intCast(i), macho_file);
        const file = ref.getFile(macho_file).?;
        assert(file.getIndex() == self.index);
        if (!sym.flags.@"export") continue;
        const off = try ar_symtab.strtab.insert(gpa, sym.getName(macho_file));
        try ar_symtab.entries.append(gpa, .{ .off = off, .file = self.index });
    }
}

pub fn updateArSize(self: *ZigObject) void {
    self.output_ar_state.size = self.data.items.len;
}

pub fn writeAr(self: ZigObject, ar_format: Archive.Format, writer: anytype) !void {
    // Header
    const size = std.math.cast(usize, self.output_ar_state.size) orelse return error.Overflow;
    try Archive.writeHeader(self.basename, size, ar_format, writer);
    // Data
    try writer.writeAll(self.data.items);
}

pub fn claimUnresolved(self: *ZigObject, macho_file: *MachO) void {
    const tracy = trace(@src());
    defer tracy.end();

    for (self.symbols.items, 0..) |*sym, i| {
        const nlist = self.symtab.items(.nlist)[i];
        if (!nlist.ext()) continue;
        if (!nlist.undf()) continue;

        if (self.getSymbolRef(@intCast(i), macho_file).getFile(macho_file) != null) continue;

        const is_import = switch (macho_file.undefined_treatment) {
            .@"error" => false,
            .warn, .suppress => nlist.weakRef(),
            .dynamic_lookup => true,
        };
        if (is_import) {
            sym.value = 0;
            sym.atom_ref = .{ .index = 0, .file = 0 };
            sym.flags.weak = false;
            sym.flags.weak_ref = nlist.weakRef();
            sym.flags.import = is_import;
            sym.visibility = .global;

            const idx = self.globals.items[i];
            macho_file.resolver.values.items[idx - 1] = .{ .index = @intCast(i), .file = self.index };
        }
    }
}

pub fn scanRelocs(self: *ZigObject, macho_file: *MachO) !void {
    for (self.getAtoms()) |atom_index| {
        const atom = self.getAtom(atom_index) orelse continue;
        if (!atom.isAlive()) continue;
        const sect = atom.getInputSection(macho_file);
        if (sect.isZerofill()) continue;
        try atom.scanRelocs(macho_file);
    }
}

pub fn resolveRelocs(self: *ZigObject, macho_file: *MachO) !void {
    const gpa = macho_file.base.comp.gpa;
    const diags = &macho_file.base.comp.link_diags;

    var has_error = false;
    for (self.getAtoms()) |atom_index| {
        const atom = self.getAtom(atom_index) orelse continue;
        if (!atom.isAlive()) continue;
        const sect = &macho_file.sections.items(.header)[atom.out_n_sect];
        if (sect.isZerofill()) continue;
        if (!macho_file.isZigSection(atom.out_n_sect)) continue; // Non-Zig sections are handled separately
        if (atom.getRelocs(macho_file).len == 0) continue;
        // TODO: we will resolve and write ZigObject's TLS data twice:
        // once here, and once in writeAtoms
        const atom_size = std.math.cast(usize, atom.size) orelse return error.Overflow;
        const code = try gpa.alloc(u8, atom_size);
        defer gpa.free(code);
        self.getAtomData(macho_file, atom.*, code) catch |err| {
            switch (err) {
                error.InputOutput => return diags.fail("fetching code for '{s}' failed", .{
                    atom.getName(macho_file),
                }),
                else => |e| return diags.fail("failed to fetch code for '{s}': {s}", .{
                    atom.getName(macho_file), @errorName(e),
                }),
            }
            has_error = true;
            continue;
        };
        const file_offset = sect.offset + atom.value;
        atom.resolveRelocs(macho_file, code) catch |err| {
            switch (err) {
                error.ResolveFailed => {},
                else => |e| return diags.fail("failed to resolve relocations: {s}", .{@errorName(e)}),
            }
            has_error = true;
            continue;
        };
        try macho_file.base.file.?.pwriteAll(code, file_offset);
    }

    if (has_error) return error.ResolveFailed;
}

pub fn calcNumRelocs(self: *ZigObject, macho_file: *MachO) void {
    for (self.getAtoms()) |atom_index| {
        const atom = self.getAtom(atom_index) orelse continue;
        if (!atom.isAlive()) continue;
        const header = &macho_file.sections.items(.header)[atom.out_n_sect];
        if (header.isZerofill()) continue;
        if (!macho_file.isZigSection(atom.out_n_sect) and !macho_file.isDebugSection(atom.out_n_sect)) continue;
        const nreloc = atom.calcNumRelocs(macho_file);
        atom.addExtra(.{ .rel_out_index = header.nreloc, .rel_out_count = nreloc }, macho_file);
        header.nreloc += nreloc;
    }
}

pub fn writeRelocs(self: *ZigObject, macho_file: *MachO) !void {
    const gpa = macho_file.base.comp.gpa;
    const diags = &macho_file.base.comp.link_diags;

    for (self.getAtoms()) |atom_index| {
        const atom = self.getAtom(atom_index) orelse continue;
        if (!atom.isAlive()) continue;
        const header = macho_file.sections.items(.header)[atom.out_n_sect];
        const relocs = macho_file.sections.items(.relocs)[atom.out_n_sect].items;
        if (header.isZerofill()) continue;
        if (!macho_file.isZigSection(atom.out_n_sect) and !macho_file.isDebugSection(atom.out_n_sect)) continue;
        if (atom.getRelocs(macho_file).len == 0) continue;
        const extra = atom.getExtra(macho_file);
        const atom_size = std.math.cast(usize, atom.size) orelse return error.Overflow;
        const code = try gpa.alloc(u8, atom_size);
        defer gpa.free(code);
        self.getAtomData(macho_file, atom.*, code) catch |err|
            return diags.fail("failed to fetch code for '{s}': {s}", .{ atom.getName(macho_file), @errorName(err) });
        const file_offset = header.offset + atom.value;
        try atom.writeRelocs(macho_file, code, relocs[extra.rel_out_index..][0..extra.rel_out_count]);
        try macho_file.base.file.?.pwriteAll(code, file_offset);
    }
}

// TODO we need this because not everything gets written out incrementally.
// For example, TLS data gets written out via traditional route.
// Is there any better way of handling this?
pub fn writeAtomsRelocatable(self: *ZigObject, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    for (self.getAtoms()) |atom_index| {
        const atom = self.getAtom(atom_index) orelse continue;
        if (!atom.isAlive()) continue;
        const sect = atom.getInputSection(macho_file);
        if (sect.isZerofill()) continue;
        if (macho_file.isZigSection(atom.out_n_sect)) continue;
        if (atom.getRelocs(macho_file).len == 0) continue;
        const off = std.math.cast(usize, atom.value) orelse return error.Overflow;
        const size = std.math.cast(usize, atom.size) orelse return error.Overflow;
        const buffer = macho_file.sections.items(.out)[atom.out_n_sect].items;
        try self.getAtomData(macho_file, atom.*, buffer[off..][0..size]);
        const relocs = macho_file.sections.items(.relocs)[atom.out_n_sect].items;
        const extra = atom.getExtra(macho_file);
        try atom.writeRelocs(macho_file, buffer[off..][0..size], relocs[extra.rel_out_index..][0..extra.rel_out_count]);
    }
}

// TODO we need this because not everything gets written out incrementally.
// For example, TLS data gets written out via traditional route.
// Is there any better way of handling this?
pub fn writeAtoms(self: *ZigObject, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    for (self.getAtoms()) |atom_index| {
        const atom = self.getAtom(atom_index) orelse continue;
        if (!atom.isAlive()) continue;
        const sect = atom.getInputSection(macho_file);
        if (sect.isZerofill()) continue;
        if (macho_file.isZigSection(atom.out_n_sect)) continue;
        const off = std.math.cast(usize, atom.value) orelse return error.Overflow;
        const size = std.math.cast(usize, atom.size) orelse return error.Overflow;
        const buffer = macho_file.sections.items(.out)[atom.out_n_sect].items;
        try self.getAtomData(macho_file, atom.*, buffer[off..][0..size]);
        try atom.resolveRelocs(macho_file, buffer[off..][0..size]);
    }
}

pub fn calcSymtabSize(self: *ZigObject, macho_file: *MachO) void {
    const tracy = trace(@src());
    defer tracy.end();

    for (self.symbols.items, 0..) |*sym, i| {
        const ref = self.getSymbolRef(@intCast(i), macho_file);
        const file = ref.getFile(macho_file) orelse continue;
        if (file.getIndex() != self.index) continue;
        if (sym.getAtom(macho_file)) |atom| if (!atom.isAlive()) continue;
        const name = sym.getName(macho_file);
        assert(name.len > 0);
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
        self.output_symtab_ctx.strsize += @as(u32, @intCast(name.len + 1));
    }
}

pub fn writeSymtab(self: ZigObject, macho_file: *MachO, ctx: anytype) void {
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
}

pub fn getInputSection(self: ZigObject, atom: Atom, macho_file: *MachO) macho.section_64 {
    _ = self;
    var sect = macho_file.sections.items(.header)[atom.out_n_sect];
    sect.addr = 0;
    sect.offset = 0;
    sect.size = atom.size;
    sect.@"align" = atom.alignment.toLog2Units();
    return sect;
}

pub fn flushModule(self: *ZigObject, macho_file: *MachO, tid: Zcu.PerThread.Id) !void {
    // Handle any lazy symbols that were emitted by incremental compilation.
    if (self.lazy_syms.getPtr(.anyerror_type)) |metadata| {
        const pt: Zcu.PerThread = .{ .zcu = macho_file.base.comp.zcu.?, .tid = tid };

        // Most lazy symbols can be updated on first use, but
        // anyerror needs to wait for everything to be flushed.
        if (metadata.text_state != .unused) self.updateLazySymbol(
            macho_file,
            pt,
            .{ .kind = .code, .ty = .anyerror_type },
            metadata.text_symbol_index,
        ) catch |err| return switch (err) {
            error.CodegenFail => error.FlushFailure,
            else => |e| e,
        };
        if (metadata.const_state != .unused) self.updateLazySymbol(
            macho_file,
            pt,
            .{ .kind = .const_data, .ty = .anyerror_type },
            metadata.const_symbol_index,
        ) catch |err| return switch (err) {
            error.CodegenFail => error.FlushFailure,
            else => |e| e,
        };
    }
    for (self.lazy_syms.values()) |*metadata| {
        if (metadata.text_state != .unused) metadata.text_state = .flushed;
        if (metadata.const_state != .unused) metadata.const_state = .flushed;
    }

    if (self.dwarf) |*dwarf| {
        const pt: Zcu.PerThread = .{ .zcu = macho_file.base.comp.zcu.?, .tid = tid };
        try dwarf.flushModule(pt);

        self.debug_abbrev_dirty = false;
        self.debug_aranges_dirty = false;
        self.debug_strtab_dirty = false;
    }

    // The point of flushModule() is to commit changes, so in theory, nothing should
    // be dirty after this. However, it is possible for some things to remain
    // dirty because they fail to be written in the event of compile errors,
    // such as debug_line_header_dirty and debug_info_header_dirty.
    assert(!self.debug_abbrev_dirty);
    assert(!self.debug_aranges_dirty);
    assert(!self.debug_strtab_dirty);
}

pub fn getNavVAddr(
    self: *ZigObject,
    macho_file: *MachO,
    pt: Zcu.PerThread,
    nav_index: InternPool.Nav.Index,
    reloc_info: link.File.RelocInfo,
) !u64 {
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const nav = ip.getNav(nav_index);
    log.debug("getNavVAddr {}({d})", .{ nav.fqn.fmt(ip), nav_index });
    const sym_index = switch (ip.indexToKey(nav.status.resolved.val)) {
        .@"extern" => |@"extern"| try self.getGlobalSymbol(
            macho_file,
            nav.name.toSlice(ip),
            @"extern".lib_name.toSlice(ip),
        ),
        else => try self.getOrCreateMetadataForNav(macho_file, nav_index),
    };
    const sym = self.symbols.items[sym_index];
    const vaddr = sym.getAddress(.{}, macho_file);
    switch (reloc_info.parent) {
        .atom_index => |atom_index| {
            const parent_atom = self.symbols.items[atom_index].getAtom(macho_file).?;
            try parent_atom.addReloc(macho_file, .{
                .tag = .@"extern",
                .offset = @intCast(reloc_info.offset),
                .target = sym_index,
                .addend = reloc_info.addend,
                .type = .unsigned,
                .meta = .{
                    .pcrel = false,
                    .has_subtractor = false,
                    .length = 3,
                    .symbolnum = @intCast(sym.nlist_idx),
                },
            });
        },
        .debug_output => |debug_output| switch (debug_output) {
            .dwarf => |wip_nav| try wip_nav.infoExternalReloc(.{
                .source_off = @intCast(reloc_info.offset),
                .target_sym = sym_index,
                .target_off = reloc_info.addend,
            }),
            .plan9 => unreachable,
            .none => unreachable,
        },
    }
    return vaddr;
}

pub fn getUavVAddr(
    self: *ZigObject,
    macho_file: *MachO,
    uav: InternPool.Index,
    reloc_info: link.File.RelocInfo,
) !u64 {
    const sym_index = self.uavs.get(uav).?.symbol_index;
    const sym = self.symbols.items[sym_index];
    const vaddr = sym.getAddress(.{}, macho_file);
    switch (reloc_info.parent) {
        .atom_index => |atom_index| {
            const parent_atom = self.symbols.items[atom_index].getAtom(macho_file).?;
            try parent_atom.addReloc(macho_file, .{
                .tag = .@"extern",
                .offset = @intCast(reloc_info.offset),
                .target = sym_index,
                .addend = reloc_info.addend,
                .type = .unsigned,
                .meta = .{
                    .pcrel = false,
                    .has_subtractor = false,
                    .length = 3,
                    .symbolnum = @intCast(sym.nlist_idx),
                },
            });
        },
        .debug_output => |debug_output| switch (debug_output) {
            .dwarf => |wip_nav| try wip_nav.infoExternalReloc(.{
                .source_off = @intCast(reloc_info.offset),
                .target_sym = sym_index,
                .target_off = reloc_info.addend,
            }),
            .plan9 => unreachable,
            .none => unreachable,
        },
    }
    return vaddr;
}

pub fn lowerUav(
    self: *ZigObject,
    macho_file: *MachO,
    pt: Zcu.PerThread,
    uav: InternPool.Index,
    explicit_alignment: Atom.Alignment,
    src_loc: Zcu.LazySrcLoc,
) !codegen.GenResult {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const val = Value.fromInterned(uav);
    const uav_alignment = switch (explicit_alignment) {
        .none => val.typeOf(zcu).abiAlignment(zcu),
        else => explicit_alignment,
    };
    if (self.uavs.get(uav)) |metadata| {
        const sym = self.symbols.items[metadata.symbol_index];
        const existing_alignment = sym.getAtom(macho_file).?.alignment;
        if (uav_alignment.order(existing_alignment).compare(.lte))
            return .{ .mcv = .{ .load_symbol = sym.nlist_idx } };
    }

    var name_buf: [32]u8 = undefined;
    const name = std.fmt.bufPrint(&name_buf, "__anon_{d}", .{
        @intFromEnum(uav),
    }) catch unreachable;
    const res = self.lowerConst(
        macho_file,
        pt,
        name,
        val,
        uav_alignment,
        macho_file.zig_const_sect_index.?,
        src_loc,
    ) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => |e| return .{ .fail = try Zcu.ErrorMsg.create(
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
    try self.uavs.put(gpa, uav, .{ .symbol_index = sym_index });
    return .{ .mcv = .{
        .load_symbol = self.symbols.items[sym_index].nlist_idx,
    } };
}

fn freeNavMetadata(self: *ZigObject, macho_file: *MachO, sym_index: Symbol.Index) void {
    const sym = self.symbols.items[sym_index];
    sym.getAtom(macho_file).?.free(macho_file);
    log.debug("adding %{d} to local symbols free list", .{sym_index});
    // TODO redo this
    // TODO free GOT entry here
}

pub fn freeNav(self: *ZigObject, macho_file: *MachO, nav_index: InternPool.Nav.Index) void {
    const gpa = macho_file.base.comp.gpa;
    log.debug("freeNav 0x{x}", .{nav_index});

    if (self.navs.fetchRemove(nav_index)) |const_kv| {
        var kv = const_kv;
        const sym_index = kv.value.symbol_index;
        self.freeNavMetadata(macho_file, sym_index);
        kv.value.exports.deinit(gpa);
    }

    // TODO free decl in dSYM
}

pub fn updateFunc(
    self: *ZigObject,
    macho_file: *MachO,
    pt: Zcu.PerThread,
    func_index: InternPool.Index,
    air: Air,
    liveness: Liveness,
) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const func = zcu.funcInfo(func_index);

    const sym_index = try self.getOrCreateMetadataForNav(macho_file, func.owner_nav);
    self.symbols.items[sym_index].getAtom(macho_file).?.freeRelocs(macho_file);

    var code_buffer = std.ArrayList(u8).init(gpa);
    defer code_buffer.deinit();

    var dwarf_wip_nav = if (self.dwarf) |*dwarf| try dwarf.initWipNav(pt, func.owner_nav, sym_index) else null;
    defer if (dwarf_wip_nav) |*wip_nav| wip_nav.deinit();

    const res = try codegen.generateFunction(
        &macho_file.base,
        pt,
        zcu.navSrcLoc(func.owner_nav),
        func_index,
        air,
        liveness,
        &code_buffer,
        if (dwarf_wip_nav) |*wip_nav| .{ .dwarf = wip_nav } else .none,
    );

    const code = switch (res) {
        .ok => code_buffer.items,
        .fail => |em| {
            try zcu.failed_codegen.put(gpa, func.owner_nav, em);
            return;
        },
    };

    const sect_index = try self.getNavOutputSection(macho_file, zcu, func.owner_nav, code);
    const old_rva, const old_alignment = blk: {
        const atom = self.symbols.items[sym_index].getAtom(macho_file).?;
        break :blk .{ atom.value, atom.alignment };
    };
    try self.updateNavCode(macho_file, pt, func.owner_nav, sym_index, sect_index, code);
    const new_rva, const new_alignment = blk: {
        const atom = self.symbols.items[sym_index].getAtom(macho_file).?;
        break :blk .{ atom.value, atom.alignment };
    };

    if (dwarf_wip_nav) |*wip_nav| {
        const sym = self.symbols.items[sym_index];
        try self.dwarf.?.finishWipNav(
            pt,
            func.owner_nav,
            .{
                .index = sym_index,
                .addr = sym.getAddress(.{}, macho_file),
                .size = sym.getAtom(macho_file).?.size,
            },
            wip_nav,
        );
    }

    // Exports will be updated by `Zcu.processExports` after the update.
    if (old_rva != new_rva and old_rva > 0) {
        // If we had to reallocate the function, we re-use the existing slot for a trampoline.
        // In the rare case that the function has been further overaligned we skip creating a
        // trampoline and update all symbols referring this function.
        if (old_alignment.order(new_alignment) == .lt) {
            @panic("TODO update all symbols referring this function");
        }

        // Create a trampoline to the new location at `old_rva`.
        if (!self.symbols.items[sym_index].flags.trampoline) {
            const name = try std.fmt.allocPrint(gpa, "{s}$trampoline", .{
                self.symbols.items[sym_index].getName(macho_file),
            });
            defer gpa.free(name);
            const name_off = try self.addString(gpa, name);
            const tr_size = trampolineSize(macho_file.getTarget().cpu.arch);
            const tr_sym_index = try self.newSymbolWithAtom(gpa, name_off, macho_file);
            const tr_sym = &self.symbols.items[tr_sym_index];
            tr_sym.out_n_sect = macho_file.zig_text_sect_index.?;
            const tr_nlist = &self.symtab.items(.nlist)[tr_sym.nlist_idx];
            tr_nlist.n_sect = macho_file.zig_text_sect_index.? + 1;
            const tr_atom = tr_sym.getAtom(macho_file).?;
            tr_atom.value = old_rva;
            tr_atom.setAlive(true);
            tr_atom.alignment = old_alignment;
            tr_atom.out_n_sect = macho_file.zig_text_sect_index.?;
            tr_atom.size = tr_size;
            self.symtab.items(.size)[tr_sym.nlist_idx] = tr_size;
            const target_sym = &self.symbols.items[sym_index];
            target_sym.addExtra(.{ .trampoline = tr_sym_index }, macho_file);
            target_sym.flags.trampoline = true;
        }
        const target_sym = self.symbols.items[sym_index];
        const source_sym = self.symbols.items[target_sym.getExtra(macho_file).trampoline];
        try writeTrampoline(source_sym, target_sym, macho_file);
    }
}

pub fn updateNav(
    self: *ZigObject,
    macho_file: *MachO,
    pt: Zcu.PerThread,
    nav_index: InternPool.Nav.Index,
) link.File.UpdateNavError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const nav = ip.getNav(nav_index);

    const nav_init = switch (ip.indexToKey(nav.status.resolved.val)) {
        .func => .none,
        .variable => |variable| variable.init,
        .@"extern" => |@"extern"| {
            if (ip.isFunctionType(@"extern".ty)) return;
            // Extern variable gets a __got entry only
            const name = @"extern".name.toSlice(ip);
            const lib_name = @"extern".lib_name.toSlice(ip);
            const index = try self.getGlobalSymbol(macho_file, name, lib_name);
            const sym = &self.symbols.items[index];
            sym.flags.is_extern_ptr = true;
            return;
        },
        else => nav.status.resolved.val,
    };

    if (nav_init != .none and Value.fromInterned(nav_init).typeOf(zcu).hasRuntimeBits(zcu)) {
        const sym_index = try self.getOrCreateMetadataForNav(macho_file, nav_index);
        self.symbols.items[sym_index].getAtom(macho_file).?.freeRelocs(macho_file);

        var code_buffer = std.ArrayList(u8).init(zcu.gpa);
        defer code_buffer.deinit();

        var debug_wip_nav = if (self.dwarf) |*dwarf| try dwarf.initWipNav(pt, nav_index, sym_index) else null;
        defer if (debug_wip_nav) |*wip_nav| wip_nav.deinit();

        const res = try codegen.generateSymbol(
            &macho_file.base,
            pt,
            zcu.navSrcLoc(nav_index),
            Value.fromInterned(nav_init),
            &code_buffer,
            .{ .atom_index = sym_index },
        );

        const code = switch (res) {
            .ok => code_buffer.items,
            .fail => |em| {
                try zcu.failed_codegen.put(zcu.gpa, nav_index, em);
                return;
            },
        };
        const sect_index = try self.getNavOutputSection(macho_file, zcu, nav_index, code);
        if (isThreadlocal(macho_file, nav_index))
            try self.updateTlv(macho_file, pt, nav_index, sym_index, sect_index, code)
        else
            try self.updateNavCode(macho_file, pt, nav_index, sym_index, sect_index, code);

        if (debug_wip_nav) |*wip_nav| {
            const sym = self.symbols.items[sym_index];
            try self.dwarf.?.finishWipNav(
                pt,
                nav_index,
                .{
                    .index = sym_index,
                    .addr = sym.getAddress(.{}, macho_file),
                    .size = sym.getAtom(macho_file).?.size,
                },
                wip_nav,
            );
        }
    } else if (self.dwarf) |*dwarf| try dwarf.updateComptimeNav(pt, nav_index);

    // Exports will be updated by `Zcu.processExports` after the update.
}

fn updateNavCode(
    self: *ZigObject,
    macho_file: *MachO,
    pt: Zcu.PerThread,
    nav_index: InternPool.Nav.Index,
    sym_index: Symbol.Index,
    sect_index: u8,
    code: []const u8,
) !void {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;
    const nav = ip.getNav(nav_index);

    log.debug("updateNavCode {} 0x{x}", .{ nav.fqn.fmt(ip), nav_index });

    const required_alignment = pt.navAlignment(nav_index).max(
        target_util.minFunctionAlignment(zcu.navFileScope(nav_index).mod.resolved_target.result),
    );

    const sect = &macho_file.sections.items(.header)[sect_index];
    const sym = &self.symbols.items[sym_index];
    const nlist = &self.symtab.items(.nlist)[sym.nlist_idx];
    const atom = sym.getAtom(macho_file).?;

    sym.out_n_sect = sect_index;
    atom.out_n_sect = sect_index;

    const sym_name = try std.fmt.allocPrintZ(gpa, "_{s}", .{nav.fqn.toSlice(ip)});
    defer gpa.free(sym_name);
    sym.name = try self.addString(gpa, sym_name);
    atom.setAlive(true);
    atom.name = sym.name;
    nlist.n_strx = sym.name.pos;
    nlist.n_type = macho.N_SECT;
    nlist.n_sect = sect_index + 1;
    self.symtab.items(.size)[sym.nlist_idx] = code.len;

    const old_size = atom.size;
    const old_vaddr = atom.value;
    atom.alignment = required_alignment;
    atom.size = code.len;

    if (old_size > 0) {
        const capacity = atom.capacity(macho_file);
        const need_realloc = code.len > capacity or !required_alignment.check(atom.value);

        if (need_realloc) {
            try atom.grow(macho_file);
            log.debug("growing {} from 0x{x} to 0x{x}", .{ nav.fqn.fmt(ip), old_vaddr, atom.value });
            if (old_vaddr != atom.value) {
                sym.value = 0;
                nlist.n_value = 0;
            }
        } else if (code.len < old_size) {
            atom.shrink(macho_file);
        } else if (self.getAtom(atom.next_index) == null) {
            const needed_size = atom.value + code.len;
            sect.size = needed_size;
        }
    } else {
        try atom.allocate(macho_file);
        errdefer self.freeNavMetadata(macho_file, sym_index);

        sym.value = 0;
        nlist.n_value = 0;
    }

    if (!sect.isZerofill()) {
        const file_offset = sect.offset + atom.value;
        try macho_file.base.file.?.pwriteAll(code, file_offset);
    }
}

/// Lowering a TLV on macOS involves two stages:
/// 1. first we lower the initializer into appopriate section (__thread_data or __thread_bss)
/// 2. next, we create a corresponding threadlocal variable descriptor in __thread_vars
fn updateTlv(
    self: *ZigObject,
    macho_file: *MachO,
    pt: Zcu.PerThread,
    nav_index: InternPool.Nav.Index,
    sym_index: Symbol.Index,
    sect_index: u8,
    code: []const u8,
) !void {
    const ip = &pt.zcu.intern_pool;
    const nav = ip.getNav(nav_index);

    log.debug("updateTlv {} (0x{x})", .{ nav.fqn.fmt(ip), nav_index });

    // 1. Lower TLV initializer
    const init_sym_index = try self.createTlvInitializer(
        macho_file,
        nav.fqn.toSlice(ip),
        pt.navAlignment(nav_index),
        sect_index,
        code,
    );

    // 2. Create TLV descriptor
    try self.createTlvDescriptor(macho_file, sym_index, init_sym_index, nav.fqn.toSlice(ip));
}

fn createTlvInitializer(
    self: *ZigObject,
    macho_file: *MachO,
    name: []const u8,
    alignment: Atom.Alignment,
    sect_index: u8,
    code: []const u8,
) !Symbol.Index {
    const gpa = macho_file.base.comp.gpa;
    const sym_name = try std.fmt.allocPrint(gpa, "{s}$tlv$init", .{name});
    defer gpa.free(sym_name);
    const string = try self.addString(gpa, sym_name);

    const sym_index = try self.newSymbolWithAtom(gpa, string, macho_file);
    const sym = &self.symbols.items[sym_index];
    const nlist = &self.symtab.items(.nlist)[sym.nlist_idx];
    const atom = sym.getAtom(macho_file).?;
    sym.out_n_sect = sect_index;
    atom.out_n_sect = sect_index;
    atom.setAlive(true);
    atom.alignment = alignment;
    atom.size = code.len;
    nlist.n_sect = sect_index + 1;
    self.symtab.items(.size)[sym.nlist_idx] = code.len;

    const slice = macho_file.sections.slice();
    const header = slice.items(.header)[sect_index];

    const gop = try self.tlv_initializers.getOrPut(gpa, atom.atom_index);
    assert(!gop.found_existing); // TODO incremental updates
    gop.value_ptr.* = .{ .symbol_index = sym_index };

    // We only store the data for the TLV if it's non-zerofill.
    if (!header.isZerofill()) {
        gop.value_ptr.data = try gpa.dupe(u8, code);
    }

    return sym_index;
}

fn createTlvDescriptor(
    self: *ZigObject,
    macho_file: *MachO,
    sym_index: Symbol.Index,
    init_sym_index: Symbol.Index,
    name: []const u8,
) !void {
    const gpa = macho_file.base.comp.gpa;

    const sym = &self.symbols.items[sym_index];
    const nlist = &self.symtab.items(.nlist)[sym.nlist_idx];
    const atom = sym.getAtom(macho_file).?;
    const alignment = Atom.Alignment.fromNonzeroByteUnits(@alignOf(u64));
    const size: u64 = @sizeOf(u64) * 3;

    const sect_index = macho_file.getSectionByName("__DATA", "__thread_vars") orelse
        try macho_file.addSection("__DATA", "__thread_vars", .{
        .flags = macho.S_THREAD_LOCAL_VARIABLES,
    });
    sym.out_n_sect = sect_index;
    atom.out_n_sect = sect_index;

    sym.value = 0;
    sym.name = try self.addString(gpa, name);
    atom.setAlive(true);
    atom.name = sym.name;
    nlist.n_strx = sym.name.pos;
    nlist.n_sect = sect_index + 1;
    nlist.n_type = macho.N_SECT;
    nlist.n_value = 0;
    self.symtab.items(.size)[sym.nlist_idx] = size;

    atom.alignment = alignment;
    atom.size = size;

    const tlv_bootstrap_index = try self.getGlobalSymbol(macho_file, "_tlv_bootstrap", null);
    try atom.addReloc(macho_file, .{
        .tag = .@"extern",
        .offset = 0,
        .target = tlv_bootstrap_index,
        .addend = 0,
        .type = .unsigned,
        .meta = .{
            .pcrel = false,
            .has_subtractor = false,
            .length = 3,
            .symbolnum = @intCast(tlv_bootstrap_index),
        },
    });
    try atom.addReloc(macho_file, .{
        .tag = .@"extern",
        .offset = 16,
        .target = init_sym_index,
        .addend = 0,
        .type = .unsigned,
        .meta = .{
            .pcrel = false,
            .has_subtractor = false,
            .length = 3,
            .symbolnum = @intCast(init_sym_index),
        },
    });
}

fn getNavOutputSection(
    self: *ZigObject,
    macho_file: *MachO,
    zcu: *Zcu,
    nav_index: InternPool.Nav.Index,
    code: []const u8,
) error{OutOfMemory}!u8 {
    _ = self;
    const ip = &zcu.intern_pool;
    const any_non_single_threaded = macho_file.base.comp.config.any_non_single_threaded;
    const nav_val = zcu.navValue(nav_index);
    if (ip.isFunctionType(nav_val.typeOf(zcu).toIntern())) return macho_file.zig_text_sect_index.?;
    const is_const, const is_threadlocal, const nav_init = switch (ip.indexToKey(nav_val.toIntern())) {
        .variable => |variable| .{ false, variable.is_threadlocal, variable.init },
        .@"extern" => |@"extern"| .{ @"extern".is_const, @"extern".is_threadlocal, .none },
        else => .{ true, false, nav_val.toIntern() },
    };
    if (any_non_single_threaded and is_threadlocal) {
        for (code) |byte| {
            if (byte != 0) break;
        } else return macho_file.getSectionByName("__DATA", "__thread_bss") orelse try macho_file.addSection(
            "__DATA",
            "__thread_bss",
            .{ .flags = macho.S_THREAD_LOCAL_ZEROFILL },
        );
        return macho_file.getSectionByName("__DATA", "__thread_data") orelse try macho_file.addSection(
            "__DATA",
            "__thread_data",
            .{ .flags = macho.S_THREAD_LOCAL_REGULAR },
        );
    }
    if (is_const) return macho_file.zig_const_sect_index.?;
    if (nav_init != .none and Value.fromInterned(nav_init).isUndefDeep(zcu))
        return switch (zcu.navFileScope(nav_index).mod.optimize_mode) {
            .Debug, .ReleaseSafe => macho_file.zig_data_sect_index.?,
            .ReleaseFast, .ReleaseSmall => macho_file.zig_bss_sect_index.?,
        };
    for (code) |byte| {
        if (byte != 0) break;
    } else return macho_file.zig_bss_sect_index.?;
    return macho_file.zig_data_sect_index.?;
}

const LowerConstResult = union(enum) {
    ok: Symbol.Index,
    fail: *Zcu.ErrorMsg,
};

fn lowerConst(
    self: *ZigObject,
    macho_file: *MachO,
    pt: Zcu.PerThread,
    name: []const u8,
    val: Value,
    required_alignment: Atom.Alignment,
    output_section_index: u8,
    src_loc: Zcu.LazySrcLoc,
) !LowerConstResult {
    const gpa = macho_file.base.comp.gpa;

    var code_buffer = std.ArrayList(u8).init(gpa);
    defer code_buffer.deinit();

    const name_str = try self.addString(gpa, name);
    const sym_index = try self.newSymbolWithAtom(gpa, name_str, macho_file);

    const res = try codegen.generateSymbol(
        &macho_file.base,
        pt,
        src_loc,
        val,
        &code_buffer,
        .{ .atom_index = sym_index },
    );
    const code = switch (res) {
        .ok => code_buffer.items,
        .fail => |em| return .{ .fail = em },
    };

    const sym = &self.symbols.items[sym_index];
    sym.out_n_sect = output_section_index;

    const nlist = &self.symtab.items(.nlist)[sym.nlist_idx];
    nlist.n_sect = output_section_index + 1;
    self.symtab.items(.size)[sym.nlist_idx] = code.len;

    const atom = sym.getAtom(macho_file).?;
    atom.setAlive(true);
    atom.alignment = required_alignment;
    atom.size = code.len;
    atom.out_n_sect = output_section_index;

    try atom.allocate(macho_file);
    // TODO rename and re-audit this method
    errdefer self.freeNavMetadata(macho_file, sym_index);

    const sect = macho_file.sections.items(.header)[output_section_index];
    const file_offset = sect.offset + atom.value;
    try macho_file.base.file.?.pwriteAll(code, file_offset);

    return .{ .ok = sym_index };
}

pub fn updateExports(
    self: *ZigObject,
    macho_file: *MachO,
    pt: Zcu.PerThread,
    exported: Zcu.Exported,
    export_indices: []const u32,
) link.File.UpdateExportsError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const zcu = pt.zcu;
    const gpa = macho_file.base.comp.gpa;
    const metadata = switch (exported) {
        .nav => |nav| blk: {
            _ = try self.getOrCreateMetadataForNav(macho_file, nav);
            break :blk self.navs.getPtr(nav).?;
        },
        .uav => |uav| self.uavs.getPtr(uav) orelse blk: {
            const first_exp = zcu.all_exports.items[export_indices[0]];
            const res = try self.lowerUav(macho_file, pt, uav, .none, first_exp.src);
            switch (res) {
                .mcv => {},
                .fail => |em| {
                    // TODO maybe it's enough to return an error here and let Zcu.processExportsInner
                    // handle the error?
                    try zcu.failed_exports.ensureUnusedCapacity(zcu.gpa, 1);
                    zcu.failed_exports.putAssumeCapacityNoClobber(export_indices[0], em);
                    return;
                },
            }
            break :blk self.uavs.getPtr(uav).?;
        },
    };
    const sym_index = metadata.symbol_index;
    const nlist_idx = self.symbols.items[sym_index].nlist_idx;
    const nlist = self.symtab.items(.nlist)[nlist_idx];

    for (export_indices) |export_idx| {
        const exp = zcu.all_exports.items[export_idx];
        if (exp.opts.section.unwrap()) |section_name| {
            if (!section_name.eqlSlice("__text", &zcu.intern_pool)) {
                try zcu.failed_exports.ensureUnusedCapacity(zcu.gpa, 1);
                zcu.failed_exports.putAssumeCapacityNoClobber(export_idx, try Zcu.ErrorMsg.create(
                    gpa,
                    exp.src,
                    "Unimplemented: ExportOptions.section",
                    .{},
                ));
                continue;
            }
        }
        if (exp.opts.linkage == .link_once) {
            try zcu.failed_exports.putNoClobber(zcu.gpa, export_idx, try Zcu.ErrorMsg.create(
                gpa,
                exp.src,
                "Unimplemented: GlobalLinkage.link_once",
                .{},
            ));
            continue;
        }

        const exp_name = exp.opts.name.toSlice(&zcu.intern_pool);
        const global_nlist_index = if (metadata.@"export"(self, exp_name)) |exp_index|
            exp_index.*
        else blk: {
            const global_nlist_index = try self.getGlobalSymbol(macho_file, exp_name, null);
            try metadata.exports.append(gpa, global_nlist_index);
            break :blk global_nlist_index;
        };
        const global_nlist = &self.symtab.items(.nlist)[global_nlist_index];
        const atom_index = self.symtab.items(.atom)[nlist_idx];
        const global_sym = &self.symbols.items[global_nlist_index];
        global_nlist.n_value = nlist.n_value;
        global_nlist.n_sect = nlist.n_sect;
        global_nlist.n_type = macho.N_EXT | macho.N_SECT;
        self.symtab.items(.size)[global_nlist_index] = self.symtab.items(.size)[nlist_idx];
        self.symtab.items(.atom)[global_nlist_index] = atom_index;
        global_sym.atom_ref = .{ .index = atom_index, .file = self.index };

        switch (exp.opts.linkage) {
            .internal => {
                // Symbol should be hidden, or in MachO lingo, private extern.
                global_nlist.n_type |= macho.N_PEXT;
                global_sym.visibility = .hidden;
            },
            .strong => {
                global_sym.visibility = .global;
            },
            .weak => {
                // Weak linkage is specified as part of n_desc field.
                // Symbol's n_type is like for a symbol with strong linkage.
                global_nlist.n_desc |= macho.N_WEAK_DEF;
                global_sym.visibility = .global;
                global_sym.flags.weak = true;
            },
            else => unreachable,
        }
    }
}

fn updateLazySymbol(
    self: *ZigObject,
    macho_file: *MachO,
    pt: Zcu.PerThread,
    lazy_sym: link.File.LazySymbol,
    symbol_index: Symbol.Index,
) !void {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;

    var required_alignment: Atom.Alignment = .none;
    var code_buffer = std.ArrayList(u8).init(gpa);
    defer code_buffer.deinit();

    const name_str = blk: {
        const name = try std.fmt.allocPrint(gpa, "__lazy_{s}_{}", .{
            @tagName(lazy_sym.kind),
            Type.fromInterned(lazy_sym.ty).fmt(pt),
        });
        defer gpa.free(name);
        break :blk try self.addString(gpa, name);
    };

    const src = Type.fromInterned(lazy_sym.ty).srcLocOrNull(zcu) orelse Zcu.LazySrcLoc.unneeded;
    const res = try codegen.generateLazySymbol(
        &macho_file.base,
        pt,
        src,
        lazy_sym,
        &required_alignment,
        &code_buffer,
        .none,
        .{ .atom_index = symbol_index },
    );
    const code = switch (res) {
        .ok => code_buffer.items,
        .fail => |em| {
            log.err("{s}", .{em.msg});
            return error.CodegenFail;
        },
    };

    const output_section_index = switch (lazy_sym.kind) {
        .code => macho_file.zig_text_sect_index.?,
        .const_data => macho_file.zig_const_sect_index.?,
    };
    const sym = &self.symbols.items[symbol_index];
    sym.name = name_str;
    sym.out_n_sect = output_section_index;

    const nlist = &self.symtab.items(.nlist)[sym.nlist_idx];
    nlist.n_strx = name_str.pos;
    nlist.n_type = macho.N_SECT;
    nlist.n_sect = output_section_index + 1;
    self.symtab.items(.size)[sym.nlist_idx] = code.len;

    const atom = sym.getAtom(macho_file).?;
    atom.setAlive(true);
    atom.name = name_str;
    atom.alignment = required_alignment;
    atom.size = code.len;
    atom.out_n_sect = output_section_index;

    try atom.allocate(macho_file);
    errdefer self.freeNavMetadata(macho_file, symbol_index);

    sym.value = 0;
    nlist.n_value = 0;

    const sect = macho_file.sections.items(.header)[output_section_index];
    const file_offset = sect.offset + atom.value;
    try macho_file.base.file.?.pwriteAll(code, file_offset);
}

/// Must be called only after a successful call to `updateNav`.
pub fn updateNavLineNumber(
    self: *ZigObject,
    pt: Zcu.PerThread,
    nav_index: InternPool.Nav.Index,
) !void {
    if (self.dwarf) |*dwarf| {
        try dwarf.updateNavLineNumber(pt.zcu, nav_index);
    }
}

pub fn deleteExport(
    self: *ZigObject,
    macho_file: *MachO,
    exported: Zcu.Exported,
    name: InternPool.NullTerminatedString,
) void {
    const zcu = macho_file.base.comp.zcu.?;

    const metadata = switch (exported) {
        .nav => |nav| self.navs.getPtr(nav),
        .uav => |uav| self.uavs.getPtr(uav),
    } orelse return;
    const nlist_index = metadata.@"export"(self, name.toSlice(&zcu.intern_pool)) orelse return;

    log.debug("deleting export '{}'", .{name.fmt(&zcu.intern_pool)});

    const nlist = &self.symtab.items(.nlist)[nlist_index.*];
    self.symtab.items(.size)[nlist_index.*] = 0;
    _ = self.globals_lookup.remove(nlist.n_strx);
    // TODO actually remove the export
    // const sym_index = macho_file.globals.get(nlist.n_strx).?;
    // const sym = &self.symbols.items[sym_index];
    // if (sym.file == self.index) {
    //     sym.* = .{};
    // }
    nlist.* = MachO.null_sym;
}

pub fn getGlobalSymbol(self: *ZigObject, macho_file: *MachO, name: []const u8, lib_name: ?[]const u8) !u32 {
    _ = lib_name;
    const gpa = macho_file.base.comp.gpa;
    const sym_name = try std.fmt.allocPrint(gpa, "_{s}", .{name});
    defer gpa.free(sym_name);
    const name_str = try self.addString(gpa, sym_name);
    const lookup_gop = try self.globals_lookup.getOrPut(gpa, name_str.pos);
    if (!lookup_gop.found_existing) {
        const sym_index = try self.newSymbol(gpa, name_str, .{});
        const sym = &self.symbols.items[sym_index];
        lookup_gop.value_ptr.* = sym.nlist_idx;
    }
    return lookup_gop.value_ptr.*;
}

const max_trampoline_len = 12;

fn trampolineSize(cpu_arch: std.Target.Cpu.Arch) u64 {
    const len = switch (cpu_arch) {
        .x86_64 => 5, // jmp rel32
        else => @panic("TODO implement trampoline size for this CPU arch"),
    };
    comptime assert(len <= max_trampoline_len);
    return len;
}

fn writeTrampoline(tr_sym: Symbol, target: Symbol, macho_file: *MachO) !void {
    const atom = tr_sym.getAtom(macho_file).?;
    const header = macho_file.sections.items(.header)[atom.out_n_sect];
    const fileoff = header.offset + atom.value;
    const source_addr = tr_sym.getAddress(.{}, macho_file);
    const target_addr = target.getAddress(.{ .trampoline = false }, macho_file);
    var buf: [max_trampoline_len]u8 = undefined;
    const out = switch (macho_file.getTarget().cpu.arch) {
        .x86_64 => try x86_64.writeTrampolineCode(source_addr, target_addr, &buf),
        else => @panic("TODO implement write trampoline for this CPU arch"),
    };
    try macho_file.base.file.?.pwriteAll(out, fileoff);
}

pub fn getOrCreateMetadataForNav(
    self: *ZigObject,
    macho_file: *MachO,
    nav_index: InternPool.Nav.Index,
) !Symbol.Index {
    const gpa = macho_file.base.comp.gpa;
    const gop = try self.navs.getOrPut(gpa, nav_index);
    if (!gop.found_existing) {
        const sym_index = try self.newSymbolWithAtom(gpa, .{}, macho_file);
        const sym = &self.symbols.items[sym_index];
        if (isThreadlocal(macho_file, nav_index)) {
            sym.flags.tlv = true;
        }
        gop.value_ptr.* = .{ .symbol_index = sym_index };
    }
    return gop.value_ptr.symbol_index;
}

pub fn getOrCreateMetadataForLazySymbol(
    self: *ZigObject,
    macho_file: *MachO,
    pt: Zcu.PerThread,
    lazy_sym: link.File.LazySymbol,
) !Symbol.Index {
    const gop = try self.lazy_syms.getOrPut(pt.zcu.gpa, lazy_sym.ty);
    errdefer _ = if (!gop.found_existing) self.lazy_syms.pop();
    if (!gop.found_existing) gop.value_ptr.* = .{};
    const symbol_index_ptr, const state_ptr = switch (lazy_sym.kind) {
        .code => .{ &gop.value_ptr.text_symbol_index, &gop.value_ptr.text_state },
        .const_data => .{ &gop.value_ptr.const_symbol_index, &gop.value_ptr.const_state },
    };
    switch (state_ptr.*) {
        .unused => symbol_index_ptr.* = try self.newSymbolWithAtom(pt.zcu.gpa, .{}, macho_file),
        .pending_flush => return symbol_index_ptr.*,
        .flushed => {},
    }
    state_ptr.* = .pending_flush;
    const symbol_index = symbol_index_ptr.*;
    // anyerror needs to be deferred until flushModule
    if (lazy_sym.ty != .anyerror_type) try self.updateLazySymbol(macho_file, pt, lazy_sym, symbol_index);
    return symbol_index;
}

fn isThreadlocal(macho_file: *MachO, nav_index: InternPool.Nav.Index) bool {
    if (!macho_file.base.comp.config.any_non_single_threaded)
        return false;
    const ip = &macho_file.base.comp.zcu.?.intern_pool;
    return switch (ip.indexToKey(ip.getNav(nav_index).status.resolved.val)) {
        .variable => |variable| variable.is_threadlocal,
        .@"extern" => |@"extern"| @"extern".is_threadlocal,
        else => false,
    };
}

fn addAtom(self: *ZigObject, allocator: Allocator) !Atom.Index {
    try self.atoms.ensureUnusedCapacity(allocator, 1);
    try self.atoms_extra.ensureUnusedCapacity(allocator, @sizeOf(Atom.Extra));
    return self.addAtomAssumeCapacity();
}

fn addAtomAssumeCapacity(self: *ZigObject) Atom.Index {
    const atom_index: Atom.Index = @intCast(self.atoms.items.len);
    const atom = self.atoms.addOneAssumeCapacity();
    atom.* = .{
        .file = self.index,
        .atom_index = atom_index,
        .extra = self.addAtomExtraAssumeCapacity(.{}),
    };
    return atom_index;
}

pub fn getAtom(self: *ZigObject, atom_index: Atom.Index) ?*Atom {
    if (atom_index == 0) return null;
    assert(atom_index < self.atoms.items.len);
    return &self.atoms.items[atom_index];
}

pub fn getAtoms(self: *ZigObject) []const Atom.Index {
    return self.atoms_indexes.items;
}

fn addAtomExtra(self: *ZigObject, allocator: Allocator, extra: Atom.Extra) !u32 {
    const fields = @typeInfo(Atom.Extra).@"struct".fields;
    try self.atoms_extra.ensureUnusedCapacity(allocator, fields.len);
    return self.addAtomExtraAssumeCapacity(extra);
}

fn addAtomExtraAssumeCapacity(self: *ZigObject, extra: Atom.Extra) u32 {
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

pub fn getAtomExtra(self: ZigObject, index: u32) Atom.Extra {
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

pub fn setAtomExtra(self: *ZigObject, index: u32, extra: Atom.Extra) void {
    assert(index > 0);
    const fields = @typeInfo(Atom.Extra).@"struct".fields;
    inline for (fields, 0..) |field, i| {
        self.atoms_extra.items[index + i] = switch (field.type) {
            u32 => @field(extra, field.name),
            else => @compileError("bad field type"),
        };
    }
}

fn addSymbol(self: *ZigObject, allocator: Allocator) !Symbol.Index {
    try self.symbols.ensureUnusedCapacity(allocator, 1);
    return self.addSymbolAssumeCapacity();
}

fn addSymbolAssumeCapacity(self: *ZigObject) Symbol.Index {
    const index: Symbol.Index = @intCast(self.symbols.items.len);
    const symbol = self.symbols.addOneAssumeCapacity();
    symbol.* = .{ .file = self.index };
    return index;
}

pub fn getSymbolRef(self: ZigObject, index: Symbol.Index, macho_file: *MachO) MachO.Ref {
    const global_index = self.globals.items[index];
    if (macho_file.resolver.get(global_index)) |ref| return ref;
    return .{ .index = index, .file = self.index };
}

pub fn addSymbolExtra(self: *ZigObject, allocator: Allocator, extra: Symbol.Extra) !u32 {
    const fields = @typeInfo(Symbol.Extra).@"struct".fields;
    try self.symbols_extra.ensureUnusedCapacity(allocator, fields.len);
    return self.addSymbolExtraAssumeCapacity(extra);
}

fn addSymbolExtraAssumeCapacity(self: *ZigObject, extra: Symbol.Extra) u32 {
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

pub fn getSymbolExtra(self: ZigObject, index: u32) Symbol.Extra {
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

pub fn setSymbolExtra(self: *ZigObject, index: u32, extra: Symbol.Extra) void {
    const fields = @typeInfo(Symbol.Extra).@"struct".fields;
    inline for (fields, 0..) |field, i| {
        self.symbols_extra.items[index + i] = switch (field.type) {
            u32 => @field(extra, field.name),
            else => @compileError("bad field type"),
        };
    }
}

fn addString(self: *ZigObject, allocator: Allocator, string: []const u8) !MachO.String {
    const off = try self.strtab.insert(allocator, string);
    return .{ .pos = off, .len = @intCast(string.len + 1) };
}

pub fn getString(self: ZigObject, string: MachO.String) [:0]const u8 {
    if (string.len == 0) return "";
    return self.strtab.buffer.items[string.pos..][0 .. string.len - 1 :0];
}

pub fn asFile(self: *ZigObject) File {
    return .{ .zig_object = self };
}

pub fn fmtSymtab(self: *ZigObject, macho_file: *MachO) std.fmt.Formatter(formatSymtab) {
    return .{ .data = .{
        .self = self,
        .macho_file = macho_file,
    } };
}

const FormatContext = struct {
    self: *ZigObject,
    macho_file: *MachO,
};

fn formatSymtab(
    ctx: FormatContext,
    comptime unused_fmt_string: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = unused_fmt_string;
    _ = options;
    try writer.writeAll("  symbols\n");
    const self = ctx.self;
    const macho_file = ctx.macho_file;
    for (self.symbols.items, 0..) |sym, i| {
        const ref = self.getSymbolRef(@intCast(i), macho_file);
        if (ref.getFile(macho_file) == null) {
            // TODO any better way of handling this?
            try writer.print("    {s} : unclaimed\n", .{sym.getName(macho_file)});
        } else {
            try writer.print("    {}\n", .{ref.getSymbol(macho_file).?.fmt(macho_file)});
        }
    }
}

pub fn fmtAtoms(self: *ZigObject, macho_file: *MachO) std.fmt.Formatter(formatAtoms) {
    return .{ .data = .{
        .self = self,
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
    const self = ctx.self;
    const macho_file = ctx.macho_file;
    try writer.writeAll("  atoms\n");
    for (self.getAtoms()) |atom_index| {
        const atom = self.getAtom(atom_index) orelse continue;
        try writer.print("    {}\n", .{atom.fmt(macho_file)});
    }
}

const AvMetadata = struct {
    symbol_index: Symbol.Index,
    /// A list of all exports aliases of this Av.
    exports: std.ArrayListUnmanaged(Symbol.Index) = .empty,

    fn @"export"(m: AvMetadata, zig_object: *ZigObject, name: []const u8) ?*u32 {
        for (m.exports.items) |*exp| {
            const nlist = zig_object.symtab.items(.nlist)[exp.*];
            const exp_name = zig_object.strtab.getAssumeExists(nlist.n_strx);
            if (mem.eql(u8, name, exp_name)) return exp;
        }
        return null;
    }
};

const LazySymbolMetadata = struct {
    const State = enum { unused, pending_flush, flushed };
    text_symbol_index: Symbol.Index = undefined,
    const_symbol_index: Symbol.Index = undefined,
    text_state: State = .unused,
    const_state: State = .unused,
};

const TlvInitializer = struct {
    symbol_index: Symbol.Index,
    data: []const u8 = &[0]u8{},

    fn deinit(tlv_init: *TlvInitializer, allocator: Allocator) void {
        allocator.free(tlv_init.data);
    }
};

const NavTable = std.AutoArrayHashMapUnmanaged(InternPool.Nav.Index, AvMetadata);
const UavTable = std.AutoArrayHashMapUnmanaged(InternPool.Index, AvMetadata);
const LazySymbolTable = std.AutoArrayHashMapUnmanaged(InternPool.Index, LazySymbolMetadata);
const RelocationTable = std.ArrayListUnmanaged(std.ArrayListUnmanaged(Relocation));
const TlvInitializerTable = std.AutoArrayHashMapUnmanaged(Atom.Index, TlvInitializer);

const x86_64 = struct {
    fn writeTrampolineCode(source_addr: u64, target_addr: u64, buf: *[max_trampoline_len]u8) ![]u8 {
        const disp = @as(i64, @intCast(target_addr)) - @as(i64, @intCast(source_addr)) - 5;
        var bytes = [_]u8{
            0xe9, 0x00, 0x00, 0x00, 0x00, // jmp rel32
        };
        assert(bytes.len == trampolineSize(.x86_64));
        mem.writeInt(i32, bytes[1..][0..4], @intCast(disp), .little);
        @memcpy(buf[0..bytes.len], &bytes);
        return buf[0..bytes.len];
    }
};

const assert = std.debug.assert;
const builtin = @import("builtin");
const codegen = @import("../../codegen.zig");
const link = @import("../../link.zig");
const log = std.log.scoped(.link);
const macho = std.macho;
const mem = std.mem;
const target_util = @import("../../target.zig");
const trace = @import("../../tracy.zig").trace;
const std = @import("std");

const Air = @import("../../Air.zig");
const Allocator = std.mem.Allocator;
const Archive = @import("Archive.zig");
const Atom = @import("Atom.zig");
const Dwarf = @import("../Dwarf.zig");
const File = @import("file.zig").File;
const InternPool = @import("../../InternPool.zig");
const Liveness = @import("../../Liveness.zig");
const MachO = @import("../MachO.zig");
const Nlist = Object.Nlist;
const Zcu = @import("../../Zcu.zig");
const Object = @import("Object.zig");
const Relocation = @import("Relocation.zig");
const Symbol = @import("Symbol.zig");
const StringTable = @import("../StringTable.zig");
const Type = @import("../../Type.zig");
const Value = @import("../../Value.zig");
const AnalUnit = InternPool.AnalUnit;
const ZigObject = @This();
