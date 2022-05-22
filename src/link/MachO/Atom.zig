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
const StringIndexAdapter = std.hash_map.StringIndexAdapter;

/// Each decl always gets a local symbol with the fully qualified name.
/// The vaddr and size are found here directly.
/// The file offset is found by computing the vaddr offset from the section vaddr
/// the symbol references, and adding that to the file offset of the section.
/// If this field is 0, it means the codegen size = 0 and there is no symbol or
/// offset table entry.
local_sym_index: u32,

/// List of symbol aliases pointing to the same atom via different nlists
aliases: std.ArrayListUnmanaged(u32) = .{},

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
/// loader in presence of ASLR.
rebases: std.ArrayListUnmanaged(u64) = .{},

/// List of offsets contained within this atom that will be dynamically bound
/// by the dynamic loader and contain pointers to resolved (at load time) extern
/// symbols (aka proxies aka imports)
bindings: std.ArrayListUnmanaged(Binding) = .{},

/// List of lazy bindings
lazy_bindings: std.ArrayListUnmanaged(Binding) = .{},

/// List of data-in-code entries. This is currently specific to x86_64 only.
dices: std.ArrayListUnmanaged(macho.data_in_code_entry) = .{},

/// Stab entry for this atom. This is currently specific to a binary created
/// by linking object files in a traditional sense - in incremental sense, we
/// bypass stabs altogether to produce dSYM bundle directly with fully relocated
/// DWARF sections.
stab: ?Stab = null,

/// Points to the previous and next neighbours
next: ?*Atom,
prev: ?*Atom,

dbg_info_atom: Dwarf.Atom,

dirty: bool = true,

pub const Binding = struct {
    n_strx: u32,
    offset: u64,
};

pub const SymbolAtOffset = struct {
    local_sym_index: u32,
    offset: u64,
    stab: ?Stab = null,
};

pub const Stab = union(enum) {
    function: u64,
    static,
    global,

    pub fn asNlists(stab: Stab, local_sym_index: u32, macho_file: anytype) ![]macho.nlist_64 {
        var nlists = std.ArrayList(macho.nlist_64).init(macho_file.base.allocator);
        defer nlists.deinit();

        const sym = macho_file.locals.items[local_sym_index];
        switch (stab) {
            .function => |size| {
                try nlists.ensureUnusedCapacity(4);
                nlists.appendAssumeCapacity(.{
                    .n_strx = 0,
                    .n_type = macho.N_BNSYM,
                    .n_sect = sym.n_sect,
                    .n_desc = 0,
                    .n_value = sym.n_value,
                });
                nlists.appendAssumeCapacity(.{
                    .n_strx = sym.n_strx,
                    .n_type = macho.N_FUN,
                    .n_sect = sym.n_sect,
                    .n_desc = 0,
                    .n_value = sym.n_value,
                });
                nlists.appendAssumeCapacity(.{
                    .n_strx = 0,
                    .n_type = macho.N_FUN,
                    .n_sect = 0,
                    .n_desc = 0,
                    .n_value = size,
                });
                nlists.appendAssumeCapacity(.{
                    .n_strx = 0,
                    .n_type = macho.N_ENSYM,
                    .n_sect = sym.n_sect,
                    .n_desc = 0,
                    .n_value = size,
                });
            },
            .global => {
                try nlists.append(.{
                    .n_strx = sym.n_strx,
                    .n_type = macho.N_GSYM,
                    .n_sect = 0,
                    .n_desc = 0,
                    .n_value = 0,
                });
            },
            .static => {
                try nlists.append(.{
                    .n_strx = sym.n_strx,
                    .n_type = macho.N_STSYM,
                    .n_sect = sym.n_sect,
                    .n_desc = 0,
                    .n_value = sym.n_value,
                });
            },
        }

        return nlists.toOwnedSlice();
    }
};

pub const Relocation = struct {
    pub const Target = union(enum) {
        local: u32,
        global: u32,
    };

    /// Offset within the atom's code buffer.
    /// Note relocation size can be inferred by relocation's kind.
    offset: u32,

    target: Target,

    addend: i64,

    subtractor: ?u32,

    pcrel: bool,

    length: u2,

    @"type": u4,
};

