index: File.Index,

sections: std.MultiArrayList(Section) = .{},
atoms: std.ArrayListUnmanaged(Atom) = .empty,
atoms_indexes: std.ArrayListUnmanaged(Atom.Index) = .empty,
atoms_extra: std.ArrayListUnmanaged(u32) = .empty,
symtab: std.ArrayListUnmanaged(macho.nlist_64) = .empty,
strtab: std.ArrayListUnmanaged(u8) = .empty,
symbols: std.ArrayListUnmanaged(Symbol) = .empty,
symbols_extra: std.ArrayListUnmanaged(u32) = .empty,
globals: std.ArrayListUnmanaged(MachO.SymbolResolver.Index) = .empty,

objc_methnames: std.ArrayListUnmanaged(u8) = .empty,
objc_selrefs: [@sizeOf(u64)]u8 = [_]u8{0} ** @sizeOf(u64),

force_undefined: std.ArrayListUnmanaged(Symbol.Index) = .empty,
entry_index: ?Symbol.Index = null,
dyld_stub_binder_index: ?Symbol.Index = null,
dyld_private_index: ?Symbol.Index = null,
objc_msg_send_index: ?Symbol.Index = null,
mh_execute_header_index: ?Symbol.Index = null,
mh_dylib_header_index: ?Symbol.Index = null,
dso_handle_index: ?Symbol.Index = null,
boundary_symbols: std.ArrayListUnmanaged(Symbol.Index) = .empty,

output_symtab_ctx: MachO.SymtabCtx = .{},

pub fn deinit(self: *InternalObject, allocator: Allocator) void {
    for (self.sections.items(.relocs)) |*relocs| {
        relocs.deinit(allocator);
    }
    self.sections.deinit(allocator);
    self.atoms.deinit(allocator);
    self.atoms_indexes.deinit(allocator);
    self.atoms_extra.deinit(allocator);
    self.symtab.deinit(allocator);
    self.strtab.deinit(allocator);
    self.symbols.deinit(allocator);
    self.symbols_extra.deinit(allocator);
    self.globals.deinit(allocator);
    self.objc_methnames.deinit(allocator);
    self.force_undefined.deinit(allocator);
    self.boundary_symbols.deinit(allocator);
}

pub fn init(self: *InternalObject, allocator: Allocator) !void {
    // Atom at index 0 is reserved as null atom.
    try self.atoms.append(allocator, .{ .extra = try self.addAtomExtra(allocator, .{}) });
    // Null byte in strtab
    try self.strtab.append(allocator, 0);
}

