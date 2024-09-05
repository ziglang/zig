/// Address allocated for this Atom.
value: i64 = 0,

/// Name of this Atom.
name_offset: u32 = 0,

/// Index into linker's input file table.
file_index: File.Index = 0,

/// Size of this atom
size: u64 = 0,

/// Alignment of this atom as a power of two.
alignment: Alignment = .@"1",

/// Index of the input section.
input_section_index: u32 = 0,

/// Index of the output section.
output_section_index: u32 = 0,

/// Index of the input section containing this atom's relocs.
relocs_section_index: u32 = 0,

/// Index of this atom in the linker's atoms table.
atom_index: Index = 0,

/// Points to the previous and next neighbors.
prev_atom_ref: Elf.Ref = .{},
next_atom_ref: Elf.Ref = .{},

/// Specifies whether this atom is alive or has been garbage collected.
alive: bool = true,

/// Specifies if the atom has been visited during garbage collection.
visited: bool = false,

extra_index: u32 = 0,

pub const Alignment = @import("../../InternPool.zig").Alignment;

pub fn name(self: Atom, elf_file: *Elf) [:0]const u8 {
    const file_ptr = self.file(elf_file).?;
    return switch (file_ptr) {
        inline else => |x| x.getString(self.name_offset),
    };
}

pub fn address(self: Atom, elf_file: *Elf) i64 {
    const shdr = elf_file.sections.items(.shdr)[self.output_section_index];
    return @as(i64, @intCast(shdr.sh_addr)) + self.value;
}

pub fn offset(self: Atom, elf_file: *Elf) u64 {
    const shdr = elf_file.sections.items(.shdr)[self.output_section_index];
    return shdr.sh_offset + @as(u64, @intCast(self.value));
}

pub fn ref(self: Atom) Elf.Ref {
    return .{ .index = self.atom_index, .file = self.file_index };
}

pub fn prevAtom(self: Atom, elf_file: *Elf) ?*Atom {
    return elf_file.atom(self.prev_atom_ref);
}

pub fn nextAtom(self: Atom, elf_file: *Elf) ?*Atom {
    return elf_file.atom(self.next_atom_ref);
}

pub fn debugTombstoneValue(self: Atom, target: Symbol, elf_file: *Elf) ?u64 {
    if (target.mergeSubsection(elf_file)) |msub| {
        if (msub.alive) return null;
    }
    if (target.atom(elf_file)) |atom_ptr| {
        if (atom_ptr.alive) return null;
    }
    const atom_name = self.name(elf_file);
    if (!mem.startsWith(u8, atom_name, ".debug")) return null;
    return if (mem.eql(u8, atom_name, ".debug_loc") or mem.eql(u8, atom_name, ".debug_ranges")) 1 else 0;
}

pub fn file(self: Atom, elf_file: *Elf) ?File {
    return elf_file.file(self.file_index);
}

pub fn thunk(self: Atom, elf_file: *Elf) *Thunk {
    const extras = self.extra(elf_file);
    return elf_file.thunk(extras.thunk);
}

pub fn inputShdr(self: Atom, elf_file: *Elf) elf.Elf64_Shdr {
    return switch (self.file(elf_file).?) {
        .object => |x| x.shdrs.items[self.input_section_index],
        .zig_object => |x| x.inputShdr(self.atom_index, elf_file),
        else => unreachable,
    };
}

pub fn relocsShndx(self: Atom) ?u32 {
    if (self.relocs_section_index == 0) return null;
    return self.relocs_section_index;
}

pub fn priority(self: Atom, elf_file: *Elf) u64 {
    const index = self.file(elf_file).?.index();
    return (@as(u64, @intCast(index)) << 32) | @as(u64, @intCast(self.input_section_index));
}

/// Returns how much room there is to grow in virtual address space.
/// File offset relocation happens transparently, so it is not included in
/// this calculation.
pub fn capacity(self: Atom, elf_file: *Elf) u64 {
    const next_addr = if (self.nextAtom(elf_file)) |next_atom|
        next_atom.address(elf_file)
    else
        std.math.maxInt(u32);
    return @intCast(next_addr - self.address(elf_file));
}

pub fn freeListEligible(self: Atom, elf_file: *Elf) bool {
    // No need to keep a free list node for the last block.
    const next = self.nextAtom(elf_file) orelse return false;
    const cap: u64 = @intCast(next.address(elf_file) - self.address(elf_file));
    const ideal_cap = Elf.padToIdeal(self.size);
    if (cap <= ideal_cap) return false;
    const surplus = cap - ideal_cap;
    return surplus >= Elf.min_text_capacity;
}

pub fn free(self: *Atom, elf_file: *Elf) void {
    log.debug("freeAtom atom({}) ({s})", .{ self.ref(), self.name(elf_file) });

    const comp = elf_file.base.comp;
    const gpa = comp.gpa;
    const shndx = self.output_section_index;
    const slice = elf_file.sections.slice();
    const free_list = &slice.items(.free_list)[shndx];
    const last_atom_ref = &slice.items(.last_atom)[shndx];
    var already_have_free_list_node = false;
    {
        var i: usize = 0;
        // TODO turn free_list into a hash map
        while (i < free_list.items.len) {
            if (free_list.items[i].eql(self.ref())) {
                _ = free_list.swapRemove(i);
                continue;
            }
            if (self.prevAtom(elf_file)) |prev_atom| {
                if (free_list.items[i].eql(prev_atom.ref())) {
                    already_have_free_list_node = true;
                }
            }
            i += 1;
        }
    }

    if (elf_file.atom(last_atom_ref.*)) |last_atom| {
        if (last_atom.ref().eql(self.ref())) {
            if (self.prevAtom(elf_file)) |prev_atom| {
                // TODO shrink the section size here
                last_atom_ref.* = prev_atom.ref();
            } else {
                last_atom_ref.* = .{};
            }
        }
    }

    if (self.prevAtom(elf_file)) |prev_atom| {
        prev_atom.next_atom_ref = self.next_atom_ref;
        if (!already_have_free_list_node and prev_atom.*.freeListEligible(elf_file)) {
            // The free list is heuristics, it doesn't have to be perfect, so we can
            // ignore the OOM here.
            free_list.append(gpa, prev_atom.ref()) catch {};
        }
    } else {
        self.prev_atom_ref = .{};
    }

    if (self.nextAtom(elf_file)) |next_atom| {
        next_atom.prev_atom_ref = self.prev_atom_ref;
    } else {
        self.next_atom_ref = .{};
    }

    switch (self.file(elf_file).?) {
        .zig_object => |zo| {
            // TODO create relocs free list
            self.freeRelocs(zo);
            // TODO figure out how to free input section mappind in ZigModule
            // const zig_object = elf_file.zigObjectPtr().?
            // assert(zig_object.atoms.swapRemove(self.atom_index));
        },
        else => {},
    }
    self.* = .{};
}

pub fn relocs(self: Atom, elf_file: *Elf) []const elf.Elf64_Rela {
    const shndx = self.relocsShndx() orelse return &[0]elf.Elf64_Rela{};
    switch (self.file(elf_file).?) {
        .zig_object => |x| return x.relocs.items[shndx].items,
        .object => |x| {
            const extras = self.extra(elf_file);
            return x.relocs.items[extras.rel_index..][0..extras.rel_count];
        },
        else => unreachable,
    }
}

pub fn writeRelocs(self: Atom, elf_file: *Elf, out_relocs: *std.ArrayList(elf.Elf64_Rela)) !void {
    relocs_log.debug("0x{x}: {s}", .{ self.address(elf_file), self.name(elf_file) });

    const cpu_arch = elf_file.getTarget().cpu.arch;
    const file_ptr = self.file(elf_file).?;
    for (self.relocs(elf_file)) |rel| {
        const target_ref = file_ptr.resolveSymbol(rel.r_sym(), elf_file);
        const target = elf_file.symbol(target_ref).?;
        const r_type = rel.r_type();
        const r_offset: u64 = @intCast(self.value + @as(i64, @intCast(rel.r_offset)));
        var r_addend = rel.r_addend;
        var r_sym: u32 = 0;
        switch (target.type(elf_file)) {
            elf.STT_SECTION => {
                r_addend += @intCast(target.address(.{}, elf_file));
                r_sym = target.outputShndx(elf_file) orelse 0;
            },
            else => {
                r_sym = target.outputSymtabIndex(elf_file) orelse 0;
            },
        }

        relocs_log.debug("  {s}: [{x} => {d}({s})] + {x}", .{
            relocation.fmtRelocType(rel.r_type(), cpu_arch),
            r_offset,
            r_sym,
            target.name(elf_file),
            r_addend,
        });

        out_relocs.appendAssumeCapacity(.{
            .r_offset = r_offset,
            .r_addend = r_addend,
            .r_info = (@as(u64, @intCast(r_sym)) << 32) | r_type,
        });
    }
}

pub fn fdes(self: Atom, elf_file: *Elf) []Fde {
    const extras = self.extra(elf_file);
    return switch (self.file(elf_file).?) {
        .shared_object => unreachable,
        .linker_defined, .zig_object => &[0]Fde{},
        .object => |x| x.fdes.items[extras.fde_start..][0..extras.fde_count],
    };
}

pub fn markFdesDead(self: Atom, elf_file: *Elf) void {
    for (self.fdes(elf_file)) |*fde| {
        fde.alive = false;
    }
}

pub fn addReloc(self: Atom, alloc: Allocator, reloc: elf.Elf64_Rela, zo: *ZigObject) !void {
    const rels = &zo.relocs.items[self.relocs_section_index];
    try rels.ensureUnusedCapacity(alloc, 1);
    self.addRelocAssumeCapacity(reloc, zo);
}

pub fn addRelocAssumeCapacity(self: Atom, reloc: elf.Elf64_Rela, zo: *ZigObject) void {
    const rels = &zo.relocs.items[self.relocs_section_index];
    rels.appendAssumeCapacity(reloc);
}

