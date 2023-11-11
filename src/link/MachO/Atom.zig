/// Each Atom always gets a symbol with the fully qualified name.
/// The symbol can reside in any object file context structure in `symtab` array
/// (see `Object`), or if the symbol is a synthetic symbol such as a GOT cell or
/// a stub trampoline, it can be found in the linkers `locals` arraylist.
/// If this field is 0 and file is 0, it means the codegen size = 0 and there is no symbol or
/// offset table entry.
sym_index: u32 = 0,

/// 0 means an Atom is a synthetic Atom such as a GOT cell defined by the linker.
/// Otherwise, it is the index into appropriate object file (indexing from 1).
/// Prefer using `getFile()` helper to get the file index out rather than using
/// the field directly.
file: u32 = 0,

/// If this Atom is not a synthetic Atom, i.e., references a subsection in an
/// Object file, `inner_sym_index` and `inner_nsyms_trailing` tell where and if
/// this Atom contains any additional symbol references that fall within this Atom's
/// address range. These could for example be an alias symbol which can be used
/// internally by the relocation records, or if the Object file couldn't be split
/// into subsections, this Atom may encompass an entire input section.
inner_sym_index: u32 = 0,
inner_nsyms_trailing: u32 = 0,

/// Size and alignment of this atom
/// Unlike in Elf, we need to store the size of this symbol as part of
/// the atom since macho.nlist_64 lacks this information.
size: u64 = 0,

/// Alignment of this atom as a power of 2.
/// For instance, aligmment of 0 should be read as 2^0 = 1 byte aligned.
alignment: Alignment = .@"1",

/// Points to the previous and next neighbours
/// TODO use the same trick as with symbols: reserve index 0 as null atom
next_index: ?Index = null,
prev_index: ?Index = null,

pub const Alignment = @import("../../InternPool.zig").Alignment;

pub const Index = u32;

pub const Binding = struct {
    target: SymbolWithLoc,
    offset: u64,
};

/// Returns `null` if the Atom is a synthetic Atom.
/// Otherwise, returns an index into an array of Objects.
pub fn getFile(self: Atom) ?u32 {
    if (self.file == 0) return null;
    return self.file - 1;
}

pub fn getSymbolIndex(self: Atom) ?u32 {
    if (self.getFile() == null and self.sym_index == 0) return null;
    return self.sym_index;
}

/// Returns symbol referencing this atom.
pub fn getSymbol(self: Atom, macho_file: *MachO) macho.nlist_64 {
    return self.getSymbolPtr(macho_file).*;
}

/// Returns pointer-to-symbol referencing this atom.
pub fn getSymbolPtr(self: Atom, macho_file: *MachO) *macho.nlist_64 {
    const sym_index = self.getSymbolIndex().?;
    return macho_file.getSymbolPtr(.{ .sym_index = sym_index, .file = self.file });
}

pub fn getSymbolWithLoc(self: Atom) SymbolWithLoc {
    const sym_index = self.getSymbolIndex().?;
    return .{ .sym_index = sym_index, .file = self.file };
}

/// Returns the name of this atom.
pub fn getName(self: Atom, macho_file: *MachO) []const u8 {
    const sym_index = self.getSymbolIndex().?;
    return macho_file.getSymbolName(.{ .sym_index = sym_index, .file = self.file });
}

/// Returns how much room there is to grow in virtual address space.
/// File offset relocation happens transparently, so it is not included in
/// this calculation.
pub fn capacity(self: Atom, macho_file: *MachO) u64 {
    const self_sym = self.getSymbol(macho_file);
    if (self.next_index) |next_index| {
        const next = macho_file.getAtom(next_index);
        const next_sym = next.getSymbol(macho_file);
        return next_sym.n_value - self_sym.n_value;
    } else {
        // We are the last atom.
        // The capacity is limited only by virtual address space.
        return macho_file.allocatedVirtualSize(self_sym.n_value);
    }
}

pub fn freeListEligible(self: Atom, macho_file: *MachO) bool {
    // No need to keep a free list node for the last atom.
    const next_index = self.next_index orelse return false;
    const next = macho_file.getAtom(next_index);
    const self_sym = self.getSymbol(macho_file);
    const next_sym = next.getSymbol(macho_file);
    const cap = next_sym.n_value - self_sym.n_value;
    const ideal_cap = MachO.padToIdeal(self.size);
    if (cap <= ideal_cap) return false;
    const surplus = cap - ideal_cap;
    return surplus >= MachO.min_text_capacity;
}