pub fn initSymbols(self: *InternalObject, macho_file: *MachO) !void {
    const newSymbolAssumeCapacity = struct {
        fn newSymbolAssumeCapacity(obj: *InternalObject, name: MachO.String, args: struct {
            type: u8 = macho.N_UNDF | macho.N_EXT,
            desc: u16 = 0,
        }) Symbol.Index {
            const index = obj.addSymbolAssumeCapacity();
            const symbol = &obj.symbols.items[index];
            symbol.name = name;
            symbol.extra = obj.addSymbolExtraAssumeCapacity(.{});
            symbol.flags.dyn_ref = args.desc & macho.REFERENCED_DYNAMICALLY != 0;
            symbol.visibility = if (args.type & macho.N_EXT != 0) blk: {
                break :blk if (args.type & macho.N_PEXT != 0) .hidden else .global;
            } else .local;

            const nlist_idx: u32 = @intCast(obj.symtab.items.len);
            const nlist = obj.symtab.addOneAssumeCapacity();
            nlist.* = .{
                .n_strx = name.pos,
                .n_type = args.type,
                .n_sect = 0,
                .n_desc = args.desc,
                .n_value = 0,
            };
            symbol.nlist_idx = nlist_idx;
            return index;
        }
    }.newSymbolAssumeCapacity;

    const gpa = macho_file.base.comp.gpa;
    var nsyms = macho_file.base.comp.force_undefined_symbols.keys().len;
    nsyms += 1; // dyld_stub_binder
    nsyms += 1; // _objc_msgSend
    if (!macho_file.base.isDynLib()) {
        nsyms += 1; // entry
        nsyms += 1; // __mh_execute_header
    } else {
        nsyms += 1; // __mh_dylib_header
    }
    nsyms += 1; // ___dso_handle
    nsyms += 1; // dyld_private

    try self.symbols.ensureTotalCapacityPrecise(gpa, nsyms);
    try self.symbols_extra.ensureTotalCapacityPrecise(gpa, nsyms * @sizeOf(Symbol.Extra));
    try self.symtab.ensureTotalCapacityPrecise(gpa, nsyms);
    try self.globals.ensureTotalCapacityPrecise(gpa, nsyms);
    self.globals.resize(gpa, nsyms) catch unreachable;
    @memset(self.globals.items, 0);

    try self.force_undefined.ensureTotalCapacityPrecise(gpa, macho_file.base.comp.force_undefined_symbols.keys().len);
    for (macho_file.base.comp.force_undefined_symbols.keys()) |name| {
        self.force_undefined.addOneAssumeCapacity().* = newSymbolAssumeCapacity(self, try self.addString(gpa, name), .{});
    }

    self.dyld_stub_binder_index = newSymbolAssumeCapacity(self, try self.addString(gpa, "dyld_stub_binder"), .{});
    self.objc_msg_send_index = newSymbolAssumeCapacity(self, try self.addString(gpa, "_objc_msgSend"), .{});

    if (!macho_file.base.isDynLib()) {
        self.entry_index = newSymbolAssumeCapacity(self, try self.addString(gpa, macho_file.entry_name orelse "_main"), .{});
        self.mh_execute_header_index = newSymbolAssumeCapacity(self, try self.addString(gpa, "__mh_execute_header"), .{
            .type = macho.N_SECT | macho.N_EXT,
            .desc = macho.REFERENCED_DYNAMICALLY,
        });
    } else {
        self.mh_dylib_header_index = newSymbolAssumeCapacity(self, try self.addString(gpa, "__mh_dylib_header"), .{
            .type = macho.N_SECT | macho.N_EXT,
        });
    }

    self.dso_handle_index = newSymbolAssumeCapacity(self, try self.addString(gpa, "___dso_handle"), .{
        .type = macho.N_SECT | macho.N_EXT,
    });
    self.dyld_private_index = newSymbolAssumeCapacity(self, try self.addString(gpa, "dyld_private"), .{
        .type = macho.N_SECT,
    });
}

pub fn resolveSymbols(self: *InternalObject, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = macho_file.base.comp.gpa;

    for (self.symtab.items, self.globals.items, 0..) |nlist, *global, i| {
        const gop = try macho_file.resolver.getOrPut(gpa, .{
            .index = @intCast(i),
            .file = self.index,
        }, macho_file);
        if (!gop.found_existing) {
            gop.ref.* = .{ .index = 0, .file = 0 };
        }
        global.* = gop.index;

        if (nlist.undf()) continue;
        if (gop.ref.getFile(macho_file) == null) {
            gop.ref.* = .{ .index = @intCast(i), .file = self.index };
            continue;
        }

        if (self.asFile().getSymbolRank(.{
            .archive = false,
            .weak = false,
            .tentative = false,
        }) < gop.ref.getSymbol(macho_file).?.getSymbolRank(macho_file)) {
            gop.ref.* = .{ .index = @intCast(i), .file = self.index };
        }
    }
}