pub fn freeRelocs(self: Atom, zo: *ZigObject) void {
    zo.relocs.items[self.relocs_section_index].clearRetainingCapacity();
}

pub fn scanRelocsRequiresCode(self: Atom, elf_file: *Elf) bool {
    const cpu_arch = elf_file.getTarget().cpu.arch;
    for (self.relocs(elf_file)) |rel| {
        switch (cpu_arch) {
            .x86_64 => {
                const r_type: elf.R_X86_64 = @enumFromInt(rel.r_type());
                if (r_type == .GOTTPOFF) return true;
            },
            else => {},
        }
    }
    return false;
}

pub fn scanRelocs(self: Atom, elf_file: *Elf, code: ?[]const u8, undefs: anytype) RelocError!void {
    const cpu_arch = elf_file.getTarget().cpu.arch;
    const file_ptr = self.file(elf_file).?;
    const rels = self.relocs(elf_file);

    var has_reloc_errors = false;
    var it = RelocsIterator{ .relocs = rels };
    while (it.next()) |rel| {
        const r_kind = relocation.decode(rel.r_type(), cpu_arch);
        if (r_kind == .none) continue;

        const symbol_ref = file_ptr.resolveSymbol(rel.r_sym(), elf_file);
        const symbol = elf_file.symbol(symbol_ref) orelse {
            const sym_name = switch (file_ptr) {
                .zig_object => |x| x.symbol(rel.r_sym()).name(elf_file),
                inline else => |x| x.symbols.items[rel.r_sym()].name(elf_file),
            };
            // Violation of One Definition Rule for COMDATs.
            // TODO convert into an error
            log.debug("{}: {s}: {s} refers to a discarded COMDAT section", .{
                file_ptr.fmtPath(),
                self.name(elf_file),
                sym_name,
            });
            continue;
        };

        const is_synthetic_symbol = switch (file_ptr) {
            .zig_object => false, // TODO: implement this once we support merge sections in ZigObject
            .object => |x| rel.r_sym() >= x.symtab.items.len,
            else => unreachable,
        };

        // Report an undefined symbol.
        if (!is_synthetic_symbol and (try self.reportUndefined(elf_file, symbol, rel, undefs)))
            continue;

        if (symbol.isIFunc(elf_file)) {
            symbol.flags.needs_got = true;
            symbol.flags.needs_plt = true;
        }

        // While traversing relocations, mark symbols that require special handling such as
        // pointer indirection via GOT, or a stub trampoline via PLT.
        switch (cpu_arch) {
            .x86_64 => x86_64.scanReloc(self, elf_file, rel, symbol, code, &it) catch |err| switch (err) {
                error.RelocFailure => has_reloc_errors = true,
                else => |e| return e,
            },
            .aarch64 => aarch64.scanReloc(self, elf_file, rel, symbol, code, &it) catch |err| switch (err) {
                error.RelocFailure => has_reloc_errors = true,
                else => |e| return e,
            },
            .riscv64 => riscv.scanReloc(self, elf_file, rel, symbol, code, &it) catch |err| switch (err) {
                error.RelocFailure => has_reloc_errors = true,
                else => |e| return e,
            },
            else => return error.UnsupportedCpuArch,
        }
    }
    if (has_reloc_errors) return error.RelocFailure;
}

fn scanReloc(
    self: Atom,
    symbol: *Symbol,
    rel: elf.Elf64_Rela,
    action: RelocAction,
    elf_file: *Elf,
) RelocError!void {
    const is_writeable = self.inputShdr(elf_file).sh_flags & elf.SHF_WRITE != 0;
    const num_dynrelocs = switch (self.file(elf_file).?) {
        .linker_defined => unreachable,
        .shared_object => unreachable,
        inline else => |x| &x.num_dynrelocs,
    };

    switch (action) {
        .none => {},

        .@"error" => if (symbol.isAbs(elf_file))
            try self.reportNoPicError(symbol, rel, elf_file)
        else
            try self.reportPicError(symbol, rel, elf_file),

        .copyrel => {
            if (elf_file.z_nocopyreloc) {
                if (symbol.isAbs(elf_file))
                    try self.reportNoPicError(symbol, rel, elf_file)
                else
                    try self.reportPicError(symbol, rel, elf_file);
            }
            symbol.flags.needs_copy_rel = true;
        },

        .dyn_copyrel => {
            if (is_writeable or elf_file.z_nocopyreloc) {
                if (!is_writeable) {
                    if (elf_file.z_notext) {
                        elf_file.has_text_reloc = true;
                    } else {
                        try self.reportTextRelocError(symbol, rel, elf_file);
                    }
                }
                num_dynrelocs.* += 1;
            } else {
                symbol.flags.needs_copy_rel = true;
            }
        },

        .plt => {
            symbol.flags.needs_plt = true;
        },

        .cplt => {
            symbol.flags.needs_plt = true;
            symbol.flags.is_canonical = true;
        },

        .dyn_cplt => {
            if (is_writeable) {
                num_dynrelocs.* += 1;
            } else {
                symbol.flags.needs_plt = true;
                symbol.flags.is_canonical = true;
            }
        },

        .dynrel, .baserel, .ifunc => {
            if (!is_writeable) {
                if (elf_file.z_notext) {
                    elf_file.has_text_reloc = true;
                } else {
                    try self.reportTextRelocError(symbol, rel, elf_file);
                }
            }
            num_dynrelocs.* += 1;

            if (action == .ifunc) elf_file.num_ifunc_dynrelocs += 1;
        },
    }
}

const RelocAction = enum {
    none,
    @"error",
    copyrel,
    dyn_copyrel,
    plt,
    dyn_cplt,
    cplt,
    dynrel,
    baserel,
    ifunc,
};

fn pcRelocAction(symbol: *const Symbol, elf_file: *Elf) RelocAction {
    // zig fmt: off
    const table: [3][4]RelocAction = .{
        //  Abs       Local   Import data  Import func
        .{ .@"error", .none,  .@"error",   .plt  }, // Shared object
        .{ .@"error", .none,  .copyrel,    .plt  }, // PIE
        .{ .none,     .none,  .copyrel,    .cplt }, // Non-PIE
    };
    // zig fmt: on
    const output = outputType(elf_file);
    const data = dataType(symbol, elf_file);
    return table[output][data];
}

fn absRelocAction(symbol: *const Symbol, elf_file: *Elf) RelocAction {
    // zig fmt: off
    const table: [3][4]RelocAction = .{
        //  Abs    Local       Import data  Import func
        .{ .none,  .@"error",  .@"error",   .@"error"  }, // Shared object
        .{ .none,  .@"error",  .@"error",   .@"error"  }, // PIE
        .{ .none,  .none,      .copyrel,    .cplt      }, // Non-PIE
    };
    // zig fmt: on
    const output = outputType(elf_file);
    const data = dataType(symbol, elf_file);
    return table[output][data];
}

fn dynAbsRelocAction(symbol: *const Symbol, elf_file: *Elf) RelocAction {
    if (symbol.isIFunc(elf_file)) return .ifunc;
    // zig fmt: off
    const table: [3][4]RelocAction = .{
        //  Abs    Local       Import data   Import func
        .{ .none,  .baserel,  .dynrel,       .dynrel    }, // Shared object
        .{ .none,  .baserel,  .dynrel,       .dynrel    }, // PIE
        .{ .none,  .none,     .dyn_copyrel,  .dyn_cplt  }, // Non-PIE
    };
    // zig fmt: on
    const output = outputType(elf_file);
    const data = dataType(symbol, elf_file);
    return table[output][data];
}

fn outputType(elf_file: *Elf) u2 {
    const comp = elf_file.base.comp;
    assert(!elf_file.base.isRelocatable());
    return switch (elf_file.base.comp.config.output_mode) {
        .Obj => unreachable,
        .Lib => 0,
        .Exe => switch (elf_file.getTarget().os.tag) {
            .haiku => 0,
            else => if (comp.config.pie) 1 else 2,
        },
    };
}

fn dataType(symbol: *const Symbol, elf_file: *Elf) u2 {
    if (symbol.isAbs(elf_file)) return 0;
    if (!symbol.flags.import) return 1;
    if (symbol.type(elf_file) != elf.STT_FUNC) return 2;
    return 3;
}

fn reportUnhandledRelocError(self: Atom, rel: elf.Elf64_Rela, elf_file: *Elf) RelocError!void {
    var err = try elf_file.base.addErrorWithNotes(1);
    try err.addMsg("fatal linker error: unhandled relocation type {} at offset 0x{x}", .{
        relocation.fmtRelocType(rel.r_type(), elf_file.getTarget().cpu.arch),
        rel.r_offset,
    });
    try err.addNote("in {}:{s}", .{ self.file(elf_file).?.fmtPath(), self.name(elf_file) });
    return error.RelocFailure;
}

fn reportTextRelocError(
    self: Atom,
    symbol: *const Symbol,
    rel: elf.Elf64_Rela,
    elf_file: *Elf,
) RelocError!void {
    var err = try elf_file.base.addErrorWithNotes(1);
    try err.addMsg("relocation at offset 0x{x} against symbol '{s}' cannot be used", .{
        rel.r_offset,
        symbol.name(elf_file),
    });
    try err.addNote("in {}:{s}", .{ self.file(elf_file).?.fmtPath(), self.name(elf_file) });
    return error.RelocFailure;
}

fn reportPicError(
    self: Atom,
    symbol: *const Symbol,
    rel: elf.Elf64_Rela,
    elf_file: *Elf,
) RelocError!void {
    var err = try elf_file.base.addErrorWithNotes(2);
    try err.addMsg("relocation at offset 0x{x} against symbol '{s}' cannot be used", .{
        rel.r_offset,
        symbol.name(elf_file),
    });
    try err.addNote("in {}:{s}", .{ self.file(elf_file).?.fmtPath(), self.name(elf_file) });
    try err.addNote("recompile with -fPIC", .{});
    return error.RelocFailure;
}