pub fn getOutputSection(macho_file: *MachO, sect: macho.section_64) !?u8 {
    const segname = sect.segName();
    const sectname = sect.sectName();
    const res: ?u8 = blk: {
        if (mem.eql(u8, "__LLVM", segname)) {
            log.debug("TODO LLVM section: type 0x{x}, name '{s},{s}'", .{
                sect.flags, segname, sectname,
            });
            break :blk null;
        }

        // We handle unwind info separately.
        if (mem.eql(u8, "__TEXT", segname) and mem.eql(u8, "__eh_frame", sectname)) {
            break :blk null;
        }
        if (mem.eql(u8, "__LD", segname) and mem.eql(u8, "__compact_unwind", sectname)) {
            break :blk null;
        }

        if (sect.isCode()) {
            if (macho_file.text_section_index == null) {
                macho_file.text_section_index = try macho_file.initSection("__TEXT", "__text", .{
                    .flags = macho.S_REGULAR |
                        macho.S_ATTR_PURE_INSTRUCTIONS |
                        macho.S_ATTR_SOME_INSTRUCTIONS,
                });
            }
            break :blk macho_file.text_section_index.?;
        }

        if (sect.isDebug()) {
            break :blk null;
        }

        switch (sect.type()) {
            macho.S_4BYTE_LITERALS,
            macho.S_8BYTE_LITERALS,
            macho.S_16BYTE_LITERALS,
            => {
                break :blk macho_file.getSectionByName("__TEXT", "__const") orelse
                    try macho_file.initSection("__TEXT", "__const", .{});
            },
            macho.S_CSTRING_LITERALS => {
                if (mem.startsWith(u8, sectname, "__objc")) {
                    break :blk macho_file.getSectionByName(segname, sectname) orelse
                        try macho_file.initSection(segname, sectname, .{});
                }
                break :blk macho_file.getSectionByName("__TEXT", "__cstring") orelse
                    try macho_file.initSection("__TEXT", "__cstring", .{
                    .flags = macho.S_CSTRING_LITERALS,
                });
            },
            macho.S_MOD_INIT_FUNC_POINTERS,
            macho.S_MOD_TERM_FUNC_POINTERS,
            => {
                break :blk macho_file.getSectionByName("__DATA_CONST", sectname) orelse
                    try macho_file.initSection("__DATA_CONST", sectname, .{
                    .flags = sect.flags,
                });
            },
            macho.S_LITERAL_POINTERS,
            macho.S_ZEROFILL,
            macho.S_THREAD_LOCAL_VARIABLES,
            macho.S_THREAD_LOCAL_VARIABLE_POINTERS,
            macho.S_THREAD_LOCAL_REGULAR,
            macho.S_THREAD_LOCAL_ZEROFILL,
            => {
                break :blk macho_file.getSectionByName(segname, sectname) orelse
                    try macho_file.initSection(segname, sectname, .{
                    .flags = sect.flags,
                });
            },
            macho.S_COALESCED => {
                break :blk macho_file.getSectionByName(segname, sectname) orelse
                    try macho_file.initSection(segname, sectname, .{});
            },
            macho.S_REGULAR => {
                if (mem.eql(u8, segname, "__TEXT")) {
                    if (mem.eql(u8, sectname, "__rodata") or
                        mem.eql(u8, sectname, "__typelink") or
                        mem.eql(u8, sectname, "__itablink") or
                        mem.eql(u8, sectname, "__gosymtab") or
                        mem.eql(u8, sectname, "__gopclntab"))
                    {
                        break :blk macho_file.getSectionByName("__TEXT", sectname) orelse
                            try macho_file.initSection("__TEXT", sectname, .{});
                    }
                }
                if (mem.eql(u8, segname, "__DATA")) {
                    if (mem.eql(u8, sectname, "__const") or
                        mem.eql(u8, sectname, "__cfstring") or
                        mem.eql(u8, sectname, "__objc_classlist") or
                        mem.eql(u8, sectname, "__objc_imageinfo"))
                    {
                        break :blk macho_file.getSectionByName("__DATA_CONST", sectname) orelse
                            try macho_file.initSection("__DATA_CONST", sectname, .{});
                    } else if (mem.eql(u8, sectname, "__data")) {
                        if (macho_file.data_section_index == null) {
                            macho_file.data_section_index = try macho_file.initSection("__DATA", "__data", .{});
                        }
                        break :blk macho_file.data_section_index.?;
                    }
                }
                break :blk macho_file.getSectionByName(segname, sectname) orelse
                    try macho_file.initSection(segname, sectname, .{});
            },
            else => break :blk null,
        }
    };

    // TODO we can do this directly in the selection logic above.
    // Or is it not worth it?
    if (macho_file.data_const_section_index == null) {
        if (macho_file.getSectionByName("__DATA_CONST", "__const")) |index| {
            macho_file.data_const_section_index = index;
        }
    }
    if (macho_file.thread_vars_section_index == null) {
        if (macho_file.getSectionByName("__DATA", "__thread_vars")) |index| {
            macho_file.thread_vars_section_index = index;
        }
    }
    if (macho_file.thread_data_section_index == null) {
        if (macho_file.getSectionByName("__DATA", "__thread_data")) |index| {
            macho_file.thread_data_section_index = index;
        }
    }
    if (macho_file.thread_bss_section_index == null) {
        if (macho_file.getSectionByName("__DATA", "__thread_bss")) |index| {
            macho_file.thread_bss_section_index = index;
        }
    }
    if (macho_file.bss_section_index == null) {
        if (macho_file.getSectionByName("__DATA", "__bss")) |index| {
            macho_file.bss_section_index = index;
        }
    }

    return res;
}

pub fn addRelocation(macho_file: *MachO, atom_index: Index, reloc: Relocation) !void {
    return addRelocations(macho_file, atom_index, &[_]Relocation{reloc});
}

pub fn addRelocations(macho_file: *MachO, atom_index: Index, relocs: []const Relocation) !void {
    const gpa = macho_file.base.allocator;
    const gop = try macho_file.relocs.getOrPut(gpa, atom_index);
    if (!gop.found_existing) {
        gop.value_ptr.* = .{};
    }
    try gop.value_ptr.ensureUnusedCapacity(gpa, relocs.len);
    for (relocs) |reloc| {
        log.debug("  (adding reloc of type {s} to target %{d})", .{
            @tagName(reloc.type),
            reloc.target.sym_index,
        });
        gop.value_ptr.appendAssumeCapacity(reloc);
    }
}

pub fn addRebase(macho_file: *MachO, atom_index: Index, offset: u32) !void {
    const gpa = macho_file.base.allocator;
    const atom = macho_file.getAtom(atom_index);
    log.debug("  (adding rebase at offset 0x{x} in %{?d})", .{ offset, atom.getSymbolIndex() });
    const gop = try macho_file.rebases.getOrPut(gpa, atom_index);
    if (!gop.found_existing) {
        gop.value_ptr.* = .{};
    }
    try gop.value_ptr.append(gpa, offset);
}

pub fn addBinding(macho_file: *MachO, atom_index: Index, binding: Binding) !void {
    const gpa = macho_file.base.allocator;
    const atom = macho_file.getAtom(atom_index);
    log.debug("  (adding binding to symbol {s} at offset 0x{x} in %{?d})", .{
        macho_file.getSymbolName(binding.target),
        binding.offset,
        atom.getSymbolIndex(),
    });
    const gop = try macho_file.bindings.getOrPut(gpa, atom_index);
    if (!gop.found_existing) {
        gop.value_ptr.* = .{};
    }
    try gop.value_ptr.append(gpa, binding);
}

pub fn resolveRelocations(
    macho_file: *MachO,
    atom_index: Index,
    relocs: []*const Relocation,
    code: []u8,
) void {
    relocs_log.debug("relocating '{s}'", .{macho_file.getAtom(atom_index).getName(macho_file)});
    for (relocs) |reloc| {
        reloc.resolve(macho_file, atom_index, code);
    }
}

pub fn freeRelocations(macho_file: *MachO, atom_index: Index) void {
    const gpa = macho_file.base.allocator;
    var removed_relocs = macho_file.relocs.fetchOrderedRemove(atom_index);
    if (removed_relocs) |*relocs| relocs.value.deinit(gpa);
    var removed_rebases = macho_file.rebases.fetchOrderedRemove(atom_index);
    if (removed_rebases) |*rebases| rebases.value.deinit(gpa);
    var removed_bindings = macho_file.bindings.fetchOrderedRemove(atom_index);
    if (removed_bindings) |*bindings| bindings.value.deinit(gpa);
}

