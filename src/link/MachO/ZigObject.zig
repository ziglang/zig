/// Externally owned memory.
path: []const u8,
index: File.Index,

symtab: std.MultiArrayList(Nlist) = .{},

symbols: std.ArrayListUnmanaged(Symbol.Index) = .{},
atoms: std.ArrayListUnmanaged(Atom.Index) = .{},

/// Table of tracked LazySymbols.
lazy_syms: LazySymbolTable = .{},

/// Table of tracked Decls.
decls: DeclTable = .{},

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

/// A table of relocations.
relocs: RelocationTable = .{},

output_symtab_ctx: MachO.SymtabCtx = .{},

pub fn init(self: *ZigObject, macho_file: *MachO) !void {
    const comp = macho_file.base.comp;
    const gpa = comp.gpa;

    try self.atoms.append(gpa, 0); // null input section
}

pub fn deinit(self: *ZigObject, allocator: Allocator) void {
    self.symtab.deinit(allocator);
    self.symbols.deinit(allocator);
    self.atoms.deinit(allocator);

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

    for (self.relocs.items) |*list| {
        list.deinit(allocator);
    }
    self.relocs.deinit(allocator);
}

fn addNlist(self: *ZigObject, allocator: Allocator) !Symbol.Index {
    try self.symtab.ensureUnusedCapacity(allocator, 1);
    const index = @as(Symbol.Index, @intCast(self.symtab.addOneAssumeCapacity()));
    self.symtab.set(index, .{
        .nlist = MachO.null_sym,
        .size = 0,
        .atom = 0,
    });
    return index;
}

pub fn addAtom(self: *ZigObject, macho_file: *MachO) !Symbol.Index {
    const gpa = macho_file.base.comp.gpa;
    const atom_index = try macho_file.addAtom();
    const symbol_index = try macho_file.addSymbol();
    const nlist_index = try self.addNlist(gpa);

    try self.atoms.append(gpa, atom_index);
    try self.symbols.append(gpa, symbol_index);

    const atom = macho_file.getAtom(atom_index).?;
    atom.file = self.index;

    const symbol = macho_file.getSymbol(symbol_index);
    symbol.file = self.index;
    symbol.atom = atom_index;

    self.symtab.items(.atom)[nlist_index] = atom_index;
    symbol.nlist_idx = nlist_index;

    const relocs_index = @as(u32, @intCast(self.relocs.items.len));
    const relocs = try self.relocs.addOne(gpa);
    relocs.* = .{};
    atom.relocs = .{ .pos = relocs_index, .len = 0 };

    return symbol_index;
}

pub fn getAtomRelocs(self: *ZigObject, atom: Atom) []const Relocation {
    const relocs = self.relocs.items[atom.relocs.pos];
    return relocs.items[0..atom.relocs.len];
}

pub fn resolveSymbols(self: *ZigObject, macho_file: *MachO) void {
    _ = self;
    _ = macho_file;
    @panic("TODO resolveSymbols");
}

pub fn resetGlobals(self: *ZigObject, macho_file: *MachO) void {
    for (self.symbols.items, 0..) |sym_index, nlist_idx| {
        if (!self.symtab.items(.nlist)[nlist_idx].ext()) continue;
        const sym = macho_file.getSymbol(sym_index);
        const name = sym.name;
        sym.* = .{};
        sym.name = name;
    }
}