pub const empty = Atom{
    .local_sym_index = 0,
    .size = 0,
    .alignment = 0,
    .prev = null,
    .next = null,
    .dbg_info_atom = undefined,
};

pub fn deinit(self: *Atom, allocator: Allocator) void {
    self.dices.deinit(allocator);
    self.lazy_bindings.deinit(allocator);
    self.bindings.deinit(allocator);
    self.rebases.deinit(allocator);
    self.relocs.deinit(allocator);
    self.contained.deinit(allocator);
    self.aliases.deinit(allocator);
    self.code.deinit(allocator);
}

pub fn clearRetainingCapacity(self: *Atom) void {
    self.dices.clearRetainingCapacity();
    self.lazy_bindings.clearRetainingCapacity();
    self.bindings.clearRetainingCapacity();
    self.rebases.clearRetainingCapacity();
    self.relocs.clearRetainingCapacity();
    self.contained.clearRetainingCapacity();
    self.aliases.clearRetainingCapacity();
    self.code.clearRetainingCapacity();
}

/// Returns how much room there is to grow in virtual address space.
/// File offset relocation happens transparently, so it is not included in
/// this calculation.
pub fn capacity(self: Atom, macho_file: MachO) u64 {
    const self_sym = macho_file.locals.items[self.local_sym_index];
    if (self.next) |next| {
        const next_sym = macho_file.locals.items[next.local_sym_index];
        return next_sym.n_value - self_sym.n_value;
    } else {
        // We are the last atom.
        // The capacity is limited only by virtual address space.
        return std.math.maxInt(u64) - self_sym.n_value;
    }
}

pub fn freeListEligible(self: Atom, macho_file: MachO) bool {
    // No need to keep a free list node for the last atom.
    const next = self.next orelse return false;
    const self_sym = macho_file.locals.items[self.local_sym_index];
    const next_sym = macho_file.locals.items[next.local_sym_index];
    const cap = next_sym.n_value - self_sym.n_value;
    const ideal_cap = MachO.padToIdeal(self.size);
    if (cap <= ideal_cap) return false;
    const surplus = cap - ideal_cap;
    return surplus >= MachO.min_text_capacity;
}

const RelocContext = struct {
    base_addr: u64 = 0,
    allocator: Allocator,
    object: *Object,
    macho_file: *MachO,
};