const InnerSymIterator = struct {
    sym_index: u32,
    nsyms: u32,
    file: u32,
    pos: u32 = 0,

    pub fn next(it: *@This()) ?SymbolWithLoc {
        if (it.pos == it.nsyms) return null;
        const res = SymbolWithLoc{ .sym_index = it.sym_index + it.pos, .file = it.file };
        it.pos += 1;
        return res;
    }
};

/// Returns an iterator over potentially contained symbols.
/// Panics when called on a synthetic Atom.
pub fn getInnerSymbolsIterator(macho_file: *MachO, atom_index: Index) InnerSymIterator {
    const atom = macho_file.getAtom(atom_index);
    assert(atom.getFile() != null);
    return .{
        .sym_index = atom.inner_sym_index,
        .nsyms = atom.inner_nsyms_trailing,
        .file = atom.file,
    };
}

/// Returns a section alias symbol if one is defined.
/// An alias symbol is used to represent the start of an input section
/// if there were no symbols defined within that range.
/// Alias symbols are only used on x86_64.
pub fn getSectionAlias(macho_file: *MachO, atom_index: Index) ?SymbolWithLoc {
    const atom = macho_file.getAtom(atom_index);
    assert(atom.getFile() != null);

    const object = macho_file.objects.items[atom.getFile().?];
    const nbase = @as(u32, @intCast(object.in_symtab.?.len));
    const ntotal = @as(u32, @intCast(object.symtab.len));
    var sym_index: u32 = nbase;
    while (sym_index < ntotal) : (sym_index += 1) {
        if (object.getAtomIndexForSymbol(sym_index)) |other_atom_index| {
            if (other_atom_index == atom_index) return SymbolWithLoc{
                .sym_index = sym_index,
                .file = atom.file,
            };
        }
    }
    return null;
}

/// Given an index into a contained symbol within, calculates an offset wrt
/// the start of this Atom.
pub fn calcInnerSymbolOffset(macho_file: *MachO, atom_index: Index, sym_index: u32) u64 {
    const atom = macho_file.getAtom(atom_index);
    assert(atom.getFile() != null);

    if (atom.sym_index == sym_index) return 0;

    const object = macho_file.objects.items[atom.getFile().?];
    const source_sym = object.getSourceSymbol(sym_index).?;
    const base_addr = if (object.getSourceSymbol(atom.sym_index)) |sym|
        sym.n_value
    else blk: {
        const nbase = @as(u32, @intCast(object.in_symtab.?.len));
        const sect_id = @as(u8, @intCast(atom.sym_index - nbase));
        const source_sect = object.getSourceSection(sect_id);
        break :blk source_sect.addr;
    };
    return source_sym.n_value - base_addr;
}

pub fn scanAtomRelocs(macho_file: *MachO, atom_index: Index, relocs: []align(1) const macho.relocation_info) !void {
    const arch = macho_file.base.options.target.cpu.arch;
    const atom = macho_file.getAtom(atom_index);
    assert(atom.getFile() != null); // synthetic atoms do not have relocs

    return switch (arch) {
        .aarch64 => scanAtomRelocsArm64(macho_file, atom_index, relocs),
        .x86_64 => scanAtomRelocsX86(macho_file, atom_index, relocs),
        else => unreachable,
    };
}

const RelocContext = struct {
    base_addr: i64 = 0,
    base_offset: i32 = 0,
};

pub fn getRelocContext(macho_file: *MachO, atom_index: Index) RelocContext {
    const atom = macho_file.getAtom(atom_index);
    assert(atom.getFile() != null); // synthetic atoms do not have relocs

    const object = macho_file.objects.items[atom.getFile().?];
    if (object.getSourceSymbol(atom.sym_index)) |source_sym| {
        const source_sect = object.getSourceSection(source_sym.n_sect - 1);
        return .{
            .base_addr = @as(i64, @intCast(source_sect.addr)),
            .base_offset = @as(i32, @intCast(source_sym.n_value - source_sect.addr)),
        };
    }
    const nbase = @as(u32, @intCast(object.in_symtab.?.len));
    const sect_id = @as(u8, @intCast(atom.sym_index - nbase));
    const source_sect = object.getSourceSection(sect_id);
    return .{
        .base_addr = @as(i64, @intCast(source_sect.addr)),
        .base_offset = 0,
    };
}

pub fn parseRelocTarget(macho_file: *MachO, ctx: struct {
    object_id: u32,
    rel: macho.relocation_info,
    code: []const u8,
    base_addr: i64 = 0,
    base_offset: i32 = 0,
}) SymbolWithLoc {
    const tracy = trace(@src());
    defer tracy.end();

    const object = &macho_file.objects.items[ctx.object_id];
    log.debug("parsing reloc target in object({d}) '{s}' ", .{ ctx.object_id, object.name });

    const sym_index = if (ctx.rel.r_extern == 0) sym_index: {
        const sect_id = @as(u8, @intCast(ctx.rel.r_symbolnum - 1));
        const rel_offset = @as(u32, @intCast(ctx.rel.r_address - ctx.base_offset));

        const address_in_section = if (ctx.rel.r_pcrel == 0) blk: {
            break :blk if (ctx.rel.r_length == 3)
                mem.readInt(u64, ctx.code[rel_offset..][0..8], .little)
            else
                mem.readInt(u32, ctx.code[rel_offset..][0..4], .little);
        } else blk: {
            assert(macho_file.base.options.target.cpu.arch == .x86_64);
            const correction: u3 = switch (@as(macho.reloc_type_x86_64, @enumFromInt(ctx.rel.r_type))) {
                .X86_64_RELOC_SIGNED => 0,
                .X86_64_RELOC_SIGNED_1 => 1,
                .X86_64_RELOC_SIGNED_2 => 2,
                .X86_64_RELOC_SIGNED_4 => 4,
                else => unreachable,
            };
            const addend = mem.readInt(i32, ctx.code[rel_offset..][0..4], .little);
            const target_address = @as(i64, @intCast(ctx.base_addr)) + ctx.rel.r_address + 4 + correction + addend;
            break :blk @as(u64, @intCast(target_address));
        };

        // Find containing atom
        log.debug("  | locating symbol by address @{x} in section {d}", .{ address_in_section, sect_id });
        break :sym_index object.getSymbolByAddress(address_in_section, sect_id);
    } else object.reverse_symtab_lookup[ctx.rel.r_symbolnum];

    const sym_loc = SymbolWithLoc{ .sym_index = sym_index, .file = ctx.object_id + 1 };
    const sym = macho_file.getSymbol(sym_loc);
    const target = if (sym.sect() and !sym.ext())
        sym_loc
    else if (object.getGlobal(sym_index)) |global_index|
        macho_file.globals.items[global_index]
    else
        sym_loc;
    log.debug("  | target %{d} ('{s}') in object({?d})", .{
        target.sym_index,
        macho_file.getSymbolName(target),
        target.getFile(),
    });
    return target;
}