pub fn markLive(self: *ZigObject, macho_file: *MachO) void {
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

pub fn calcSymtabSize(self: *ZigObject, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    for (self.symbols.items) |sym_index| {
        const sym = macho_file.getSymbol(sym_index);
        const file = sym.getFile(macho_file) orelse continue;
        if (file.getIndex() != self.index) continue;
        if (sym.getAtom(macho_file)) |atom| if (!atom.flags.alive) continue;
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
}

pub fn writeSymtab(self: ZigObject, macho_file: *MachO) void {
    const tracy = trace(@src());
    defer tracy.end();

    for (self.symbols.items) |sym_index| {
        const sym = macho_file.getSymbol(sym_index);
        const file = sym.getFile(macho_file) orelse continue;
        if (file.getIndex() != self.index) continue;
        const idx = sym.getOutputSymtabIndex(macho_file) orelse continue;
        const n_strx = @as(u32, @intCast(macho_file.strtab.items.len));
        macho_file.strtab.appendSliceAssumeCapacity(sym.getName(macho_file));
        macho_file.strtab.appendAssumeCapacity(0);
        const out_sym = &macho_file.symtab.items[idx];
        out_sym.n_strx = n_strx;
        sym.setOutputSym(macho_file, out_sym);
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

pub fn flushModule(self: *ZigObject, macho_file: *MachO) !void {
    _ = self;
    _ = macho_file;
    @panic("TODO flushModule");
}

pub fn getDeclVAddr(
    self: *ZigObject,
    macho_file: *MachO,
    decl_index: InternPool.DeclIndex,
    reloc_info: link.File.RelocInfo,
) !u64 {
    _ = self;
    _ = macho_file;
    _ = decl_index;
    _ = reloc_info;
    @panic("TODO getDeclVAddr");
}

pub fn getAnonDeclVAddr(
    self: *ZigObject,
    macho_file: *MachO,
    decl_val: InternPool.Index,
    reloc_info: link.File.RelocInfo,
) !u64 {
    _ = self;
    _ = macho_file;
    _ = decl_val;
    _ = reloc_info;
    @panic("TODO getAnonDeclVAddr");
}

pub fn lowerAnonDecl(
    self: *ZigObject,
    macho_file: *MachO,
    decl_val: InternPool.Index,
    explicit_alignment: InternPool.Alignment,
    src_loc: Module.SrcLoc,
) !codegen.Result {
    _ = self;
    _ = macho_file;
    _ = decl_val;
    _ = explicit_alignment;
    _ = src_loc;
    @panic("TODO lowerAnonDecl");
}

pub fn freeDecl(self: *ZigObject, macho_file: *MachO, decl_index: InternPool.DeclIndex) void {
    _ = self;
    _ = macho_file;
    _ = decl_index;
    @panic("TODO freeDecl");
}

pub fn updateFunc(
    self: *ZigObject,
    macho_file: *MachO,
    mod: *Module,
    func_index: InternPool.Index,
    air: Air,
    liveness: Liveness,
) !void {
    _ = self;
    _ = macho_file;
    _ = mod;
    _ = func_index;
    _ = air;
    _ = liveness;
    @panic("TODO updateFunc");
}

pub fn updateDecl(
    self: *ZigObject,
    macho_file: *MachO,
    mod: *Module,
    decl_index: InternPool.DeclIndex,
) link.File.UpdateDeclError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const decl = mod.declPtr(decl_index);

    if (decl.val.getExternFunc(mod)) |_| {
        return;
    }

    if (decl.isExtern(mod)) {
        // Extern variable gets a __got entry only
        const variable = decl.getOwnedVariable(mod).?;
        const name = mod.intern_pool.stringToSlice(decl.name);
        const lib_name = mod.intern_pool.stringToSliceUnwrap(variable.lib_name);
        const index = try self.getGlobalSymbol(macho_file, name, lib_name);
        macho_file.getSymbol(index).flags.needs_got = true;
        return;
    }

    const sym_index = try self.getOrCreateMetadataForDecl(macho_file, decl_index);
    // TODO: free relocs if any

    const gpa = macho_file.base.comp.gpa;
    var code_buffer = std.ArrayList(u8).init(gpa);
    defer code_buffer.deinit();

    var decl_state: ?Dwarf.DeclState = null; // TODO: Dwarf
    defer if (decl_state) |*ds| ds.deinit();

    const decl_val = if (decl.val.getVariable(mod)) |variable| Value.fromInterned(variable.init) else decl.val;
    const dio: codegen.DebugInfoOutput = if (decl_state) |*ds| .{ .dwarf = ds } else .none;
    const res =
        try codegen.generateSymbol(&macho_file.base, decl.srcLoc(mod), .{
        .ty = decl.ty,
        .val = decl_val,
    }, &code_buffer, dio, .{
        .parent_atom_index = sym_index,
    });

    const code = switch (res) {
        .ok => code_buffer.items,
        .fail => |em| {
            decl.analysis = .codegen_failure;
            try mod.failed_decls.put(mod.gpa, decl_index, em);
            return;
        },
    };
    const sect_index = try self.getDeclOutputSection(macho_file, decl, code);
    const is_threadlocal = switch (macho_file.sections.items(.header)[sect_index].type()) {
        macho.S_THREAD_LOCAL_ZEROFILL, macho.S_THREAD_LOCAL_REGULAR => true,
        else => false,
    };
    if (is_threadlocal) {
        // TODO: emit TLV
        @panic("TODO updateDecl for TLS");
    } else {
        try self.updateDeclCode(macho_file, decl_index, sym_index, sect_index, code);
    }

    // if (decl_state) |*ds| {
    //     try self.d_sym.?.dwarf.commitDeclState(
    //         mod,
    //         decl_index,
    //         addr,
    //         self.getAtom(atom_index).size,
    //         ds,
    //     );
    // }

    // Since we updated the vaddr and the size, each corresponding export symbol also
    // needs to be updated.
    try self.updateExports(macho_file, mod, .{ .decl_index = decl_index }, mod.getDeclExports(decl_index));
}

fn updateDeclCode(
    self: *ZigObject,
    macho_file: *MachO,
    decl_index: InternPool.DeclIndex,
    sym_index: Symbol.Index,
    sect_index: u8,
    code: []const u8,
) !void {
    const gpa = macho_file.base.comp.gpa;
    const mod = macho_file.base.comp.module.?;
    const decl = mod.declPtr(decl_index);
    const decl_name = mod.intern_pool.stringToSlice(try decl.getFullyQualifiedName(mod));

    log.debug("updateDeclCode {s}{*}", .{ decl_name, decl });

    const required_alignment = decl.getAlignment(mod);

    const sect = &macho_file.sections.items(.header)[sect_index];
    const sym = macho_file.getSymbol(sym_index);
    const nlist = &self.symtab.items(.nlist)[sym.nlist_idx];
    const atom = sym.getAtom(macho_file).?;

    sym.out_n_sect = sect_index;
    atom.out_n_sect = sect_index;

    sym.name = try macho_file.strings.insert(gpa, decl_name);
    atom.flags.alive = true;
    atom.name = sym.name;
    nlist.n_strx = sym.name;
    nlist.n_type = macho.N_SECT;
    nlist.n_sect = sect_index + 1;
    self.symtab.items(.size)[sym.nlist_idx] = code.len;

    const old_size = atom.size;
    const old_vaddr = atom.value;
    atom.alignment = required_alignment;
    atom.size = code.len;

    if (old_size > 0) {
        const capacity = atom.capacity(macho_file);
        const need_realloc = code.len > capacity or !required_alignment.check(sym.getAddress(.{}, macho_file));

        if (need_realloc) {
            try atom.grow(macho_file);
            log.debug("growing {s} from 0x{x} to 0x{x}", .{ decl_name, old_vaddr, atom.value });
            if (old_vaddr != atom.value) {
                sym.value = 0;
                nlist.n_value = 0;

                if (!macho_file.base.isRelocatable()) {
                    log.debug("  (updating offset table entry)", .{});
                    assert(sym.flags.has_zig_got);
                    const extra = sym.getExtra(macho_file).?;
                    try macho_file.zig_got.writeOne(macho_file, extra.zig_got);
                }
            }
        } else if (code.len < old_size) {
            atom.shrink(macho_file);
        } else if (macho_file.getAtom(atom.next_index) == null) {
            const needed_size = (sym.getAddress(.{}, macho_file) + code.len) - sect.addr;
            sect.size = needed_size;
        }
    } else {
        try atom.allocate(macho_file);
        // TODO: freeDeclMetadata in case of error

        sym.value = 0;
        sym.flags.needs_zig_got = true;
        nlist.n_value = 0;

        if (!macho_file.base.isRelocatable()) {
            const gop = try sym.getOrCreateZigGotEntry(sym_index, macho_file);
            try macho_file.zig_got.writeOne(macho_file, gop.index);
        }
    }

    if (!sect.isZerofill()) {
        const file_offset = sect.offset + sym.getAddress(.{}, macho_file) - sect.addr;
        try macho_file.base.file.?.pwriteAll(code, file_offset);
    }
}

fn getDeclOutputSection(
    self: *ZigObject,
    macho_file: *MachO,
    decl: *const Module.Decl,
    code: []const u8,
) error{OutOfMemory}!u8 {
    _ = self;
    const mod = macho_file.base.comp.module.?;
    const any_non_single_threaded = macho_file.base.comp.config.any_non_single_threaded;
    const sect_id: u8 = switch (decl.ty.zigTypeTag(mod)) {
        .Fn => macho_file.zig_text_section_index.?,
        else => blk: {
            if (decl.getOwnedVariable(mod)) |variable| {
                if (variable.is_threadlocal and any_non_single_threaded) {
                    const is_all_zeroes = for (code) |byte| {
                        if (byte != 0) break false;
                    } else true;
                    if (is_all_zeroes) break :blk macho_file.getSectionByName("__DATA", "__thread_bss") orelse try macho_file.addSection(
                        "__DATA",
                        "__thread_bss",
                        .{ .flags = macho.S_THREAD_LOCAL_ZEROFILL },
                    );
                    break :blk macho_file.getSectionByName("__DATA", "__thread_data") orelse try macho_file.addSection(
                        "__DATA",
                        "__thread_data",
                        .{ .flags = macho.S_THREAD_LOCAL_REGULAR },
                    );
                }

                if (variable.is_const) break :blk macho_file.zig_data_const_section_index.?;
                if (Value.fromInterned(variable.init).isUndefDeep(mod)) {
                    // TODO: get the optimize_mode from the Module that owns the decl instead
                    // of using the root module here.
                    break :blk switch (macho_file.base.comp.root_mod.optimize_mode) {
                        .Debug, .ReleaseSafe => macho_file.zig_data_section_index.?,
                        .ReleaseFast, .ReleaseSmall => macho_file.zig_bss_section_index.?,
                    };
                }

                // TODO I blatantly copied the logic from the Wasm linker, but is there a less
                // intrusive check for all zeroes than this?
                const is_all_zeroes = for (code) |byte| {
                    if (byte != 0) break false;
                } else true;
                if (is_all_zeroes) break :blk macho_file.zig_bss_section_index.?;
                break :blk macho_file.zig_data_section_index.?;
            }
            break :blk macho_file.zig_data_const_section_index.?;
        },
    };
    return sect_id;
}

pub fn lowerUnnamedConst(
    self: *ZigObject,
    macho_file: *MachO,
    typed_value: TypedValue,
    decl_index: InternPool.DeclIndex,
) !u32 {
    _ = self;
    _ = macho_file;
    _ = typed_value;
    _ = decl_index;
    @panic("TODO lowerUnnamedConst");
}

pub fn updateExports(
    self: *ZigObject,
    macho_file: *MachO,
    mod: *Module,
    exported: Module.Exported,
    exports: []const *Module.Export,
) link.File.UpdateExportsError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = macho_file.base.comp.gpa;
    const metadata = switch (exported) {
        .decl_index => |decl_index| blk: {
            _ = try self.getOrCreateMetadataForDecl(macho_file, decl_index);
            break :blk self.decls.getPtr(decl_index).?;
        },
        .value => |value| self.anon_decls.getPtr(value) orelse blk: {
            const first_exp = exports[0];
            const res = try self.lowerAnonDecl(macho_file, value, .none, first_exp.getSrcLoc(mod));
            switch (res) {
                .ok => {},
                .fail => |em| {
                    // TODO maybe it's enough to return an error here and let Module.processExportsInner
                    // handle the error?
                    try mod.failed_exports.ensureUnusedCapacity(mod.gpa, 1);
                    mod.failed_exports.putAssumeCapacityNoClobber(first_exp, em);
                    return;
                },
            }
            break :blk self.anon_decls.getPtr(value).?;
        },
    };
    const sym_index = metadata.symbol_index;
    const nlist_idx = macho_file.getSymbol(sym_index).nlist_idx;
    const nlist = self.symtab.items(.nlist)[nlist_idx];

    for (exports) |exp| {
        if (exp.opts.section.unwrap()) |section_name| {
            if (!mod.intern_pool.stringEqlSlice(section_name, "__text")) {
                try mod.failed_exports.ensureUnusedCapacity(mod.gpa, 1);
                mod.failed_exports.putAssumeCapacityNoClobber(exp, try Module.ErrorMsg.create(
                    gpa,
                    exp.getSrcLoc(mod),
                    "Unimplemented: ExportOptions.section",
                    .{},
                ));
                continue;
            }
        }
        if (exp.opts.linkage == .LinkOnce) {
            try mod.failed_exports.putNoClobber(mod.gpa, exp, try Module.ErrorMsg.create(
                gpa,
                exp.getSrcLoc(mod),
                "Unimplemented: GlobalLinkage.LinkOnce",
                .{},
            ));
            continue;
        }

        const exp_name = try std.fmt.allocPrint(gpa, "_{}", .{exp.opts.name.fmt(&mod.intern_pool)});
        defer gpa.free(exp_name);

        const name_off = try macho_file.strings.insert(gpa, exp_name);
        const global_nlist_index = if (metadata.@"export"(self, macho_file, exp_name)) |exp_index|
            exp_index.*
        else blk: {
            const global_nlist_index = try self.getGlobalSymbol(macho_file, exp_name, null);
            try metadata.exports.append(gpa, global_nlist_index);
            break :blk global_nlist_index;
        };
        const global_nlist = &self.symtab.items(.nlist)[global_nlist_index];
        global_nlist.n_strx = name_off;
        global_nlist.n_value = nlist.n_value;
        global_nlist.n_sect = nlist.n_sect;
        global_nlist.n_type = macho.N_EXT | macho.N_SECT;
        self.symtab.items(.size)[global_nlist_index] = self.symtab.items(.size)[nlist_idx];
        self.symtab.items(.atom)[global_nlist_index] = self.symtab.items(.atom)[nlist_idx];

        switch (exp.opts.linkage) {
            .Internal => {
                // Symbol should be hidden, or in MachO lingo, private extern.
                global_nlist.n_type |= macho.N_PEXT;
            },
            .Strong => {},
            .Weak => {
                // Weak linkage is specified as part of n_desc field.
                // Symbol's n_type is like for a symbol with strong linkage.
                global_nlist.n_desc |= macho.N_WEAK_DEF;
            },
            else => unreachable,
        }
    }
}

/// Must be called only after a successful call to `updateDecl`.
pub fn updateDeclLineNumber(
    self: *ZigObject,
    mod: *Module,
    decl_index: InternPool.DeclIndex,
) !void {
    _ = self;
    _ = mod;
    _ = decl_index;
    @panic("TODO updateDeclLineNumber");
}

pub fn deleteDeclExport(
    self: *ZigObject,
    macho_file: *MachO,
    decl_index: InternPool.DeclIndex,
    name: InternPool.NullTerminatedString,
) void {
    _ = self;
    _ = macho_file;
    _ = decl_index;
    _ = name;
    @panic("TODO deleteDeclExport");
}

pub fn getGlobalSymbol(self: *ZigObject, macho_file: *MachO, name: []const u8, lib_name: ?[]const u8) !u32 {
    _ = self;
    _ = macho_file;
    _ = name;
    _ = lib_name;
    @panic("TODO getGlobalSymbol");
}

pub fn getOrCreateMetadataForDecl(
    self: *ZigObject,
    macho_file: *MachO,
    decl_index: InternPool.DeclIndex,
) !Symbol.Index {
    const gpa = macho_file.base.comp.gpa;
    const gop = try self.decls.getOrPut(gpa, decl_index);
    if (!gop.found_existing) {
        const any_non_single_threaded = macho_file.base.comp.config.any_non_single_threaded;
        const sym_index = try self.addAtom(macho_file);
        const mod = macho_file.base.comp.module.?;
        const decl = mod.declPtr(decl_index);
        const sym = macho_file.getSymbol(sym_index);
        if (decl.getOwnedVariable(mod)) |variable| {
            if (variable.is_threadlocal and any_non_single_threaded) {
                sym.flags.tlv = true;
            }
        }
        if (!sym.flags.tlv) {
            sym.flags.needs_zig_got = true;
        }
        gop.value_ptr.* = .{ .symbol_index = sym_index };
    }
    return gop.value_ptr.symbol_index;
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
    for (ctx.self.symbols.items) |index| {
        const sym = ctx.macho_file.getSymbol(index);
        try writer.print("    {}\n", .{sym.fmt(ctx.macho_file)});
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
    try writer.writeAll("  atoms\n");
    for (ctx.self.atoms.items) |atom_index| {
        const atom = ctx.macho_file.getAtom(atom_index) orelse continue;
        try writer.print("    {}\n", .{atom.fmt(ctx.macho_file)});
    }
}

const DeclMetadata = struct {
    symbol_index: Symbol.Index,
    /// A list of all exports aliases of this Decl.
    exports: std.ArrayListUnmanaged(Symbol.Index) = .{},

    fn @"export"(m: DeclMetadata, zig_object: *ZigObject, macho_file: *MachO, name: []const u8) ?*u32 {
        for (m.exports.items) |*exp| {
            const nlist = zig_object.symtab.items(.nlist)[exp.*];
            const exp_name = macho_file.strings.getAssumeExists(nlist.n_strx);
            if (mem.eql(u8, name, exp_name)) return exp;
        }
        return null;
    }
};

const LazySymbolMetadata = struct {
    const State = enum { unused, pending_flush, flushed };
    text_symbol_index: Symbol.Index = undefined,
    data_const_symbol_index: Symbol.Index = undefined,
    text_state: State = .unused,
    rodata_state: State = .unused,
};

const DeclTable = std.AutoHashMapUnmanaged(InternPool.DeclIndex, DeclMetadata);
const UnnamedConstTable = std.AutoHashMapUnmanaged(InternPool.DeclIndex, std.ArrayListUnmanaged(Symbol.Index));
const AnonDeclTable = std.AutoHashMapUnmanaged(InternPool.Index, DeclMetadata);
const LazySymbolTable = std.AutoArrayHashMapUnmanaged(InternPool.OptionalDeclIndex, LazySymbolMetadata);
const RelocationTable = std.ArrayListUnmanaged(std.ArrayListUnmanaged(Relocation));

const assert = std.debug.assert;
const builtin = @import("builtin");
const codegen = @import("../../codegen.zig");
const link = @import("../../link.zig");
const log = std.log.scoped(.link);
const macho = std.macho;
const mem = std.mem;
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
const Module = @import("../../Module.zig");
const Object = @import("Object.zig");
const Relocation = @import("Relocation.zig");
const Symbol = @import("Symbol.zig");
const StringTable = @import("../StringTable.zig");
const Type = @import("../../type.zig").Type;
const Value = @import("../../value.zig").Value;
const TypedValue = @import("../../TypedValue.zig");
const ZigObject = @This();