pub fn resolveBoundarySymbols(self: *InternalObject, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = macho_file.base.comp.gpa;
    var boundary_symbols = std.StringArrayHashMap(MachO.Ref).init(gpa);
    defer boundary_symbols.deinit();

    for (macho_file.objects.items) |index| {
        const object = macho_file.getFile(index).?.object;
        for (object.symbols.items, 0..) |sym, i| {
            const nlist = object.symtab.items(.nlist)[i];
            if (!nlist.undf() or !nlist.ext()) continue;
            const ref = object.getSymbolRef(@intCast(i), macho_file);
            if (ref.getFile(macho_file) != null) continue;
            const name = sym.getName(macho_file);
            if (mem.startsWith(u8, name, "segment$start$") or
                mem.startsWith(u8, name, "segment$end$") or
                mem.startsWith(u8, name, "section$start$") or
                mem.startsWith(u8, name, "section$end$"))
            {
                const gop = try boundary_symbols.getOrPut(name);
                if (!gop.found_existing) {
                    gop.value_ptr.* = .{ .index = @intCast(i), .file = index };
                }
            }
        }
    }

    const nsyms = boundary_symbols.values().len;
    try self.boundary_symbols.ensureTotalCapacityPrecise(gpa, nsyms);
    try self.symbols.ensureUnusedCapacity(gpa, nsyms);
    try self.symtab.ensureUnusedCapacity(gpa, nsyms);
    try self.symbols_extra.ensureUnusedCapacity(gpa, nsyms * @sizeOf(Symbol.Extra));
    try self.globals.ensureUnusedCapacity(gpa, nsyms);

    for (boundary_symbols.keys(), boundary_symbols.values()) |name, ref| {
        const name_str = try self.addString(gpa, name);
        const sym_index = self.addSymbolAssumeCapacity();
        self.boundary_symbols.appendAssumeCapacity(sym_index);
        const sym = &self.symbols.items[sym_index];
        sym.name = name_str;
        sym.visibility = .local;
        const nlist_idx: u32 = @intCast(self.symtab.items.len);
        const nlist = self.symtab.addOneAssumeCapacity();
        nlist.* = .{
            .n_strx = name_str.pos,
            .n_type = macho.N_SECT,
            .n_sect = 0,
            .n_desc = 0,
            .n_value = 0,
        };
        sym.nlist_idx = nlist_idx;
        sym.extra = self.addSymbolExtraAssumeCapacity(.{});

        const idx = ref.getFile(macho_file).?.object.globals.items[ref.index];
        self.globals.addOneAssumeCapacity().* = idx;
        macho_file.resolver.values.items[idx - 1] = .{ .index = sym_index, .file = self.index };
    }
}

pub fn markLive(self: *InternalObject, macho_file: *MachO) void {
    const tracy = trace(@src());
    defer tracy.end();

    for (0..self.symbols.items.len) |i| {
        const nlist = self.symtab.items[i];
        if (!nlist.ext()) continue;

        const ref = self.getSymbolRef(@intCast(i), macho_file);
        const file = ref.getFile(macho_file) orelse continue;
        if (file == .object and !file.object.alive) {
            file.object.alive = true;
            file.object.markLive(macho_file);
        }
    }
}

/// Creates a fake input sections __TEXT,__objc_methname and __DATA,__objc_selrefs.
pub fn addObjcMsgsendSections(self: *InternalObject, sym_name: []const u8, macho_file: *MachO) !Symbol.Index {
    const methname_sym_index = try self.addObjcMethnameSection(sym_name, macho_file);
    return try self.addObjcSelrefsSection(methname_sym_index, macho_file);
}