pub fn getRelocTargetAtomIndex(macho_file: *MachO, target: SymbolWithLoc) ?Index {
    if (target.getFile() == null) {
        const target_sym_name = macho_file.getSymbolName(target);
        if (mem.eql(u8, "__mh_execute_header", target_sym_name)) return null;
        if (mem.eql(u8, "___dso_handle", target_sym_name)) return null;

        unreachable; // referenced symbol not found
    }

    const object = macho_file.objects.items[target.getFile().?];
    return object.getAtomIndexForSymbol(target.sym_index);
}

fn scanAtomRelocsArm64(
    macho_file: *MachO,
    atom_index: Index,
    relocs: []align(1) const macho.relocation_info,
) !void {
    for (relocs) |rel| {
        const rel_type = @as(macho.reloc_type_arm64, @enumFromInt(rel.r_type));

        switch (rel_type) {
            .ARM64_RELOC_ADDEND, .ARM64_RELOC_SUBTRACTOR => continue,
            else => {},
        }

        if (rel.r_extern == 0) continue;

        const atom = macho_file.getAtom(atom_index);
        const object = &macho_file.objects.items[atom.getFile().?];
        const sym_index = object.reverse_symtab_lookup[rel.r_symbolnum];
        const sym_loc = SymbolWithLoc{
            .sym_index = sym_index,
            .file = atom.file,
        };

        const target = if (object.getGlobal(sym_index)) |global_index|
            macho_file.globals.items[global_index]
        else
            sym_loc;

        switch (rel_type) {
            .ARM64_RELOC_BRANCH26 => {
                // TODO rewrite relocation
                const sym = macho_file.getSymbol(target);
                if (sym.undf()) try macho_file.addStubEntry(target);
            },
            .ARM64_RELOC_GOT_LOAD_PAGE21,
            .ARM64_RELOC_GOT_LOAD_PAGEOFF12,
            .ARM64_RELOC_POINTER_TO_GOT,
            => {
                // TODO rewrite relocation
                try macho_file.addGotEntry(target);
            },
            .ARM64_RELOC_TLVP_LOAD_PAGE21,
            .ARM64_RELOC_TLVP_LOAD_PAGEOFF12,
            => {
                const sym = macho_file.getSymbol(target);
                if (sym.undf()) try macho_file.addTlvPtrEntry(target);
            },
            else => {},
        }
    }
}

fn scanAtomRelocsX86(
    macho_file: *MachO,
    atom_index: Index,
    relocs: []align(1) const macho.relocation_info,
) !void {
    for (relocs) |rel| {
        const rel_type = @as(macho.reloc_type_x86_64, @enumFromInt(rel.r_type));

        switch (rel_type) {
            .X86_64_RELOC_SUBTRACTOR => continue,
            else => {},
        }

        if (rel.r_extern == 0) continue;

        const atom = macho_file.getAtom(atom_index);
        const object = &macho_file.objects.items[atom.getFile().?];
        const sym_index = object.reverse_symtab_lookup[rel.r_symbolnum];
        const sym_loc = SymbolWithLoc{
            .sym_index = sym_index,
            .file = atom.file,
        };

        const target = if (object.getGlobal(sym_index)) |global_index|
            macho_file.globals.items[global_index]
        else
            sym_loc;

        switch (rel_type) {
            .X86_64_RELOC_BRANCH => {
                // TODO rewrite relocation
                const sym = macho_file.getSymbol(target);
                if (sym.undf()) try macho_file.addStubEntry(target);
            },
            .X86_64_RELOC_GOT, .X86_64_RELOC_GOT_LOAD => {
                // TODO rewrite relocation
                try macho_file.addGotEntry(target);
            },
            .X86_64_RELOC_TLV => {
                const sym = macho_file.getSymbol(target);
                if (sym.undf()) try macho_file.addTlvPtrEntry(target);
            },
            else => {},
        }
    }
}

pub fn resolveRelocs(
    macho_file: *MachO,
    atom_index: Index,
    atom_code: []u8,
    atom_relocs: []align(1) const macho.relocation_info,
) !void {
    const arch = macho_file.base.options.target.cpu.arch;
    const atom = macho_file.getAtom(atom_index);
    assert(atom.getFile() != null); // synthetic atoms do not have relocs

    relocs_log.debug("resolving relocations in ATOM(%{d}, '{s}')", .{
        atom.sym_index,
        macho_file.getSymbolName(atom.getSymbolWithLoc()),
    });

    const ctx = getRelocContext(macho_file, atom_index);

    return switch (arch) {
        .aarch64 => resolveRelocsArm64(macho_file, atom_index, atom_code, atom_relocs, ctx),
        .x86_64 => resolveRelocsX86(macho_file, atom_index, atom_code, atom_relocs, ctx),
        else => unreachable,
    };
}

pub fn getRelocTargetAddress(macho_file: *MachO, target: SymbolWithLoc, is_tlv: bool) u64 {
    const target_atom_index = getRelocTargetAtomIndex(macho_file, target) orelse {
        // If there is no atom for target, we still need to check for special, atom-less
        // symbols such as `___dso_handle`.
        const target_name = macho_file.getSymbolName(target);
        const atomless_sym = macho_file.getSymbol(target);
        log.debug("    | atomless target '{s}'", .{target_name});
        return atomless_sym.n_value;
    };
    const target_atom = macho_file.getAtom(target_atom_index);
    log.debug("    | target ATOM(%{d}, '{s}') in object({?})", .{
        target_atom.sym_index,
        macho_file.getSymbolName(target_atom.getSymbolWithLoc()),
        target_atom.getFile(),
    });

    const target_sym = macho_file.getSymbol(target_atom.getSymbolWithLoc());
    assert(target_sym.n_desc != MachO.N_DEAD);

    // If `target` is contained within the target atom, pull its address value.
    const offset = if (target_atom.getFile() != null) blk: {
        const object = macho_file.objects.items[target_atom.getFile().?];
        break :blk if (object.getSourceSymbol(target.sym_index)) |_|
            Atom.calcInnerSymbolOffset(macho_file, target_atom_index, target.sym_index)
        else
            0; // section alias
    } else 0;
    const base_address: u64 = if (is_tlv) base_address: {
        // For TLV relocations, the value specified as a relocation is the displacement from the
        // TLV initializer (either value in __thread_data or zero-init in __thread_bss) to the first
        // defined TLV template init section in the following order:
        // * wrt to __thread_data if defined, then
        // * wrt to __thread_bss
        // TODO remember to check what the mechanism was prior to HAS_TLV_INITIALIZERS in earlier versions of macOS
        const sect_id: u16 = sect_id: {
            if (macho_file.thread_data_section_index) |i| {
                break :sect_id i;
            } else if (macho_file.thread_bss_section_index) |i| {
                break :sect_id i;
            } else break :base_address 0;
        };
        break :base_address macho_file.sections.items(.header)[sect_id].addr;
    } else 0;
    return target_sym.n_value + offset - base_address;
}

