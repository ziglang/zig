const Atom = @This();

const std = @import("std");
const build_options = @import("build_options");
const aarch64 = @import("../../arch/aarch64/bits.zig");
const assert = std.debug.assert;
const log = std.log.scoped(.link);
const macho = std.macho;
const math = std.math;
const mem = std.mem;
const meta = std.meta;
const trace = @import("../../tracy.zig").trace;

const Allocator = mem.Allocator;
const Arch = std.Target.Cpu.Arch;
const Dwarf = @import("../Dwarf.zig");
const MachO = @import("../MachO.zig");
const Object = @import("Object.zig");
const RelocationIncr = @import("Relocation.zig"); // temporary name until we clean up object-file relocation scanning
const SymbolWithLoc = MachO.SymbolWithLoc;

/// Each decl always gets a local symbol with the fully qualified name.
/// The vaddr and size are found here directly.
/// The file offset is found by computing the vaddr offset from the section vaddr
/// the symbol references, and adding that to the file offset of the section.
/// If this field is 0, it means the codegen size = 0 and there is no symbol or
/// offset table entry.
sym_index: u32,

/// null means symbol defined by Zig source.
file: ?u32,

/// List of symbols contained within this atom
contained: std.ArrayListUnmanaged(SymbolAtOffset) = .{},

/// Code (may be non-relocated) this atom represents
code: std.ArrayListUnmanaged(u8) = .{},

/// Size and alignment of this atom
/// Unlike in Elf, we need to store the size of this symbol as part of
/// the atom since macho.nlist_64 lacks this information.
size: u64,

/// Alignment of this atom as a power of 2.
/// For instance, alignment of 0 should be read as 2^0 = 1 byte aligned.
alignment: u32,

/// List of relocations belonging to this atom.
relocs: std.ArrayListUnmanaged(Relocation) = .{},

/// List of offsets contained within this atom that need rebasing by the dynamic
/// loader for example in presence of ASLR.
rebases: std.ArrayListUnmanaged(u64) = .{},

/// List of offsets contained within this atom that will be dynamically bound
/// by the dynamic loader and contain pointers to resolved (at load time) extern
/// symbols (aka proxies aka imports).
bindings: std.ArrayListUnmanaged(Binding) = .{},

/// List of lazy bindings (cf bindings above).
lazy_bindings: std.ArrayListUnmanaged(Binding) = .{},

/// Points to the previous and next neighbours
next: ?*Atom,
prev: ?*Atom,

dbg_info_atom: Dwarf.Atom,

dirty: bool = true,

pub const Binding = struct {
    target: SymbolWithLoc,
    offset: u64,
};

pub const SymbolAtOffset = struct {
    sym_index: u32,
    offset: u64,
};

pub const Relocation = struct {
    /// Offset within the atom's code buffer.
    /// Note relocation size can be inferred by relocation's kind.
    offset: u32,

    target: MachO.SymbolWithLoc,

    addend: i64,

    subtractor: ?MachO.SymbolWithLoc,

    pcrel: bool,

    length: u2,

    @"type": u4,

    pub fn getTargetAtom(self: Relocation, macho_file: *MachO) ?*Atom {
        const is_via_got = got: {
            switch (macho_file.base.options.target.cpu.arch) {
                .aarch64 => break :got switch (@intToEnum(macho.reloc_type_arm64, self.@"type")) {
                    .ARM64_RELOC_GOT_LOAD_PAGE21,
                    .ARM64_RELOC_GOT_LOAD_PAGEOFF12,
                    .ARM64_RELOC_POINTER_TO_GOT,
                    => true,
                    else => false,
                },
                .x86_64 => break :got switch (@intToEnum(macho.reloc_type_x86_64, self.@"type")) {
                    .X86_64_RELOC_GOT, .X86_64_RELOC_GOT_LOAD => true,
                    else => false,
                },
                else => unreachable,
            }
        };

        if (is_via_got) {
            return macho_file.getGotAtomForSymbol(self.target).?; // panic means fatal error
        }
        if (macho_file.getStubsAtomForSymbol(self.target)) |stubs_atom| return stubs_atom;
        if (macho_file.getTlvPtrAtomForSymbol(self.target)) |tlv_ptr_atom| return tlv_ptr_atom;
        return macho_file.getAtomForSymbol(self.target);
    }
};

pub const empty = Atom{
    .sym_index = 0,
    .file = null,
    .size = 0,
    .alignment = 0,
    .prev = null,
    .next = null,
    .dbg_info_atom = undefined,
};

pub fn deinit(self: *Atom, allocator: Allocator) void {
    self.lazy_bindings.deinit(allocator);
    self.bindings.deinit(allocator);
    self.rebases.deinit(allocator);
    self.relocs.deinit(allocator);
    self.contained.deinit(allocator);
    self.code.deinit(allocator);
}