fn addObjcMethnameSection(self: *InternalObject, methname: []const u8, macho_file: *MachO) !Symbol.Index {
    const gpa = macho_file.base.comp.gpa;
    const atom_index = try self.addAtom(gpa);
    try self.atoms_indexes.append(gpa, atom_index);
    const atom = self.getAtom(atom_index).?;
    atom.size = methname.len + 1;
    atom.alignment = .@"1";

    const n_sect = try self.addSection(gpa, "__TEXT", "__objc_methname");
    const sect = &self.sections.items(.header)[n_sect];
    sect.flags = macho.S_CSTRING_LITERALS;
    sect.size = atom.size;
    sect.@"align" = 0;
    atom.n_sect = n_sect;
    self.sections.items(.extra)[n_sect].is_objc_methname = true;

    sect.offset = @intCast(self.objc_methnames.items.len);
    try self.objc_methnames.ensureUnusedCapacity(gpa, methname.len + 1);
    self.objc_methnames.writer(gpa).print("{s}\x00", .{methname}) catch unreachable;

    const name_str = try self.addString(gpa, "ltmp");
    const sym_index = try self.addSymbol(gpa);
    const sym = &self.symbols.items[sym_index];
    sym.name = name_str;
    sym.atom_ref = .{ .index = atom_index, .file = self.index };
    sym.extra = try self.addSymbolExtra(gpa, .{});
    const nlist_idx: u32 = @intCast(self.symtab.items.len);
    const nlist = try self.symtab.addOne(gpa);
    nlist.* = .{
        .n_strx = name_str.pos,
        .n_type = macho.N_SECT,
        .n_sect = @intCast(n_sect + 1),
        .n_desc = 0,
        .n_value = 0,
    };
    sym.nlist_idx = nlist_idx;
    try self.globals.append(gpa, 0);

    return atom_index;
}

fn addObjcSelrefsSection(self: *InternalObject, methname_sym_index: Symbol.Index, macho_file: *MachO) !Symbol.Index {
    const gpa = macho_file.base.comp.gpa;
    const atom_index = try self.addAtom(gpa);
    try self.atoms_indexes.append(gpa, atom_index);
    const atom = self.getAtom(atom_index).?;
    atom.size = @sizeOf(u64);
    atom.alignment = .@"8";

    const n_sect = try self.addSection(gpa, "__DATA", "__objc_selrefs");
    const sect = &self.sections.items(.header)[n_sect];
    sect.flags = macho.S_LITERAL_POINTERS | macho.S_ATTR_NO_DEAD_STRIP;
    sect.offset = 0;
    sect.size = atom.size;
    sect.@"align" = 3;
    atom.n_sect = n_sect;
    self.sections.items(.extra)[n_sect].is_objc_selref = true;

    const relocs = &self.sections.items(.relocs)[n_sect];
    try relocs.ensureUnusedCapacity(gpa, 1);
    relocs.appendAssumeCapacity(.{
        .tag = .@"extern",
        .offset = 0,
        .target = methname_sym_index,
        .addend = 0,
        .type = .unsigned,
        .meta = .{
            .pcrel = false,
            .length = 3,
            .symbolnum = 0, // Only used when synthesising unwind records so can be anything
            .has_subtractor = false,
        },
    });
    atom.addExtra(.{ .rel_index = 0, .rel_count = 1 }, macho_file);

    const sym_index = try self.addSymbol(gpa);
    const sym = &self.symbols.items[sym_index];
    sym.atom_ref = .{ .index = atom_index, .file = self.index };
    sym.extra = try self.addSymbolExtra(gpa, .{});
    const nlist_idx: u32 = @intCast(self.symtab.items.len);
    const nlist = try self.symtab.addOne(gpa);
    nlist.* = .{
        .n_strx = 0,
        .n_type = macho.N_SECT,
        .n_sect = @intCast(n_sect + 1),
        .n_desc = 0,
        .n_value = 0,
    };
    sym.nlist_idx = nlist_idx;
    try self.globals.append(gpa, 0);
    atom.addExtra(.{ .literal_symbol_index = sym_index }, macho_file);

    return sym_index;
}