fn reportNoPicError(
    self: Atom,
    symbol: *const Symbol,
    rel: elf.Elf64_Rela,
    elf_file: *Elf,
) RelocError!void {
    var err = try elf_file.base.addErrorWithNotes(2);
    try err.addMsg("relocation at offset 0x{x} against symbol '{s}' cannot be used", .{
        rel.r_offset,
        symbol.name(elf_file),
    });
    try err.addNote("in {}:{s}", .{ self.file(elf_file).?.fmtPath(), self.name(elf_file) });
    try err.addNote("recompile with -fno-PIC", .{});
    return error.RelocFailure;
}

// This function will report any undefined non-weak symbols that are not imports.
fn reportUndefined(
    self: Atom,
    elf_file: *Elf,
    sym: *const Symbol,
    rel: elf.Elf64_Rela,
    undefs: anytype,
) !bool {
    const comp = elf_file.base.comp;
    const gpa = comp.gpa;
    const file_ptr = self.file(elf_file).?;
    const rel_esym = switch (file_ptr) {
        .zig_object => |x| x.symbol(rel.r_sym()).elfSym(elf_file),
        inline else => |x| x.symtab.items[rel.r_sym()],
    };
    const esym = sym.elfSym(elf_file);
    if (rel_esym.st_shndx == elf.SHN_UNDEF and
        rel_esym.st_bind() == elf.STB_GLOBAL and
        sym.esym_index > 0 and
        !sym.flags.import and
        esym.st_shndx == elf.SHN_UNDEF)
    {
        const idx = switch (file_ptr) {
            .zig_object => |x| x.symbols_resolver.items[rel.r_sym() & ZigObject.symbol_mask],
            .object => |x| x.symbols_resolver.items[rel.r_sym() - x.first_global.?],
            inline else => |x| x.symbols_resolver.items[rel.r_sym()],
        };
        const gop = try undefs.getOrPut(idx);
        if (!gop.found_existing) {
            gop.value_ptr.* = std.ArrayList(Elf.Ref).init(gpa);
        }
        try gop.value_ptr.append(.{ .index = self.atom_index, .file = self.file_index });
        return true;
    }

    return false;
}

pub fn resolveRelocsAlloc(self: Atom, elf_file: *Elf, code: []u8) RelocError!void {
    relocs_log.debug("0x{x}: {s}", .{ self.address(elf_file), self.name(elf_file) });

    const cpu_arch = elf_file.getTarget().cpu.arch;
    const file_ptr = self.file(elf_file).?;
    var stream = std.io.fixedBufferStream(code);

    const rels = self.relocs(elf_file);
    var it = RelocsIterator{ .relocs = rels };
    var has_reloc_errors = false;
    while (it.next()) |rel| {
        const r_kind = relocation.decode(rel.r_type(), cpu_arch);
        if (r_kind == .none) continue;

        const target_ref = file_ptr.resolveSymbol(rel.r_sym(), elf_file);
        const target = elf_file.symbol(target_ref).?;
        const r_offset = std.math.cast(usize, rel.r_offset) orelse return error.Overflow;

        // We will use equation format to resolve relocations:
        // https://intezer.com/blog/malware-analysis/executable-and-linkable-format-101-part-3-relocations/
        //
        // Address of the source atom.
        const P = self.address(elf_file) + @as(i64, @intCast(rel.r_offset));
        // Addend from the relocation.
        const A = rel.r_addend;
        // Address of the target symbol - can be address of the symbol within an atom or address of PLT stub, or address of a Zig trampoline.
        const S = target.address(.{}, elf_file);
        // Address of the global offset table.
        const GOT = elf_file.gotAddress();
        // Relative offset to the start of the global offset table.
        const G = target.gotAddress(elf_file) - GOT;
        // // Address of the thread pointer.
        const TP = elf_file.tpAddress();
        // Address of the dynamic thread pointer.
        const DTP = elf_file.dtpAddress();

        relocs_log.debug("  {s}: {x}: [{x} => {x}] GOT({x}) ({s})", .{
            relocation.fmtRelocType(rel.r_type(), cpu_arch),
            r_offset,
            P,
            S + A,
            G + GOT + A,
            target.name(elf_file),
        });

        try stream.seekTo(r_offset);

        const args = ResolveArgs{ P, A, S, GOT, G, TP, DTP };

        switch (cpu_arch) {
            .x86_64 => x86_64.resolveRelocAlloc(self, elf_file, rel, target, args, &it, code, &stream) catch |err| switch (err) {
                error.RelocFailure,
                error.RelaxFailure,
                error.InvalidInstruction,
                error.CannotEncode,
                => has_reloc_errors = true,
                else => |e| return e,
            },
            .aarch64 => aarch64.resolveRelocAlloc(self, elf_file, rel, target, args, &it, code, &stream) catch |err| switch (err) {
                error.RelocFailure,
                error.RelaxFailure,
                error.UnexpectedRemainder,
                error.DivisionByZero,
                => has_reloc_errors = true,
                else => |e| return e,
            },
            .riscv64 => riscv.resolveRelocAlloc(self, elf_file, rel, target, args, &it, code, &stream) catch |err| switch (err) {
                error.RelocFailure,
                error.RelaxFailure,
                => has_reloc_errors = true,
                else => |e| return e,
            },
            else => return error.UnsupportedCpuArch,
        }
    }

    if (has_reloc_errors) return error.RelaxFailure;
}

fn resolveDynAbsReloc(
    self: Atom,
    target: *const Symbol,
    rel: elf.Elf64_Rela,
    action: RelocAction,
    elf_file: *Elf,
    writer: anytype,
) !void {
    const comp = elf_file.base.comp;
    const gpa = comp.gpa;
    const cpu_arch = elf_file.getTarget().cpu.arch;
    const P: u64 = @intCast(self.address(elf_file) + @as(i64, @intCast(rel.r_offset)));
    const A = rel.r_addend;
    const S = target.address(.{}, elf_file);
    const is_writeable = self.inputShdr(elf_file).sh_flags & elf.SHF_WRITE != 0;

    const num_dynrelocs = switch (self.file(elf_file).?) {
        .linker_defined => unreachable,
        .shared_object => unreachable,
        inline else => |x| x.num_dynrelocs,
    };
    try elf_file.rela_dyn.ensureUnusedCapacity(gpa, num_dynrelocs);

    switch (action) {
        .@"error",
        .plt,
        => unreachable,

        .copyrel,
        .cplt,
        .none,
        => try writer.writeInt(i32, @as(i32, @truncate(S + A)), .little),

        .dyn_copyrel => {
            if (is_writeable or elf_file.z_nocopyreloc) {
                elf_file.addRelaDynAssumeCapacity(.{
                    .offset = P,
                    .sym = target.extra(elf_file).dynamic,
                    .type = relocation.encode(.abs, cpu_arch),
                    .addend = A,
                });
                try applyDynamicReloc(A, elf_file, writer);
            } else {
                try writer.writeInt(i32, @as(i32, @truncate(S + A)), .little);
            }
        },

        .dyn_cplt => {
            if (is_writeable) {
                elf_file.addRelaDynAssumeCapacity(.{
                    .offset = P,
                    .sym = target.extra(elf_file).dynamic,
                    .type = relocation.encode(.abs, cpu_arch),
                    .addend = A,
                });
                try applyDynamicReloc(A, elf_file, writer);
            } else {
                try writer.writeInt(i32, @as(i32, @truncate(S + A)), .little);
            }
        },

        .dynrel => {
            elf_file.addRelaDynAssumeCapacity(.{
                .offset = P,
                .sym = target.extra(elf_file).dynamic,
                .type = relocation.encode(.abs, cpu_arch),
                .addend = A,
            });
            try applyDynamicReloc(A, elf_file, writer);
        },

        .baserel => {
            elf_file.addRelaDynAssumeCapacity(.{
                .offset = P,
                .type = relocation.encode(.rel, cpu_arch),
                .addend = S + A,
            });
            try applyDynamicReloc(S + A, elf_file, writer);
        },

        .ifunc => {
            const S_ = target.address(.{ .plt = false }, elf_file);
            elf_file.addRelaDynAssumeCapacity(.{
                .offset = P,
                .type = relocation.encode(.irel, cpu_arch),
                .addend = S_ + A,
            });
            try applyDynamicReloc(S_ + A, elf_file, writer);
        },
    }
}

fn applyDynamicReloc(value: i64, elf_file: *Elf, writer: anytype) !void {
    _ = elf_file;
    // if (elf_file.options.apply_dynamic_relocs) {
    try writer.writeInt(i64, value, .little);
    // }
}