pub fn clearRetainingCapacity(self: *Atom) void {
    self.lazy_bindings.clearRetainingCapacity();
    self.bindings.clearRetainingCapacity();
    self.rebases.clearRetainingCapacity();
    self.relocs.clearRetainingCapacity();
    self.contained.clearRetainingCapacity();
    self.code.clearRetainingCapacity();
}

/// Returns symbol referencing this atom.
pub fn getSymbol(self: Atom, macho_file: *MachO) macho.nlist_64 {
    return self.getSymbolPtr(macho_file).*;
}

/// Returns pointer-to-symbol referencing this atom.
pub fn getSymbolPtr(self: Atom, macho_file: *MachO) *macho.nlist_64 {
    return macho_file.getSymbolPtr(.{
        .sym_index = self.sym_index,
        .file = self.file,
    });
}

pub fn getSymbolWithLoc(self: Atom) SymbolWithLoc {
    return .{ .sym_index = self.sym_index, .file = self.file };
}

/// Returns true if the symbol pointed at with `sym_loc` is contained within this atom.
/// WARNING this function assumes all atoms have been allocated in the virtual memory.
/// Calling it without allocating with `MachO.allocateSymbols` (or equivalent) will
/// give bogus results.
pub fn isSymbolContained(self: Atom, sym_loc: SymbolWithLoc, macho_file: *MachO) bool {
    const sym = macho_file.getSymbol(sym_loc);
    if (!sym.sect()) return false;
    const self_sym = self.getSymbol(macho_file);
    return sym.n_value >= self_sym.n_value and sym.n_value < self_sym.n_value + self.size;
}

/// Returns the name of this atom.
pub fn getName(self: Atom, macho_file: *MachO) []const u8 {
    return macho_file.getSymbolName(.{
        .sym_index = self.sym_index,
        .file = self.file,
    });
}

/// Returns how much room there is to grow in virtual address space.
/// File offset relocation happens transparently, so it is not included in
/// this calculation.
pub fn capacity(self: Atom, macho_file: *MachO) u64 {
    const self_sym = self.getSymbol(macho_file);
    if (self.next) |next| {
        const next_sym = next.getSymbol(macho_file);
        return next_sym.n_value - self_sym.n_value;
    } else {
        // We are the last atom.
        // The capacity is limited only by virtual address space.
        return std.math.maxInt(u64) - self_sym.n_value;
    }
}

pub fn freeListEligible(self: Atom, macho_file: *MachO) bool {
    // No need to keep a free list node for the last atom.
    const next = self.next orelse return false;
    const self_sym = self.getSymbol(macho_file);
    const next_sym = next.getSymbol(macho_file);
    const cap = next_sym.n_value - self_sym.n_value;
    const ideal_cap = MachO.padToIdeal(self.size);
    if (cap <= ideal_cap) return false;
    const surplus = cap - ideal_cap;
    return surplus >= MachO.min_text_capacity;
}

const RelocContext = struct {
    macho_file: *MachO,
    base_addr: u64 = 0,
    base_offset: i32 = 0,
};

