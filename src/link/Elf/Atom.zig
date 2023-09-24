/// Address allocated for this Atom.
value: u64 = 0,

/// Name of this Atom.
name_offset: u32 = 0,

/// Index into linker's input file table.
file_index: File.Index = 0,

/// Size of this atom
size: u64 = 0,

/// Alignment of this atom as a power of two.
alignment: Alignment = .@"1",

/// Index of the input section.
input_section_index: Index = 0,

/// Index of the output section.
output_section_index: u16 = 0,

/// Index of the input section containing this atom's relocs.
relocs_section_index: Index = 0,

/// Index of this atom in the linker's atoms table.
atom_index: Index = 0,

/// Specifies whether this atom is alive or has been garbage collected.
alive: bool = false,

/// Specifies if the atom has been visited during garbage collection.
visited: bool = false,

/// Start index of FDEs referencing this atom.
fde_start: u32 = 0,

/// End index of FDEs referencing this atom.
fde_end: u32 = 0,

/// Points to the previous and next neighbors, based on the `text_offset`.
/// This can be used to find, for example, the capacity of this `TextBlock`.
prev_index: Index = 0,
next_index: Index = 0,

pub const Alignment = @import("../../InternPool.zig").Alignment;

pub fn name(self: Atom, elf_file: *Elf) []const u8 {
    return elf_file.strtab.getAssumeExists(self.name_offset);
}

pub fn inputShdr(self: Atom, elf_file: *Elf) elf.Elf64_Shdr {
    const object = elf_file.file(self.file_index).?.object;
    return object.shdrs.items[self.input_section_index];
}

pub fn outputShndx(self: Atom) ?u16 {
    if (self.output_section_index == 0) return null;
    return self.output_section_index;
}

pub fn codeInObject(self: Atom, elf_file: *Elf) error{Overflow}![]const u8 {
    const object = elf_file.file(self.file_index).?.object;
    return object.shdrContents(self.input_section_index);
}

