/// Address offset allocated for this Atom wrt to its section start address.
value: u64 = 0,

/// Name of this Atom.
name: u32 = 0,

/// Index into linker's input file table.
file: File.Index = 0,

/// Size of this atom
size: u64 = 0,

/// Alignment of this atom as a power of two.
alignment: Alignment = .@"1",

/// Index of the input section.
n_sect: u32 = 0,

/// Index of the output section.
out_n_sect: u8 = 0,

/// Offset within the parent section pointed to by n_sect.
/// off + size <= parent section size.
off: u64 = 0,

/// Index of this atom in the linker's atoms table.
atom_index: Index = 0,

flags: Flags = .{},

/// Points to the previous and next neighbors, based on the `text_offset`.
/// This can be used to find, for example, the capacity of this `TextBlock`.
prev_index: Index = 0,
next_index: Index = 0,

extra: u32 = 0,

pub fn getName(self: Atom, macho_file: *MachO) [:0]const u8 {
    return switch (self.getFile(macho_file)) {
        .dylib => unreachable,
        .zig_object => |x| x.strtab.getAssumeExists(self.name),
        inline else => |x| x.getString(self.name),
    };
}

pub fn getFile(self: Atom, macho_file: *MachO) File {
    return macho_file.getFile(self.file).?;
}

pub fn getData(self: Atom, macho_file: *MachO, buffer: []u8) !void {
    assert(buffer.len == self.size);
    switch (self.getFile(macho_file)) {
        .internal => |x| try x.getAtomData(self, buffer),
        .object => |x| try x.getAtomData(macho_file, self, buffer),
        .zig_object => |x| try x.getAtomData(macho_file, self, buffer),
        else => unreachable,
    }
}

pub fn getRelocs(self: Atom, macho_file: *MachO) []const Relocation {
    return switch (self.getFile(macho_file)) {
        .dylib => unreachable,
        inline else => |x| x.getAtomRelocs(self, macho_file),
    };
}

pub fn getInputSection(self: Atom, macho_file: *MachO) macho.section_64 {
    return switch (self.getFile(macho_file)) {
        .dylib => unreachable,
        .zig_object => |x| x.getInputSection(self, macho_file),
        .object => |x| x.sections.items(.header)[self.n_sect],
        .internal => |x| x.sections.items(.header)[self.n_sect],
    };
}

pub fn getInputAddress(self: Atom, macho_file: *MachO) u64 {
    return self.getInputSection(macho_file).addr + self.off;
}

pub fn getAddress(self: Atom, macho_file: *MachO) u64 {
    const header = macho_file.sections.items(.header)[self.out_n_sect];
    return header.addr + self.value;
}

pub fn getPriority(self: Atom, macho_file: *MachO) u64 {
    const file = self.getFile(macho_file);
    return (@as(u64, @intCast(file.getIndex())) << 32) | @as(u64, @intCast(self.n_sect));
}

pub fn getUnwindRecords(self: Atom, macho_file: *MachO) []const UnwindInfo.Record.Index {
    if (!self.flags.unwind) return &[0]UnwindInfo.Record.Index{};
    const extra = self.getExtra(macho_file).?;
    return switch (self.getFile(macho_file)) {
        .dylib, .zig_object, .internal => unreachable,
        .object => |x| x.unwind_records.items[extra.unwind_index..][0..extra.unwind_count],
    };
}

pub fn markUnwindRecordsDead(self: Atom, macho_file: *MachO) void {
    for (self.getUnwindRecords(macho_file)) |cu_index| {
        const cu = macho_file.getUnwindRecord(cu_index);
        cu.alive = false;

        if (cu.getFdePtr(macho_file)) |fde| {
            fde.alive = false;
        }
    }
}

pub fn getThunk(self: Atom, macho_file: *MachO) *Thunk {
    assert(self.flags.thunk);
    const extra = self.getExtra(macho_file).?;
    return macho_file.getThunk(extra.thunk);
}

pub fn getLiteralPoolIndex(self: Atom, macho_file: *MachO) ?MachO.LiteralPool.Index {
    if (!self.flags.literal_pool) return null;
    return self.getExtra(macho_file).?.literal_index;
}

const AddExtraOpts = struct {
    thunk: ?u32 = null,
    rel_index: ?u32 = null,
    rel_count: ?u32 = null,
    unwind_index: ?u32 = null,
    unwind_count: ?u32 = null,
    literal_index: ?u32 = null,
};

pub fn addExtra(atom: *Atom, opts: AddExtraOpts, macho_file: *MachO) !void {
    if (atom.getExtra(macho_file) == null) {
        atom.extra = try macho_file.addAtomExtra(.{});
    }
    var extra = atom.getExtra(macho_file).?;
    inline for (@typeInfo(@TypeOf(opts)).Struct.fields) |field| {
        if (@field(opts, field.name)) |x| {
            @field(extra, field.name) = x;
        }
    }
    atom.setExtra(extra, macho_file);
}

pub inline fn getExtra(atom: Atom, macho_file: *MachO) ?Extra {
    return macho_file.getAtomExtra(atom.extra);
}

pub inline fn setExtra(atom: Atom, extra: Extra, macho_file: *MachO) void {
    macho_file.setAtomExtra(atom.extra, extra);
}