pub fn parseRelocs(self: *Atom, relocs: []align(1) const macho.relocation_info, context: RelocContext) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = context.macho_file.base.allocator;

    const arch = context.macho_file.base.options.target.cpu.arch;
    var addend: i64 = 0;
    var subtractor: ?SymbolWithLoc = null;

    for (relocs) |rel, i| {
        blk: {
            switch (arch) {
                .aarch64 => switch (@intToEnum(macho.reloc_type_arm64, rel.r_type)) {
                    .ARM64_RELOC_ADDEND => {
                        assert(addend == 0);
                        addend = rel.r_symbolnum;
                        // Verify that it's followed by ARM64_RELOC_PAGE21 or ARM64_RELOC_PAGEOFF12.
                        if (relocs.len <= i + 1) {
                            log.err("no relocation after ARM64_RELOC_ADDEND", .{});
                            return error.UnexpectedRelocationType;
                        }
                        const next = @intToEnum(macho.reloc_type_arm64, relocs[i + 1].r_type);
                        switch (next) {
                            .ARM64_RELOC_PAGE21, .ARM64_RELOC_PAGEOFF12 => {},
                            else => {
                                log.err("unexpected relocation type after ARM64_RELOC_ADDEND", .{});
                                log.err("  expected ARM64_RELOC_PAGE21 or ARM64_RELOC_PAGEOFF12", .{});
                                log.err("  found {s}", .{@tagName(next)});
                                return error.UnexpectedRelocationType;
                            },
                        }
                        continue;
                    },
                    .ARM64_RELOC_SUBTRACTOR => {},
                    else => break :blk,
                },
                .x86_64 => switch (@intToEnum(macho.reloc_type_x86_64, rel.r_type)) {
                    .X86_64_RELOC_SUBTRACTOR => {},
                    else => break :blk,
                },
                else => unreachable,
            }

            assert(subtractor == null);
            const sym_loc = MachO.SymbolWithLoc{
                .sym_index = rel.r_symbolnum,
                .file = self.file,
            };
            const sym = context.macho_file.getSymbol(sym_loc);
            if (sym.sect() and !sym.ext()) {
                subtractor = sym_loc;
            } else {
                const sym_name = context.macho_file.getSymbolName(sym_loc);
                subtractor = context.macho_file.getGlobal(sym_name).?;
            }
            // Verify that *_SUBTRACTOR is followed by *_UNSIGNED.
            if (relocs.len <= i + 1) {
                log.err("no relocation after *_RELOC_SUBTRACTOR", .{});
                return error.UnexpectedRelocationType;
            }
            switch (arch) {
                .aarch64 => switch (@intToEnum(macho.reloc_type_arm64, relocs[i + 1].r_type)) {
                    .ARM64_RELOC_UNSIGNED => {},
                    else => {
                        log.err("unexpected relocation type after ARM64_RELOC_ADDEND", .{});
                        log.err("  expected ARM64_RELOC_UNSIGNED", .{});
                        log.err("  found {s}", .{
                            @tagName(@intToEnum(macho.reloc_type_arm64, relocs[i + 1].r_type)),
                        });
                        return error.UnexpectedRelocationType;
                    },
                },
                .x86_64 => switch (@intToEnum(macho.reloc_type_x86_64, relocs[i + 1].r_type)) {
                    .X86_64_RELOC_UNSIGNED => {},
                    else => {
                        log.err("unexpected relocation type after X86_64_RELOC_ADDEND", .{});
                        log.err("  expected X86_64_RELOC_UNSIGNED", .{});
                        log.err("  found {s}", .{
                            @tagName(@intToEnum(macho.reloc_type_x86_64, relocs[i + 1].r_type)),
                        });
                        return error.UnexpectedRelocationType;
                    },
                },
                else => unreachable,
            }
            continue;
        }

        const object = &context.macho_file.objects.items[self.file.?];
        const target = target: {
            if (rel.r_extern == 0) {
                const sect_id = @intCast(u16, rel.r_symbolnum - 1);
                const sym_index = object.sections_as_symbols.get(sect_id) orelse blk: {
                    const sect = object.getSourceSection(sect_id);
                    const gop = (try context.macho_file.getOutputSection(sect)) orelse
                        unreachable;
                    const out_sect_id = gop.sect_id;
                    const sym_index = @intCast(u32, object.symtab.items.len);
                    try object.symtab.append(gpa, .{
                        .n_strx = 0,
                        .n_type = macho.N_SECT,
                        .n_sect = out_sect_id + 1,
                        .n_desc = 0,
                        .n_value = sect.addr,
                    });
                    try object.sections_as_symbols.putNoClobber(gpa, sect_id, sym_index);
                    break :blk sym_index;
                };
                break :target MachO.SymbolWithLoc{ .sym_index = sym_index, .file = self.file };
            }

            const sym_loc = MachO.SymbolWithLoc{
                .sym_index = rel.r_symbolnum,
                .file = self.file,
            };
            const sym = context.macho_file.getSymbol(sym_loc);

            if (sym.sect() and !sym.ext()) {
                break :target sym_loc;
            } else {
                const sym_name = context.macho_file.getSymbolName(sym_loc);
                break :target context.macho_file.getGlobal(sym_name).?;
            }
        };
        const offset = @intCast(u32, rel.r_address - context.base_offset);

        switch (arch) {
            .aarch64 => {
                switch (@intToEnum(macho.reloc_type_arm64, rel.r_type)) {
                    .ARM64_RELOC_BRANCH26 => {
                        // TODO rewrite relocation
                        try addStub(target, context);
                    },
                    .ARM64_RELOC_GOT_LOAD_PAGE21,
                    .ARM64_RELOC_GOT_LOAD_PAGEOFF12,
                    .ARM64_RELOC_POINTER_TO_GOT,
                    => {
                        // TODO rewrite relocation
                        try addGotEntry(target, context);
                    },
                    .ARM64_RELOC_UNSIGNED => {
                        addend = if (rel.r_length == 3)
                            mem.readIntLittle(i64, self.code.items[offset..][0..8])
                        else
                            mem.readIntLittle(i32, self.code.items[offset..][0..4]);
                        if (rel.r_extern == 0) {
                            const target_sect_base_addr = object.getSourceSection(@intCast(u16, rel.r_symbolnum - 1)).addr;
                            addend -= @intCast(i64, target_sect_base_addr);
                        }
                        try self.addPtrBindingOrRebase(rel, target, context);
                    },
                    .ARM64_RELOC_TLVP_LOAD_PAGE21,
                    .ARM64_RELOC_TLVP_LOAD_PAGEOFF12,
                    => {
                        try addTlvPtrEntry(target, context);
                    },
                    else => {},
                }
            },
            .x86_64 => {
                const rel_type = @intToEnum(macho.reloc_type_x86_64, rel.r_type);
                switch (rel_type) {
                    .X86_64_RELOC_BRANCH => {
                        // TODO rewrite relocation
                        try addStub(target, context);
                        addend = mem.readIntLittle(i32, self.code.items[offset..][0..4]);
                    },
                    .X86_64_RELOC_GOT, .X86_64_RELOC_GOT_LOAD => {
                        // TODO rewrite relocation
                        try addGotEntry(target, context);
                        addend = mem.readIntLittle(i32, self.code.items[offset..][0..4]);
                    },
                    .X86_64_RELOC_UNSIGNED => {
                        addend = if (rel.r_length == 3)
                            mem.readIntLittle(i64, self.code.items[offset..][0..8])
                        else
                            mem.readIntLittle(i32, self.code.items[offset..][0..4]);
                        if (rel.r_extern == 0) {
                            const target_sect_base_addr = object.getSourceSection(@intCast(u16, rel.r_symbolnum - 1)).addr;
                            addend -= @intCast(i64, target_sect_base_addr);
                        }
                        try self.addPtrBindingOrRebase(rel, target, context);
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
                        addend = mem.readIntLittle(i32, self.code.items[offset..][0..4]) + correction;
                        if (rel.r_extern == 0) {
                            // Note for the future self: when r_extern == 0, we should subtract correction from the
                            // addend.
                            const target_sect_base_addr = object.getSourceSection(@intCast(u16, rel.r_symbolnum - 1)).addr;
                            // We need to add base_offset, i.e., offset of this atom wrt to the source
                            // section. Otherwise, the addend will over-/under-shoot.
                            addend += @intCast(i64, context.base_addr + offset + 4) -
                                @intCast(i64, target_sect_base_addr) + context.base_offset;
                        }
                    },
                    .X86_64_RELOC_TLV => {
                        try addTlvPtrEntry(target, context);
                    },
                    else => {},
                }
            },
            else => unreachable,
        }

        try self.relocs.append(gpa, .{
            .offset = offset,
            .target = target,
            .addend = addend,
            .subtractor = subtractor,
            .pcrel = rel.r_pcrel == 1,
            .length = rel.r_length,
            .@"type" = rel.r_type,
        });

        addend = 0;
        subtractor = null;
    }
}