pub fn resolveObjcMsgSendSymbols(self: *InternalObject, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = macho_file.base.comp.gpa;

    var objc_msgsend_syms = std.StringArrayHashMap(MachO.Ref).init(gpa);
    defer objc_msgsend_syms.deinit();

    for (macho_file.objects.items) |index| {
        const object = macho_file.getFile(index).?.object;

        for (object.symbols.items, 0..) |sym, i| {
            const nlist = object.symtab.items(.nlist)[i];
            if (!nlist.ext()) continue;
            if (!nlist.undf()) continue;

            const ref = object.getSymbolRef(@intCast(i), macho_file);
            if (ref.getFile(macho_file) != null) continue;

            const name = sym.getName(macho_file);
            if (mem.startsWith(u8, name, "_objc_msgSend$")) {
                const gop = try objc_msgsend_syms.getOrPut(name);
                if (!gop.found_existing) {
                    gop.value_ptr.* = .{ .index = @intCast(i), .file = index };
                }
            }
        }
    }

    for (objc_msgsend_syms.keys(), objc_msgsend_syms.values()) |sym_name, ref| {
        const name = MachO.eatPrefix(sym_name, "_objc_msgSend$").?;
        const selrefs_index = try self.addObjcMsgsendSections(name, macho_file);

        const name_str = try self.addString(gpa, sym_name);
        const sym_index = try self.addSymbol(gpa);
        const sym = &self.symbols.items[sym_index];
        sym.name = name_str;
        sym.visibility = .hidden;
        const nlist_idx: u32 = @intCast(self.symtab.items.len);
        const nlist = try self.symtab.addOne(gpa);
        nlist.* = .{
            .n_strx = name_str.pos,
            .n_type = macho.N_SECT | macho.N_EXT | macho.N_PEXT,
            .n_sect = 0,
            .n_desc = 0,
            .n_value = 0,
        };
        sym.nlist_idx = nlist_idx;
        sym.extra = try self.addSymbolExtra(gpa, .{ .objc_selrefs = selrefs_index });
        sym.setSectionFlags(.{ .objc_stubs = true });

        const idx = ref.getFile(macho_file).?.object.globals.items[ref.index];
        try self.globals.append(gpa, idx);
        macho_file.resolver.values.items[idx - 1] = .{ .index = sym_index, .file = self.index };
    }
}

pub fn resolveLiterals(self: *InternalObject, lp: *MachO.LiteralPool, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = macho_file.base.comp.gpa;

    var buffer = std.ArrayList(u8).init(gpa);
    defer buffer.deinit();

    const slice = self.sections.slice();
    for (slice.items(.header), self.getAtoms()) |header, atom_index| {
        if (!Object.isPtrLiteral(header)) continue;
        const atom = self.getAtom(atom_index).?;
        const relocs = atom.getRelocs(macho_file);
        assert(relocs.len == 1);
        const rel = relocs[0];
        assert(rel.tag == .@"extern");
        const target = rel.getTargetSymbol(atom.*, macho_file).getAtom(macho_file).?;
        const target_size = std.math.cast(usize, target.size) orelse return error.Overflow;
        try buffer.ensureUnusedCapacity(target_size);
        buffer.resize(target_size) catch unreachable;
        @memcpy(buffer.items, try self.getSectionData(target.n_sect));
        const res = try lp.insert(gpa, header.type(), buffer.items);
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

pub fn dedupLiterals(self: *InternalObject, lp: MachO.LiteralPool, macho_file: *MachO) void {
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
            if (!Object.isPtrLiteral(target_atom.getInputSection(macho_file))) continue;
            const lp_index = target_atom.getExtra(macho_file).literal_pool_index;
            const lp_sym = lp.getSymbol(lp_index, macho_file);
            const lp_atom_ref = lp_sym.atom_ref;
            if (target_atom.atom_index != lp_atom_ref.index or target_atom.file != lp_atom_ref.file) {
                target_sym.atom_ref = lp_atom_ref;
            }
        }
    }

    for (self.symbols.items) |*sym| {
        if (!sym.getSectionFlags().objc_stubs) continue;
        const extra = sym.getExtra(macho_file);
        const file = sym.getFile(macho_file).?;
        if (file.getIndex() != self.index) continue;
        const tsym = switch (file) {
            .dylib => unreachable,
            inline else => |x| &x.symbols.items[extra.objc_selrefs],
        };
        const atom = tsym.getAtom(macho_file) orelse continue;
        if (!Object.isPtrLiteral(atom.getInputSection(macho_file))) continue;
        const lp_index = atom.getExtra(macho_file).literal_pool_index;
        const lp_sym = lp.getSymbol(lp_index, macho_file);
        const lp_atom_ref = lp_sym.atom_ref;
        if (atom.atom_index != lp_atom_ref.index or atom.file != lp_atom_ref.file) {
            tsym.atom_ref = lp_atom_ref;
        }
    }
}