fn resolveRelocsArm64(
    macho_file: *MachO,
    atom_index: Index,
    atom_code: []u8,
    atom_relocs: []align(1) const macho.relocation_info,
    context: RelocContext,
) !void {
    const atom = macho_file.getAtom(atom_index);
    const object = macho_file.objects.items[atom.getFile().?];

    var addend: ?i64 = null;
    var subtractor: ?SymbolWithLoc = null;

    for (atom_relocs) |rel| {
        const rel_type = @as(macho.reloc_type_arm64, @enumFromInt(rel.r_type));

        switch (rel_type) {
            .ARM64_RELOC_ADDEND => {
                assert(addend == null);

                relocs_log.debug("  RELA({s}) @ {x} => {x}", .{ @tagName(rel_type), rel.r_address, rel.r_symbolnum });

                addend = rel.r_symbolnum;
                continue;
            },
            .ARM64_RELOC_SUBTRACTOR => {
                assert(subtractor == null);

                relocs_log.debug("  RELA({s}) @ {x} => %{d} in object({?d})", .{
                    @tagName(rel_type),
                    rel.r_address,
                    rel.r_symbolnum,
                    atom.getFile(),
                });

                subtractor = parseRelocTarget(macho_file, .{
                    .object_id = atom.getFile().?,
                    .rel = rel,
                    .code = atom_code,
                    .base_addr = context.base_addr,
                    .base_offset = context.base_offset,
                });
                continue;
            },
            else => {},
        }

        const target = parseRelocTarget(macho_file, .{
            .object_id = atom.getFile().?,
            .rel = rel,
            .code = atom_code,
            .base_addr = context.base_addr,
            .base_offset = context.base_offset,
        });
        const rel_offset = @as(u32, @intCast(rel.r_address - context.base_offset));

        relocs_log.debug("  RELA({s}) @ {x} => %{d} ('{s}') in object({?})", .{
            @tagName(rel_type),
            rel.r_address,
            target.sym_index,
            macho_file.getSymbolName(target),
            target.getFile(),
        });

        const source_addr = blk: {
            const source_sym = macho_file.getSymbol(atom.getSymbolWithLoc());
            break :blk source_sym.n_value + rel_offset;
        };
        const target_addr = blk: {
            if (relocRequiresGot(macho_file, rel)) break :blk macho_file.getGotEntryAddress(target).?;
            if (relocIsTlv(macho_file, rel) and macho_file.getSymbol(target).undf())
                break :blk macho_file.getTlvPtrEntryAddress(target).?;
            if (relocIsStub(macho_file, rel) and macho_file.getSymbol(target).undf())
                break :blk macho_file.getStubsEntryAddress(target).?;
            const is_tlv = is_tlv: {
                const source_sym = macho_file.getSymbol(atom.getSymbolWithLoc());
                const header = macho_file.sections.items(.header)[source_sym.n_sect - 1];
                break :is_tlv header.type() == macho.S_THREAD_LOCAL_VARIABLES;
            };
            break :blk getRelocTargetAddress(macho_file, target, is_tlv);
        };

        relocs_log.debug("    | source_addr = 0x{x}", .{source_addr});

        switch (rel_type) {
            .ARM64_RELOC_BRANCH26 => {
                relocs_log.debug("  source {s} (object({?})), target {s}", .{
                    macho_file.getSymbolName(atom.getSymbolWithLoc()),
                    atom.getFile(),
                    macho_file.getSymbolName(target),
                });

                const displacement = if (Relocation.calcPcRelativeDisplacementArm64(
                    source_addr,
                    target_addr,
                )) |disp| blk: {
                    relocs_log.debug("    | target_addr = 0x{x}", .{target_addr});
                    break :blk disp;
                } else |_| blk: {
                    const thunk_index = macho_file.thunk_table.get(atom_index).?;
                    const thunk = macho_file.thunks.items[thunk_index];
                    const thunk_sym_loc = if (macho_file.getSymbol(target).undf())
                        thunk.getTrampoline(macho_file, .stub, target).?
                    else
                        thunk.getTrampoline(macho_file, .atom, target).?;
                    const thunk_addr = macho_file.getSymbol(thunk_sym_loc).n_value;
                    relocs_log.debug("    | target_addr = 0x{x} (thunk)", .{thunk_addr});
                    break :blk try Relocation.calcPcRelativeDisplacementArm64(source_addr, thunk_addr);
                };

                const code = atom_code[rel_offset..][0..4];
                var inst = aarch64.Instruction{
                    .unconditional_branch_immediate = mem.bytesToValue(meta.TagPayload(
                        aarch64.Instruction,
                        aarch64.Instruction.unconditional_branch_immediate,
                    ), code),
                };
                inst.unconditional_branch_immediate.imm26 = @as(u26, @truncate(@as(u28, @bitCast(displacement >> 2))));
                mem.writeInt(u32, code, inst.toU32(), .little);
            },

            .ARM64_RELOC_PAGE21,
            .ARM64_RELOC_GOT_LOAD_PAGE21,
            .ARM64_RELOC_TLVP_LOAD_PAGE21,
            => {
                const adjusted_target_addr = @as(u64, @intCast(@as(i64, @intCast(target_addr)) + (addend orelse 0)));

                relocs_log.debug("    | target_addr = 0x{x}", .{adjusted_target_addr});

                const pages = @as(u21, @bitCast(Relocation.calcNumberOfPages(source_addr, adjusted_target_addr)));
                const code = atom_code[rel_offset..][0..4];
                var inst = aarch64.Instruction{
                    .pc_relative_address = mem.bytesToValue(meta.TagPayload(
                        aarch64.Instruction,
                        aarch64.Instruction.pc_relative_address,
                    ), code),
                };
                inst.pc_relative_address.immhi = @as(u19, @truncate(pages >> 2));
                inst.pc_relative_address.immlo = @as(u2, @truncate(pages));
                mem.writeInt(u32, code, inst.toU32(), .little);
                addend = null;
            },

            .ARM64_RELOC_PAGEOFF12 => {
                const adjusted_target_addr = @as(u64, @intCast(@as(i64, @intCast(target_addr)) + (addend orelse 0)));

                relocs_log.debug("    | target_addr = 0x{x}", .{adjusted_target_addr});

                const code = atom_code[rel_offset..][0..4];
                if (Relocation.isArithmeticOp(code)) {
                    const off = try Relocation.calcPageOffset(adjusted_target_addr, .arithmetic);
                    var inst = aarch64.Instruction{
                        .add_subtract_immediate = mem.bytesToValue(meta.TagPayload(
                            aarch64.Instruction,
                            aarch64.Instruction.add_subtract_immediate,
                        ), code),
                    };
                    inst.add_subtract_immediate.imm12 = off;
                    mem.writeInt(u32, code, inst.toU32(), .little);
                } else {
                    var inst = aarch64.Instruction{
                        .load_store_register = mem.bytesToValue(meta.TagPayload(
                            aarch64.Instruction,
                            aarch64.Instruction.load_store_register,
                        ), code),
                    };
                    const off = try Relocation.calcPageOffset(adjusted_target_addr, switch (inst.load_store_register.size) {
                        0 => if (inst.load_store_register.v == 1)
                            Relocation.PageOffsetInstKind.load_store_128
                        else
                            Relocation.PageOffsetInstKind.load_store_8,
                        1 => .load_store_16,
                        2 => .load_store_32,
                        3 => .load_store_64,
                    });
                    inst.load_store_register.offset = off;
                    mem.writeInt(u32, code, inst.toU32(), .little);
                }
                addend = null;
            },

            .ARM64_RELOC_GOT_LOAD_PAGEOFF12 => {
                const code = atom_code[rel_offset..][0..4];
                const adjusted_target_addr = @as(u64, @intCast(@as(i64, @intCast(target_addr)) + (addend orelse 0)));

                relocs_log.debug("    | target_addr = 0x{x}", .{adjusted_target_addr});

                const off = try Relocation.calcPageOffset(adjusted_target_addr, .load_store_64);
                var inst: aarch64.Instruction = .{
                    .load_store_register = mem.bytesToValue(meta.TagPayload(
                        aarch64.Instruction,
                        aarch64.Instruction.load_store_register,
                    ), code),
                };
                inst.load_store_register.offset = off;
                mem.writeInt(u32, code, inst.toU32(), .little);
                addend = null;
            },

            .ARM64_RELOC_TLVP_LOAD_PAGEOFF12 => {
                const code = atom_code[rel_offset..][0..4];
                const adjusted_target_addr = @as(u64, @intCast(@as(i64, @intCast(target_addr)) + (addend orelse 0)));

                relocs_log.debug("    | target_addr = 0x{x}", .{adjusted_target_addr});

                const RegInfo = struct {
                    rd: u5,
                    rn: u5,
                    size: u2,
                };
                const reg_info: RegInfo = blk: {
                    if (Relocation.isArithmeticOp(code)) {
                        const inst = mem.bytesToValue(meta.TagPayload(
                            aarch64.Instruction,
                            aarch64.Instruction.add_subtract_immediate,
                        ), code);
                        break :blk .{
                            .rd = inst.rd,
                            .rn = inst.rn,
                            .size = inst.sf,
                        };
                    } else {
                        const inst = mem.bytesToValue(meta.TagPayload(
                            aarch64.Instruction,
                            aarch64.Instruction.load_store_register,
                        ), code);
                        break :blk .{
                            .rd = inst.rt,
                            .rn = inst.rn,
                            .size = inst.size,
                        };
                    }
                };

                var inst = if (macho_file.tlv_ptr_table.lookup.contains(target)) aarch64.Instruction{
                    .load_store_register = .{
                        .rt = reg_info.rd,
                        .rn = reg_info.rn,
                        .offset = try Relocation.calcPageOffset(adjusted_target_addr, .load_store_64),
                        .opc = 0b01,
                        .op1 = 0b01,
                        .v = 0,
                        .size = reg_info.size,
                    },
                } else aarch64.Instruction{
                    .add_subtract_immediate = .{
                        .rd = reg_info.rd,
                        .rn = reg_info.rn,
                        .imm12 = try Relocation.calcPageOffset(adjusted_target_addr, .arithmetic),
                        .sh = 0,
                        .s = 0,
                        .op = 0,
                        .sf = @as(u1, @truncate(reg_info.size)),
                    },
                };
                mem.writeInt(u32, code, inst.toU32(), .little);
                addend = null;
            },

            .ARM64_RELOC_POINTER_TO_GOT => {
                relocs_log.debug("    | target_addr = 0x{x}", .{target_addr});
                const result = math.cast(i32, @as(i64, @intCast(target_addr)) - @as(i64, @intCast(source_addr))) orelse
                    return error.Overflow;
                mem.writeInt(u32, atom_code[rel_offset..][0..4], @as(u32, @bitCast(result)), .little);
            },

            .ARM64_RELOC_UNSIGNED => {
                var ptr_addend = if (rel.r_length == 3)
                    mem.readInt(i64, atom_code[rel_offset..][0..8], .little)
                else
                    mem.readInt(i32, atom_code[rel_offset..][0..4], .little);

                if (rel.r_extern == 0) {
                    const base_addr = if (target.sym_index >= object.source_address_lookup.len)
                        @as(i64, @intCast(object.getSourceSection(@as(u8, @intCast(rel.r_symbolnum - 1))).addr))
                    else
                        object.source_address_lookup[target.sym_index];
                    ptr_addend -= base_addr;
                }

                const result = blk: {
                    if (subtractor) |sub| {
                        const sym = macho_file.getSymbol(sub);
                        break :blk @as(i64, @intCast(target_addr)) - @as(i64, @intCast(sym.n_value)) + ptr_addend;
                    } else {
                        break :blk @as(i64, @intCast(target_addr)) + ptr_addend;
                    }
                };
                relocs_log.debug("    | target_addr = 0x{x}", .{result});

                if (rel.r_length == 3) {
                    mem.writeInt(u64, atom_code[rel_offset..][0..8], @as(u64, @bitCast(result)), .little);
                } else {
                    mem.writeInt(u32, atom_code[rel_offset..][0..4], @as(u32, @truncate(@as(u64, @bitCast(result)))), .little);
                }

                subtractor = null;
            },

            .ARM64_RELOC_ADDEND => unreachable,
            .ARM64_RELOC_SUBTRACTOR => unreachable,
        }
    }
}