fn addPtrBindingOrRebase(
    self: *Atom,
    rel: macho.relocation_info,
    target: MachO.SymbolWithLoc,
    context: RelocContext,
) !void {
    const gpa = context.macho_file.base.allocator;
    const sym = context.macho_file.getSymbol(target);
    if (sym.undf()) {
        try self.bindings.append(gpa, .{
            .target = target,
            .offset = @intCast(u32, rel.r_address - context.base_offset),
        });
    } else {
        const source_sym = self.getSymbol(context.macho_file);
        const section = context.macho_file.sections.get(source_sym.n_sect - 1);
        const header = section.header;
        const segment_index = section.segment_index;
        const sect_type = header.@"type"();

        const should_rebase = rebase: {
            if (rel.r_length != 3) break :rebase false;

            // TODO actually, a check similar to what dyld is doing, that is, verifying
            // that the segment is writable should be enough here.
            const is_right_segment = blk: {
                if (context.macho_file.data_segment_cmd_index) |idx| {
                    if (segment_index == idx) {
                        break :blk true;
                    }
                }
                if (context.macho_file.data_const_segment_cmd_index) |idx| {
                    if (segment_index == idx) {
                        break :blk true;
                    }
                }
                break :blk false;
            };

            if (!is_right_segment) break :rebase false;
            if (sect_type != macho.S_LITERAL_POINTERS and
                sect_type != macho.S_REGULAR and
                sect_type != macho.S_MOD_INIT_FUNC_POINTERS and
                sect_type != macho.S_MOD_TERM_FUNC_POINTERS)
            {
                break :rebase false;
            }

            break :rebase true;
        };

        if (should_rebase) {
            try self.rebases.append(gpa, @intCast(u32, rel.r_address - context.base_offset));
        }
    }
}