pub fn parseRelocs(self: *Atom, relocs: []macho.relocation_info, context: RelocContext) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const arch = context.macho_file.base.options.target.cpu.arch;
    var addend: i64 = 0;
    var subtractor: ?u32 = null;

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
                                log.err("  found {s}", .{next});
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
            const sym = context.object.symtab.items[rel.r_symbolnum];
            if (sym.sect() and !sym.ext()) {
                subtractor = context.object.symbol_mapping.get(rel.r_symbolnum).?;
            } else {
                const sym_name = context.object.getString(sym.n_strx);
                const n_strx = context.macho_file.strtab_dir.getKeyAdapted(
                    @as([]const u8, sym_name),
                    StringIndexAdapter{
                        .bytes = &context.macho_file.strtab,
                    },
                ).?;
                const resolv = context.macho_file.symbol_resolver.get(n_strx).?;
                assert(resolv.where == .global);
                subtractor = resolv.local_sym_index;
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
                        log.err("  found {s}", .{@intToEnum(macho.reloc_type_arm64, relocs[i + 1].r_type)});
                        return error.UnexpectedRelocationType;
                    },
                },
                .x86_64 => switch (@intToEnum(macho.reloc_type_x86_64, relocs[i + 1].r_type)) {
                    .X86_64_RELOC_UNSIGNED => {},
                    else => {
                        log.err("unexpected relocation type after X86_64_RELOC_ADDEND", .{});
                        log.err("  expected X86_64_RELOC_UNSIGNED", .{});
                        log.err("  found {s}", .{@intToEnum(macho.reloc_type_x86_64, relocs[i + 1].r_type)});
                        return error.UnexpectedRelocationType;
                    },
                },
                else => unreachable,
            }
            continue;
        }

        const target = target: {
            if (rel.r_extern == 0) {
                const sect_id = @intCast(u16, rel.r_symbolnum - 1);
                const local_sym_index = context.object.sections_as_symbols.get(sect_id) orelse blk: {
                    const seg = context.object.load_commands.items[context.object.segment_cmd_index.?].segment;
                    const sect = seg.sections.items[sect_id];
                    const match = (try context.macho_file.getMatchingSection(sect)) orelse
                        unreachable;
                    const local_sym_index = @intCast(u32, context.macho_file.locals.items.len);
                    try context.macho_file.locals.append(context.allocator, .{
                        .n_strx = 0,
                        .n_type = macho.N_SECT,
                        .n_sect = @intCast(u8, context.macho_file.section_ordinals.getIndex(match).? + 1),
                        .n_desc = 0,
                        .n_value = 0,
                    });
                    try context.object.sections_as_symbols.putNoClobber(context.allocator, sect_id, local_sym_index);
                    break :blk local_sym_index;
                };
                break :target Relocation.Target{ .local = local_sym_index };
            }

            const sym = context.object.symtab.items[rel.r_symbolnum];
            const sym_name = context.object.getString(sym.n_strx);

            if (sym.sect() and !sym.ext()) {
                const sym_index = context.object.symbol_mapping.get(rel.r_symbolnum) orelse unreachable;
                break :target Relocation.Target{ .local = sym_index };
            }

            const n_strx = context.macho_file.strtab_dir.getKeyAdapted(
                @as([]const u8, sym_name),
                StringIndexAdapter{
                    .bytes = &context.macho_file.strtab,
                },
            ) orelse unreachable;
            break :target Relocation.Target{ .global = n_strx };
        };
        const offset = @intCast(u32, rel.r_address);

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
                            const seg = context.object.load_commands.items[context.object.segment_cmd_index.?].segment;
                            const target_sect_base_addr = seg.sections.items[rel.r_symbolnum - 1].addr;
                            addend -= @intCast(i64, target_sect_base_addr);
                        }
                        try self.addPtrBindingOrRebase(rel, target, context);
                    },
                    .ARM64_RELOC_TLVP_LOAD_PAGE21,
                    .ARM64_RELOC_TLVP_LOAD_PAGEOFF12,
                    => {
                        if (target == .global) {
                            try addTlvPtrEntry(target, context);
                        }
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
                            const seg = context.object.load_commands.items[context.object.segment_cmd_index.?].segment;
                            const target_sect_base_addr = seg.sections.items[rel.r_symbolnum - 1].addr;
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
                            const seg = context.object.load_commands.items[context.object.segment_cmd_index.?].segment;
                            const target_sect_base_addr = seg.sections.items[rel.r_symbolnum - 1].addr;
                            addend += @intCast(i64, context.base_addr + offset + 4) -
                                @intCast(i64, target_sect_base_addr);
                        }
                    },
                    .X86_64_RELOC_TLV => {
                        if (target == .global) {
                            try addTlvPtrEntry(target, context);
                        }
                    },
                    else => {},
                }
            },
            else => unreachable,
        }

        try self.relocs.append(context.allocator, .{
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
    target: Relocation.Target,
    context: RelocContext,
) !void {
    switch (target) {
        .global => |n_strx| {
            try self.bindings.append(context.allocator, .{
                .n_strx = n_strx,
                .offset = @intCast(u32, rel.r_address),
            });
        },
        .local => {
            const source_sym = context.macho_file.locals.items[self.local_sym_index];
            const match = context.macho_file.section_ordinals.keys()[source_sym.n_sect - 1];
            const seg = context.macho_file.load_commands.items[match.seg].segment;
            const sect = seg.sections.items[match.sect];
            const sect_type = sect.type_();

            const should_rebase = rebase: {
                if (rel.r_length != 3) break :rebase false;

                // TODO actually, a check similar to what dyld is doing, that is, verifying
                // that the segment is writable should be enough here.
                const is_right_segment = blk: {
                    if (context.macho_file.data_segment_cmd_index) |idx| {
                        if (match.seg == idx) {
                            break :blk true;
                        }
                    }
                    if (context.macho_file.data_const_segment_cmd_index) |idx| {
                        if (match.seg == idx) {
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
                try self.rebases.append(context.allocator, @intCast(u32, rel.r_address));
            }
        },
    }
}

fn addTlvPtrEntry(target: Relocation.Target, context: RelocContext) !void {
    if (context.macho_file.tlv_ptr_entries_table.contains(target)) return;

    const index = try context.macho_file.allocateTlvPtrEntry(target);
    const atom = try context.macho_file.createTlvPtrAtom(target);
    context.macho_file.tlv_ptr_entries.items[index].atom = atom;

    const match = (try context.macho_file.getMatchingSection(.{
        .segname = MachO.makeStaticString("__DATA"),
        .sectname = MachO.makeStaticString("__thread_ptrs"),
        .flags = macho.S_THREAD_LOCAL_VARIABLE_POINTERS,
    })).?;
    if (!context.object.start_atoms.contains(match)) {
        try context.object.start_atoms.putNoClobber(context.allocator, match, atom);
    }
    if (context.object.end_atoms.getPtr(match)) |last| {
        last.*.next = atom;
        atom.prev = last.*;
        last.* = atom;
    } else {
        try context.object.end_atoms.putNoClobber(context.allocator, match, atom);
    }
}

fn addGotEntry(target: Relocation.Target, context: RelocContext) !void {
    if (context.macho_file.got_entries_table.contains(target)) return;

    const index = try context.macho_file.allocateGotEntry(target);
    const atom = try context.macho_file.createGotAtom(target);
    context.macho_file.got_entries.items[index].atom = atom;

    const match = MachO.MatchingSection{
        .seg = context.macho_file.data_const_segment_cmd_index.?,
        .sect = context.macho_file.got_section_index.?,
    };
    if (!context.object.start_atoms.contains(match)) {
        try context.object.start_atoms.putNoClobber(context.allocator, match, atom);
    }
    if (context.object.end_atoms.getPtr(match)) |last| {
        last.*.next = atom;
        atom.prev = last.*;
        last.* = atom;
    } else {
        try context.object.end_atoms.putNoClobber(context.allocator, match, atom);
    }
}

fn addStub(target: Relocation.Target, context: RelocContext) !void {
    if (target != .global) return;
    if (context.macho_file.stubs_table.contains(target.global)) return;
    // If the symbol has been resolved as defined globally elsewhere (in a different translation unit),
    // then skip creating stub entry.
    // TODO Is this the correct for the incremental?
    if (context.macho_file.symbol_resolver.get(target.global).?.where == .global) return;

    const stub_index = try context.macho_file.allocateStubEntry(target.global);

    // TODO clean this up!
    const stub_helper_atom = atom: {
        const atom = try context.macho_file.createStubHelperAtom();
        const match = MachO.MatchingSection{
            .seg = context.macho_file.text_segment_cmd_index.?,
            .sect = context.macho_file.stub_helper_section_index.?,
        };
        if (!context.object.start_atoms.contains(match)) {
            try context.object.start_atoms.putNoClobber(context.allocator, match, atom);
        }
        if (context.object.end_atoms.getPtr(match)) |last| {
            last.*.next = atom;
            atom.prev = last.*;
            last.* = atom;
        } else {
            try context.object.end_atoms.putNoClobber(context.allocator, match, atom);
        }
        break :atom atom;
    };
    const laptr_atom = atom: {
        const atom = try context.macho_file.createLazyPointerAtom(
            stub_helper_atom.local_sym_index,
            target.global,
        );
        const match = MachO.MatchingSection{
            .seg = context.macho_file.data_segment_cmd_index.?,
            .sect = context.macho_file.la_symbol_ptr_section_index.?,
        };
        if (!context.object.start_atoms.contains(match)) {
            try context.object.start_atoms.putNoClobber(context.allocator, match, atom);
        }
        if (context.object.end_atoms.getPtr(match)) |last| {
            last.*.next = atom;
            atom.prev = last.*;
            last.* = atom;
        } else {
            try context.object.end_atoms.putNoClobber(context.allocator, match, atom);
        }
        break :atom atom;
    };
    const atom = try context.macho_file.createStubAtom(laptr_atom.local_sym_index);
    const match = MachO.MatchingSection{
        .seg = context.macho_file.text_segment_cmd_index.?,
        .sect = context.macho_file.stubs_section_index.?,
    };
    if (!context.object.start_atoms.contains(match)) {
        try context.object.start_atoms.putNoClobber(context.allocator, match, atom);
    }
    if (context.object.end_atoms.getPtr(match)) |last| {
        last.*.next = atom;
        atom.prev = last.*;
        last.* = atom;
    } else {
        try context.object.end_atoms.putNoClobber(context.allocator, match, atom);
    }
    context.macho_file.stubs.items[stub_index] = atom;
}

pub fn resolveRelocs(self: *Atom, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    for (self.relocs.items) |rel| {
        log.debug("relocating {}", .{rel});
        const arch = macho_file.base.options.target.cpu.arch;
        const source_addr = blk: {
            const sym = macho_file.locals.items[self.local_sym_index];
            break :blk sym.n_value + rel.offset;
        };
        var is_via_thread_ptrs: bool = false;
        const target_addr = blk: {
            const is_via_got = got: {
                switch (arch) {
                    .aarch64 => break :got switch (@intToEnum(macho.reloc_type_arm64, rel.@"type")) {
                        .ARM64_RELOC_GOT_LOAD_PAGE21,
                        .ARM64_RELOC_GOT_LOAD_PAGEOFF12,
                        .ARM64_RELOC_POINTER_TO_GOT,
                        => true,
                        else => false,
                    },
                    .x86_64 => break :got switch (@intToEnum(macho.reloc_type_x86_64, rel.@"type")) {
                        .X86_64_RELOC_GOT, .X86_64_RELOC_GOT_LOAD => true,
                        else => false,
                    },
                    else => unreachable,
                }
            };

            if (is_via_got) {
                const got_index = macho_file.got_entries_table.get(rel.target) orelse {
                    log.err("expected GOT entry for symbol", .{});
                    switch (rel.target) {
                        .local => |sym_index| log.err("  local @{d}", .{sym_index}),
                        .global => |n_strx| log.err("  global @'{s}'", .{macho_file.getString(n_strx)}),
                    }
                    log.err("  this is an internal linker error", .{});
                    return error.FailedToResolveRelocationTarget;
                };
                const atom = macho_file.got_entries.items[got_index].atom;
                break :blk macho_file.locals.items[atom.local_sym_index].n_value;
            }

            switch (rel.target) {
                .local => |sym_index| {
                    const sym = macho_file.locals.items[sym_index];
                    const is_tlv = is_tlv: {
                        const source_sym = macho_file.locals.items[self.local_sym_index];
                        const match = macho_file.section_ordinals.keys()[source_sym.n_sect - 1];
                        const seg = macho_file.load_commands.items[match.seg].segment;
                        const sect = seg.sections.items[match.sect];
                        break :is_tlv sect.type_() == macho.S_THREAD_LOCAL_VARIABLES;
                    };
                    if (is_tlv) {
                        // For TLV relocations, the value specified as a relocation is the displacement from the
                        // TLV initializer (either value in __thread_data or zero-init in __thread_bss) to the first
                        // defined TLV template init section in the following order:
                        // * wrt to __thread_data if defined, then
                        // * wrt to __thread_bss
                        const seg = macho_file.load_commands.items[macho_file.data_segment_cmd_index.?].segment;
                        const base_address = inner: {
                            if (macho_file.tlv_data_section_index) |i| {
                                break :inner seg.sections.items[i].addr;
                            } else if (macho_file.tlv_bss_section_index) |i| {
                                break :inner seg.sections.items[i].addr;
                            } else {
                                log.err("threadlocal variables present but no initializer sections found", .{});
                                log.err("  __thread_data not found", .{});
                                log.err("  __thread_bss not found", .{});
                                return error.FailedToResolveRelocationTarget;
                            }
                        };
                        break :blk sym.n_value - base_address;
                    }
                    break :blk sym.n_value;
                },
                .global => |n_strx| {
                    // TODO Still trying to figure out how to possibly use stubs for local symbol indirection with
                    // branching instructions. If it is not possible, then the best course of action is to
                    // resurrect the former approach of defering creating synthethic atoms in __got and __la_symbol_ptr
                    // sections until we resolve the relocations.
                    const resolv = macho_file.symbol_resolver.get(n_strx).?;
                    switch (resolv.where) {
                        .global => break :blk macho_file.globals.items[resolv.where_index].n_value,
                        .undef => {
                            if (macho_file.stubs_table.get(n_strx)) |stub_index| {
                                const atom = macho_file.stubs.items[stub_index];
                                break :blk macho_file.locals.items[atom.local_sym_index].n_value;
                            } else {
                                if (macho_file.tlv_ptr_entries_table.get(rel.target)) |tlv_ptr_index| {
                                    is_via_thread_ptrs = true;
                                    const atom = macho_file.tlv_ptr_entries.items[tlv_ptr_index].atom;
                                    break :blk macho_file.locals.items[atom.local_sym_index].n_value;
                                }
                                break :blk 0;
                            }
                        },
                    }
                },
            }
        };

        log.debug("  | source_addr = 0x{x}", .{source_addr});
        log.debug("  | target_addr = 0x{x}", .{target_addr});

        switch (arch) {
            .aarch64 => {
                switch (@intToEnum(macho.reloc_type_arm64, rel.@"type")) {
                    .ARM64_RELOC_BRANCH26 => {
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
                        var inst = if (is_via_thread_ptrs) blk: {
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
                        const result = math.cast(i32, @intCast(i64, target_addr) - @intCast(i64, source_addr)) orelse return error.Overflow;
                        mem.writeIntLittle(u32, self.code.items[rel.offset..][0..4], @bitCast(u32, result));
                    },
                    .ARM64_RELOC_UNSIGNED => {
                        const result = blk: {
                            if (rel.subtractor) |subtractor| {
                                const sym = macho_file.locals.items[subtractor];
                                break :blk @intCast(i64, target_addr) - @intCast(i64, sym.n_value) + rel.addend;
                            } else {
                                break :blk @intCast(i64, target_addr) + rel.addend;
                            }
                        };

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
                        const displacement = math.cast(
                            i32,
                            @intCast(i64, target_addr) - @intCast(i64, source_addr) - 4 + rel.addend,
                        ) orelse return error.Overflow;
                        mem.writeIntLittle(u32, self.code.items[rel.offset..][0..4], @bitCast(u32, displacement));
                    },
                    .X86_64_RELOC_GOT, .X86_64_RELOC_GOT_LOAD => {
                        const displacement = math.cast(
                            i32,
                            @intCast(i64, target_addr) - @intCast(i64, source_addr) - 4 + rel.addend,
                        ) orelse return error.Overflow;
                        mem.writeIntLittle(u32, self.code.items[rel.offset..][0..4], @bitCast(u32, displacement));
                    },
                    .X86_64_RELOC_TLV => {
                        if (!is_via_thread_ptrs) {
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
                        const displacement = math.cast(
                            i32,
                            actual_target_addr - @intCast(i64, source_addr + correction + 4),
                        ) orelse return error.Overflow;
                        mem.writeIntLittle(u32, self.code.items[rel.offset..][0..4], @bitCast(u32, displacement));
                    },
                    .X86_64_RELOC_UNSIGNED => {
                        const result = blk: {
                            if (rel.subtractor) |subtractor| {
                                const sym = macho_file.locals.items[subtractor];
                                break :blk @intCast(i64, target_addr) - @intCast(i64, sym.n_value) + rel.addend;
                            } else {
                                break :blk @intCast(i64, target_addr) + rel.addend;
                            }
                        };

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