fn resolveRelocsX86(
    macho_file: *MachO,
    atom_index: Index,
    atom_code: []u8,
    atom_relocs: []align(1) const macho.relocation_info,
    context: RelocContext,
) !void {
    const atom = macho_file.getAtom(atom_index);
    const object = macho_file.objects.items[atom.getFile().?];

    var subtractor: ?SymbolWithLoc = null;

    for (atom_relocs) |rel| {
        const rel_type = @as(macho.reloc_type_x86_64, @enumFromInt(rel.r_type));

        switch (rel_type) {
            .X86_64_RELOC_SUBTRACTOR => {
                assert(subtractor == null);

                relocs_log.debug("  RELA({s}) @ {x} => %{d} in object({?d})", .{
                    @tagName(rel_type),
                    rel.r_address,
                    rel.r_symbolnum,
                    atom.getFile(),
                });

                subtractor = parseRelocTarget(macho_file, .{
                    .object_id = atom.getFile().?,
                    .rel = rel,
                    .code = atom_code,
                    .base_addr = context.base_addr,
                    .base_offset = context.base_offset,
                });
                continue;
            },
            else => {},
        }

        const target = parseRelocTarget(macho_file, .{
            .object_id = atom.getFile().?,
            .rel = rel,
            .code = atom_code,
            .base_addr = context.base_addr,
            .base_offset = context.base_offset,
        });
        const rel_offset = @as(u32, @intCast(rel.r_address - context.base_offset));

        relocs_log.debug("  RELA({s}) @ {x} => %{d} ('{s}') in object({?})", .{
            @tagName(rel_type),
            rel.r_address,
            target.sym_index,
            macho_file.getSymbolName(target),
            target.getFile(),
        });

        const source_addr = blk: {
            const source_sym = macho_file.getSymbol(atom.getSymbolWithLoc());
            break :blk source_sym.n_value + rel_offset;
        };
        const target_addr = blk: {
            if (relocRequiresGot(macho_file, rel)) break :blk macho_file.getGotEntryAddress(target).?;
            if (relocIsStub(macho_file, rel) and macho_file.getSymbol(target).undf())
                break :blk macho_file.getStubsEntryAddress(target).?;
            if (relocIsTlv(macho_file, rel) and macho_file.getSymbol(target).undf())
                break :blk macho_file.getTlvPtrEntryAddress(target).?;
            const is_tlv = is_tlv: {
                const source_sym = macho_file.getSymbol(atom.getSymbolWithLoc());
                const header = macho_file.sections.items(.header)[source_sym.n_sect - 1];
                break :is_tlv header.type() == macho.S_THREAD_LOCAL_VARIABLES;
            };
            break :blk getRelocTargetAddress(macho_file, target, is_tlv);
        };

        relocs_log.debug("    | source_addr = 0x{x}", .{source_addr});

        switch (rel_type) {
            .X86_64_RELOC_BRANCH => {
                const addend = mem.readInt(i32, atom_code[rel_offset..][0..4], .little);
                const adjusted_target_addr = @as(u64, @intCast(@as(i64, @intCast(target_addr)) + addend));
                relocs_log.debug("    | target_addr = 0x{x}", .{adjusted_target_addr});
                const disp = try Relocation.calcPcRelativeDisplacementX86(source_addr, adjusted_target_addr, 0);
                mem.writeInt(i32, atom_code[rel_offset..][0..4], disp, .little);
            },

            .X86_64_RELOC_GOT,
            .X86_64_RELOC_GOT_LOAD,
            => {
                const addend = mem.readInt(i32, atom_code[rel_offset..][0..4], .little);
                const adjusted_target_addr = @as(u64, @intCast(@as(i64, @intCast(target_addr)) + addend));
                relocs_log.debug("    | target_addr = 0x{x}", .{adjusted_target_addr});
                const disp = try Relocation.calcPcRelativeDisplacementX86(source_addr, adjusted_target_addr, 0);
                mem.writeInt(i32, atom_code[rel_offset..][0..4], disp, .little);
            },

            .X86_64_RELOC_TLV => {
                const addend = mem.readInt(i32, atom_code[rel_offset..][0..4], .little);
                const adjusted_target_addr = @as(u64, @intCast(@as(i64, @intCast(target_addr)) + addend));
                relocs_log.debug("    | target_addr = 0x{x}", .{adjusted_target_addr});
                const disp = try Relocation.calcPcRelativeDisplacementX86(source_addr, adjusted_target_addr, 0);

                if (macho_file.tlv_ptr_table.lookup.get(target) == null) {
                    // We need to rewrite the opcode from movq to leaq.
                    atom_code[rel_offset - 2] = 0x8d;
                }

                mem.writeInt(i32, atom_code[rel_offset..][0..4], disp, .little);
            },

            .X86_64_RELOC_SIGNED,
            .X86_64_RELOC_SIGNED_1,
            .X86_64_RELOC_SIGNED_2,
            .X86_64_RELOC_SIGNED_4,
            => {
                const correction: u3 = switch (rel_type) {
                    .X86_64_RELOC_SIGNED => 0,
                    .X86_64_RELOC_SIGNED_1 => 1,
                    .X86_64_RELOC_SIGNED_2 => 2,
                    .X86_64_RELOC_SIGNED_4 => 4,
                    else => unreachable,
                };
                var addend = mem.readInt(i32, atom_code[rel_offset..][0..4], .little) + correction;

                if (rel.r_extern == 0) {
                    const base_addr = if (target.sym_index >= object.source_address_lookup.len)
                        @as(i64, @intCast(object.getSourceSection(@as(u8, @intCast(rel.r_symbolnum - 1))).addr))
                    else
                        object.source_address_lookup[target.sym_index];
                    addend += @as(i32, @intCast(@as(i64, @intCast(context.base_addr)) + rel.r_address + 4 -
                        @as(i64, @intCast(base_addr))));
                }

                const adjusted_target_addr = @as(u64, @intCast(@as(i64, @intCast(target_addr)) + addend));

                relocs_log.debug("    | target_addr = 0x{x}", .{adjusted_target_addr});

                const disp = try Relocation.calcPcRelativeDisplacementX86(source_addr, adjusted_target_addr, correction);
                mem.writeInt(i32, atom_code[rel_offset..][0..4], disp, .little);
            },

            .X86_64_RELOC_UNSIGNED => {
                var addend = if (rel.r_length == 3)
                    mem.readInt(i64, atom_code[rel_offset..][0..8], .little)
                else
                    mem.readInt(i32, atom_code[rel_offset..][0..4], .little);

                if (rel.r_extern == 0) {
                    const base_addr = if (target.sym_index >= object.source_address_lookup.len)
                        @as(i64, @intCast(object.getSourceSection(@as(u8, @intCast(rel.r_symbolnum - 1))).addr))
                    else
                        object.source_address_lookup[target.sym_index];
                    addend -= base_addr;
                }

                const result = blk: {
                    if (subtractor) |sub| {
                        const sym = macho_file.getSymbol(sub);
                        break :blk @as(i64, @intCast(target_addr)) - @as(i64, @intCast(sym.n_value)) + addend;
                    } else {
                        break :blk @as(i64, @intCast(target_addr)) + addend;
                    }
                };
                relocs_log.debug("    | target_addr = 0x{x}", .{result});

                if (rel.r_length == 3) {
                    mem.writeInt(u64, atom_code[rel_offset..][0..8], @as(u64, @bitCast(result)), .little);
                } else {
                    mem.writeInt(u32, atom_code[rel_offset..][0..4], @as(u32, @truncate(@as(u64, @bitCast(result)))), .little);
                }

                subtractor = null;
            },

            .X86_64_RELOC_SUBTRACTOR => unreachable,
        }
    }
}