pub fn scanRelocs(self: *InternalObject, macho_file: *MachO) void {
    const tracy = trace(@src());
    defer tracy.end();

    if (self.getEntryRef(macho_file)) |ref| {
        if (ref.getFile(macho_file) != null) {
            const sym = ref.getSymbol(macho_file).?;
            if (sym.flags.import) sym.setSectionFlags(.{ .stubs = true });
        }
    }
    if (self.getDyldStubBinderRef(macho_file)) |ref| {
        if (ref.getFile(macho_file) != null) {
            const sym = ref.getSymbol(macho_file).?;
            sym.setSectionFlags(.{ .needs_got = true });
        }
    }
    if (self.getObjcMsgSendRef(macho_file)) |ref| {
        if (ref.getFile(macho_file) != null) {
            const sym = ref.getSymbol(macho_file).?;
            // TODO is it always needed, or only if we are synthesising fast stubs
            sym.setSectionFlags(.{ .needs_got = true });
        }
    }
}

pub fn allocateSyntheticSymbols(self: *InternalObject, macho_file: *MachO) void {
    const text_seg = macho_file.getTextSegment();

    if (self.mh_execute_header_index) |index| {
        const ref = self.getSymbolRef(index, macho_file);
        if (ref.getFile(macho_file)) |file| {
            if (file.getIndex() == self.index) {
                const sym = &self.symbols.items[index];
                sym.value = text_seg.vmaddr;
            }
        }
    }

    if (macho_file.data_sect_index) |idx| {
        const sect = macho_file.sections.items(.header)[idx];
        for (&[_]?Symbol.Index{
            self.dso_handle_index,
            self.mh_dylib_header_index,
            self.dyld_private_index,
        }) |maybe_index| {
            if (maybe_index) |index| {
                const ref = self.getSymbolRef(index, macho_file);
                if (ref.getFile(macho_file)) |file| {
                    if (file.getIndex() == self.index) {
                        const sym = &self.symbols.items[index];
                        sym.value = sect.addr;
                        sym.out_n_sect = idx;
                    }
                }
            }
        }
    }
}