fn addTlvPtrEntry(target: MachO.SymbolWithLoc, context: RelocContext) !void {
    const target_sym = context.macho_file.getSymbol(target);
    if (!target_sym.undf()) return;
    if (context.macho_file.tlv_ptr_entries_table.contains(target)) return;

    const index = try context.macho_file.allocateTlvPtrEntry(target);
    const atom = try context.macho_file.createTlvPtrAtom(target);
    context.macho_file.tlv_ptr_entries.items[index].sym_index = atom.sym_index;
}

fn addGotEntry(target: MachO.SymbolWithLoc, context: RelocContext) !void {
    if (context.macho_file.got_entries_table.contains(target)) return;

    const index = try context.macho_file.allocateGotEntry(target);
    const atom = try context.macho_file.createGotAtom(target);
    context.macho_file.got_entries.items[index].sym_index = atom.sym_index;
}

fn addStub(target: MachO.SymbolWithLoc, context: RelocContext) !void {
    const target_sym = context.macho_file.getSymbol(target);
    if (!target_sym.undf()) return;
    if (context.macho_file.stubs_table.contains(target)) return;

    const stub_index = try context.macho_file.allocateStubEntry(target);

    const stub_helper_atom = try context.macho_file.createStubHelperAtom();
    const laptr_atom = try context.macho_file.createLazyPointerAtom(stub_helper_atom.sym_index, target);
    const stub_atom = try context.macho_file.createStubAtom(laptr_atom.sym_index);

    context.macho_file.stubs.items[stub_index].sym_index = stub_atom.sym_index;
}