pub fn getAtomCode(macho_file: *MachO, atom_index: Index) []const u8 {
    const atom = macho_file.getAtom(atom_index);
    assert(atom.getFile() != null); // Synthetic atom shouldn't need to inquire for code.
    const object = macho_file.objects.items[atom.getFile().?];
    const source_sym = object.getSourceSymbol(atom.sym_index) orelse {
        // If there was no matching symbol present in the source symtab, this means
        // we are dealing with either an entire section, or part of it, but also
        // starting at the beginning.
        const nbase = @as(u32, @intCast(object.in_symtab.?.len));
        const sect_id = @as(u8, @intCast(atom.sym_index - nbase));
        const source_sect = object.getSourceSection(sect_id);
        assert(!source_sect.isZerofill());
        const code = object.getSectionContents(source_sect);
        const code_len = @as(usize, @intCast(atom.size));
        return code[0..code_len];
    };
    const source_sect = object.getSourceSection(source_sym.n_sect - 1);
    assert(!source_sect.isZerofill());
    const code = object.getSectionContents(source_sect);
    const offset = @as(usize, @intCast(source_sym.n_value - source_sect.addr));
    const code_len = @as(usize, @intCast(atom.size));
    return code[offset..][0..code_len];
}

pub fn getAtomRelocs(macho_file: *MachO, atom_index: Index) []const macho.relocation_info {
    const atom = macho_file.getAtom(atom_index);
    assert(atom.getFile() != null); // Synthetic atom shouldn't need to unique for relocs.
    const object = macho_file.objects.items[atom.getFile().?];
    const cache = object.relocs_lookup[atom.sym_index];

    const source_sect_id = if (object.getSourceSymbol(atom.sym_index)) |source_sym| blk: {
        break :blk source_sym.n_sect - 1;
    } else blk: {
        // If there was no matching symbol present in the source symtab, this means
        // we are dealing with either an entire section, or part of it, but also
        // starting at the beginning.
        const nbase = @as(u32, @intCast(object.in_symtab.?.len));
        const sect_id = @as(u8, @intCast(atom.sym_index - nbase));
        break :blk sect_id;
    };
    const source_sect = object.getSourceSection(source_sect_id);
    assert(!source_sect.isZerofill());
    const relocs = object.getRelocs(source_sect_id);
    return relocs[cache.start..][0..cache.len];
}