pub fn resolveRelocsNonAlloc(self: Atom, elf_file: *Elf, code: []u8, undefs: anytype) !void {
    relocs_log.debug("0x{x}: {s}", .{ self.address(elf_file), self.name(elf_file) });

    const cpu_arch = elf_file.getTarget().cpu.arch;
    const file_ptr = self.file(elf_file).?;
    var stream = std.io.fixedBufferStream(code);

    const rels = self.relocs(elf_file);
    var has_reloc_errors = false;
    var it = RelocsIterator{ .relocs = rels };
    while (it.next()) |rel| {
        const r_kind = relocation.decode(rel.r_type(), cpu_arch);
        if (r_kind == .none) continue;

        const r_offset = std.math.cast(usize, rel.r_offset) orelse return error.Overflow;

        const target_ref = file_ptr.resolveSymbol(rel.r_sym(), elf_file);
        const target = elf_file.symbol(target_ref) orelse {
            const sym_name = switch (file_ptr) {
                .zig_object => |x| x.symbol(rel.r_sym()).name(elf_file),
                inline else => |x| x.symbols.items[rel.r_sym()].name(elf_file),
            };
            // Violation of One Definition Rule for COMDATs.
            // TODO convert into an error
            log.debug("{}: {s}: {s} refers to a discarded COMDAT section", .{
                file_ptr.fmtPath(),
                self.name(elf_file),
                sym_name,
            });
            continue;
        };
        const is_synthetic_symbol = switch (file_ptr) {
            .zig_object => false, // TODO: implement this once we support merge sections in ZigObject
            .object => |x| rel.r_sym() >= x.symtab.items.len,
            else => unreachable,
        };

        // Report an undefined symbol.
        if (!is_synthetic_symbol and (try self.reportUndefined(elf_file, target, rel, undefs)))
            continue;

        // We will use equation format to resolve relocations:
        // https://intezer.com/blog/malware-analysis/executable-and-linkable-format-101-part-3-relocations/
        //
        const P = self.address(elf_file) + @as(i64, @intCast(rel.r_offset));
        // Addend from the relocation.
        const A = rel.r_addend;
        // Address of the target symbol - can be address of the symbol within an atom or address of PLT stub.
        const S = target.address(.{}, elf_file);
        // Address of the global offset table.
        const GOT = elf_file.gotAddress();
        // Address of the dynamic thread pointer.
        const DTP = elf_file.dtpAddress();

        const args = ResolveArgs{ P, A, S, GOT, 0, 0, DTP };

        relocs_log.debug("  {}: {x}: [{x} => {x}] ({s})", .{
            relocation.fmtRelocType(rel.r_type(), cpu_arch),
            rel.r_offset,
            P,
            S + A,
            target.name(elf_file),
        });

        try stream.seekTo(r_offset);

        switch (cpu_arch) {
            .x86_64 => x86_64.resolveRelocNonAlloc(self, elf_file, rel, target, args, &it, code, &stream) catch |err| switch (err) {
                error.RelocFailure => has_reloc_errors = true,
                else => |e| return e,
            },
            .aarch64 => aarch64.resolveRelocNonAlloc(self, elf_file, rel, target, args, &it, code, &stream) catch |err| switch (err) {
                error.RelocFailure => has_reloc_errors = true,
                else => |e| return e,
            },
            .riscv64 => riscv.resolveRelocNonAlloc(self, elf_file, rel, target, args, &it, code, &stream) catch |err| switch (err) {
                error.RelocFailure => has_reloc_errors = true,
                else => |e| return e,
            },
            else => return error.UnsupportedCpuArch,
        }
    }

    if (has_reloc_errors) return error.RelocFailure;
}

const AddExtraOpts = struct {
    thunk: ?u32 = null,
    fde_start: ?u32 = null,
    fde_count: ?u32 = null,
    rel_index: ?u32 = null,
    rel_count: ?u32 = null,
};

pub fn addExtra(atom: *Atom, opts: AddExtraOpts, elf_file: *Elf) void {
    const file_ptr = atom.file(elf_file).?;
    var extras = file_ptr.atomExtra(atom.extra_index);
    inline for (@typeInfo(@TypeOf(opts)).@"struct".fields) |field| {
        if (@field(opts, field.name)) |x| {
            @field(extras, field.name) = x;
        }
    }
    file_ptr.setAtomExtra(atom.extra_index, extras);
}

pub inline fn extra(atom: Atom, elf_file: *Elf) Extra {
    return atom.file(elf_file).?.atomExtra(atom.extra_index);
}

pub inline fn setExtra(atom: Atom, extras: Extra, elf_file: *Elf) void {
    atom.file(elf_file).?.setAtomExtra(atom.extra_index, extras);
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
    try writer.print("atom({d}) : {s} : @{x} : shdr({d}) : align({x}) : size({x})", .{
        atom.atom_index,           atom.name(elf_file),                   atom.address(elf_file),
        atom.output_section_index, atom.alignment.toByteUnits() orelse 0, atom.size,
    });
    if (atom.fdes(elf_file).len > 0) {
        try writer.writeAll(" : fdes{ ");
        const extras = atom.extra(elf_file);
        for (atom.fdes(elf_file), extras.fde_start..) |fde, i| {
            try writer.print("{d}", .{i});
            if (!fde.alive) try writer.writeAll("([*])");
            if (i - extras.fde_start < extras.fde_count - 1) try writer.writeAll(", ");
        }
        try writer.writeAll(" }");
    }
    if (!atom.alive) {
        try writer.writeAll(" : [*]");
    }
}

pub const Index = u32;