pub fn initOutputSection(sect: macho.section_64, macho_file: *MachO) !u8 {
    if (macho_file.base.isRelocatable()) {
        const osec = macho_file.getSectionByName(sect.segName(), sect.sectName()) orelse
            try macho_file.addSection(
            sect.segName(),
            sect.sectName(),
            .{ .flags = sect.flags },
        );
        return osec;
    }

    const segname, const sectname, const flags = blk: {
        if (sect.isCode()) break :blk .{
            "__TEXT",
            "__text",
            macho.S_REGULAR | macho.S_ATTR_PURE_INSTRUCTIONS | macho.S_ATTR_SOME_INSTRUCTIONS,
        };

        switch (sect.type()) {
            macho.S_4BYTE_LITERALS,
            macho.S_8BYTE_LITERALS,
            macho.S_16BYTE_LITERALS,
            => break :blk .{ "__TEXT", "__const", macho.S_REGULAR },

            macho.S_CSTRING_LITERALS => {
                if (mem.startsWith(u8, sect.sectName(), "__objc")) break :blk .{
                    sect.segName(), sect.sectName(), macho.S_REGULAR,
                };
                break :blk .{ "__TEXT", "__cstring", macho.S_CSTRING_LITERALS };
            },

            macho.S_MOD_INIT_FUNC_POINTERS,
            macho.S_MOD_TERM_FUNC_POINTERS,
            => break :blk .{ "__DATA_CONST", sect.sectName(), sect.flags },

            macho.S_LITERAL_POINTERS,
            macho.S_ZEROFILL,
            macho.S_GB_ZEROFILL,
            macho.S_THREAD_LOCAL_VARIABLES,
            macho.S_THREAD_LOCAL_VARIABLE_POINTERS,
            macho.S_THREAD_LOCAL_REGULAR,
            macho.S_THREAD_LOCAL_ZEROFILL,
            => break :blk .{ sect.segName(), sect.sectName(), sect.flags },

            macho.S_COALESCED => break :blk .{
                sect.segName(),
                sect.sectName(),
                macho.S_REGULAR,
            },

            macho.S_REGULAR => {
                const segname = sect.segName();
                const sectname = sect.sectName();
                if (mem.eql(u8, segname, "__DATA")) {
                    if (mem.eql(u8, sectname, "__cfstring") or
                        mem.eql(u8, sectname, "__objc_classlist") or
                        mem.eql(u8, sectname, "__objc_imageinfo")) break :blk .{
                        "__DATA_CONST",
                        sectname,
                        macho.S_REGULAR,
                    };
                }
                break :blk .{ segname, sectname, sect.flags };
            },

            else => break :blk .{ sect.segName(), sect.sectName(), sect.flags },
        }
    };
    return macho_file.getSectionByName(segname, sectname) orelse try macho_file.addSection(
        segname,
        sectname,
        .{ .flags = flags },
    );
}

/// Returns how much room there is to grow in virtual address space.
/// File offset relocation happens transparently, so it is not included in
/// this calculation.
pub fn capacity(self: Atom, macho_file: *MachO) u64 {
    const next_addr = if (macho_file.getAtom(self.next_index)) |next|
        next.getAddress(macho_file)
    else
        std.math.maxInt(u32);
    return next_addr - self.getAddress(macho_file);
}

pub fn freeListEligible(self: Atom, macho_file: *MachO) bool {
    // No need to keep a free list node for the last block.
    const next = macho_file.getAtom(self.next_index) orelse return false;
    const cap = next.getAddress(macho_file) - self.getAddress(macho_file);
    const ideal_cap = MachO.padToIdeal(self.size);
    if (cap <= ideal_cap) return false;
    const surplus = cap - ideal_cap;
    return surplus >= MachO.min_text_capacity;
}