pub fn relocRequiresGot(macho_file: *MachO, rel: macho.relocation_info) bool {
    switch (macho_file.base.options.target.cpu.arch) {
        .aarch64 => switch (@as(macho.reloc_type_arm64, @enumFromInt(rel.r_type))) {
            .ARM64_RELOC_GOT_LOAD_PAGE21,
            .ARM64_RELOC_GOT_LOAD_PAGEOFF12,
            .ARM64_RELOC_POINTER_TO_GOT,
            => return true,
            else => return false,
        },
        .x86_64 => switch (@as(macho.reloc_type_x86_64, @enumFromInt(rel.r_type))) {
            .X86_64_RELOC_GOT,
            .X86_64_RELOC_GOT_LOAD,
            => return true,
            else => return false,
        },
        else => unreachable,
    }
}

pub fn relocIsTlv(macho_file: *MachO, rel: macho.relocation_info) bool {
    switch (macho_file.base.options.target.cpu.arch) {
        .aarch64 => switch (@as(macho.reloc_type_arm64, @enumFromInt(rel.r_type))) {
            .ARM64_RELOC_TLVP_LOAD_PAGE21,
            .ARM64_RELOC_TLVP_LOAD_PAGEOFF12,
            => return true,
            else => return false,
        },
        .x86_64 => switch (@as(macho.reloc_type_x86_64, @enumFromInt(rel.r_type))) {
            .X86_64_RELOC_TLV => return true,
            else => return false,
        },
        else => unreachable,
    }
}

pub fn relocIsStub(macho_file: *MachO, rel: macho.relocation_info) bool {
    switch (macho_file.base.options.target.cpu.arch) {
        .aarch64 => switch (@as(macho.reloc_type_arm64, @enumFromInt(rel.r_type))) {
            .ARM64_RELOC_BRANCH26 => return true,
            else => return false,
        },
        .x86_64 => switch (@as(macho.reloc_type_x86_64, @enumFromInt(rel.r_type))) {
            .X86_64_RELOC_BRANCH => return true,
            else => return false,
        },
        else => unreachable,
    }
}

const Atom = @This();

const std = @import("std");
const build_options = @import("build_options");
const aarch64 = @import("../../arch/aarch64/bits.zig");
const assert = std.debug.assert;
const log = std.log.scoped(.link);
const relocs_log = std.log.scoped(.link_relocs);
const macho = std.macho;
const math = std.math;
const mem = std.mem;
const meta = std.meta;
const trace = @import("../../tracy.zig").trace;

const Allocator = mem.Allocator;
const Arch = std.Target.Cpu.Arch;
const MachO = @import("../MachO.zig");
pub const Relocation = @import("Relocation.zig");
const SymbolWithLoc = MachO.SymbolWithLoc;