const x86_64 = struct {
    fn scanReloc(
        atom: Atom,
        elf_file: *Elf,
        rel: elf.Elf64_Rela,
        symbol: *Symbol,
        code: ?[]const u8,
        it: *RelocsIterator,
    ) !void {
        dev.check(.x86_64_backend);
        const is_static = elf_file.base.isStatic();
        const is_dyn_lib = elf_file.isEffectivelyDynLib();

        const r_type: elf.R_X86_64 = @enumFromInt(rel.r_type());
        const r_offset = std.math.cast(usize, rel.r_offset) orelse return error.Overflow;

        switch (r_type) {
            .@"64" => {
                try atom.scanReloc(symbol, rel, dynAbsRelocAction(symbol, elf_file), elf_file);
            },

            .@"32",
            .@"32S",
            => {
                try atom.scanReloc(symbol, rel, absRelocAction(symbol, elf_file), elf_file);
            },

            .GOT32,
            .GOTPC32,
            .GOTPC64,
            .GOTPCREL,
            .GOTPCREL64,
            .GOTPCRELX,
            .REX_GOTPCRELX,
            => {
                symbol.flags.needs_got = true;
            },

            .PLT32,
            .PLTOFF64,
            => {
                if (symbol.flags.import) {
                    symbol.flags.needs_plt = true;
                }
            },

            .PC32 => {
                try atom.scanReloc(symbol, rel, pcRelocAction(symbol, elf_file), elf_file);
            },

            .TLSGD => {
                // TODO verify followed by appropriate relocation such as PLT32 __tls_get_addr

                if (is_static or (!symbol.flags.import and !is_dyn_lib)) {
                    // Relax if building with -static flag as __tls_get_addr() will not be present in libc.a
                    // We skip the next relocation.
                    it.skip(1);
                } else if (!symbol.flags.import and is_dyn_lib) {
                    symbol.flags.needs_gottp = true;
                    it.skip(1);
                } else {
                    symbol.flags.needs_tlsgd = true;
                }
            },

            .TLSLD => {
                // TODO verify followed by appropriate relocation such as PLT32 __tls_get_addr

                if (is_static or !is_dyn_lib) {
                    // Relax if building with -static flag as __tls_get_addr() will not be present in libc.a
                    // We skip the next relocation.
                    it.skip(1);
                } else {
                    elf_file.got.flags.needs_tlsld = true;
                }
            },

            .GOTTPOFF => {
                const should_relax = blk: {
                    if (is_dyn_lib or symbol.flags.import) break :blk false;
                    if (!x86_64.canRelaxGotTpOff(code.?[r_offset - 3 ..])) break :blk false;
                    break :blk true;
                };
                if (!should_relax) {
                    symbol.flags.needs_gottp = true;
                }
            },

            .GOTPC32_TLSDESC => {
                const should_relax = is_static or (!is_dyn_lib and !symbol.flags.import);
                if (!should_relax) {
                    symbol.flags.needs_tlsdesc = true;
                }
            },

            .TPOFF32,
            .TPOFF64,
            => {
                if (is_dyn_lib) try atom.reportPicError(symbol, rel, elf_file);
            },

            .GOTOFF64,
            .DTPOFF32,
            .DTPOFF64,
            .SIZE32,
            .SIZE64,
            .TLSDESC_CALL,
            => {},

            else => try atom.reportUnhandledRelocError(rel, elf_file),
        }
    }

    fn resolveRelocAlloc(
        atom: Atom,
        elf_file: *Elf,
        rel: elf.Elf64_Rela,
        target: *const Symbol,
        args: ResolveArgs,
        it: *RelocsIterator,
        code: []u8,
        stream: anytype,
    ) (error{ InvalidInstruction, CannotEncode } || RelocError)!void {
        dev.check(.x86_64_backend);
        const r_type: elf.R_X86_64 = @enumFromInt(rel.r_type());
        const r_offset = std.math.cast(usize, rel.r_offset) orelse return error.Overflow;

        const cwriter = stream.writer();

        const P, const A, const S, const GOT, const G, const TP, const DTP = args;

        switch (r_type) {
            .NONE => unreachable,

            .@"64" => {
                try atom.resolveDynAbsReloc(
                    target,
                    rel,
                    dynAbsRelocAction(target, elf_file),
                    elf_file,
                    cwriter,
                );
            },

            .PLT32 => try cwriter.writeInt(i32, @as(i32, @intCast(S + A - P)), .little),
            .PC32 => try cwriter.writeInt(i32, @as(i32, @intCast(S + A - P)), .little),

            .GOTPCREL => try cwriter.writeInt(i32, @as(i32, @intCast(G + GOT + A - P)), .little),
            .GOTPC32 => try cwriter.writeInt(i32, @as(i32, @intCast(GOT + A - P)), .little),
            .GOTPC64 => try cwriter.writeInt(i64, GOT + A - P, .little),

            .GOTPCRELX => {
                if (!target.flags.import and !target.isIFunc(elf_file) and !target.isAbs(elf_file)) blk: {
                    x86_64.relaxGotpcrelx(code[r_offset - 2 ..]) catch break :blk;
                    try cwriter.writeInt(i32, @as(i32, @intCast(S + A - P)), .little);
                    return;
                }
                try cwriter.writeInt(i32, @as(i32, @intCast(G + GOT + A - P)), .little);
            },

            .REX_GOTPCRELX => {
                if (!target.flags.import and !target.isIFunc(elf_file) and !target.isAbs(elf_file)) blk: {
                    x86_64.relaxRexGotpcrelx(code[r_offset - 3 ..]) catch break :blk;
                    try cwriter.writeInt(i32, @as(i32, @intCast(S + A - P)), .little);
                    return;
                }
                try cwriter.writeInt(i32, @as(i32, @intCast(G + GOT + A - P)), .little);
            },

            .@"32" => try cwriter.writeInt(u32, @as(u32, @truncate(@as(u64, @intCast(S + A)))), .little),
            .@"32S" => try cwriter.writeInt(i32, @as(i32, @truncate(S + A)), .little),

            .TPOFF32 => try cwriter.writeInt(i32, @as(i32, @truncate(S + A - TP)), .little),
            .TPOFF64 => try cwriter.writeInt(i64, S + A - TP, .little),

            .DTPOFF32 => try cwriter.writeInt(i32, @as(i32, @truncate(S + A - DTP)), .little),
            .DTPOFF64 => try cwriter.writeInt(i64, S + A - DTP, .little),

            .TLSGD => {
                if (target.flags.has_tlsgd) {
                    const S_ = target.tlsGdAddress(elf_file);
                    try cwriter.writeInt(i32, @as(i32, @intCast(S_ + A - P)), .little);
                } else if (target.flags.has_gottp) {
                    const S_ = target.gotTpAddress(elf_file);
                    try x86_64.relaxTlsGdToIe(atom, &.{ rel, it.next().? }, @intCast(S_ - P), elf_file, stream);
                } else {
                    try x86_64.relaxTlsGdToLe(
                        atom,
                        &.{ rel, it.next().? },
                        @as(i32, @intCast(S - TP)),
                        elf_file,
                        stream,
                    );
                }
            },

            .TLSLD => {
                if (elf_file.got.tlsld_index) |entry_index| {
                    const tlsld_entry = elf_file.got.entries.items[entry_index];
                    const S_ = tlsld_entry.address(elf_file);
                    try cwriter.writeInt(i32, @as(i32, @intCast(S_ + A - P)), .little);
                } else {
                    try x86_64.relaxTlsLdToLe(
                        atom,
                        &.{ rel, it.next().? },
                        @as(i32, @intCast(TP - elf_file.tlsAddress())),
                        elf_file,
                        stream,
                    );
                }
            },

            .GOTPC32_TLSDESC => {
                if (target.flags.has_tlsdesc) {
                    const S_ = target.tlsDescAddress(elf_file);
                    try cwriter.writeInt(i32, @as(i32, @intCast(S_ + A - P)), .little);
                } else {
                    x86_64.relaxGotPcTlsDesc(code[r_offset - 3 ..]) catch {
                        var err = try elf_file.base.addErrorWithNotes(1);
                        try err.addMsg("could not relax {s}", .{@tagName(r_type)});
                        try err.addNote("in {}:{s} at offset 0x{x}", .{
                            atom.file(elf_file).?.fmtPath(),
                            atom.name(elf_file),
                            rel.r_offset,
                        });
                        return error.RelaxFailure;
                    };
                    try cwriter.writeInt(i32, @as(i32, @intCast(S - TP)), .little);
                }
            },

            .TLSDESC_CALL => if (!target.flags.has_tlsdesc) {
                // call -> nop
                try cwriter.writeAll(&.{ 0x66, 0x90 });
            },

            .GOTTPOFF => {
                if (target.flags.has_gottp) {
                    const S_ = target.gotTpAddress(elf_file);
                    try cwriter.writeInt(i32, @as(i32, @intCast(S_ + A - P)), .little);
                } else {
                    x86_64.relaxGotTpOff(code[r_offset - 3 ..]);
                    try cwriter.writeInt(i32, @as(i32, @intCast(S - TP)), .little);
                }
            },

            .GOT32 => try cwriter.writeInt(i32, @as(i32, @intCast(G + A)), .little),

            else => try atom.reportUnhandledRelocError(rel, elf_file),
        }
    }

    fn resolveRelocNonAlloc(
        atom: Atom,
        elf_file: *Elf,
        rel: elf.Elf64_Rela,
        target: *const Symbol,
        args: ResolveArgs,
        it: *RelocsIterator,
        code: []u8,
        stream: anytype,
    ) !void {
        dev.check(.x86_64_backend);
        _ = code;
        _ = it;
        const r_type: elf.R_X86_64 = @enumFromInt(rel.r_type());
        const cwriter = stream.writer();

        _, const A, const S, const GOT, _, _, const DTP = args;

        switch (r_type) {
            .NONE => unreachable,
            .@"8" => try cwriter.writeInt(u8, @as(u8, @bitCast(@as(i8, @intCast(S + A)))), .little),
            .@"16" => try cwriter.writeInt(u16, @as(u16, @bitCast(@as(i16, @intCast(S + A)))), .little),
            .@"32" => try cwriter.writeInt(u32, @as(u32, @bitCast(@as(i32, @intCast(S + A)))), .little),
            .@"32S" => try cwriter.writeInt(i32, @as(i32, @intCast(S + A)), .little),
            .@"64" => if (atom.debugTombstoneValue(target.*, elf_file)) |value|
                try cwriter.writeInt(u64, value, .little)
            else
                try cwriter.writeInt(i64, S + A, .little),
            .DTPOFF32 => if (atom.debugTombstoneValue(target.*, elf_file)) |value|
                try cwriter.writeInt(u64, value, .little)
            else
                try cwriter.writeInt(i32, @as(i32, @intCast(S + A - DTP)), .little),
            .DTPOFF64 => if (atom.debugTombstoneValue(target.*, elf_file)) |value|
                try cwriter.writeInt(u64, value, .little)
            else
                try cwriter.writeInt(i64, S + A - DTP, .little),
            .GOTOFF64 => try cwriter.writeInt(i64, S + A - GOT, .little),
            .GOTPC64 => try cwriter.writeInt(i64, GOT + A, .little),
            .SIZE32 => {
                const size = @as(i64, @intCast(target.elfSym(elf_file).st_size));
                try cwriter.writeInt(u32, @bitCast(@as(i32, @intCast(size + A))), .little);
            },
            .SIZE64 => {
                const size = @as(i64, @intCast(target.elfSym(elf_file).st_size));
                try cwriter.writeInt(i64, @intCast(size + A), .little);
            },
            else => try atom.reportUnhandledRelocError(rel, elf_file),
        }
    }

    fn relaxGotpcrelx(code: []u8) !void {
        dev.check(.x86_64_backend);
        const old_inst = disassemble(code) orelse return error.RelaxFailure;
        const inst = switch (old_inst.encoding.mnemonic) {
            .call => try Instruction.new(old_inst.prefix, .call, &.{
                // TODO: hack to force imm32s in the assembler
                .{ .imm = Immediate.s(-129) },
            }),
            .jmp => try Instruction.new(old_inst.prefix, .jmp, &.{
                // TODO: hack to force imm32s in the assembler
                .{ .imm = Immediate.s(-129) },
            }),
            else => return error.RelaxFailure,
        };
        relocs_log.debug("    relaxing {} => {}", .{ old_inst.encoding, inst.encoding });
        const nop = try Instruction.new(.none, .nop, &.{});
        try encode(&.{ nop, inst }, code);
    }

    fn relaxRexGotpcrelx(code: []u8) !void {
        dev.check(.x86_64_backend);
        const old_inst = disassemble(code) orelse return error.RelaxFailure;
        switch (old_inst.encoding.mnemonic) {
            .mov => {
                const inst = try Instruction.new(old_inst.prefix, .lea, &old_inst.ops);
                relocs_log.debug("    relaxing {} => {}", .{ old_inst.encoding, inst.encoding });
                try encode(&.{inst}, code);
            },
            else => return error.RelaxFailure,
        }
    }

    fn relaxTlsGdToIe(
        self: Atom,
        rels: []const elf.Elf64_Rela,
        value: i32,
        elf_file: *Elf,
        stream: anytype,
    ) !void {
        dev.check(.x86_64_backend);
        assert(rels.len == 2);
        const writer = stream.writer();
        const rel: elf.R_X86_64 = @enumFromInt(rels[1].r_type());
        switch (rel) {
            .PC32,
            .PLT32,
            => {
                var insts = [_]u8{
                    0x64, 0x48, 0x8b, 0x04, 0x25, 0, 0, 0, 0, // movq %fs:0,%rax
                    0x48, 0x03, 0x05, 0, 0, 0, 0, // add foo@gottpoff(%rip), %rax
                };
                std.mem.writeInt(i32, insts[12..][0..4], value - 12, .little);
                try stream.seekBy(-4);
                try writer.writeAll(&insts);
            },

            else => {
                var err = try elf_file.base.addErrorWithNotes(1);
                try err.addMsg("TODO: rewrite {} when followed by {}", .{
                    relocation.fmtRelocType(rels[0].r_type(), .x86_64),
                    relocation.fmtRelocType(rels[1].r_type(), .x86_64),
                });
                try err.addNote("in {}:{s} at offset 0x{x}", .{
                    self.file(elf_file).?.fmtPath(),
                    self.name(elf_file),
                    rels[0].r_offset,
                });
                return error.RelaxFailure;
            },
        }
    }

    fn relaxTlsLdToLe(
        self: Atom,
        rels: []const elf.Elf64_Rela,
        value: i32,
        elf_file: *Elf,
        stream: anytype,
    ) !void {
        dev.check(.x86_64_backend);
        assert(rels.len == 2);
        const writer = stream.writer();
        const rel: elf.R_X86_64 = @enumFromInt(rels[1].r_type());
        switch (rel) {
            .PC32,
            .PLT32,
            => {
                var insts = [_]u8{
                    0x31, 0xc0, // xor %eax, %eax
                    0x64, 0x48, 0x8b, 0, // mov %fs:(%rax), %rax
                    0x48, 0x2d, 0, 0, 0, 0, // sub $tls_size, %rax
                };
                std.mem.writeInt(i32, insts[8..][0..4], value, .little);
                try stream.seekBy(-3);
                try writer.writeAll(&insts);
            },

            .GOTPCREL,
            .GOTPCRELX,
            => {
                var insts = [_]u8{
                    0x31, 0xc0, // xor %eax, %eax
                    0x64, 0x48, 0x8b, 0, // mov %fs:(%rax), %rax
                    0x48, 0x2d, 0, 0, 0, 0, // sub $tls_size, %rax
                    0x90, // nop
                };
                std.mem.writeInt(i32, insts[8..][0..4], value, .little);
                try stream.seekBy(-3);
                try writer.writeAll(&insts);
            },

            else => {
                var err = try elf_file.base.addErrorWithNotes(1);
                try err.addMsg("TODO: rewrite {} when followed by {}", .{
                    relocation.fmtRelocType(rels[0].r_type(), .x86_64),
                    relocation.fmtRelocType(rels[1].r_type(), .x86_64),
                });
                try err.addNote("in {}:{s} at offset 0x{x}", .{
                    self.file(elf_file).?.fmtPath(),
                    self.name(elf_file),
                    rels[0].r_offset,
                });
                return error.RelaxFailure;
            },
        }
    }

    fn canRelaxGotTpOff(code: []const u8) bool {
        dev.check(.x86_64_backend);
        const old_inst = disassemble(code) orelse return false;
        switch (old_inst.encoding.mnemonic) {
            .mov => if (Instruction.new(old_inst.prefix, .mov, &.{
                old_inst.ops[0],
                // TODO: hack to force imm32s in the assembler
                .{ .imm = Immediate.s(-129) },
            })) |inst| {
                inst.encode(std.io.null_writer, .{}) catch return false;
                return true;
            } else |_| return false,
            else => return false,
        }
    }

    fn relaxGotTpOff(code: []u8) void {
        dev.check(.x86_64_backend);
        const old_inst = disassemble(code) orelse unreachable;
        switch (old_inst.encoding.mnemonic) {
            .mov => {
                const inst = Instruction.new(old_inst.prefix, .mov, &.{
                    old_inst.ops[0],
                    // TODO: hack to force imm32s in the assembler
                    .{ .imm = Immediate.s(-129) },
                }) catch unreachable;
                relocs_log.debug("    relaxing {} => {}", .{ old_inst.encoding, inst.encoding });
                encode(&.{inst}, code) catch unreachable;
            },
            else => unreachable,
        }
    }

    fn relaxGotPcTlsDesc(code: []u8) !void {
        dev.check(.x86_64_backend);
        const old_inst = disassemble(code) orelse return error.RelaxFailure;
        switch (old_inst.encoding.mnemonic) {
            .lea => {
                const inst = try Instruction.new(old_inst.prefix, .mov, &.{
                    old_inst.ops[0],
                    // TODO: hack to force imm32s in the assembler
                    .{ .imm = Immediate.s(-129) },
                });
                relocs_log.debug("    relaxing {} => {}", .{ old_inst.encoding, inst.encoding });
                try encode(&.{inst}, code);
            },
            else => return error.RelaxFailure,
        }
    }

    fn relaxTlsGdToLe(
        self: Atom,
        rels: []const elf.Elf64_Rela,
        value: i32,
        elf_file: *Elf,
        stream: anytype,
    ) !void {
        dev.check(.x86_64_backend);
        assert(rels.len == 2);
        const writer = stream.writer();
        const rel: elf.R_X86_64 = @enumFromInt(rels[1].r_type());
        switch (rel) {
            .PC32,
            .PLT32,
            .GOTPCREL,
            .GOTPCRELX,
            => {
                var insts = [_]u8{
                    0x64, 0x48, 0x8b, 0x04, 0x25, 0, 0, 0, 0, // movq %fs:0,%rax
                    0x48, 0x81, 0xc0, 0, 0, 0, 0, // add $tp_offset, %rax
                };
                std.mem.writeInt(i32, insts[12..][0..4], value, .little);
                try stream.seekBy(-4);
                try writer.writeAll(&insts);
                relocs_log.debug("    relaxing {} and {}", .{
                    relocation.fmtRelocType(rels[0].r_type(), .x86_64),
                    relocation.fmtRelocType(rels[1].r_type(), .x86_64),
                });
            },

            else => {
                var err = try elf_file.base.addErrorWithNotes(1);
                try err.addMsg("fatal linker error: rewrite {} when followed by {}", .{
                    relocation.fmtRelocType(rels[0].r_type(), .x86_64),
                    relocation.fmtRelocType(rels[1].r_type(), .x86_64),
                });
                try err.addNote("in {}:{s} at offset 0x{x}", .{
                    self.file(elf_file).?.fmtPath(),
                    self.name(elf_file),
                    rels[0].r_offset,
                });
                return error.RelaxFailure;
            },
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
    const Immediate = Instruction.Immediate;
    const Instruction = encoder.Instruction;
};

const aarch64 = struct {
    fn scanReloc(
        atom: Atom,
        elf_file: *Elf,
        rel: elf.Elf64_Rela,
        symbol: *Symbol,
        code: ?[]const u8,
        it: *RelocsIterator,
    ) !void {
        _ = code;
        _ = it;

        const r_type: elf.R_AARCH64 = @enumFromInt(rel.r_type());
        const is_dyn_lib = elf_file.isEffectivelyDynLib();

        switch (r_type) {
            .ABS64 => {
                try atom.scanReloc(symbol, rel, dynAbsRelocAction(symbol, elf_file), elf_file);
            },

            .ADR_PREL_PG_HI21 => {
                try atom.scanReloc(symbol, rel, pcRelocAction(symbol, elf_file), elf_file);
            },

            .ADR_GOT_PAGE => {
                // TODO: relax if possible
                symbol.flags.needs_got = true;
            },

            .LD64_GOT_LO12_NC,
            .LD64_GOTPAGE_LO15,
            => {
                symbol.flags.needs_got = true;
            },

            .CALL26,
            .JUMP26,
            => {
                if (symbol.flags.import) {
                    symbol.flags.needs_plt = true;
                }
            },

            .TLSLE_ADD_TPREL_HI12,
            .TLSLE_ADD_TPREL_LO12_NC,
            => {
                if (is_dyn_lib) try atom.reportPicError(symbol, rel, elf_file);
            },

            .TLSIE_ADR_GOTTPREL_PAGE21,
            .TLSIE_LD64_GOTTPREL_LO12_NC,
            => {
                symbol.flags.needs_gottp = true;
            },

            .TLSGD_ADR_PAGE21,
            .TLSGD_ADD_LO12_NC,
            => {
                symbol.flags.needs_tlsgd = true;
            },

            .TLSDESC_ADR_PAGE21,
            .TLSDESC_LD64_LO12,
            .TLSDESC_ADD_LO12,
            .TLSDESC_CALL,
            => {
                const should_relax = elf_file.base.isStatic() or (!is_dyn_lib and !symbol.flags.import);
                if (!should_relax) {
                    symbol.flags.needs_tlsdesc = true;
                }
            },

            .ADD_ABS_LO12_NC,
            .ADR_PREL_LO21,
            .LDST8_ABS_LO12_NC,
            .LDST16_ABS_LO12_NC,
            .LDST32_ABS_LO12_NC,
            .LDST64_ABS_LO12_NC,
            .LDST128_ABS_LO12_NC,
            .PREL32,
            .PREL64,
            => {},

            else => try atom.reportUnhandledRelocError(rel, elf_file),
        }
    }

    fn resolveRelocAlloc(
        atom: Atom,
        elf_file: *Elf,
        rel: elf.Elf64_Rela,
        target: *const Symbol,
        args: ResolveArgs,
        it: *RelocsIterator,
        code_buffer: []u8,
        stream: anytype,
    ) (error{ UnexpectedRemainder, DivisionByZero } || RelocError)!void {
        _ = it;

        const r_type: elf.R_AARCH64 = @enumFromInt(rel.r_type());
        const r_offset = std.math.cast(usize, rel.r_offset) orelse return error.Overflow;
        const cwriter = stream.writer();
        const code = code_buffer[r_offset..][0..4];
        const file_ptr = atom.file(elf_file).?;

        const P, const A, const S, const GOT, const G, const TP, const DTP = args;
        _ = DTP;

        switch (r_type) {
            .NONE => unreachable,
            .ABS64 => {
                try atom.resolveDynAbsReloc(
                    target,
                    rel,
                    dynAbsRelocAction(target, elf_file),
                    elf_file,
                    cwriter,
                );
            },

            .CALL26,
            .JUMP26,
            => {
                const disp: i28 = math.cast(i28, S + A - P) orelse blk: {
                    const th = atom.thunk(elf_file);
                    const target_index = file_ptr.resolveSymbol(rel.r_sym(), elf_file);
                    const S_ = th.targetAddress(target_index, elf_file);
                    break :blk math.cast(i28, S_ + A - P) orelse return error.Overflow;
                };
                aarch64_util.writeBranchImm(disp, code);
            },

            .PREL32 => {
                const value = math.cast(i32, S + A - P) orelse return error.Overflow;
                mem.writeInt(u32, code, @bitCast(value), .little);
            },

            .PREL64 => {
                const value = S + A - P;
                mem.writeInt(u64, code_buffer[r_offset..][0..8], @bitCast(value), .little);
            },

            .ADR_PREL_PG_HI21 => {
                // TODO: check for relaxation of ADRP+ADD
                const pages = @as(u21, @bitCast(try aarch64_util.calcNumberOfPages(P, S + A)));
                aarch64_util.writeAdrpInst(pages, code);
            },

            .ADR_GOT_PAGE => if (target.flags.has_got) {
                const pages = @as(u21, @bitCast(try aarch64_util.calcNumberOfPages(P, G + GOT + A)));
                aarch64_util.writeAdrpInst(pages, code);
            } else {
                // TODO: relax
                var err = try elf_file.base.addErrorWithNotes(1);
                try err.addMsg("TODO: relax ADR_GOT_PAGE", .{});
                try err.addNote("in {}:{s} at offset 0x{x}", .{
                    atom.file(elf_file).?.fmtPath(),
                    atom.name(elf_file),
                    r_offset,
                });
            },

            .LD64_GOT_LO12_NC => {
                assert(target.flags.has_got);
                const taddr = @as(u64, @intCast(G + GOT + A));
                aarch64_util.writeLoadStoreRegInst(@divExact(@as(u12, @truncate(taddr)), 8), code);
            },

            .ADD_ABS_LO12_NC => {
                const taddr = @as(u64, @intCast(S + A));
                aarch64_util.writeAddImmInst(@truncate(taddr), code);
            },

            .LDST8_ABS_LO12_NC,
            .LDST16_ABS_LO12_NC,
            .LDST32_ABS_LO12_NC,
            .LDST64_ABS_LO12_NC,
            .LDST128_ABS_LO12_NC,
            => {
                // TODO: NC means no overflow check
                const taddr = @as(u64, @intCast(S + A));
                const off: u12 = switch (r_type) {
                    .LDST8_ABS_LO12_NC => @truncate(taddr),
                    .LDST16_ABS_LO12_NC => @divExact(@as(u12, @truncate(taddr)), 2),
                    .LDST32_ABS_LO12_NC => @divExact(@as(u12, @truncate(taddr)), 4),
                    .LDST64_ABS_LO12_NC => @divExact(@as(u12, @truncate(taddr)), 8),
                    .LDST128_ABS_LO12_NC => @divExact(@as(u12, @truncate(taddr)), 16),
                    else => unreachable,
                };
                aarch64_util.writeLoadStoreRegInst(off, code);
            },

            .TLSLE_ADD_TPREL_HI12 => {
                const value = math.cast(i12, (S + A - TP) >> 12) orelse
                    return error.Overflow;
                aarch64_util.writeAddImmInst(@bitCast(value), code);
            },

            .TLSLE_ADD_TPREL_LO12_NC => {
                const value: i12 = @truncate(S + A - TP);
                aarch64_util.writeAddImmInst(@bitCast(value), code);
            },

            .TLSIE_ADR_GOTTPREL_PAGE21 => {
                const S_ = target.gotTpAddress(elf_file);
                relocs_log.debug("      [{x} => {x}]", .{ P, S_ + A });
                const pages: u21 = @bitCast(try aarch64_util.calcNumberOfPages(P, S_ + A));
                aarch64_util.writeAdrpInst(pages, code);
            },

            .TLSIE_LD64_GOTTPREL_LO12_NC => {
                const S_ = target.gotTpAddress(elf_file);
                relocs_log.debug("      [{x} => {x}]", .{ P, S_ + A });
                const off: u12 = try math.divExact(u12, @truncate(@as(u64, @bitCast(S_ + A))), 8);
                aarch64_util.writeLoadStoreRegInst(off, code);
            },

            .TLSGD_ADR_PAGE21 => {
                const S_ = target.tlsGdAddress(elf_file);
                relocs_log.debug("      [{x} => {x}]", .{ P, S_ + A });
                const pages: u21 = @bitCast(try aarch64_util.calcNumberOfPages(P, S_ + A));
                aarch64_util.writeAdrpInst(pages, code);
            },

            .TLSGD_ADD_LO12_NC => {
                const S_ = target.tlsGdAddress(elf_file);
                relocs_log.debug("      [{x} => {x}]", .{ P, S_ + A });
                const off: u12 = @truncate(@as(u64, @bitCast(S_ + A)));
                aarch64_util.writeAddImmInst(off, code);
            },

            .TLSDESC_ADR_PAGE21 => {
                if (target.flags.has_tlsdesc) {
                    const S_ = target.tlsDescAddress(elf_file);
                    relocs_log.debug("      [{x} => {x}]", .{ P, S_ + A });
                    const pages: u21 = @bitCast(try aarch64_util.calcNumberOfPages(P, S_ + A));
                    aarch64_util.writeAdrpInst(pages, code);
                } else {
                    relocs_log.debug("      relaxing adrp => nop", .{});
                    mem.writeInt(u32, code, Instruction.nop().toU32(), .little);
                }
            },

            .TLSDESC_LD64_LO12 => {
                if (target.flags.has_tlsdesc) {
                    const S_ = target.tlsDescAddress(elf_file);
                    relocs_log.debug("      [{x} => {x}]", .{ P, S_ + A });
                    const off: u12 = try math.divExact(u12, @truncate(@as(u64, @bitCast(S_ + A))), 8);
                    aarch64_util.writeLoadStoreRegInst(off, code);
                } else {
                    relocs_log.debug("      relaxing ldr => nop", .{});
                    mem.writeInt(u32, code, Instruction.nop().toU32(), .little);
                }
            },

            .TLSDESC_ADD_LO12 => {
                if (target.flags.has_tlsdesc) {
                    const S_ = target.tlsDescAddress(elf_file);
                    relocs_log.debug("      [{x} => {x}]", .{ P, S_ + A });
                    const off: u12 = @truncate(@as(u64, @bitCast(S_ + A)));
                    aarch64_util.writeAddImmInst(off, code);
                } else {
                    const old_inst = Instruction{
                        .add_subtract_immediate = mem.bytesToValue(std.meta.TagPayload(
                            Instruction,
                            Instruction.add_subtract_immediate,
                        ), code),
                    };
                    const rd: Register = @enumFromInt(old_inst.add_subtract_immediate.rd);
                    relocs_log.debug("      relaxing add({s}) => movz(x0, {x})", .{ @tagName(rd), S + A - TP });
                    const value: u16 = @bitCast(math.cast(i16, (S + A - TP) >> 16) orelse return error.Overflow);
                    mem.writeInt(u32, code, Instruction.movz(.x0, value, 16).toU32(), .little);
                }
            },

            .TLSDESC_CALL => if (!target.flags.has_tlsdesc) {
                const old_inst = Instruction{
                    .unconditional_branch_register = mem.bytesToValue(std.meta.TagPayload(
                        Instruction,
                        Instruction.unconditional_branch_register,
                    ), code),
                };
                const rn: Register = @enumFromInt(old_inst.unconditional_branch_register.rn);
                relocs_log.debug("      relaxing br({s}) => movk(x0, {x})", .{ @tagName(rn), S + A - TP });
                const value: u16 = @bitCast(@as(i16, @truncate(S + A - TP)));
                mem.writeInt(u32, code, Instruction.movk(.x0, value, 0).toU32(), .little);
            },

            else => try atom.reportUnhandledRelocError(rel, elf_file),
        }
    }

    fn resolveRelocNonAlloc(
        atom: Atom,
        elf_file: *Elf,
        rel: elf.Elf64_Rela,
        target: *const Symbol,
        args: ResolveArgs,
        it: *RelocsIterator,
        code: []u8,
        stream: anytype,
    ) !void {
        _ = it;
        _ = code;

        const r_type: elf.R_AARCH64 = @enumFromInt(rel.r_type());
        const cwriter = stream.writer();

        _, const A, const S, _, _, _, _ = args;

        switch (r_type) {
            .NONE => unreachable,
            .ABS32 => try cwriter.writeInt(i32, @as(i32, @intCast(S + A)), .little),
            .ABS64 => if (atom.debugTombstoneValue(target.*, elf_file)) |value|
                try cwriter.writeInt(u64, value, .little)
            else
                try cwriter.writeInt(i64, S + A, .little),
            else => try atom.reportUnhandledRelocError(rel, elf_file),
        }
    }

    const aarch64_util = @import("../aarch64.zig");
    const Instruction = aarch64_util.Instruction;
    const Register = aarch64_util.Register;
};

const riscv = struct {
    fn scanReloc(
        atom: Atom,
        elf_file: *Elf,
        rel: elf.Elf64_Rela,
        symbol: *Symbol,
        code: ?[]const u8,
        it: *RelocsIterator,
    ) !void {
        _ = code;
        _ = it;

        const r_type: elf.R_RISCV = @enumFromInt(rel.r_type());

        switch (r_type) {
            .@"32" => try atom.scanReloc(symbol, rel, absRelocAction(symbol, elf_file), elf_file),
            .@"64" => try atom.scanReloc(symbol, rel, dynAbsRelocAction(symbol, elf_file), elf_file),
            .HI20 => try atom.scanReloc(symbol, rel, absRelocAction(symbol, elf_file), elf_file),

            .CALL_PLT => if (symbol.flags.import) {
                symbol.flags.needs_plt = true;
            },
            .GOT_HI20 => symbol.flags.needs_got = true,

            .TPREL_HI20,
            .TPREL_LO12_I,
            .TPREL_LO12_S,
            .TPREL_ADD,

            .PCREL_HI20,
            .PCREL_LO12_I,
            .PCREL_LO12_S,
            .LO12_I,
            .LO12_S,
            .ADD32,
            .SUB32,
            => {},

            else => try atom.reportUnhandledRelocError(rel, elf_file),
        }
    }

    fn resolveRelocAlloc(
        atom: Atom,
        elf_file: *Elf,
        rel: elf.Elf64_Rela,
        target: *const Symbol,
        args: ResolveArgs,
        it: *RelocsIterator,
        code: []u8,
        stream: anytype,
    ) !void {
        const r_type: elf.R_RISCV = @enumFromInt(rel.r_type());
        const r_offset = std.math.cast(usize, rel.r_offset) orelse return error.Overflow;
        const cwriter = stream.writer();

        const P, const A, const S, const GOT, const G, const TP, const DTP = args;
        _ = TP;
        _ = DTP;

        switch (r_type) {
            .NONE => unreachable,

            .@"32" => try cwriter.writeInt(u32, @as(u32, @truncate(@as(u64, @intCast(S + A)))), .little),

            .@"64" => {
                try atom.resolveDynAbsReloc(
                    target,
                    rel,
                    dynAbsRelocAction(target, elf_file),
                    elf_file,
                    cwriter,
                );
            },

            .ADD32 => riscv_util.writeAddend(i32, .add, code[r_offset..][0..4], S + A),
            .SUB32 => riscv_util.writeAddend(i32, .sub, code[r_offset..][0..4], S + A),

            .HI20 => {
                const value: u32 = @bitCast(math.cast(i32, S + A) orelse return error.Overflow);
                riscv_util.writeInstU(code[r_offset..][0..4], value);
            },

            .GOT_HI20 => {
                assert(target.flags.has_got);
                const disp: u32 = @bitCast(math.cast(i32, G + GOT + A - P) orelse return error.Overflow);
                riscv_util.writeInstU(code[r_offset..][0..4], disp);
            },

            .CALL_PLT => {
                // TODO: relax
                const disp: u32 = @bitCast(math.cast(i32, S + A - P) orelse return error.Overflow);
                riscv_util.writeInstU(code[r_offset..][0..4], disp); // auipc
                riscv_util.writeInstI(code[r_offset + 4 ..][0..4], disp); // jalr
            },

            .PCREL_HI20 => {
                const disp: u32 = @bitCast(math.cast(i32, S + A - P) orelse return error.Overflow);
                riscv_util.writeInstU(code[r_offset..][0..4], disp);
            },

            .PCREL_LO12_I,
            .PCREL_LO12_S,
            => {
                assert(A == 0); // according to the spec
                // We need to find the paired reloc for this relocation.
                const file_ptr = atom.file(elf_file).?;
                const atom_addr = atom.address(elf_file);
                const pos = it.pos;
                const pair = while (it.prev()) |pair| {
                    if (S == atom_addr + @as(i64, @intCast(pair.r_offset))) break pair;
                } else {
                    // TODO: implement searching forward
                    var err = try elf_file.base.addErrorWithNotes(1);
                    try err.addMsg("TODO: find HI20 paired reloc scanning forward", .{});
                    try err.addNote("in {}:{s} at offset 0x{x}", .{
                        atom.file(elf_file).?.fmtPath(),
                        atom.name(elf_file),
                        rel.r_offset,
                    });
                    return error.RelocFailure;
                };
                it.pos = pos;
                const target_ref_ = file_ptr.resolveSymbol(pair.r_sym(), elf_file);
                const target_ = elf_file.symbol(target_ref_).?;
                const S_ = target_.address(.{}, elf_file);
                const A_ = pair.r_addend;
                const P_ = atom_addr + @as(i64, @intCast(pair.r_offset));
                const G_ = target_.gotAddress(elf_file) - GOT;
                const disp = switch (@as(elf.R_RISCV, @enumFromInt(pair.r_type()))) {
                    .PCREL_HI20 => math.cast(i32, S_ + A_ - P_) orelse return error.Overflow,
                    .GOT_HI20 => math.cast(i32, G_ + GOT + A_ - P_) orelse return error.Overflow,
                    else => unreachable,
                };
                relocs_log.debug("      [{x} => {x}]", .{ P_, disp + P_ });
                switch (r_type) {
                    .PCREL_LO12_I => riscv_util.writeInstI(code[r_offset..][0..4], @bitCast(disp)),
                    .PCREL_LO12_S => riscv_util.writeInstS(code[r_offset..][0..4], @bitCast(disp)),
                    else => unreachable,
                }
            },

            .LO12_I,
            .LO12_S,
            => {
                const disp: u32 = @bitCast(math.cast(i32, S + A) orelse return error.Overflow);
                switch (r_type) {
                    .LO12_I => riscv_util.writeInstI(code[r_offset..][0..4], disp),
                    .LO12_S => riscv_util.writeInstS(code[r_offset..][0..4], disp),
                    else => unreachable,
                }
            },

            .TPREL_HI20 => {
                const target_addr: u32 = @intCast(target.address(.{}, elf_file));
                const val: i32 = @intCast(S + A - target_addr);
                riscv_util.writeInstU(code[r_offset..][0..4], @bitCast(val));
            },

            .TPREL_LO12_I,
            .TPREL_LO12_S,
            => {
                const target_addr: u32 = @intCast(target.address(.{}, elf_file));
                const val: i32 = @intCast(S + A - target_addr);
                switch (r_type) {
                    .TPREL_LO12_I => riscv_util.writeInstI(code[r_offset..][0..4], @bitCast(val)),
                    .TPREL_LO12_S => riscv_util.writeInstS(code[r_offset..][0..4], @bitCast(val)),
                    else => unreachable,
                }
            },

            .TPREL_ADD => {
                // TODO: annotates an ADD instruction that can be removed when TPREL is relaxed
            },

            else => try atom.reportUnhandledRelocError(rel, elf_file),
        }
    }

    fn resolveRelocNonAlloc(
        atom: Atom,
        elf_file: *Elf,
        rel: elf.Elf64_Rela,
        target: *const Symbol,
        args: ResolveArgs,
        it: *RelocsIterator,
        code: []u8,
        stream: anytype,
    ) !void {
        _ = it;

        const r_type: elf.R_RISCV = @enumFromInt(rel.r_type());
        const r_offset = std.math.cast(usize, rel.r_offset) orelse return error.Overflow;
        const cwriter = stream.writer();

        _, const A, const S, const GOT, _, _, const DTP = args;
        _ = GOT;
        _ = DTP;

        switch (r_type) {
            .NONE => unreachable,

            .@"32" => try cwriter.writeInt(i32, @as(i32, @intCast(S + A)), .little),
            .@"64" => if (atom.debugTombstoneValue(target.*, elf_file)) |value|
                try cwriter.writeInt(u64, value, .little)
            else
                try cwriter.writeInt(i64, S + A, .little),

            .ADD8 => riscv_util.writeAddend(i8, .add, code[r_offset..][0..1], S + A),
            .SUB8 => riscv_util.writeAddend(i8, .sub, code[r_offset..][0..1], S + A),
            .ADD16 => riscv_util.writeAddend(i16, .add, code[r_offset..][0..2], S + A),
            .SUB16 => riscv_util.writeAddend(i16, .sub, code[r_offset..][0..2], S + A),
            .ADD32 => riscv_util.writeAddend(i32, .add, code[r_offset..][0..4], S + A),
            .SUB32 => riscv_util.writeAddend(i32, .sub, code[r_offset..][0..4], S + A),
            .ADD64 => riscv_util.writeAddend(i64, .add, code[r_offset..][0..8], S + A),
            .SUB64 => riscv_util.writeAddend(i64, .sub, code[r_offset..][0..8], S + A),

            .SET8 => mem.writeInt(i8, code[r_offset..][0..1], @as(i8, @truncate(S + A)), .little),
            .SET16 => mem.writeInt(i16, code[r_offset..][0..2], @as(i16, @truncate(S + A)), .little),
            .SET32 => mem.writeInt(i32, code[r_offset..][0..4], @as(i32, @truncate(S + A)), .little),

            .SET6 => riscv_util.writeSetSub6(.set, code[r_offset..][0..1], S + A),
            .SUB6 => riscv_util.writeSetSub6(.sub, code[r_offset..][0..1], S + A),

            else => try atom.reportUnhandledRelocError(rel, elf_file),
        }
    }

    const riscv_util = @import("../riscv.zig");
};

const ResolveArgs = struct { i64, i64, i64, i64, i64, i64, i64 };

const RelocError = error{
    Overflow,
    OutOfMemory,
    NoSpaceLeft,
    RelocFailure,
    RelaxFailure,
    UnsupportedCpuArch,
};

const RelocsIterator = struct {
    relocs: []const elf.Elf64_Rela,
    pos: i64 = -1,

    fn next(it: *RelocsIterator) ?elf.Elf64_Rela {
        it.pos += 1;
        if (it.pos >= it.relocs.len) return null;
        return it.relocs[@intCast(it.pos)];
    }

    fn prev(it: *RelocsIterator) ?elf.Elf64_Rela {
        if (it.pos == -1) return null;
        const rel = it.relocs[@intCast(it.pos)];
        it.pos -= 1;
        return rel;
    }

    fn skip(it: *RelocsIterator, num: usize) void {
        assert(num > 0);
        it.pos += @intCast(num);
    }
};

pub const Extra = struct {
    /// Index of the range extension thunk of this atom.
    thunk: u32 = 0,

    /// Start index of FDEs referencing this atom.
    fde_start: u32 = 0,

    /// Count of FDEs referencing this atom.
    fde_count: u32 = 0,

    /// Start index of relocations belonging to this atom.
    rel_index: u32 = 0,

    /// Count of relocations belonging to this atom.
    rel_count: u32 = 0,
};

const std = @import("std");
const assert = std.debug.assert;
const elf = std.elf;
const eh_frame = @import("eh_frame.zig");
const log = std.log.scoped(.link);
const math = std.math;
const mem = std.mem;
const relocs_log = std.log.scoped(.link_relocs);
const relocation = @import("relocation.zig");

const Allocator = mem.Allocator;
const Atom = @This();
const Elf = @import("../Elf.zig");
const Fde = eh_frame.Fde;
const File = @import("file.zig").File;
const Object = @import("Object.zig");
const Symbol = @import("Symbol.zig");
const Thunk = @import("Thunk.zig");
const ZigObject = @import("ZigObject.zig");
const dev = @import("../../dev.zig");