pub fn allocate(self: *Atom, macho_file: *MachO) !void {
    const sect = &macho_file.sections.items(.header)[self.out_n_sect];
    const free_list = &macho_file.sections.items(.free_list)[self.out_n_sect];
    const last_atom_index = &macho_file.sections.items(.last_atom_index)[self.out_n_sect];
    const new_atom_ideal_capacity = MachO.padToIdeal(self.size);

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
        var i: usize = free_list.items.len;
        while (i < free_list.items.len) {
            const big_atom_index = free_list.items[i];
            const big_atom = macho_file.getAtom(big_atom_index).?;
            // We now have a pointer to a live atom that has too much capacity.
            // Is it enough that we could fit this new atom?
            const cap = big_atom.capacity(macho_file);
            const ideal_capacity = MachO.padToIdeal(cap);
            const ideal_capacity_end_vaddr = std.math.add(u64, big_atom.value, ideal_capacity) catch ideal_capacity;
            const capacity_end_vaddr = big_atom.value + cap;
            const new_start_vaddr_unaligned = capacity_end_vaddr - new_atom_ideal_capacity;
            const new_start_vaddr = self.alignment.backward(new_start_vaddr_unaligned);
            if (new_start_vaddr < ideal_capacity_end_vaddr) {
                // Additional bookkeeping here to notice if this free list node
                // should be deleted because the block that it points to has grown to take up
                // more of the extra capacity.
                if (!big_atom.freeListEligible(macho_file)) {
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
            const keep_free_list_node = remaining_capacity >= MachO.min_text_capacity;

            // Set up the metadata to be updated, after errors are no longer possible.
            atom_placement = big_atom_index;
            if (!keep_free_list_node) {
                free_list_removal = i;
            }
            break :blk new_start_vaddr;
        } else if (macho_file.getAtom(last_atom_index.*)) |last| {
            const ideal_capacity = MachO.padToIdeal(last.size);
            const ideal_capacity_end_vaddr = last.value + ideal_capacity;
            const new_start_vaddr = self.alignment.forward(ideal_capacity_end_vaddr);
            // Set up the metadata to be updated, after errors are no longer possible.
            atom_placement = last.atom_index;
            break :blk new_start_vaddr;
        } else {
            break :blk 0;
        }
    };

    log.debug("allocated atom({d}) : '{s}' at 0x{x} to 0x{x}", .{
        self.atom_index,
        self.getName(macho_file),
        self.getAddress(macho_file),
        self.getAddress(macho_file) + self.size,
    });

    const expand_section = if (atom_placement) |placement_index|
        macho_file.getAtom(placement_index).?.next_index == 0
    else
        true;
    if (expand_section) {
        const needed_size = self.value + self.size;
        try macho_file.growSection(self.out_n_sect, needed_size);
        last_atom_index.* = self.atom_index;

        // const zig_object = macho_file_file.getZigObject().?;
        // if (zig_object.dwarf) |_| {
        //     // The .debug_info section has `low_pc` and `high_pc` values which is the virtual address
        //     // range of the compilation unit. When we expand the text section, this range changes,
        //     // so the DW_TAG.compile_unit tag of the .debug_info section becomes dirty.
        //     zig_object.debug_info_header_dirty = true;
        //     // This becomes dirty for the same reason. We could potentially make this more
        //     // fine-grained with the addition of support for more compilation units. It is planned to
        //     // model each package as a different compilation unit.
        //     zig_object.debug_aranges_section_dirty = true;
        // }
    }
    sect.@"align" = @max(sect.@"align", self.alignment.toLog2Units());

    // This function can also reallocate an atom.
    // In this case we need to "unplug" it from its previous location before
    // plugging it in to its new location.
    if (macho_file.getAtom(self.prev_index)) |prev| {
        prev.next_index = self.next_index;
    }
    if (macho_file.getAtom(self.next_index)) |next| {
        next.prev_index = self.prev_index;
    }

    if (atom_placement) |big_atom_index| {
        const big_atom = macho_file.getAtom(big_atom_index).?;
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

    self.flags.alive = true;
}

pub fn shrink(self: *Atom, macho_file: *MachO) void {
    _ = self;
    _ = macho_file;
}

pub fn grow(self: *Atom, macho_file: *MachO) !void {
    if (!self.alignment.check(self.value) or self.size > self.capacity(macho_file))
        try self.allocate(macho_file);
}

pub fn free(self: *Atom, macho_file: *MachO) void {
    log.debug("freeAtom {d} ({s})", .{ self.atom_index, self.getName(macho_file) });

    const comp = macho_file.base.comp;
    const gpa = comp.gpa;
    const free_list = &macho_file.sections.items(.free_list)[self.out_n_sect];
    const last_atom_index = &macho_file.sections.items(.last_atom_index)[self.out_n_sect];
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

    if (macho_file.getAtom(last_atom_index.*)) |last_atom| {
        if (last_atom.atom_index == self.atom_index) {
            if (macho_file.getAtom(self.prev_index)) |_| {
                // TODO shrink the section size here
                last_atom_index.* = self.prev_index;
            } else {
                last_atom_index.* = 0;
            }
        }
    }

    if (macho_file.getAtom(self.prev_index)) |prev| {
        prev.next_index = self.next_index;
        if (!already_have_free_list_node and prev.*.freeListEligible(macho_file)) {
            // The free list is heuristics, it doesn't have to be perfect, so we can
            // ignore the OOM here.
            free_list.append(gpa, prev.atom_index) catch {};
        }
    } else {
        self.prev_index = 0;
    }

    if (macho_file.getAtom(self.next_index)) |next| {
        next.prev_index = self.prev_index;
    } else {
        self.next_index = 0;
    }

    // TODO create relocs free list
    self.freeRelocs(macho_file);
    // TODO figure out how to free input section mappind in ZigModule
    // const zig_object = macho_file.zigObjectPtr().?
    // assert(zig_object.atoms.swapRemove(self.atom_index));
    self.* = .{};
}

pub fn addReloc(self: *Atom, macho_file: *MachO, reloc: Relocation) !void {
    const gpa = macho_file.base.comp.gpa;
    const file = self.getFile(macho_file);
    assert(file == .zig_object);
    assert(self.flags.relocs);
    var extra = self.getExtra(macho_file).?;
    const rels = &file.zig_object.relocs.items[extra.rel_index];
    try rels.append(gpa, reloc);
    extra.rel_count += 1;
    self.setExtra(extra, macho_file);
}

pub fn freeRelocs(self: *Atom, macho_file: *MachO) void {
    if (!self.flags.relocs) return;
    self.getFile(macho_file).zig_object.freeAtomRelocs(self.*, macho_file);
    var extra = self.getExtra(macho_file).?;
    extra.rel_count = 0;
    self.setExtra(extra, macho_file);
}

pub fn scanRelocs(self: Atom, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();
    assert(self.flags.alive);

    const dynrel_ctx = switch (self.getFile(macho_file)) {
        .zig_object => |x| &x.dynamic_relocs,
        .object => |x| &x.dynamic_relocs,
        else => unreachable,
    };
    const relocs = self.getRelocs(macho_file);

    for (relocs) |rel| {
        if (try self.reportUndefSymbol(rel, macho_file)) continue;

        switch (rel.type) {
            .branch => {
                const symbol = rel.getTargetSymbol(macho_file);
                if (symbol.flags.import or (symbol.flags.@"export" and symbol.flags.weak) or symbol.flags.interposable) {
                    symbol.flags.stubs = true;
                    if (symbol.flags.weak) {
                        macho_file.binds_to_weak = true;
                    }
                } else if (mem.startsWith(u8, symbol.getName(macho_file), "_objc_msgSend$")) {
                    symbol.flags.objc_stubs = true;
                }
            },

            .got_load,
            .got_load_page,
            .got_load_pageoff,
            => {
                const symbol = rel.getTargetSymbol(macho_file);
                if (symbol.flags.import or
                    (symbol.flags.@"export" and symbol.flags.weak) or
                    symbol.flags.interposable or
                    macho_file.getTarget().cpu.arch == .aarch64) // TODO relax on arm64
                {
                    symbol.flags.needs_got = true;
                    if (symbol.flags.weak) {
                        macho_file.binds_to_weak = true;
                    }
                }
            },

            .zig_got_load => {
                assert(rel.getTargetSymbol(macho_file).flags.has_zig_got);
            },

            .got => {
                rel.getTargetSymbol(macho_file).flags.needs_got = true;
            },

            .tlv,
            .tlvp_page,
            .tlvp_pageoff,
            => {
                const symbol = rel.getTargetSymbol(macho_file);
                if (!symbol.flags.tlv) {
                    try macho_file.reportParseError2(
                        self.getFile(macho_file).getIndex(),
                        "{s}: illegal thread-local variable reference to regular symbol {s}",
                        .{ self.getName(macho_file), symbol.getName(macho_file) },
                    );
                }
                if (symbol.flags.import or (symbol.flags.@"export" and symbol.flags.weak) or symbol.flags.interposable) {
                    symbol.flags.tlv_ptr = true;
                    if (symbol.flags.weak) {
                        macho_file.binds_to_weak = true;
                    }
                }
            },

            .unsigned => {
                if (rel.meta.length == 3) { // TODO this really should check if this is pointer width
                    if (rel.tag == .@"extern") {
                        const symbol = rel.getTargetSymbol(macho_file);
                        if (symbol.isTlvInit(macho_file)) {
                            macho_file.has_tlv = true;
                            continue;
                        }
                        if (symbol.flags.import) {
                            dynrel_ctx.bind_relocs += 1;
                            if (symbol.flags.weak) {
                                dynrel_ctx.weak_bind_relocs += 1;
                                macho_file.binds_to_weak = true;
                            }
                            continue;
                        }
                        if (symbol.flags.@"export" and symbol.flags.weak) {
                            dynrel_ctx.weak_bind_relocs += 1;
                            macho_file.binds_to_weak = true;
                        } else if (symbol.flags.interposable) {
                            dynrel_ctx.bind_relocs += 1;
                        }
                    }
                    dynrel_ctx.rebase_relocs += 1;
                }
            },

            .signed,
            .signed1,
            .signed2,
            .signed4,
            .page,
            .pageoff,
            .subtractor,
            => {},
        }
    }
}

fn reportUndefSymbol(self: Atom, rel: Relocation, macho_file: *MachO) !bool {
    if (rel.tag == .local) return false;

    const sym = rel.getTargetSymbol(macho_file);
    if (sym.getFile(macho_file) == null) {
        const gpa = macho_file.base.comp.gpa;
        const gop = try macho_file.undefs.getOrPut(gpa, rel.target);
        if (!gop.found_existing) {
            gop.value_ptr.* = .{};
        }
        try gop.value_ptr.append(gpa, self.atom_index);
        return true;
    }

    return false;
}

pub fn resolveRelocs(self: Atom, macho_file: *MachO, buffer: []u8) !void {
    const tracy = trace(@src());
    defer tracy.end();

    assert(!self.getInputSection(macho_file).isZerofill());
    const file = self.getFile(macho_file);
    const name = self.getName(macho_file);
    const relocs = self.getRelocs(macho_file);

    relocs_log.debug("{x}: {s}", .{ self.getAddress(macho_file), name });

    var has_error = false;
    var stream = std.io.fixedBufferStream(buffer);
    var i: usize = 0;
    while (i < relocs.len) : (i += 1) {
        const rel = relocs[i];
        const rel_offset = rel.offset - self.off;
        const subtractor = if (rel.meta.has_subtractor) relocs[i - 1] else null;

        if (rel.tag == .@"extern") {
            if (rel.getTargetSymbol(macho_file).getFile(macho_file) == null) continue;
        }

        try stream.seekTo(rel_offset);
        self.resolveRelocInner(rel, subtractor, buffer, macho_file, stream.writer()) catch |err| {
            switch (err) {
                error.RelaxFail => {
                    const target = switch (rel.tag) {
                        .@"extern" => rel.getTargetSymbol(macho_file).getName(macho_file),
                        .local => rel.getTargetAtom(macho_file).getName(macho_file),
                    };
                    try macho_file.reportParseError2(
                        file.getIndex(),
                        "{s}: 0x{x}: 0x{x}: failed to relax relocation: type {s}, target {s}",
                        .{ name, self.getAddress(macho_file), rel.offset, @tagName(rel.type), target },
                    );
                    has_error = true;
                },
                error.RelaxFailUnexpectedInstruction => has_error = true,
                else => |e| return e,
            }
        };
    }

    if (has_error) return error.ResolveFailed;
}

const ResolveError = error{
    RelaxFail,
    RelaxFailUnexpectedInstruction,
    NoSpaceLeft,
    DivisionByZero,
    UnexpectedRemainder,
    Overflow,
    OutOfMemory,
};

fn resolveRelocInner(
    self: Atom,
    rel: Relocation,
    subtractor: ?Relocation,
    code: []u8,
    macho_file: *MachO,
    writer: anytype,
) ResolveError!void {
    const cpu_arch = macho_file.getTarget().cpu.arch;
    const rel_offset = math.cast(usize, rel.offset - self.off) orelse return error.Overflow;
    const seg_id = macho_file.sections.items(.segment_id)[self.out_n_sect];
    const seg = macho_file.segments.items[seg_id];
    const P = @as(i64, @intCast(self.getAddress(macho_file))) + @as(i64, @intCast(rel_offset));
    const A = rel.addend + rel.getRelocAddend(cpu_arch);
    const S: i64 = @intCast(rel.getTargetAddress(macho_file));
    const G: i64 = @intCast(rel.getGotTargetAddress(macho_file));
    const TLS = @as(i64, @intCast(macho_file.getTlsAddress()));
    const SUB = if (subtractor) |sub| @as(i64, @intCast(sub.getTargetAddress(macho_file))) else 0;
    // Address of the __got_zig table entry if any.
    const ZIG_GOT = @as(i64, @intCast(rel.getZigGotTargetAddress(macho_file)));

    const divExact = struct {
        fn divExact(atom: Atom, r: Relocation, num: u12, den: u12, ctx: *MachO) !u12 {
            return math.divExact(u12, num, den) catch {
                try ctx.reportParseError2(atom.getFile(ctx).getIndex(), "{s}: unexpected remainder when resolving {s} at offset 0x{x}", .{
                    atom.getName(ctx),
                    r.fmtPretty(ctx.getTarget().cpu.arch),
                    r.offset,
                });
                return error.UnexpectedRemainder;
            };
        }
    }.divExact;

    switch (rel.tag) {
        .local => relocs_log.debug("  {x}<+{d}>: {s}: [=> {x}] atom({d})", .{
            P,
            rel_offset,
            @tagName(rel.type),
            S + A - SUB,
            rel.getTargetAtom(macho_file).atom_index,
        }),
        .@"extern" => relocs_log.debug("  {x}<+{d}>: {s}: [=> {x}] G({x}) ZG({x}) ({s})", .{
            P,
            rel_offset,
            @tagName(rel.type),
            S + A - SUB,
            G + A,
            ZIG_GOT + A,
            rel.getTargetSymbol(macho_file).getName(macho_file),
        }),
    }

    switch (rel.type) {
        .subtractor => {},

        .unsigned => {
            assert(!rel.meta.pcrel);
            if (rel.meta.length == 3) {
                if (rel.tag == .@"extern") {
                    const sym = rel.getTargetSymbol(macho_file);
                    if (sym.isTlvInit(macho_file)) {
                        try writer.writeInt(u64, @intCast(S - TLS), .little);
                        return;
                    }
                    const entry = bind.Entry{
                        .target = rel.target,
                        .offset = @as(u64, @intCast(P)) - seg.vmaddr,
                        .segment_id = seg_id,
                        .addend = A,
                    };
                    if (sym.flags.import) {
                        macho_file.bind.entries.appendAssumeCapacity(entry);
                        if (sym.flags.weak) {
                            macho_file.weak_bind.entries.appendAssumeCapacity(entry);
                        }
                        return;
                    }
                    if (sym.flags.@"export" and sym.flags.weak) {
                        macho_file.weak_bind.entries.appendAssumeCapacity(entry);
                    } else if (sym.flags.interposable) {
                        macho_file.bind.entries.appendAssumeCapacity(entry);
                    }
                }
                macho_file.rebase.entries.appendAssumeCapacity(.{
                    .offset = @as(u64, @intCast(P)) - seg.vmaddr,
                    .segment_id = seg_id,
                });
                try writer.writeInt(u64, @bitCast(S + A - SUB), .little);
            } else if (rel.meta.length == 2) {
                try writer.writeInt(u32, @bitCast(@as(i32, @truncate(S + A - SUB))), .little);
            } else unreachable;
        },

        .got => {
            assert(rel.tag == .@"extern");
            assert(rel.meta.length == 2);
            assert(rel.meta.pcrel);
            try writer.writeInt(i32, @intCast(G + A - P), .little);
        },

        .branch => {
            assert(rel.meta.length == 2);
            assert(rel.meta.pcrel);
            assert(rel.tag == .@"extern");

            switch (cpu_arch) {
                .x86_64 => try writer.writeInt(i32, @intCast(S + A - P), .little),
                .aarch64 => {
                    const disp: i28 = math.cast(i28, S + A - P) orelse blk: {
                        const thunk = self.getThunk(macho_file);
                        const S_: i64 = @intCast(thunk.getTargetAddress(rel.target, macho_file));
                        break :blk math.cast(i28, S_ + A - P) orelse return error.Overflow;
                    };
                    aarch64.writeBranchImm(disp, code[rel_offset..][0..4]);
                },
                else => unreachable,
            }
        },

        .got_load => {
            assert(rel.tag == .@"extern");
            assert(rel.meta.length == 2);
            assert(rel.meta.pcrel);
            if (rel.getTargetSymbol(macho_file).flags.has_got) {
                try writer.writeInt(i32, @intCast(G + A - P), .little);
            } else {
                try x86_64.relaxGotLoad(self, code[rel_offset - 3 ..], rel, macho_file);
                try writer.writeInt(i32, @intCast(S + A - P), .little);
            }
        },

        .zig_got_load => {
            assert(rel.tag == .@"extern");
            assert(rel.meta.length == 2);
            assert(rel.meta.pcrel);
            switch (cpu_arch) {
                .x86_64 => try writer.writeInt(i32, @intCast(ZIG_GOT + A - P), .little),
                .aarch64 => @panic("TODO resolve __got_zig indirection reloc"),
                else => unreachable,
            }
        },

        .tlv => {
            assert(rel.tag == .@"extern");
            assert(rel.meta.length == 2);
            assert(rel.meta.pcrel);
            const sym = rel.getTargetSymbol(macho_file);
            if (sym.flags.tlv_ptr) {
                const S_: i64 = @intCast(sym.getTlvPtrAddress(macho_file));
                try writer.writeInt(i32, @intCast(S_ + A - P), .little);
            } else {
                try x86_64.relaxTlv(code[rel_offset - 3 ..]);
                try writer.writeInt(i32, @intCast(S + A - P), .little);
            }
        },

        .signed, .signed1, .signed2, .signed4 => {
            assert(rel.meta.length == 2);
            assert(rel.meta.pcrel);
            try writer.writeInt(i32, @intCast(S + A - P), .little);
        },

        .page,
        .got_load_page,
        .tlvp_page,
        => {
            assert(rel.tag == .@"extern");
            assert(rel.meta.length == 2);
            assert(rel.meta.pcrel);
            const sym = rel.getTargetSymbol(macho_file);
            const source = math.cast(u64, P) orelse return error.Overflow;
            const target = target: {
                const target = switch (rel.type) {
                    .page => S + A,
                    .got_load_page => G + A,
                    .tlvp_page => if (sym.flags.tlv_ptr) blk: {
                        const S_: i64 = @intCast(sym.getTlvPtrAddress(macho_file));
                        break :blk S_ + A;
                    } else S + A,
                    else => unreachable,
                };
                break :target math.cast(u64, target) orelse return error.Overflow;
            };
            const pages = @as(u21, @bitCast(try aarch64.calcNumberOfPages(@intCast(source), @intCast(target))));
            aarch64.writeAdrpInst(pages, code[rel_offset..][0..4]);
        },

        .pageoff => {
            assert(rel.tag == .@"extern");
            assert(rel.meta.length == 2);
            assert(!rel.meta.pcrel);
            const target = math.cast(u64, S + A) orelse return error.Overflow;
            const inst_code = code[rel_offset..][0..4];
            if (aarch64.isArithmeticOp(inst_code)) {
                aarch64.writeAddImmInst(@truncate(target), inst_code);
            } else {
                var inst = aarch64.Instruction{
                    .load_store_register = mem.bytesToValue(std.meta.TagPayload(
                        aarch64.Instruction,
                        aarch64.Instruction.load_store_register,
                    ), inst_code),
                };
                inst.load_store_register.offset = switch (inst.load_store_register.size) {
                    0 => if (inst.load_store_register.v == 1)
                        try divExact(self, rel, @truncate(target), 16, macho_file)
                    else
                        @truncate(target),
                    1 => try divExact(self, rel, @truncate(target), 2, macho_file),
                    2 => try divExact(self, rel, @truncate(target), 4, macho_file),
                    3 => try divExact(self, rel, @truncate(target), 8, macho_file),
                };
                try writer.writeInt(u32, inst.toU32(), .little);
            }
        },

        .got_load_pageoff => {
            assert(rel.tag == .@"extern");
            assert(rel.meta.length == 2);
            assert(!rel.meta.pcrel);
            const target = math.cast(u64, G + A) orelse return error.Overflow;
            aarch64.writeLoadStoreRegInst(try divExact(self, rel, @truncate(target), 8, macho_file), code[rel_offset..][0..4]);
        },

        .tlvp_pageoff => {
            assert(rel.tag == .@"extern");
            assert(rel.meta.length == 2);
            assert(!rel.meta.pcrel);

            const sym = rel.getTargetSymbol(macho_file);
            const target = target: {
                const target = if (sym.flags.tlv_ptr) blk: {
                    const S_: i64 = @intCast(sym.getTlvPtrAddress(macho_file));
                    break :blk S_ + A;
                } else S + A;
                break :target math.cast(u64, target) orelse return error.Overflow;
            };

            const RegInfo = struct {
                rd: u5,
                rn: u5,
                size: u2,
            };

            const inst_code = code[rel_offset..][0..4];
            const reg_info: RegInfo = blk: {
                if (aarch64.isArithmeticOp(inst_code)) {
                    const inst = mem.bytesToValue(std.meta.TagPayload(
                        aarch64.Instruction,
                        aarch64.Instruction.add_subtract_immediate,
                    ), inst_code);
                    break :blk .{
                        .rd = inst.rd,
                        .rn = inst.rn,
                        .size = inst.sf,
                    };
                } else {
                    const inst = mem.bytesToValue(std.meta.TagPayload(
                        aarch64.Instruction,
                        aarch64.Instruction.load_store_register,
                    ), inst_code);
                    break :blk .{
                        .rd = inst.rt,
                        .rn = inst.rn,
                        .size = inst.size,
                    };
                }
            };

            var inst = if (sym.flags.tlv_ptr) aarch64.Instruction{
                .load_store_register = .{
                    .rt = reg_info.rd,
                    .rn = reg_info.rn,
                    .offset = try divExact(self, rel, @truncate(target), 8, macho_file),
                    .opc = 0b01,
                    .op1 = 0b01,
                    .v = 0,
                    .size = reg_info.size,
                },
            } else aarch64.Instruction{
                .add_subtract_immediate = .{
                    .rd = reg_info.rd,
                    .rn = reg_info.rn,
                    .imm12 = @truncate(target),
                    .sh = 0,
                    .s = 0,
                    .op = 0,
                    .sf = @as(u1, @truncate(reg_info.size)),
                },
            };
            try writer.writeInt(u32, inst.toU32(), .little);
        },
    }
}

const x86_64 = struct {
    fn relaxGotLoad(self: Atom, code: []u8, rel: Relocation, macho_file: *MachO) ResolveError!void {
        const old_inst = disassemble(code) orelse return error.RelaxFail;
        switch (old_inst.encoding.mnemonic) {
            .mov => {
                const inst = Instruction.new(old_inst.prefix, .lea, &old_inst.ops) catch return error.RelaxFail;
                relocs_log.debug("    relaxing {} => {}", .{ old_inst.encoding, inst.encoding });
                encode(&.{inst}, code) catch return error.RelaxFail;
            },
            else => |x| {
                var err = try macho_file.addErrorWithNotes(2);
                try err.addMsg(macho_file, "{s}: 0x{x}: 0x{x}: failed to relax relocation of type {s}", .{
                    self.getName(macho_file),
                    self.getAddress(macho_file),
                    rel.offset,
                    @tagName(rel.type),
                });
                try err.addNote(macho_file, "expected .mov instruction but found .{s}", .{@tagName(x)});
                try err.addNote(macho_file, "while parsing {}", .{self.getFile(macho_file).fmtPath()});
                return error.RelaxFailUnexpectedInstruction;
            },
        }
    }

    fn relaxTlv(code: []u8) error{RelaxFail}!void {
        const old_inst = disassemble(code) orelse return error.RelaxFail;
        switch (old_inst.encoding.mnemonic) {
            .mov => {
                const inst = Instruction.new(old_inst.prefix, .lea, &old_inst.ops) catch return error.RelaxFail;
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

pub fn calcNumRelocs(self: Atom, macho_file: *MachO) u32 {
    const relocs = self.getRelocs(macho_file);
    switch (macho_file.getTarget().cpu.arch) {
        .aarch64 => {
            var nreloc: u32 = 0;
            for (relocs) |rel| {
                nreloc += 1;
                switch (rel.type) {
                    .page, .pageoff => if (rel.addend > 0) {
                        nreloc += 1;
                    },
                    else => {},
                }
            }
            return nreloc;
        },
        .x86_64 => return @intCast(relocs.len),
        else => unreachable,
    }
}

pub fn writeRelocs(self: Atom, macho_file: *MachO, code: []u8, buffer: *std.ArrayList(macho.relocation_info)) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const cpu_arch = macho_file.getTarget().cpu.arch;
    const relocs = self.getRelocs(macho_file);
    var stream = std.io.fixedBufferStream(code);

    for (relocs) |rel| {
        const rel_offset = rel.offset - self.off;
        const r_address: i32 = math.cast(i32, self.value + rel_offset) orelse return error.Overflow;
        const r_symbolnum = r_symbolnum: {
            const r_symbolnum: u32 = switch (rel.tag) {
                .local => rel.getTargetAtom(macho_file).out_n_sect + 1,
                .@"extern" => rel.getTargetSymbol(macho_file).getOutputSymtabIndex(macho_file).?,
            };
            break :r_symbolnum math.cast(u24, r_symbolnum) orelse return error.Overflow;
        };
        const r_extern = rel.tag == .@"extern";
        var addend = rel.addend + rel.getRelocAddend(cpu_arch);
        if (rel.tag == .local) {
            const target: i64 = @intCast(rel.getTargetAddress(macho_file));
            addend += target;
        }

        try stream.seekTo(rel_offset);

        switch (cpu_arch) {
            .aarch64 => {
                if (rel.type == .unsigned) switch (rel.meta.length) {
                    0, 1 => unreachable,
                    2 => try stream.writer().writeInt(i32, @truncate(addend), .little),
                    3 => try stream.writer().writeInt(i64, addend, .little),
                } else if (addend > 0) {
                    buffer.appendAssumeCapacity(.{
                        .r_address = r_address,
                        .r_symbolnum = @bitCast(math.cast(i24, addend) orelse return error.Overflow),
                        .r_pcrel = 0,
                        .r_length = 2,
                        .r_extern = 0,
                        .r_type = @intFromEnum(macho.reloc_type_arm64.ARM64_RELOC_ADDEND),
                    });
                }

                const r_type: macho.reloc_type_arm64 = switch (rel.type) {
                    .page => .ARM64_RELOC_PAGE21,
                    .pageoff => .ARM64_RELOC_PAGEOFF12,
                    .got_load_page => .ARM64_RELOC_GOT_LOAD_PAGE21,
                    .got_load_pageoff => .ARM64_RELOC_GOT_LOAD_PAGEOFF12,
                    .tlvp_page => .ARM64_RELOC_TLVP_LOAD_PAGE21,
                    .tlvp_pageoff => .ARM64_RELOC_TLVP_LOAD_PAGEOFF12,
                    .branch => .ARM64_RELOC_BRANCH26,
                    .got => .ARM64_RELOC_POINTER_TO_GOT,
                    .subtractor => .ARM64_RELOC_SUBTRACTOR,
                    .unsigned => .ARM64_RELOC_UNSIGNED,

                    .zig_got_load,
                    .signed,
                    .signed1,
                    .signed2,
                    .signed4,
                    .got_load,
                    .tlv,
                    => unreachable,
                };
                buffer.appendAssumeCapacity(.{
                    .r_address = r_address,
                    .r_symbolnum = r_symbolnum,
                    .r_pcrel = @intFromBool(rel.meta.pcrel),
                    .r_extern = @intFromBool(r_extern),
                    .r_length = rel.meta.length,
                    .r_type = @intFromEnum(r_type),
                });
            },
            .x86_64 => {
                if (rel.meta.pcrel) {
                    if (rel.tag == .local) {
                        addend -= @as(i64, @intCast(self.getAddress(macho_file) + rel_offset));
                    } else {
                        addend += 4;
                    }
                }
                switch (rel.meta.length) {
                    0, 1 => unreachable,
                    2 => try stream.writer().writeInt(i32, @truncate(addend), .little),
                    3 => try stream.writer().writeInt(i64, addend, .little),
                }

                const r_type: macho.reloc_type_x86_64 = switch (rel.type) {
                    .signed => .X86_64_RELOC_SIGNED,
                    .signed1 => .X86_64_RELOC_SIGNED_1,
                    .signed2 => .X86_64_RELOC_SIGNED_2,
                    .signed4 => .X86_64_RELOC_SIGNED_4,
                    .got_load => .X86_64_RELOC_GOT_LOAD,
                    .tlv => .X86_64_RELOC_TLV,
                    .branch => .X86_64_RELOC_BRANCH,
                    .got => .X86_64_RELOC_GOT,
                    .subtractor => .X86_64_RELOC_SUBTRACTOR,
                    .unsigned => .X86_64_RELOC_UNSIGNED,

                    .zig_got_load,
                    .page,
                    .pageoff,
                    .got_load_page,
                    .got_load_pageoff,
                    .tlvp_page,
                    .tlvp_pageoff,
                    => unreachable,
                };
                buffer.appendAssumeCapacity(.{
                    .r_address = r_address,
                    .r_symbolnum = r_symbolnum,
                    .r_pcrel = @intFromBool(rel.meta.pcrel),
                    .r_extern = @intFromBool(r_extern),
                    .r_length = rel.meta.length,
                    .r_type = @intFromEnum(r_type),
                });
            },
            else => unreachable,
        }
    }
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
    @compileError("do not format Atom directly");
}

pub fn fmt(atom: Atom, macho_file: *MachO) std.fmt.Formatter(format2) {
    return .{ .data = .{
        .atom = atom,
        .macho_file = macho_file,
    } };
}

const FormatContext = struct {
    atom: Atom,
    macho_file: *MachO,
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
    const macho_file = ctx.macho_file;
    try writer.print("atom({d}) : {s} : @{x} : sect({d}) : align({x}) : size({x}) : nreloc({d})", .{
        atom.atom_index,                atom.getName(macho_file), atom.getAddress(macho_file),
        atom.out_n_sect,                atom.alignment,           atom.size,
        atom.getRelocs(macho_file).len,
    });
    if (atom.flags.thunk) try writer.print(" : thunk({d})", .{atom.getExtra(macho_file).?.thunk});
    if (!atom.flags.alive) try writer.writeAll(" : [*]");
    if (atom.flags.unwind) {
        try writer.writeAll(" : unwind{ ");
        const extra = atom.getExtra(macho_file).?;
        for (atom.getUnwindRecords(macho_file), extra.unwind_index..) |index, i| {
            const rec = macho_file.getUnwindRecord(index);
            try writer.print("{d}", .{index});
            if (!rec.alive) try writer.writeAll("([*])");
            if (i < extra.unwind_index + extra.unwind_count - 1) try writer.writeAll(", ");
        }
        try writer.writeAll(" }");
    }
}

pub const Index = u32;

pub const Flags = packed struct {
    /// Specifies whether this atom is alive or has been garbage collected.
    alive: bool = true,

    /// Specifies if this atom has been visited during garbage collection.
    visited: bool = false,

    /// Whether this atom has a range extension thunk.
    thunk: bool = false,

    /// Whether this atom has any relocations.
    relocs: bool = false,

    /// Whether this atom has any unwind records.
    unwind: bool = false,

    /// Whether this atom has LiteralPool entry.
    literal_pool: bool = false,
};

pub const Extra = struct {
    /// Index of the range extension thunk of this atom.
    thunk: u32 = 0,

    /// Start index of relocations belonging to this atom.
    rel_index: u32 = 0,

    /// Count of relocations belonging to this atom.
    rel_count: u32 = 0,

    /// Start index of relocations belonging to this atom.
    unwind_index: u32 = 0,

    /// Count of relocations belonging to this atom.
    unwind_count: u32 = 0,

    /// Index into LiteralPool entry for this atom.
    literal_index: u32 = 0,
};

pub const Alignment = @import("../../InternPool.zig").Alignment;

const aarch64 = @import("../aarch64.zig");
const assert = std.debug.assert;
const bind = @import("dyld_info/bind.zig");
const macho = std.macho;
const math = std.math;
const mem = std.mem;
const log = std.log.scoped(.link);
const relocs_log = std.log.scoped(.link_relocs);
const std = @import("std");
const trace = @import("../../tracy.zig").trace;

const Allocator = mem.Allocator;
const Atom = @This();
const File = @import("file.zig").File;
const MachO = @import("../MachO.zig");
const Object = @import("Object.zig");
const Relocation = @import("Relocation.zig");
const Symbol = @import("Symbol.zig");
const Thunk = @import("thunks.zig").Thunk;
const UnwindInfo = @import("UnwindInfo.zig");