pub fn calcSymtabSize(self: *InternalObject, macho_file: *MachO) void {
    for (self.symbols.items, 0..) |*sym, i| {
        const ref = self.getSymbolRef(@intCast(i), macho_file);
        const file = ref.getFile(macho_file) orelse continue;
        if (file.getIndex() != self.index) continue;
        if (sym.getName(macho_file).len == 0) continue;
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
}

pub fn writeAtoms(self: *InternalObject, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    for (self.getAtoms()) |atom_index| {
        const atom = self.getAtom(atom_index) orelse continue;
        if (!atom.isAlive()) continue;
        const sect = atom.getInputSection(macho_file);
        if (sect.isZerofill()) continue;
        const off = std.math.cast(usize, atom.value) orelse return error.Overflow;
        const size = std.math.cast(usize, atom.size) orelse return error.Overflow;
        const buffer = macho_file.sections.items(.out)[atom.out_n_sect].items[off..][0..size];
        @memcpy(buffer, try self.getSectionData(atom.n_sect));
        try atom.resolveRelocs(macho_file, buffer);
    }
}

pub fn writeSymtab(self: InternalObject, macho_file: *MachO, ctx: anytype) void {
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

fn addSection(self: *InternalObject, allocator: Allocator, segname: []const u8, sectname: []const u8) !u32 {
    const n_sect = @as(u32, @intCast(try self.sections.addOne(allocator)));
    self.sections.set(n_sect, .{
        .header = .{
            .sectname = MachO.makeStaticString(sectname),
            .segname = MachO.makeStaticString(segname),
        },
    });
    return n_sect;
}

fn getSectionData(self: *const InternalObject, index: u32) error{Overflow}![]const u8 {
    const slice = self.sections.slice();
    assert(index < slice.items(.header).len);
    const sect = slice.items(.header)[index];
    const extra = slice.items(.extra)[index];
    if (extra.is_objc_methname) {
        const size = std.math.cast(usize, sect.size) orelse return error.Overflow;
        return self.objc_methnames.items[sect.offset..][0..size];
    } else if (extra.is_objc_selref)
        return &self.objc_selrefs
    else
        @panic("ref to non-existent section");
}

pub fn addString(self: *InternalObject, allocator: Allocator, string: []const u8) !MachO.String {
    const off: u32 = @intCast(self.strtab.items.len);
    try self.strtab.ensureUnusedCapacity(allocator, string.len + 1);
    self.strtab.appendSliceAssumeCapacity(string);
    self.strtab.appendAssumeCapacity(0);
    return .{ .pos = off, .len = @intCast(string.len + 1) };
}

pub fn getString(self: InternalObject, string: MachO.String) [:0]const u8 {
    assert(string.pos < self.strtab.items.len and string.pos + string.len <= self.strtab.items.len);
    if (string.len == 0) return "";
    return self.strtab.items[string.pos..][0 .. string.len - 1 :0];
}

pub fn asFile(self: *InternalObject) File {
    return .{ .internal = self };
}

pub fn getAtomRelocs(self: *const InternalObject, atom: Atom, macho_file: *MachO) []const Relocation {
    const extra = atom.getExtra(macho_file);
    const relocs = self.sections.items(.relocs)[atom.n_sect];
    return relocs.items[extra.rel_index..][0..extra.rel_count];
}

fn addAtom(self: *InternalObject, allocator: Allocator) !Atom.Index {
    const atom_index: Atom.Index = @intCast(self.atoms.items.len);
    const atom = try self.atoms.addOne(allocator);
    atom.* = .{
        .file = self.index,
        .atom_index = atom_index,
        .extra = try self.addAtomExtra(allocator, .{}),
    };
    return atom_index;
}

pub fn getAtom(self: *InternalObject, atom_index: Atom.Index) ?*Atom {
    if (atom_index == 0) return null;
    assert(atom_index < self.atoms.items.len);
    return &self.atoms.items[atom_index];
}

pub fn getAtoms(self: InternalObject) []const Atom.Index {
    return self.atoms_indexes.items;
}

fn addAtomExtra(self: *InternalObject, allocator: Allocator, extra: Atom.Extra) !u32 {
    const fields = @typeInfo(Atom.Extra).@"struct".fields;
    try self.atoms_extra.ensureUnusedCapacity(allocator, fields.len);
    return self.addAtomExtraAssumeCapacity(extra);
}

fn addAtomExtraAssumeCapacity(self: *InternalObject, extra: Atom.Extra) u32 {
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

pub fn getAtomExtra(self: InternalObject, index: u32) Atom.Extra {
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

pub fn setAtomExtra(self: *InternalObject, index: u32, extra: Atom.Extra) void {
    assert(index > 0);
    const fields = @typeInfo(Atom.Extra).@"struct".fields;
    inline for (fields, 0..) |field, i| {
        self.atoms_extra.items[index + i] = switch (field.type) {
            u32 => @field(extra, field.name),
            else => @compileError("bad field type"),
        };
    }
}

pub fn getEntryRef(self: InternalObject, macho_file: *MachO) ?MachO.Ref {
    const index = self.entry_index orelse return null;
    return self.getSymbolRef(index, macho_file);
}

pub fn getDyldStubBinderRef(self: InternalObject, macho_file: *MachO) ?MachO.Ref {
    const index = self.dyld_stub_binder_index orelse return null;
    return self.getSymbolRef(index, macho_file);
}

pub fn getDyldPrivateRef(self: InternalObject, macho_file: *MachO) ?MachO.Ref {
    const index = self.dyld_private_index orelse return null;
    return self.getSymbolRef(index, macho_file);
}

pub fn getObjcMsgSendRef(self: InternalObject, macho_file: *MachO) ?MachO.Ref {
    const index = self.objc_msg_send_index orelse return null;
    return self.getSymbolRef(index, macho_file);
}

pub fn addSymbol(self: *InternalObject, allocator: Allocator) !Symbol.Index {
    try self.symbols.ensureUnusedCapacity(allocator, 1);
    return self.addSymbolAssumeCapacity();
}

pub fn addSymbolAssumeCapacity(self: *InternalObject) Symbol.Index {
    const index: Symbol.Index = @intCast(self.symbols.items.len);
    const symbol = self.symbols.addOneAssumeCapacity();
    symbol.* = .{ .file = self.index };
    return index;
}

pub fn getSymbolRef(self: InternalObject, index: Symbol.Index, macho_file: *MachO) MachO.Ref {
    const global_index = self.globals.items[index];
    if (macho_file.resolver.get(global_index)) |ref| return ref;
    return .{ .index = index, .file = self.index };
}

pub fn addSymbolExtra(self: *InternalObject, allocator: Allocator, extra: Symbol.Extra) !u32 {
    const fields = @typeInfo(Symbol.Extra).@"struct".fields;
    try self.symbols_extra.ensureUnusedCapacity(allocator, fields.len);
    return self.addSymbolExtraAssumeCapacity(extra);
}

fn addSymbolExtraAssumeCapacity(self: *InternalObject, extra: Symbol.Extra) u32 {
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

pub fn getSymbolExtra(self: InternalObject, index: u32) Symbol.Extra {
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

pub fn setSymbolExtra(self: *InternalObject, index: u32, extra: Symbol.Extra) void {
    const fields = @typeInfo(Symbol.Extra).@"struct".fields;
    inline for (fields, 0..) |field, i| {
        self.symbols_extra.items[index + i] = switch (field.type) {
            u32 => @field(extra, field.name),
            else => @compileError("bad field type"),
        };
    }
}

const FormatContext = struct {
    self: *InternalObject,
    macho_file: *MachO,
};

pub fn fmtAtoms(self: *InternalObject, macho_file: *MachO) std.fmt.Formatter(formatAtoms) {
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
    try writer.writeAll("  atoms\n");
    for (ctx.self.getAtoms()) |atom_index| {
        const atom = ctx.self.getAtom(atom_index) orelse continue;
        try writer.print("    {}\n", .{atom.fmt(ctx.macho_file)});
    }
}

pub fn fmtSymtab(self: *InternalObject, macho_file: *MachO) std.fmt.Formatter(formatSymtab) {
    return .{ .data = .{
        .self = self,
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
    const macho_file = ctx.macho_file;
    const self = ctx.self;
    try writer.writeAll("  symbols\n");
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

const Section = struct {
    header: macho.section_64,
    relocs: std.ArrayListUnmanaged(Relocation) = .empty,
    extra: Extra = .{},

    const Extra = packed struct {
        is_objc_methname: bool = false,
        is_objc_selref: bool = false,
    };
};

const assert = std.debug.assert;
const macho = std.macho;
const mem = std.mem;
const std = @import("std");
const trace = @import("../../tracy.zig").trace;

const Allocator = std.mem.Allocator;
const Atom = @import("Atom.zig");
const File = @import("file.zig").File;
const InternalObject = @This();
const MachO = @import("../MachO.zig");
const Object = @import("Object.zig");
const Relocation = @import("Relocation.zig");
const Symbol = @import("Symbol.zig");