pub fn resolveRelocs(self: *Atom, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    log.debug("ATOM(%{d}, '{s}')", .{ self.sym_index, self.getName(macho_file) });

    for (self.relocs.items) |rel| {
        const arch = macho_file.base.options.target.cpu.arch;
        switch (arch) {
            .aarch64 => {
                log.debug("  RELA({s}) @ {x} => %{d} in object({?d})", .{
                    @tagName(@intToEnum(macho.reloc_type_arm64, rel.@"type")),
                    rel.offset,
                    rel.target.sym_index,
                    rel.target.file,
                });
            },
            .x86_64 => {
                log.debug("  RELA({s}) @ {x} => %{d} in object({?d})", .{
                    @tagName(@intToEnum(macho.reloc_type_x86_64, rel.@"type")),
                    rel.offset,
                    rel.target.sym_index,
                    rel.target.file,
                });
            },
            else => unreachable,
        }

        const source_addr = blk: {
            const source_sym = self.getSymbol(macho_file);
            break :blk source_sym.n_value + rel.offset;
        };
        const is_tlv = is_tlv: {
            const source_sym = self.getSymbol(macho_file);
            const header = macho_file.sections.items(.header)[source_sym.n_sect - 1];
            break :is_tlv header.@"type"() == macho.S_THREAD_LOCAL_VARIABLES;
        };
        const target_addr = blk: {
            const target_atom = rel.getTargetAtom(macho_file) orelse {
                // If there is no atom for target, we still need to check for special, atom-less
                // symbols such as `___dso_handle`.
                const target_name = macho_file.getSymbolName(rel.target);
                assert(macho_file.getGlobal(target_name) != null);
                const atomless_sym = macho_file.getSymbol(rel.target);
                log.debug("    | atomless target '{s}'", .{target_name});
                break :blk atomless_sym.n_value;
            };
            log.debug("    | target ATOM(%{d}, '{s}') in object({?d})", .{
                target_atom.sym_index,
                target_atom.getName(macho_file),
                target_atom.file,
            });
            // If `rel.target` is contained within the target atom, pull its address value.
            const target_sym = if (target_atom.isSymbolContained(rel.target, macho_file))
                macho_file.getSymbol(rel.target)
            else
                target_atom.getSymbol(macho_file);
            assert(target_sym.n_desc != MachO.N_DESC_GCED);
            const base_address: u64 = if (is_tlv) base_address: {
                // For TLV relocations, the value specified as a relocation is the displacement from the
                // TLV initializer (either value in __thread_data or zero-init in __thread_bss) to the first
                // defined TLV template init section in the following order:
                // * wrt to __thread_data if defined, then
                // * wrt to __thread_bss
                const sect_id: u16 = sect_id: {
                    if (macho_file.getSectionByName("__DATA", "__thread_data")) |i| {
                        break :sect_id i;
                    } else if (macho_file.getSectionByName("__DATA", "__thread_bss")) |i| {
                        break :sect_id i;
                    } else {
                        log.err("threadlocal variables present but no initializer sections found", .{});
                        log.err("  __thread_data not found", .{});
                        log.err("  __thread_bss not found", .{});
                        return error.FailedToResolveRelocationTarget;
                    }
                };
                break :base_address macho_file.sections.items(.header)[sect_id].addr;
            } else 0;
            break :blk target_sym.n_value - base_address;
        };

        log.debug("    | source_addr = 0x{x}", .{source_addr});

        switch (arch) {
            .aarch64 => {
                switch (@intToEnum(macho.reloc_type_arm64, rel.@"type")) {
                    .ARM64_RELOC_BRANCH26 => {
                        log.debug("    | target_addr = 0x{x}", .{target_addr});
                        const displacement = math.cast(
                            i28,
                            @intCast(i64, target_addr) - @intCast(i64, source_addr),
                        ) orelse {
                            log.err("jump too big to encode as i28 displacement value", .{});
                            log.err("  (target - source) = displacement => 0x{x} - 0x{x} = 0x{x}", .{
                                target_addr,
                                source_addr,
                                @intCast(i64, target_addr) - @intCast(i64, source_addr),
                            });
                            log.err("  TODO implement branch islands to extend jump distance for arm64", .{});
                            return error.TODOImplementBranchIslands;
                        };
                        const code = self.code.items[rel.offset..][0..4];
                        var inst = aarch64.Instruction{
                            .unconditional_branch_immediate = mem.bytesToValue(meta.TagPayload(
                                aarch64.Instruction,
                                aarch64.Instruction.unconditional_branch_immediate,
                            ), code),
                        };
                        inst.unconditional_branch_immediate.imm26 = @truncate(u26, @bitCast(u28, displacement >> 2));
                        mem.writeIntLittle(u32, code, inst.toU32());
                    },
                    .ARM64_RELOC_PAGE21,
                    .ARM64_RELOC_GOT_LOAD_PAGE21,
                    .ARM64_RELOC_TLVP_LOAD_PAGE21,
                    => {
                        const actual_target_addr = @intCast(i64, target_addr) + rel.addend;
                        log.debug("    | target_addr = 0x{x}", .{actual_target_addr});
                        const source_page = @intCast(i32, source_addr >> 12);
                        const target_page = @intCast(i32, actual_target_addr >> 12);
                        const pages = @bitCast(u21, @intCast(i21, target_page - source_page));
                        const code = self.code.items[rel.offset..][0..4];
                        var inst = aarch64.Instruction{
                            .pc_relative_address = mem.bytesToValue(meta.TagPayload(
                                aarch64.Instruction,
                                aarch64.Instruction.pc_relative_address,
                            ), code),
                        };
                        inst.pc_relative_address.immhi = @truncate(u19, pages >> 2);
                        inst.pc_relative_address.immlo = @truncate(u2, pages);
                        mem.writeIntLittle(u32, code, inst.toU32());
                    },
                    .ARM64_RELOC_PAGEOFF12 => {
                        const code = self.code.items[rel.offset..][0..4];
                        const actual_target_addr = @intCast(i64, target_addr) + rel.addend;
                        log.debug("    | target_addr = 0x{x}", .{actual_target_addr});
                        const narrowed = @truncate(u12, @intCast(u64, actual_target_addr));
                        if (isArithmeticOp(self.code.items[rel.offset..][0..4])) {
                            var inst = aarch64.Instruction{
                                .add_subtract_immediate = mem.bytesToValue(meta.TagPayload(
                                    aarch64.Instruction,
                                    aarch64.Instruction.add_subtract_immediate,
                                ), code),
                            };
                            inst.add_subtract_immediate.imm12 = narrowed;
                            mem.writeIntLittle(u32, code, inst.toU32());
                        } else {
                            var inst = aarch64.Instruction{
                                .load_store_register = mem.bytesToValue(meta.TagPayload(
                                    aarch64.Instruction,
                                    aarch64.Instruction.load_store_register,
                                ), code),
                            };
                            const offset: u12 = blk: {
                                if (inst.load_store_register.size == 0) {
                                    if (inst.load_store_register.v == 1) {
                                        // 128-bit SIMD is scaled by 16.
                                        break :blk try math.divExact(u12, narrowed, 16);
                                    }
                                    // Otherwise, 8-bit SIMD or ldrb.
                                    break :blk narrowed;
                                } else {
                                    const denom: u4 = try math.powi(u4, 2, inst.load_store_register.size);
                                    break :blk try math.divExact(u12, narrowed, denom);
                                }
                            };
                            inst.load_store_register.offset = offset;
                            mem.writeIntLittle(u32, code, inst.toU32());
                        }
                    },
                    .ARM64_RELOC_GOT_LOAD_PAGEOFF12 => {
                        const code = self.code.items[rel.offset..][0..4];
                        const actual_target_addr = @intCast(i64, target_addr) + rel.addend;
                        log.debug("    | target_addr = 0x{x}", .{actual_target_addr});
                        const narrowed = @truncate(u12, @intCast(u64, actual_target_addr));
                        var inst: aarch64.Instruction = .{
                            .load_store_register = mem.bytesToValue(meta.TagPayload(
                                aarch64.Instruction,
                                aarch64.Instruction.load_store_register,
                            ), code),
                        };
                        const offset = try math.divExact(u12, narrowed, 8);
                        inst.load_store_register.offset = offset;
                        mem.writeIntLittle(u32, code, inst.toU32());
                    },
                    .ARM64_RELOC_TLVP_LOAD_PAGEOFF12 => {
                        const code = self.code.items[rel.offset..][0..4];
                        const actual_target_addr = @intCast(i64, target_addr) + rel.addend;
                        log.debug("    | target_addr = 0x{x}", .{actual_target_addr});

                        const RegInfo = struct {
                            rd: u5,
                            rn: u5,
                            size: u2,
                        };
                        const reg_info: RegInfo = blk: {
                            if (isArithmeticOp(code)) {
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
                        const narrowed = @truncate(u12, @intCast(u64, actual_target_addr));
                        var inst = if (macho_file.tlv_ptr_entries_table.contains(rel.target)) blk: {
                            const offset = try math.divExact(u12, narrowed, 8);
                            break :blk aarch64.Instruction{
                                .load_store_register = .{
                                    .rt = reg_info.rd,
                                    .rn = reg_info.rn,
                                    .offset = offset,
                                    .opc = 0b01,
                                    .op1 = 0b01,
                                    .v = 0,
                                    .size = reg_info.size,
                                },
                            };
                        } else aarch64.Instruction{
                            .add_subtract_immediate = .{
                                .rd = reg_info.rd,
                                .rn = reg_info.rn,
                                .imm12 = narrowed,
                                .sh = 0,
                                .s = 0,
                                .op = 0,
                                .sf = @truncate(u1, reg_info.size),
                            },
                        };
                        mem.writeIntLittle(u32, code, inst.toU32());
                    },
                    .ARM64_RELOC_POINTER_TO_GOT => {
                        log.debug("    | target_addr = 0x{x}", .{target_addr});
                        const result = math.cast(i32, @intCast(i64, target_addr) - @intCast(i64, source_addr)) orelse return error.Overflow;
                        mem.writeIntLittle(u32, self.code.items[rel.offset..][0..4], @bitCast(u32, result));
                    },
                    .ARM64_RELOC_UNSIGNED => {
                        const result = blk: {
                            if (rel.subtractor) |subtractor| {
                                const sym = macho_file.getSymbol(subtractor);
                                break :blk @intCast(i64, target_addr) - @intCast(i64, sym.n_value) + rel.addend;
                            } else {
                                break :blk @intCast(i64, target_addr) + rel.addend;
                            }
                        };
                        log.debug("    | target_addr = 0x{x}", .{result});

                        if (rel.length == 3) {
                            mem.writeIntLittle(u64, self.code.items[rel.offset..][0..8], @bitCast(u64, result));
                        } else {
                            mem.writeIntLittle(
                                u32,
                                self.code.items[rel.offset..][0..4],
                                @truncate(u32, @bitCast(u64, result)),
                            );
                        }
                    },
                    .ARM64_RELOC_SUBTRACTOR => unreachable,
                    .ARM64_RELOC_ADDEND => unreachable,
                }
            },
            .x86_64 => {
                switch (@intToEnum(macho.reloc_type_x86_64, rel.@"type")) {
                    .X86_64_RELOC_BRANCH => {
                        log.debug("    | target_addr = 0x{x}", .{target_addr});
                        const displacement = math.cast(
                            i32,
                            @intCast(i64, target_addr) - @intCast(i64, source_addr) - 4 + rel.addend,
                        ) orelse return error.Overflow;
                        mem.writeIntLittle(u32, self.code.items[rel.offset..][0..4], @bitCast(u32, displacement));
                    },
                    .X86_64_RELOC_GOT, .X86_64_RELOC_GOT_LOAD => {
                        log.debug("    | target_addr = 0x{x}", .{target_addr});
                        const displacement = math.cast(
                            i32,
                            @intCast(i64, target_addr) - @intCast(i64, source_addr) - 4 + rel.addend,
                        ) orelse return error.Overflow;
                        mem.writeIntLittle(u32, self.code.items[rel.offset..][0..4], @bitCast(u32, displacement));
                    },
                    .X86_64_RELOC_TLV => {
                        log.debug("    | target_addr = 0x{x}", .{target_addr});
                        if (!macho_file.tlv_ptr_entries_table.contains(rel.target)) {
                            // We need to rewrite the opcode from movq to leaq.
                            self.code.items[rel.offset - 2] = 0x8d;
                        }
                        const displacement = math.cast(
                            i32,
                            @intCast(i64, target_addr) - @intCast(i64, source_addr) - 4 + rel.addend,
                        ) orelse return error.Overflow;
                        mem.writeIntLittle(u32, self.code.items[rel.offset..][0..4], @bitCast(u32, displacement));
                    },
                    .X86_64_RELOC_SIGNED,
                    .X86_64_RELOC_SIGNED_1,
                    .X86_64_RELOC_SIGNED_2,
                    .X86_64_RELOC_SIGNED_4,
                    => {
                        const correction: u3 = switch (@intToEnum(macho.reloc_type_x86_64, rel.@"type")) {
                            .X86_64_RELOC_SIGNED => 0,
                            .X86_64_RELOC_SIGNED_1 => 1,
                            .X86_64_RELOC_SIGNED_2 => 2,
                            .X86_64_RELOC_SIGNED_4 => 4,
                            else => unreachable,
                        };
                        const actual_target_addr = @intCast(i64, target_addr) + rel.addend;
                        log.debug("    | target_addr = 0x{x}", .{actual_target_addr});
                        const displacement = math.cast(
                            i32,
                            actual_target_addr - @intCast(i64, source_addr + correction + 4),
                        ) orelse return error.Overflow;
                        mem.writeIntLittle(u32, self.code.items[rel.offset..][0..4], @bitCast(u32, displacement));
                    },
                    .X86_64_RELOC_UNSIGNED => {
                        const result = blk: {
                            if (rel.subtractor) |subtractor| {
                                const sym = macho_file.getSymbol(subtractor);
                                break :blk @intCast(i64, target_addr) - @intCast(i64, sym.n_value) + rel.addend;
                            } else {
                                break :blk @intCast(i64, target_addr) + rel.addend;
                            }
                        };
                        log.debug("    | target_addr = 0x{x}", .{result});

                        if (rel.length == 3) {
                            mem.writeIntLittle(u64, self.code.items[rel.offset..][0..8], @bitCast(u64, result));
                        } else {
                            mem.writeIntLittle(
                                u32,
                                self.code.items[rel.offset..][0..4],
                                @truncate(u32, @bitCast(u64, result)),
                            );
                        }
                    },
                    .X86_64_RELOC_SUBTRACTOR => unreachable,
                }
            },
            else => unreachable,
        }
    }
}

inline fn isArithmeticOp(inst: *const [4]u8) bool {
    const group_decode = @truncate(u5, inst[3]);
    return ((group_decode >> 2) == 4);
}

pub fn addRelocation(self: *Atom, macho_file: *MachO, reloc: RelocationIncr) !void {
    const gpa = macho_file.base.allocator;
    log.debug("  (adding reloc of type {s} to target %{d})", .{ @tagName(reloc.@"type"), reloc.target.sym_index });
    const gop = try macho_file.relocs.getOrPut(gpa, self);
    if (!gop.found_existing) {
        gop.value_ptr.* = .{};
    }
    try gop.value_ptr.append(gpa, reloc);
}

pub fn resolveRelocationsInCodeBuffer(self: *Atom, macho_file: *MachO, code: []u8) !void {
    const relocs = macho_file.relocs.get(self) orelse return;

    log.debug("relocating '{s}'", .{self.getName(macho_file)});

    for (relocs.items) |*reloc| {
        // We don't check for dirty relocation as we resolve in memory so it's effectively free.
        try reloc.resolve(self, macho_file, code);
        reloc.dirty = false;
    }
}

pub fn resolveRelocationsInFile(self: *Atom, macho_file: *MachO) !void {
    const relocs = macho_file.relocs.get(self) orelse return;
    const gpa = macho_file.base.allocator;

    // No code available in a buffer; we need to read it in from the binary.
    const source_sym = self.getSymbol(macho_file);
    const source_section = macho_file.sections.get(source_sym.n_sect - 1).header;
    const file_offset = source_section.offset + source_sym.value - source_section.addr;
    const code = try gpa.alloc(u8, self.size);
    try self.base.file.?.preadAll(code, file_offset);
    defer gpa.free(code);

    log.debug("relocating '{s}'", .{self.getName(macho_file)});

    for (relocs.items) |*reloc| {
        if (!reloc.dirty) continue;
        try reloc.resolve(self, macho_file, code);
        reloc.dirty = false;
    }

    try self.base.file.?.pwriteAll(code, file_offset);
}