/// Returns atom's code and optionally uncompresses data if required (for compressed sections).
/// Caller owns the memory.
pub fn codeInObjectUncompressAlloc(self: Atom, elf_file: *Elf) ![]u8 {
    const gpa = elf_file.base.allocator;
    const data = try self.codeInObject(elf_file);
    const shdr = self.inputShdr(elf_file);
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

pub fn priority(self: Atom, elf_file: *Elf) u64 {
    const index = elf_file.file(self.file_index).?.index();
    return (@as(u64, @intCast(index)) << 32) | @as(u64, @intCast(self.input_section_index));
}

/// Returns how much room there is to grow in virtual address space.
/// File offset relocation happens transparently, so it is not included in
/// this calculation.
pub fn capacity(self: Atom, elf_file: *Elf) u64 {
    const next_value = if (elf_file.atom(self.next_index)) |next| next.value else std.math.maxInt(u32);
    return next_value - self.value;
}

pub fn freeListEligible(self: Atom, elf_file: *Elf) bool {
    // No need to keep a free list node for the last block.
    const next = elf_file.atom(self.next_index) orelse return false;
    const cap = next.value - self.value;
    const ideal_cap = Elf.padToIdeal(self.size);
    if (cap <= ideal_cap) return false;
    const surplus = cap - ideal_cap;
    return surplus >= Elf.min_text_capacity;
}

pub fn allocate(self: *Atom, elf_file: *Elf) !void {
    const shdr = &elf_file.shdrs.items[self.outputShndx().?];
    const meta = elf_file.last_atom_and_free_list_table.getPtr(self.outputShndx().?).?;
    const free_list = &meta.free_list;
    const last_atom_index = &meta.last_atom_index;
    const new_atom_ideal_capacity = Elf.padToIdeal(self.size);

    // We use these to indicate our intention to update metadata, placing the new atom,
    // and possibly removing a free list node.
    // It would be simpler to do it inside the for loop below, but that would cause a
    // problem if an error was returned later in the function. So this action
    // is actually carried out at the end of the function, when errors are no longer possible.
    var atom_placement: ?Atom.Index = null;
    var free_list_removal: ?usize = null;

    // First we look for an appropriately sized free list node.
    // The list is unordered. We'll just take the first thing that works.
    self.value = blk: {
        var i: usize = if (elf_file.base.child_pid == null) 0 else free_list.items.len;
        while (i < free_list.items.len) {
            const big_atom_index = free_list.items[i];
            const big_atom = elf_file.atom(big_atom_index).?;
            // We now have a pointer to a live atom that has too much capacity.
            // Is it enough that we could fit this new atom?
            const cap = big_atom.capacity(elf_file);
            const ideal_capacity = Elf.padToIdeal(cap);
            const ideal_capacity_end_vaddr = std.math.add(u64, big_atom.value, ideal_capacity) catch ideal_capacity;
            const capacity_end_vaddr = big_atom.value + cap;
            const new_start_vaddr_unaligned = capacity_end_vaddr - new_atom_ideal_capacity;
            const new_start_vaddr = self.alignment.backward(new_start_vaddr_unaligned);
            if (new_start_vaddr < ideal_capacity_end_vaddr) {
                // Additional bookkeeping here to notice if this free list node
                // should be deleted because the block that it points to has grown to take up
                // more of the extra capacity.
                if (!big_atom.freeListEligible(elf_file)) {
                    _ = free_list.swapRemove(i);
                } else {
                    i += 1;
                }
                continue;
            }
            // At this point we know that we will place the new block here. But the
            // remaining question is whether there is still yet enough capacity left
            // over for there to still be a free list node.
            const remaining_capacity = new_start_vaddr - ideal_capacity_end_vaddr;
            const keep_free_list_node = remaining_capacity >= Elf.min_text_capacity;

            // Set up the metadata to be updated, after errors are no longer possible.
            atom_placement = big_atom_index;
            if (!keep_free_list_node) {
                free_list_removal = i;
            }
            break :blk new_start_vaddr;
        } else if (elf_file.atom(last_atom_index.*)) |last| {
            const ideal_capacity = Elf.padToIdeal(last.size);
            const ideal_capacity_end_vaddr = last.value + ideal_capacity;
            const new_start_vaddr = self.alignment.forward(ideal_capacity_end_vaddr);
            // Set up the metadata to be updated, after errors are no longer possible.
            atom_placement = last.atom_index;
            break :blk new_start_vaddr;
        } else {
            break :blk shdr.sh_addr;
        }
    };

    const expand_section = if (atom_placement) |placement_index|
        elf_file.atom(placement_index).?.next_index == 0
    else
        true;
    if (expand_section) {
        const needed_size = (self.value + self.size) - shdr.sh_addr;
        try elf_file.growAllocSection(self.outputShndx().?, needed_size);
        last_atom_index.* = self.atom_index;

        if (elf_file.dwarf) |_| {
            // The .debug_info section has `low_pc` and `high_pc` values which is the virtual address
            // range of the compilation unit. When we expand the text section, this range changes,
            // so the DW_TAG.compile_unit tag of the .debug_info section becomes dirty.
            elf_file.debug_info_header_dirty = true;
            // This becomes dirty for the same reason. We could potentially make this more
            // fine-grained with the addition of support for more compilation units. It is planned to
            // model each package as a different compilation unit.
            elf_file.debug_aranges_section_dirty = true;
        }
    }
    shdr.sh_addralign = @max(shdr.sh_addralign, self.alignment.toByteUnitsOptional().?);

    // This function can also reallocate an atom.
    // In this case we need to "unplug" it from its previous location before
    // plugging it in to its new location.
    if (elf_file.atom(self.prev_index)) |prev| {
        prev.next_index = self.next_index;
    }
    if (elf_file.atom(self.next_index)) |next| {
        next.prev_index = self.prev_index;
    }

    if (atom_placement) |big_atom_index| {
        const big_atom = elf_file.atom(big_atom_index).?;
        self.prev_index = big_atom_index;
        self.next_index = big_atom.next_index;
        big_atom.next_index = self.atom_index;
    } else {
        self.prev_index = 0;
        self.next_index = 0;
    }
    if (free_list_removal) |i| {
        _ = free_list.swapRemove(i);
    }
}

pub fn shrink(self: *Atom, elf_file: *Elf) void {
    _ = self;
    _ = elf_file;
}

pub fn grow(self: *Atom, elf_file: *Elf) !void {
    if (!self.alignment.check(self.value) or self.size > self.capacity(elf_file))
        try self.allocate(elf_file);
}

pub fn free(self: *Atom, elf_file: *Elf) void {
    log.debug("freeAtom {d} ({s})", .{ self.atom_index, self.name(elf_file) });

    const gpa = elf_file.base.allocator;
    const zig_module = elf_file.file(self.file_index).?.zig_module;
    const shndx = self.outputShndx().?;
    const meta = elf_file.last_atom_and_free_list_table.getPtr(shndx).?;
    const free_list = &meta.free_list;
    const last_atom_index = &meta.last_atom_index;
    var already_have_free_list_node = false;
    {
        var i: usize = 0;
        // TODO turn free_list into a hash map
        while (i < free_list.items.len) {
            if (free_list.items[i] == self.atom_index) {
                _ = free_list.swapRemove(i);
                continue;
            }
            if (free_list.items[i] == self.prev_index) {
                already_have_free_list_node = true;
            }
            i += 1;
        }
    }

    if (elf_file.atom(last_atom_index.*)) |last_atom| {
        if (last_atom.atom_index == self.atom_index) {
            if (elf_file.atom(self.prev_index)) |_| {
                // TODO shrink the section size here
                last_atom_index.* = self.prev_index;
            } else {
                last_atom_index.* = 0;
            }
        }
    }

    if (elf_file.atom(self.prev_index)) |prev| {
        prev.next_index = self.next_index;
        if (!already_have_free_list_node and prev.*.freeListEligible(elf_file)) {
            // The free list is heuristics, it doesn't have to be perfect, so we can
            // ignore the OOM here.
            free_list.append(gpa, prev.atom_index) catch {};
        }
    } else {
        self.prev_index = 0;
    }

    if (elf_file.atom(self.next_index)) |next| {
        next.prev_index = self.prev_index;
    } else {
        self.next_index = 0;
    }

    // TODO create relocs free list
    self.freeRelocs(elf_file);
    assert(zig_module.atoms.swapRemove(self.atom_index));
    self.* = .{};
}

pub fn relocs(self: Atom, elf_file: *Elf) error{Overflow}![]align(1) const elf.Elf64_Rela {
    return switch (elf_file.file(self.file_index).?) {
        .zig_module => |x| x.relocs.items[self.relocs_section_index].items,
        .object => |x| x.getRelocs(self.relocs_section_index),
        else => unreachable,
    };
}

pub fn addReloc(self: Atom, elf_file: *Elf, reloc: elf.Elf64_Rela) !void {
    const gpa = elf_file.base.allocator;
    const file_ptr = elf_file.file(self.file_index).?;
    assert(file_ptr == .zig_module);
    const zig_module = file_ptr.zig_module;
    const rels = &zig_module.relocs.items[self.relocs_section_index];
    try rels.append(gpa, reloc);
}

pub fn freeRelocs(self: Atom, elf_file: *Elf) void {
    const file_ptr = elf_file.file(self.file_index).?;
    assert(file_ptr == .zig_module);
    const zig_module = file_ptr.zig_module;
    zig_module.relocs.items[self.relocs_section_index].clearRetainingCapacity();
}

pub fn scanRelocs(self: Atom, elf_file: *Elf, undefs: anytype) !void {
    const file_ptr = elf_file.file(self.file_index).?;
    const rels = try self.relocs(elf_file);
    var i: usize = 0;
    while (i < rels.len) : (i += 1) {
        const rel = rels[i];

        if (rel.r_type() == elf.R_X86_64_NONE) continue;

        const symbol_index = switch (file_ptr) {
            .zig_module => |x| x.symbol(rel.r_sym()),
            .object => |x| x.symbols.items[rel.r_sym()],
            else => unreachable,
        };
        const symbol = elf_file.symbol(symbol_index);

        // Check for violation of One Definition Rule for COMDATs.
        if (symbol.file(elf_file) == null) {
            // TODO convert into an error
            log.debug("{}: {s}: {s} refers to a discarded COMDAT section", .{
                file_ptr.fmtPath(),
                self.name(elf_file),
                symbol.name(elf_file),
            });
            continue;
        }

        // Report an undefined symbol.
        try self.reportUndefined(elf_file, symbol, symbol_index, rel, undefs);

        // While traversing relocations, mark symbols that require special handling such as
        // pointer indirection via GOT, or a stub trampoline via PLT.
        switch (rel.r_type()) {
            elf.R_X86_64_64 => {},

            elf.R_X86_64_32,
            elf.R_X86_64_32S,
            => {},

            elf.R_X86_64_GOT32,
            elf.R_X86_64_GOT64,
            elf.R_X86_64_GOTPC32,
            elf.R_X86_64_GOTPC64,
            elf.R_X86_64_GOTPCREL,
            elf.R_X86_64_GOTPCREL64,
            elf.R_X86_64_GOTPCRELX,
            elf.R_X86_64_REX_GOTPCRELX,
            => {
                symbol.flags.needs_got = true;
            },

            elf.R_X86_64_PLT32,
            elf.R_X86_64_PLTOFF64,
            => {
                if (symbol.flags.import) {
                    symbol.flags.needs_plt = true;
                }
            },

            elf.R_X86_64_PC32 => {},

            else => @panic("TODO"),
        }
    }
}

// This function will report any undefined non-weak symbols that are not imports.
fn reportUndefined(
    self: Atom,
    elf_file: *Elf,
    sym: *const Symbol,
    sym_index: Symbol.Index,
    rel: elf.Elf64_Rela,
    undefs: anytype,
) !void {
    const rel_esym = switch (elf_file.file(self.file_index).?) {
        .zig_module => |x| x.elfSym(rel.r_sym()).*,
        .object => |x| x.symtab[rel.r_sym()],
        else => unreachable,
    };
    const esym = sym.elfSym(elf_file);
    if (rel_esym.st_shndx == elf.SHN_UNDEF and
        rel_esym.st_bind() == elf.STB_GLOBAL and
        sym.esym_index > 0 and
        !sym.flags.import and
        esym.st_shndx == elf.SHN_UNDEF)
    {
        const gop = try undefs.getOrPut(sym_index);
        if (!gop.found_existing) {
            gop.value_ptr.* = std.ArrayList(Atom.Index).init(elf_file.base.allocator);
        }
        try gop.value_ptr.append(self.atom_index);
    }
}

/// TODO mark relocs dirty
pub fn resolveRelocs(self: Atom, elf_file: *Elf, code: []u8) !void {
    relocs_log.debug("0x{x}: {s}", .{ self.value, self.name(elf_file) });

    const file_ptr = elf_file.file(self.file_index).?;
    var stream = std.io.fixedBufferStream(code);
    const cwriter = stream.writer();

    for (try self.relocs(elf_file)) |rel| {
        const r_type = rel.r_type();
        if (r_type == elf.R_X86_64_NONE) continue;

        const target = switch (file_ptr) {
            .zig_module => |x| elf_file.symbol(x.symbol(rel.r_sym())),
            .object => |x| elf_file.symbol(x.symbols.items[rel.r_sym()]),
            else => unreachable,
        };
        const r_offset = std.math.cast(usize, rel.r_offset) orelse return error.Overflow;

        // We will use equation format to resolve relocations:
        // https://intezer.com/blog/malware-analysis/executable-and-linkable-format-101-part-3-relocations/
        //
        // Address of the source atom.
        const P = @as(i64, @intCast(self.value + rel.r_offset));
        // Addend from the relocation.
        const A = rel.r_addend;
        // Address of the target symbol - can be address of the symbol within an atom or address of PLT stub.
        const S = @as(i64, @intCast(target.address(.{}, elf_file)));
        // Address of the global offset table.
        const GOT = blk: {
            const shndx = if (elf_file.got_plt_section_index) |shndx|
                shndx
            else if (elf_file.got_section_index) |shndx|
                shndx
            else
                null;
            break :blk if (shndx) |index| @as(i64, @intCast(elf_file.shdrs.items[index].sh_addr)) else 0;
        };
        // Relative offset to the start of the global offset table.
        const G = @as(i64, @intCast(target.gotAddress(elf_file))) - GOT;
        // // Address of the thread pointer.
        // const TP = @as(i64, @intCast(elf_file.getTpAddress()));
        // // Address of the dynamic thread pointer.
        // const DTP = @as(i64, @intCast(elf_file.getDtpAddress()));

        relocs_log.debug("  {s}: {x}: [{x} => {x}] G({x}) ({s})", .{
            fmtRelocType(r_type),
            r_offset,
            P,
            S + A,
            G + GOT + A,
            target.name(elf_file),
        });

        try stream.seekTo(r_offset);

        switch (rel.r_type()) {
            elf.R_X86_64_NONE => unreachable,

            elf.R_X86_64_64 => try cwriter.writeIntLittle(i64, S + A),

            elf.R_X86_64_32 => try cwriter.writeIntLittle(u32, @as(u32, @truncate(@as(u64, @intCast(S + A))))),
            elf.R_X86_64_32S => try cwriter.writeIntLittle(i32, @as(i32, @truncate(S + A))),

            elf.R_X86_64_PLT32,
            elf.R_X86_64_PC32,
            => try cwriter.writeIntLittle(i32, @as(i32, @intCast(S + A - P))),

            elf.R_X86_64_GOTPCREL => try cwriter.writeIntLittle(i32, @as(i32, @intCast(G + GOT + A - P))),
            elf.R_X86_64_GOTPC32 => try cwriter.writeIntLittle(i32, @as(i32, @intCast(GOT + A - P))),
            elf.R_X86_64_GOTPC64 => try cwriter.writeIntLittle(i64, GOT + A - P),

            elf.R_X86_64_GOTPCRELX => {
                if (!target.flags.import and !target.isIFunc(elf_file) and !target.isAbs(elf_file)) blk: {
                    x86_64.relaxGotpcrelx(code[r_offset - 2 ..]) catch break :blk;
                    try cwriter.writeIntLittle(i32, @as(i32, @intCast(S + A - P)));
                    continue;
                }
                try cwriter.writeIntLittle(i32, @as(i32, @intCast(G + GOT + A - P)));
            },

            elf.R_X86_64_REX_GOTPCRELX => {
                if (!target.flags.import and !target.isIFunc(elf_file) and !target.isAbs(elf_file)) blk: {
                    x86_64.relaxRexGotpcrelx(code[r_offset - 3 ..]) catch break :blk;
                    try cwriter.writeIntLittle(i32, @as(i32, @intCast(S + A - P)));
                    continue;
                }
                try cwriter.writeIntLittle(i32, @as(i32, @intCast(G + GOT + A - P)));
            },

            else => {
                log.err("TODO: unhandled relocation type {}", .{fmtRelocType(rel.r_type())});
                @panic("TODO unhandled relocation type");
            },
        }
    }
}

pub fn fmtRelocType(r_type: u32) std.fmt.Formatter(formatRelocType) {
    return .{ .data = r_type };
}

fn formatRelocType(
    r_type: u32,
    comptime unused_fmt_string: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = unused_fmt_string;
    _ = options;
    const str = switch (r_type) {
        elf.R_X86_64_NONE => "R_X86_64_NONE",
        elf.R_X86_64_64 => "R_X86_64_64",
        elf.R_X86_64_PC32 => "R_X86_64_PC32",
        elf.R_X86_64_GOT32 => "R_X86_64_GOT32",
        elf.R_X86_64_PLT32 => "R_X86_64_PLT32",
        elf.R_X86_64_COPY => "R_X86_64_COPY",
        elf.R_X86_64_GLOB_DAT => "R_X86_64_GLOB_DAT",
        elf.R_X86_64_JUMP_SLOT => "R_X86_64_JUMP_SLOT",
        elf.R_X86_64_RELATIVE => "R_X86_64_RELATIVE",
        elf.R_X86_64_GOTPCREL => "R_X86_64_GOTPCREL",
        elf.R_X86_64_32 => "R_X86_64_32",
        elf.R_X86_64_32S => "R_X86_64_32S",
        elf.R_X86_64_16 => "R_X86_64_16",
        elf.R_X86_64_PC16 => "R_X86_64_PC16",
        elf.R_X86_64_8 => "R_X86_64_8",
        elf.R_X86_64_PC8 => "R_X86_64_PC8",
        elf.R_X86_64_DTPMOD64 => "R_X86_64_DTPMOD64",
        elf.R_X86_64_DTPOFF64 => "R_X86_64_DTPOFF64",
        elf.R_X86_64_TPOFF64 => "R_X86_64_TPOFF64",
        elf.R_X86_64_TLSGD => "R_X86_64_TLSGD",
        elf.R_X86_64_TLSLD => "R_X86_64_TLSLD",
        elf.R_X86_64_DTPOFF32 => "R_X86_64_DTPOFF32",
        elf.R_X86_64_GOTTPOFF => "R_X86_64_GOTTPOFF",
        elf.R_X86_64_TPOFF32 => "R_X86_64_TPOFF32",
        elf.R_X86_64_PC64 => "R_X86_64_PC64",
        elf.R_X86_64_GOTOFF64 => "R_X86_64_GOTOFF64",
        elf.R_X86_64_GOTPC32 => "R_X86_64_GOTPC32",
        elf.R_X86_64_GOT64 => "R_X86_64_GOT64",
        elf.R_X86_64_GOTPCREL64 => "R_X86_64_GOTPCREL64",
        elf.R_X86_64_GOTPC64 => "R_X86_64_GOTPC64",
        elf.R_X86_64_GOTPLT64 => "R_X86_64_GOTPLT64",
        elf.R_X86_64_PLTOFF64 => "R_X86_64_PLTOFF64",
        elf.R_X86_64_SIZE32 => "R_X86_64_SIZE32",
        elf.R_X86_64_SIZE64 => "R_X86_64_SIZE64",
        elf.R_X86_64_GOTPC32_TLSDESC => "R_X86_64_GOTPC32_TLSDESC",
        elf.R_X86_64_TLSDESC_CALL => "R_X86_64_TLSDESC_CALL",
        elf.R_X86_64_TLSDESC => "R_X86_64_TLSDESC",
        elf.R_X86_64_IRELATIVE => "R_X86_64_IRELATIVE",
        elf.R_X86_64_RELATIVE64 => "R_X86_64_RELATIVE64",
        elf.R_X86_64_GOTPCRELX => "R_X86_64_GOTPCRELX",
        elf.R_X86_64_REX_GOTPCRELX => "R_X86_64_REX_GOTPCRELX",
        elf.R_X86_64_NUM => "R_X86_64_NUM",
        else => "R_X86_64_UNKNOWN",
    };
    try writer.print("{s}", .{str});
}

pub fn format(
    atom: Atom,
    comptime unused_fmt_string: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = atom;
    _ = unused_fmt_string;
    _ = options;
    _ = writer;
    @compileError("do not format symbols directly");
}

pub fn fmt(atom: Atom, elf_file: *Elf) std.fmt.Formatter(format2) {
    return .{ .data = .{
        .atom = atom,
        .elf_file = elf_file,
    } };
}

const FormatContext = struct {
    atom: Atom,
    elf_file: *Elf,
};

fn format2(
    ctx: FormatContext,
    comptime unused_fmt_string: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = options;
    _ = unused_fmt_string;
    const atom = ctx.atom;
    const elf_file = ctx.elf_file;
    try writer.print("atom({d}) : {s} : @{x} : sect({d}) : align({x}) : size({x})", .{
        atom.atom_index,           atom.name(elf_file), atom.value,
        atom.output_section_index, atom.alignment,      atom.size,
    });
    // if (atom.fde_start != atom.fde_end) {
    //     try writer.writeAll(" : fdes{ ");
    //     for (atom.getFdes(elf_file), atom.fde_start..) |fde, i| {
    //         try writer.print("{d}", .{i});
    //         if (!fde.alive) try writer.writeAll("([*])");
    //         if (i < atom.fde_end - 1) try writer.writeAll(", ");
    //     }
    //     try writer.writeAll(" }");
    // }
    const gc_sections = if (elf_file.base.options.gc_sections) |gc_sections| gc_sections else false;
    if (gc_sections and !atom.alive) {
        try writer.writeAll(" : [*]");
    }
}

// TODO this has to be u32 but for now, to avoid redesigning elfSym machinery for
// ZigModule, keep it at u16 with the intention of bumping it to u32 in the near
// future.
pub const Index = u16;

const x86_64 = struct {
    pub fn relaxGotpcrelx(code: []u8) !void {
        const old_inst = disassemble(code) orelse return error.RelaxFail;
        const inst = switch (old_inst.encoding.mnemonic) {
            .call => try Instruction.new(old_inst.prefix, .call, &.{
                // TODO: hack to force imm32s in the assembler
                .{ .imm = Immediate.s(-129) },
            }),
            .jmp => try Instruction.new(old_inst.prefix, .jmp, &.{
                // TODO: hack to force imm32s in the assembler
                .{ .imm = Immediate.s(-129) },
            }),
            else => return error.RelaxFail,
        };
        relocs_log.debug("    relaxing {} => {}", .{ old_inst.encoding, inst.encoding });
        const nop = try Instruction.new(.none, .nop, &.{});
        encode(&.{ nop, inst }, code) catch return error.RelaxFail;
    }

    pub fn relaxRexGotpcrelx(code: []u8) !void {
        const old_inst = disassemble(code) orelse return error.RelaxFail;
        switch (old_inst.encoding.mnemonic) {
            .mov => {
                const inst = try Instruction.new(old_inst.prefix, .lea, &old_inst.ops);
                relocs_log.debug("    relaxing {} => {}", .{ old_inst.encoding, inst.encoding });
                encode(&.{inst}, code) catch return error.RelaxFail;
            },
            else => return error.RelaxFail,
        }
    }

    fn disassemble(code: []const u8) ?Instruction {
        var disas = Disassembler.init(code);
        const inst = disas.next() catch return null;
        return inst;
    }

    fn encode(insts: []const Instruction, code: []u8) !void {
        var stream = std.io.fixedBufferStream(code);
        const writer = stream.writer();
        for (insts) |inst| {
            try inst.encode(writer, .{});
        }
    }

    const bits = @import("../../arch/x86_64/bits.zig");
    const encoder = @import("../../arch/x86_64/encoder.zig");
    const Disassembler = @import("../../arch/x86_64/Disassembler.zig");
    const Immediate = bits.Immediate;
    const Instruction = encoder.Instruction;
};

const std = @import("std");
const assert = std.debug.assert;
const elf = std.elf;
const log = std.log.scoped(.link);
const relocs_log = std.log.scoped(.link_relocs);

const Allocator = std.mem.Allocator;
const Atom = @This();
const Elf = @import("../Elf.zig");
const File = @import("file.zig").File;
const Symbol = @import("Symbol.zig");
