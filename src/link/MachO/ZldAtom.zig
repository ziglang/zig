//! An atom is a single smallest unit of measure that will get an
//! allocated virtual memory address in the final linked image.
//! For example, we parse each input section within an input relocatable
//! object file into a set of atoms which are then laid out contiguously
//! as they were defined in the input file.

const Atom = @This();

const std = @import("std");
const build_options = @import("build_options");
const aarch64 = @import("../../arch/aarch64/bits.zig");
const assert = std.debug.assert;
const log = std.log.scoped(.atom);
const macho = std.macho;
const math = std.math;
const mem = std.mem;
const meta = std.meta;
const trace = @import("../../tracy.zig").trace;

const Allocator = mem.Allocator;
const Arch = std.Target.Cpu.Arch;
const AtomIndex = @import("zld.zig").AtomIndex;
const Object = @import("Object.zig");
const SymbolWithLoc = @import("zld.zig").SymbolWithLoc;
const Zld = @import("zld.zig").Zld;

/// Each Atom always gets a symbol with the fully qualified name.
/// The symbol can reside in any object file context structure in `symtab` array
/// (see `Object`), or if the symbol is a synthetic symbol such as a GOT cell or
/// a stub trampoline, it can be found in the linkers `locals` arraylist.
sym_index: u32,

/// 0 means an Atom is a synthetic Atom such as a GOT cell defined by the linker.
/// Otherwise, it is the index into appropriate object file (indexing from 1).
/// Prefer using `getFile()` helper to get the file index out rather than using
/// the field directly.
file: u32,

/// If this Atom is not a synthetic Atom, i.e., references a subsection in an
/// Object file, `inner_sym_index` and `inner_nsyms_trailing` tell where and if
/// this Atom contains any additional symbol references that fall within this Atom's
/// address range. These could for example be an alias symbol which can be used
/// internally by the relocation records, or if the Object file couldn't be split
/// into subsections, this Atom may encompass an entire input section.
inner_sym_index: u32,
inner_nsyms_trailing: u32,

/// Size of this atom.
size: u64,

/// Alignment of this atom as a power of 2.
/// For instance, aligmment of 0 should be read as 2^0 = 1 byte aligned.
alignment: u32,

/// Points to the previous and next neighbours
next_index: ?AtomIndex,
prev_index: ?AtomIndex,

pub const empty = Atom{
    .sym_index = 0,
    .inner_sym_index = 0,
    .inner_nsyms_trailing = 0,
    .file = 0,
    .size = 0,
    .alignment = 0,
    .prev_index = null,
    .next_index = null,
};

/// Returns `null` if the Atom is a synthetic Atom.
/// Otherwise, returns an index into an array of Objects.
pub fn getFile(self: Atom) ?u32 {
    if (self.file == 0) return null;
    return self.file - 1;
}

pub inline fn getSymbolWithLoc(self: Atom) SymbolWithLoc {
    return .{
        .sym_index = self.sym_index,
        .file = self.file,
    };
}

const InnerSymIterator = struct {
    sym_index: u32,
    count: u32,
    file: u32,

    pub fn next(it: *@This()) ?SymbolWithLoc {
        if (it.count == 0) return null;
        const res = SymbolWithLoc{ .sym_index = it.sym_index, .file = it.file };
        it.sym_index += 1;
        it.count -= 1;
        return res;
    }
};

/// Returns an iterator over potentially contained symbols.
/// Panics when called on a synthetic Atom.
pub fn getInnerSymbolsIterator(zld: *Zld, atom_index: AtomIndex) InnerSymIterator {
    const atom = zld.getAtom(atom_index);
    assert(atom.getFile() != null);
    return .{
        .sym_index = atom.inner_sym_index,
        .count = atom.inner_nsyms_trailing,
        .file = atom.file,
    };
}

/// Returns a section alias symbol if one is defined.
/// An alias symbol is used to represent the start of an input section
/// if there were no symbols defined within that range.
/// Alias symbols are only used on x86_64.
pub fn getSectionAlias(zld: *Zld, atom_index: AtomIndex) ?SymbolWithLoc {
    const atom = zld.getAtom(atom_index);
    assert(atom.getFile() != null);

    const object = zld.objects.items[atom.getFile().?];
    const nbase = @intCast(u32, object.in_symtab.?.len);
    const ntotal = @intCast(u32, object.symtab.len);
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
pub fn calcInnerSymbolOffset(zld: *Zld, atom_index: AtomIndex, sym_index: u32) u64 {
    const atom = zld.getAtom(atom_index);
    assert(atom.getFile() != null);

    if (atom.sym_index == sym_index) return 0;

    const object = zld.objects.items[atom.getFile().?];
    const source_sym = object.getSourceSymbol(sym_index).?;
    const base_addr = if (object.getSourceSymbol(atom.sym_index)) |sym|
        sym.n_value
    else blk: {
        const nbase = @intCast(u32, object.in_symtab.?.len);
        const sect_id = @intCast(u8, atom.sym_index - nbase);
        const source_sect = object.getSourceSection(sect_id);
        break :blk source_sect.addr;
    };
    return source_sym.n_value - base_addr;
}

pub fn scanAtomRelocs(zld: *Zld, atom_index: AtomIndex, relocs: []align(1) const macho.relocation_info) !void {
    const arch = zld.options.target.cpu.arch;
    const atom = zld.getAtom(atom_index);
    assert(atom.getFile() != null); // synthetic atoms do not have relocs

    return switch (arch) {
        .aarch64 => scanAtomRelocsArm64(zld, atom_index, relocs),
        .x86_64 => scanAtomRelocsX86(zld, atom_index, relocs),
        else => unreachable,
    };
}

const RelocContext = struct {
    base_addr: i64 = 0,
    base_offset: i32 = 0,
};

pub fn getRelocContext(zld: *Zld, atom_index: AtomIndex) RelocContext {
    const atom = zld.getAtom(atom_index);
    assert(atom.getFile() != null); // synthetic atoms do not have relocs

    const object = zld.objects.items[atom.getFile().?];
    if (object.getSourceSymbol(atom.sym_index)) |source_sym| {
        const source_sect = object.getSourceSection(source_sym.n_sect - 1);
        return .{
            .base_addr = @intCast(i64, source_sect.addr),
            .base_offset = @intCast(i32, source_sym.n_value - source_sect.addr),
        };
    }
    const nbase = @intCast(u32, object.in_symtab.?.len);
    const sect_id = @intCast(u8, atom.sym_index - nbase);
    const source_sect = object.getSourceSection(sect_id);
    return .{
        .base_addr = @intCast(i64, source_sect.addr),
        .base_offset = 0,
    };
}

pub fn parseRelocTarget(zld: *Zld, ctx: struct {
    object_id: u32,
    rel: macho.relocation_info,
    code: []const u8,
    base_addr: i64 = 0,
    base_offset: i32 = 0,
}) SymbolWithLoc {
    const tracy = trace(@src());
    defer tracy.end();

    const object = &zld.objects.items[ctx.object_id];
    log.debug("parsing reloc target in object({d}) '{s}' ", .{ ctx.object_id, object.name });

    const sym_index = if (ctx.rel.r_extern == 0) sym_index: {
        const sect_id = @intCast(u8, ctx.rel.r_symbolnum - 1);
        const rel_offset = @intCast(u32, ctx.rel.r_address - ctx.base_offset);

        const address_in_section = if (ctx.rel.r_pcrel == 0) blk: {
            break :blk if (ctx.rel.r_length == 3)
                mem.readIntLittle(u64, ctx.code[rel_offset..][0..8])
            else
                mem.readIntLittle(u32, ctx.code[rel_offset..][0..4]);
        } else blk: {
            assert(zld.options.target.cpu.arch == .x86_64);
            const correction: u3 = switch (@intToEnum(macho.reloc_type_x86_64, ctx.rel.r_type)) {
                .X86_64_RELOC_SIGNED => 0,
                .X86_64_RELOC_SIGNED_1 => 1,
                .X86_64_RELOC_SIGNED_2 => 2,
                .X86_64_RELOC_SIGNED_4 => 4,
                else => unreachable,
            };
            const addend = mem.readIntLittle(i32, ctx.code[rel_offset..][0..4]);
            const target_address = @intCast(i64, ctx.base_addr) + ctx.rel.r_address + 4 + correction + addend;
            break :blk @intCast(u64, target_address);
        };

        // Find containing atom
        log.debug("  | locating symbol by address @{x} in section {d}", .{ address_in_section, sect_id });
        const candidate = object.getSymbolByAddress(address_in_section, sect_id);
        // Make sure we are not dealing with a local alias.
        const atom_index = object.getAtomIndexForSymbol(candidate) orelse break :sym_index candidate;
        const atom = zld.getAtom(atom_index);
        break :sym_index atom.sym_index;
    } else object.reverse_symtab_lookup[ctx.rel.r_symbolnum];

    const sym_loc = SymbolWithLoc{ .sym_index = sym_index, .file = ctx.object_id + 1 };
    const sym = zld.getSymbol(sym_loc);
    const target = if (sym.sect() and !sym.ext())
        sym_loc
    else if (object.getGlobal(sym_index)) |global_index|
        zld.globals.items[global_index]
    else
        sym_loc;
    log.debug("  | target %{d} ('{s}') in object({?d})", .{
        target.sym_index,
        zld.getSymbolName(target),
        target.getFile(),
    });
    return target;
}

pub fn getRelocTargetAtomIndex(zld: *Zld, target: SymbolWithLoc, is_via_got: bool) ?AtomIndex {
    if (is_via_got) {
        return zld.getGotAtomIndexForSymbol(target).?; // panic means fatal error
    }
    if (zld.getStubsAtomIndexForSymbol(target)) |stubs_atom| return stubs_atom;
    if (zld.getTlvPtrAtomIndexForSymbol(target)) |tlv_ptr_atom| return tlv_ptr_atom;

    if (target.getFile() == null) {
        const target_sym_name = zld.getSymbolName(target);
        if (mem.eql(u8, "__mh_execute_header", target_sym_name)) return null;
        if (mem.eql(u8, "___dso_handle", target_sym_name)) return null;

        unreachable; // referenced symbol not found
    }

    const object = zld.objects.items[target.getFile().?];
    return object.getAtomIndexForSymbol(target.sym_index);
}

fn scanAtomRelocsArm64(zld: *Zld, atom_index: AtomIndex, relocs: []align(1) const macho.relocation_info) !void {
    for (relocs) |rel| {
        const rel_type = @intToEnum(macho.reloc_type_arm64, rel.r_type);

        switch (rel_type) {
            .ARM64_RELOC_ADDEND, .ARM64_RELOC_SUBTRACTOR => continue,
            else => {},
        }

        if (rel.r_extern == 0) continue;

        const atom = zld.getAtom(atom_index);
        const object = &zld.objects.items[atom.getFile().?];
        const sym_index = object.reverse_symtab_lookup[rel.r_symbolnum];
        const sym_loc = SymbolWithLoc{
            .sym_index = sym_index,
            .file = atom.file,
        };
        const sym = zld.getSymbol(sym_loc);

        if (sym.sect() and !sym.ext()) continue;

        const target = if (object.getGlobal(sym_index)) |global_index|
            zld.globals.items[global_index]
        else
            sym_loc;

        switch (rel_type) {
            .ARM64_RELOC_BRANCH26 => {
                // TODO rewrite relocation
                try addStub(zld, target);
            },
            .ARM64_RELOC_GOT_LOAD_PAGE21,
            .ARM64_RELOC_GOT_LOAD_PAGEOFF12,
            .ARM64_RELOC_POINTER_TO_GOT,
            => {
                // TODO rewrite relocation
                try addGotEntry(zld, target);
            },
            .ARM64_RELOC_TLVP_LOAD_PAGE21,
            .ARM64_RELOC_TLVP_LOAD_PAGEOFF12,
            => {
                try addTlvPtrEntry(zld, target);
            },
            else => {},
        }
    }
}

fn scanAtomRelocsX86(zld: *Zld, atom_index: AtomIndex, relocs: []align(1) const macho.relocation_info) !void {
    for (relocs) |rel| {
        const rel_type = @intToEnum(macho.reloc_type_x86_64, rel.r_type);

        switch (rel_type) {
            .X86_64_RELOC_SUBTRACTOR => continue,
            else => {},
        }

        if (rel.r_extern == 0) continue;

        const atom = zld.getAtom(atom_index);
        const object = &zld.objects.items[atom.getFile().?];
        const sym_index = object.reverse_symtab_lookup[rel.r_symbolnum];
        const sym_loc = SymbolWithLoc{
            .sym_index = sym_index,
            .file = atom.file,
        };
        const sym = zld.getSymbol(sym_loc);

        if (sym.sect() and !sym.ext()) continue;

        const target = if (object.getGlobal(sym_index)) |global_index|
            zld.globals.items[global_index]
        else
            sym_loc;

        switch (rel_type) {
            .X86_64_RELOC_BRANCH => {
                // TODO rewrite relocation
                try addStub(zld, target);
            },
            .X86_64_RELOC_GOT, .X86_64_RELOC_GOT_LOAD => {
                // TODO rewrite relocation
                try addGotEntry(zld, target);
            },
            .X86_64_RELOC_TLV => {
                try addTlvPtrEntry(zld, target);
            },
            else => {},
        }
    }
}

fn addTlvPtrEntry(zld: *Zld, target: SymbolWithLoc) !void {
    const target_sym = zld.getSymbol(target);
    if (!target_sym.undf()) return;
    if (zld.tlv_ptr_table.contains(target)) return;

    const gpa = zld.gpa;
    const atom_index = try zld.createTlvPtrAtom();
    const tlv_ptr_index = @intCast(u32, zld.tlv_ptr_entries.items.len);
    try zld.tlv_ptr_entries.append(gpa, .{
        .target = target,
        .atom_index = atom_index,
    });
    try zld.tlv_ptr_table.putNoClobber(gpa, target, tlv_ptr_index);
}

pub fn addGotEntry(zld: *Zld, target: SymbolWithLoc) !void {
    if (zld.got_table.contains(target)) return;
    const gpa = zld.gpa;
    const atom_index = try zld.createGotAtom();
    const got_index = @intCast(u32, zld.got_entries.items.len);
    try zld.got_entries.append(gpa, .{
        .target = target,
        .atom_index = atom_index,
    });
    try zld.got_table.putNoClobber(gpa, target, got_index);
}

pub fn addStub(zld: *Zld, target: SymbolWithLoc) !void {
    const target_sym = zld.getSymbol(target);
    if (!target_sym.undf()) return;
    if (zld.stubs_table.contains(target)) return;

    const gpa = zld.gpa;
    _ = try zld.createStubHelperAtom();
    _ = try zld.createLazyPointerAtom();
    const atom_index = try zld.createStubAtom();
    const stubs_index = @intCast(u32, zld.stubs.items.len);
    try zld.stubs.append(gpa, .{
        .target = target,
        .atom_index = atom_index,
    });
    try zld.stubs_table.putNoClobber(gpa, target, stubs_index);
}

pub fn resolveRelocs(
    zld: *Zld,
    atom_index: AtomIndex,
    atom_code: []u8,
    atom_relocs: []align(1) const macho.relocation_info,
) !void {
    const arch = zld.options.target.cpu.arch;
    const atom = zld.getAtom(atom_index);
    assert(atom.getFile() != null); // synthetic atoms do not have relocs

    log.debug("resolving relocations in ATOM(%{d}, '{s}')", .{
        atom.sym_index,
        zld.getSymbolName(atom.getSymbolWithLoc()),
    });

    const ctx = getRelocContext(zld, atom_index);

    return switch (arch) {
        .aarch64 => resolveRelocsArm64(zld, atom_index, atom_code, atom_relocs, ctx),
        .x86_64 => resolveRelocsX86(zld, atom_index, atom_code, atom_relocs, ctx),
        else => unreachable,
    };
}

pub fn getRelocTargetAddress(zld: *Zld, target: SymbolWithLoc, is_via_got: bool, is_tlv: bool) !u64 {
    const target_atom_index = getRelocTargetAtomIndex(zld, target, is_via_got) orelse {
        // If there is no atom for target, we still need to check for special, atom-less
        // symbols such as `___dso_handle`.
        const target_name = zld.getSymbolName(target);
        const atomless_sym = zld.getSymbol(target);
        log.debug("    | atomless target '{s}'", .{target_name});
        return atomless_sym.n_value;
    };
    const target_atom = zld.getAtom(target_atom_index);
    log.debug("    | target ATOM(%{d}, '{s}') in object({?})", .{
        target_atom.sym_index,
        zld.getSymbolName(target_atom.getSymbolWithLoc()),
        target_atom.getFile(),
    });

    const target_sym = zld.getSymbol(target_atom.getSymbolWithLoc());
    assert(target_sym.n_desc != @import("zld.zig").N_DEAD);

    // If `target` is contained within the target atom, pull its address value.
    const offset = if (target_atom.getFile() != null) blk: {
        const object = zld.objects.items[target_atom.getFile().?];
        break :blk if (object.getSourceSymbol(target.sym_index)) |_|
            Atom.calcInnerSymbolOffset(zld, target_atom_index, target.sym_index)
        else
            0; // section alias
    } else 0;
    const base_address: u64 = if (is_tlv) base_address: {
        // For TLV relocations, the value specified as a relocation is the displacement from the
        // TLV initializer (either value in __thread_data or zero-init in __thread_bss) to the first
        // defined TLV template init section in the following order:
        // * wrt to __thread_data if defined, then
        // * wrt to __thread_bss
        const sect_id: u16 = sect_id: {
            if (zld.getSectionByName("__DATA", "__thread_data")) |i| {
                break :sect_id i;
            } else if (zld.getSectionByName("__DATA", "__thread_bss")) |i| {
                break :sect_id i;
            } else {
                log.err("threadlocal variables present but no initializer sections found", .{});
                log.err("  __thread_data not found", .{});
                log.err("  __thread_bss not found", .{});
                return error.FailedToResolveRelocationTarget;
            }
        };
        break :base_address zld.sections.items(.header)[sect_id].addr;
    } else 0;
    return target_sym.n_value + offset - base_address;
}

fn resolveRelocsArm64(
    zld: *Zld,
    atom_index: AtomIndex,
    atom_code: []u8,
    atom_relocs: []align(1) const macho.relocation_info,
    context: RelocContext,
) !void {
    const atom = zld.getAtom(atom_index);
    const object = zld.objects.items[atom.getFile().?];

    var addend: ?i64 = null;
    var subtractor: ?SymbolWithLoc = null;

    for (atom_relocs) |rel| {
        const rel_type = @intToEnum(macho.reloc_type_arm64, rel.r_type);

        switch (rel_type) {
            .ARM64_RELOC_ADDEND => {
                assert(addend == null);

                log.debug("  RELA({s}) @ {x} => {x}", .{ @tagName(rel_type), rel.r_address, rel.r_symbolnum });

                addend = rel.r_symbolnum;
                continue;
            },
            .ARM64_RELOC_SUBTRACTOR => {
                assert(subtractor == null);

                log.debug("  RELA({s}) @ {x} => %{d} in object({?d})", .{
                    @tagName(rel_type),
                    rel.r_address,
                    rel.r_symbolnum,
                    atom.getFile(),
                });

                subtractor = parseRelocTarget(zld, .{
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

        const target = parseRelocTarget(zld, .{
            .object_id = atom.getFile().?,
            .rel = rel,
            .code = atom_code,
            .base_addr = context.base_addr,
            .base_offset = context.base_offset,
        });
        const rel_offset = @intCast(u32, rel.r_address - context.base_offset);

        log.debug("  RELA({s}) @ {x} => %{d} ('{s}') in object({?})", .{
            @tagName(rel_type),
            rel.r_address,
            target.sym_index,
            zld.getSymbolName(target),
            target.getFile(),
        });

        const source_addr = blk: {
            const source_sym = zld.getSymbol(atom.getSymbolWithLoc());
            break :blk source_sym.n_value + rel_offset;
        };
        const is_via_got = relocRequiresGot(zld, rel);
        const is_tlv = is_tlv: {
            const source_sym = zld.getSymbol(atom.getSymbolWithLoc());
            const header = zld.sections.items(.header)[source_sym.n_sect - 1];
            break :is_tlv header.type() == macho.S_THREAD_LOCAL_VARIABLES;
        };
        const target_addr = try getRelocTargetAddress(zld, target, is_via_got, is_tlv);

        log.debug("    | source_addr = 0x{x}", .{source_addr});

        switch (rel_type) {
            .ARM64_RELOC_BRANCH26 => {
                const actual_target = if (zld.getStubsAtomIndexForSymbol(target)) |stub_atom_index| inner: {
                    const stub_atom = zld.getAtom(stub_atom_index);
                    break :inner stub_atom.getSymbolWithLoc();
                } else target;
                log.debug("  source {s} (object({?})), target {s} (object({?}))", .{
                    zld.getSymbolName(atom.getSymbolWithLoc()),
                    atom.getFile(),
                    zld.getSymbolName(target),
                    zld.getAtom(getRelocTargetAtomIndex(zld, target, is_via_got).?).getFile(),
                });

                const displacement = if (calcPcRelativeDisplacementArm64(
                    source_addr,
                    zld.getSymbol(actual_target).n_value,
                )) |disp| blk: {
                    log.debug("    | target_addr = 0x{x}", .{zld.getSymbol(actual_target).n_value});
                    break :blk disp;
                } else |_| blk: {
                    const thunk_index = zld.thunk_table.get(atom_index).?;
                    const thunk = zld.thunks.items[thunk_index];
                    const thunk_sym = zld.getSymbol(thunk.getTrampolineForSymbol(
                        zld,
                        actual_target,
                    ).?);
                    log.debug("    | target_addr = 0x{x} (thunk)", .{thunk_sym.n_value});
                    break :blk try calcPcRelativeDisplacementArm64(source_addr, thunk_sym.n_value);
                };

                const code = atom_code[rel_offset..][0..4];
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
                const adjusted_target_addr = @intCast(u64, @intCast(i64, target_addr) + (addend orelse 0));

                log.debug("    | target_addr = 0x{x}", .{adjusted_target_addr});

                const pages = @bitCast(u21, calcNumberOfPages(source_addr, adjusted_target_addr));
                const code = atom_code[rel_offset..][0..4];
                var inst = aarch64.Instruction{
                    .pc_relative_address = mem.bytesToValue(meta.TagPayload(
                        aarch64.Instruction,
                        aarch64.Instruction.pc_relative_address,
                    ), code),
                };
                inst.pc_relative_address.immhi = @truncate(u19, pages >> 2);
                inst.pc_relative_address.immlo = @truncate(u2, pages);
                mem.writeIntLittle(u32, code, inst.toU32());
                addend = null;
            },

            .ARM64_RELOC_PAGEOFF12 => {
                const adjusted_target_addr = @intCast(u64, @intCast(i64, target_addr) + (addend orelse 0));

                log.debug("    | target_addr = 0x{x}", .{adjusted_target_addr});

                const code = atom_code[rel_offset..][0..4];
                if (isArithmeticOp(code)) {
                    const off = try calcPageOffset(adjusted_target_addr, .arithmetic);
                    var inst = aarch64.Instruction{
                        .add_subtract_immediate = mem.bytesToValue(meta.TagPayload(
                            aarch64.Instruction,
                            aarch64.Instruction.add_subtract_immediate,
                        ), code),
                    };
                    inst.add_subtract_immediate.imm12 = off;
                    mem.writeIntLittle(u32, code, inst.toU32());
                } else {
                    var inst = aarch64.Instruction{
                        .load_store_register = mem.bytesToValue(meta.TagPayload(
                            aarch64.Instruction,
                            aarch64.Instruction.load_store_register,
                        ), code),
                    };
                    const off = try calcPageOffset(adjusted_target_addr, switch (inst.load_store_register.size) {
                        0 => if (inst.load_store_register.v == 1)
                            PageOffsetInstKind.load_store_128
                        else
                            PageOffsetInstKind.load_store_8,
                        1 => .load_store_16,
                        2 => .load_store_32,
                        3 => .load_store_64,
                    });
                    inst.load_store_register.offset = off;
                    mem.writeIntLittle(u32, code, inst.toU32());
                }
                addend = null;
            },

            .ARM64_RELOC_GOT_LOAD_PAGEOFF12 => {
                const code = atom_code[rel_offset..][0..4];
                const adjusted_target_addr = @intCast(u64, @intCast(i64, target_addr) + (addend orelse 0));

                log.debug("    | target_addr = 0x{x}", .{adjusted_target_addr});

                const off = try calcPageOffset(adjusted_target_addr, .load_store_64);
                var inst: aarch64.Instruction = .{
                    .load_store_register = mem.bytesToValue(meta.TagPayload(
                        aarch64.Instruction,
                        aarch64.Instruction.load_store_register,
                    ), code),
                };
                inst.load_store_register.offset = off;
                mem.writeIntLittle(u32, code, inst.toU32());
                addend = null;
            },

            .ARM64_RELOC_TLVP_LOAD_PAGEOFF12 => {
                const code = atom_code[rel_offset..][0..4];
                const adjusted_target_addr = @intCast(u64, @intCast(i64, target_addr) + (addend orelse 0));

                log.debug("    | target_addr = 0x{x}", .{adjusted_target_addr});

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

                var inst = if (zld.tlv_ptr_table.contains(target)) aarch64.Instruction{
                    .load_store_register = .{
                        .rt = reg_info.rd,
                        .rn = reg_info.rn,
                        .offset = try calcPageOffset(adjusted_target_addr, .load_store_64),
                        .opc = 0b01,
                        .op1 = 0b01,
                        .v = 0,
                        .size = reg_info.size,
                    },
                } else aarch64.Instruction{
                    .add_subtract_immediate = .{
                        .rd = reg_info.rd,
                        .rn = reg_info.rn,
                        .imm12 = try calcPageOffset(adjusted_target_addr, .arithmetic),
                        .sh = 0,
                        .s = 0,
                        .op = 0,
                        .sf = @truncate(u1, reg_info.size),
                    },
                };
                mem.writeIntLittle(u32, code, inst.toU32());
                addend = null;
            },

            .ARM64_RELOC_POINTER_TO_GOT => {
                log.debug("    | target_addr = 0x{x}", .{target_addr});
                const result = math.cast(i32, @intCast(i64, target_addr) - @intCast(i64, source_addr)) orelse
                    return error.Overflow;
                mem.writeIntLittle(u32, atom_code[rel_offset..][0..4], @bitCast(u32, result));
            },

            .ARM64_RELOC_UNSIGNED => {
                var ptr_addend = if (rel.r_length == 3)
                    mem.readIntLittle(i64, atom_code[rel_offset..][0..8])
                else
                    mem.readIntLittle(i32, atom_code[rel_offset..][0..4]);

                if (rel.r_extern == 0) {
                    const base_addr = if (target.sym_index >= object.source_address_lookup.len)
                        @intCast(i64, object.getSourceSection(@intCast(u8, rel.r_symbolnum - 1)).addr)
                    else
                        object.source_address_lookup[target.sym_index];
                    ptr_addend -= base_addr;
                }

                const result = blk: {
                    if (subtractor) |sub| {
                        const sym = zld.getSymbol(sub);
                        break :blk @intCast(i64, target_addr) - @intCast(i64, sym.n_value) + ptr_addend;
                    } else {
                        break :blk @intCast(i64, target_addr) + ptr_addend;
                    }
                };
                log.debug("    | target_addr = 0x{x}", .{result});

                if (rel.r_length == 3) {
                    mem.writeIntLittle(u64, atom_code[rel_offset..][0..8], @bitCast(u64, result));
                } else {
                    mem.writeIntLittle(u32, atom_code[rel_offset..][0..4], @truncate(u32, @bitCast(u64, result)));
                }

                subtractor = null;
            },

            .ARM64_RELOC_ADDEND => unreachable,
            .ARM64_RELOC_SUBTRACTOR => unreachable,
        }
    }
}

fn resolveRelocsX86(
    zld: *Zld,
    atom_index: AtomIndex,
    atom_code: []u8,
    atom_relocs: []align(1) const macho.relocation_info,
    context: RelocContext,
) !void {
    const atom = zld.getAtom(atom_index);
    const object = zld.objects.items[atom.getFile().?];

    var subtractor: ?SymbolWithLoc = null;

    for (atom_relocs) |rel| {
        const rel_type = @intToEnum(macho.reloc_type_x86_64, rel.r_type);

        switch (rel_type) {
            .X86_64_RELOC_SUBTRACTOR => {
                assert(subtractor == null);

                log.debug("  RELA({s}) @ {x} => %{d} in object({?d})", .{
                    @tagName(rel_type),
                    rel.r_address,
                    rel.r_symbolnum,
                    atom.getFile(),
                });

                subtractor = parseRelocTarget(zld, .{
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

        const target = parseRelocTarget(zld, .{
            .object_id = atom.getFile().?,
            .rel = rel,
            .code = atom_code,
            .base_addr = context.base_addr,
            .base_offset = context.base_offset,
        });
        const rel_offset = @intCast(u32, rel.r_address - context.base_offset);

        log.debug("  RELA({s}) @ {x} => %{d} ('{s}') in object({?})", .{
            @tagName(rel_type),
            rel.r_address,
            target.sym_index,
            zld.getSymbolName(target),
            target.getFile(),
        });

        const source_addr = blk: {
            const source_sym = zld.getSymbol(atom.getSymbolWithLoc());
            break :blk source_sym.n_value + rel_offset;
        };
        const is_via_got = relocRequiresGot(zld, rel);
        const is_tlv = is_tlv: {
            const source_sym = zld.getSymbol(atom.getSymbolWithLoc());
            const header = zld.sections.items(.header)[source_sym.n_sect - 1];
            break :is_tlv header.type() == macho.S_THREAD_LOCAL_VARIABLES;
        };

        log.debug("    | source_addr = 0x{x}", .{source_addr});

        const target_addr = try getRelocTargetAddress(zld, target, is_via_got, is_tlv);

        switch (rel_type) {
            .X86_64_RELOC_BRANCH => {
                const addend = mem.readIntLittle(i32, atom_code[rel_offset..][0..4]);
                const adjusted_target_addr = @intCast(u64, @intCast(i64, target_addr) + addend);
                log.debug("    | target_addr = 0x{x}", .{adjusted_target_addr});
                const disp = try calcPcRelativeDisplacementX86(source_addr, adjusted_target_addr, 0);
                mem.writeIntLittle(i32, atom_code[rel_offset..][0..4], disp);
            },

            .X86_64_RELOC_GOT,
            .X86_64_RELOC_GOT_LOAD,
            => {
                const addend = mem.readIntLittle(i32, atom_code[rel_offset..][0..4]);
                const adjusted_target_addr = @intCast(u64, @intCast(i64, target_addr) + addend);
                log.debug("    | target_addr = 0x{x}", .{adjusted_target_addr});
                const disp = try calcPcRelativeDisplacementX86(source_addr, adjusted_target_addr, 0);
                mem.writeIntLittle(i32, atom_code[rel_offset..][0..4], disp);
            },

            .X86_64_RELOC_TLV => {
                const addend = mem.readIntLittle(i32, atom_code[rel_offset..][0..4]);
                const adjusted_target_addr = @intCast(u64, @intCast(i64, target_addr) + addend);
                log.debug("    | target_addr = 0x{x}", .{adjusted_target_addr});
                const disp = try calcPcRelativeDisplacementX86(source_addr, adjusted_target_addr, 0);

                if (zld.tlv_ptr_table.get(target) == null) {
                    // We need to rewrite the opcode from movq to leaq.
                    atom_code[rel_offset - 2] = 0x8d;
                }

                mem.writeIntLittle(i32, atom_code[rel_offset..][0..4], disp);
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
                var addend = mem.readIntLittle(i32, atom_code[rel_offset..][0..4]) + correction;

                if (rel.r_extern == 0) {
                    const base_addr = if (target.sym_index >= object.source_address_lookup.len)
                        @intCast(i64, object.getSourceSection(@intCast(u8, rel.r_symbolnum - 1)).addr)
                    else
                        object.source_address_lookup[target.sym_index];
                    addend += @intCast(i32, @intCast(i64, context.base_addr) + rel.r_address + 4 -
                        @intCast(i64, base_addr));
                }

                const adjusted_target_addr = @intCast(u64, @intCast(i64, target_addr) + addend);

                log.debug("    | target_addr = 0x{x}", .{adjusted_target_addr});

                const disp = try calcPcRelativeDisplacementX86(source_addr, adjusted_target_addr, correction);
                mem.writeIntLittle(i32, atom_code[rel_offset..][0..4], disp);
            },

            .X86_64_RELOC_UNSIGNED => {
                var addend = if (rel.r_length == 3)
                    mem.readIntLittle(i64, atom_code[rel_offset..][0..8])
                else
                    mem.readIntLittle(i32, atom_code[rel_offset..][0..4]);

                if (rel.r_extern == 0) {
                    const base_addr = if (target.sym_index >= object.source_address_lookup.len)
                        @intCast(i64, object.getSourceSection(@intCast(u8, rel.r_symbolnum - 1)).addr)
                    else
                        object.source_address_lookup[target.sym_index];
                    addend -= base_addr;
                }

                const result = blk: {
                    if (subtractor) |sub| {
                        const sym = zld.getSymbol(sub);
                        break :blk @intCast(i64, target_addr) - @intCast(i64, sym.n_value) + addend;
                    } else {
                        break :blk @intCast(i64, target_addr) + addend;
                    }
                };
                log.debug("    | target_addr = 0x{x}", .{result});

                if (rel.r_length == 3) {
                    mem.writeIntLittle(u64, atom_code[rel_offset..][0..8], @bitCast(u64, result));
                } else {
                    mem.writeIntLittle(u32, atom_code[rel_offset..][0..4], @truncate(u32, @bitCast(u64, result)));
                }

                subtractor = null;
            },

            .X86_64_RELOC_SUBTRACTOR => unreachable,
        }
    }
}

inline fn isArithmeticOp(inst: *const [4]u8) bool {
    const group_decode = @truncate(u5, inst[3]);
    return ((group_decode >> 2) == 4);
}

pub fn getAtomCode(zld: *Zld, atom_index: AtomIndex) []const u8 {
    const atom = zld.getAtom(atom_index);
    assert(atom.getFile() != null); // Synthetic atom shouldn't need to inquire for code.
    const object = zld.objects.items[atom.getFile().?];
    const source_sym = object.getSourceSymbol(atom.sym_index) orelse {
        // If there was no matching symbol present in the source symtab, this means
        // we are dealing with either an entire section, or part of it, but also
        // starting at the beginning.
        const nbase = @intCast(u32, object.in_symtab.?.len);
        const sect_id = @intCast(u8, atom.sym_index - nbase);
        const source_sect = object.getSourceSection(sect_id);
        assert(!source_sect.isZerofill());
        const code = object.getSectionContents(source_sect);
        const code_len = @intCast(usize, atom.size);
        return code[0..code_len];
    };
    const source_sect = object.getSourceSection(source_sym.n_sect - 1);
    assert(!source_sect.isZerofill());
    const code = object.getSectionContents(source_sect);
    const offset = @intCast(usize, source_sym.n_value - source_sect.addr);
    const code_len = @intCast(usize, atom.size);
    return code[offset..][0..code_len];
}

pub fn getAtomRelocs(zld: *Zld, atom_index: AtomIndex) []const macho.relocation_info {
    const atom = zld.getAtom(atom_index);
    assert(atom.getFile() != null); // Synthetic atom shouldn't need to unique for relocs.
    const object = zld.objects.items[atom.getFile().?];
    const cache = object.relocs_lookup[atom.sym_index];

    const source_sect_id = if (object.getSourceSymbol(atom.sym_index)) |source_sym| blk: {
        break :blk source_sym.n_sect - 1;
    } else blk: {
        // If there was no matching symbol present in the source symtab, this means
        // we are dealing with either an entire section, or part of it, but also
        // starting at the beginning.
        const nbase = @intCast(u32, object.in_symtab.?.len);
        const sect_id = @intCast(u8, atom.sym_index - nbase);
        break :blk sect_id;
    };
    const source_sect = object.getSourceSection(source_sect_id);
    assert(!source_sect.isZerofill());
    const relocs = object.getRelocs(source_sect_id);
    return relocs[cache.start..][0..cache.len];
}

pub fn calcPcRelativeDisplacementX86(source_addr: u64, target_addr: u64, correction: u3) error{Overflow}!i32 {
    const disp = @intCast(i64, target_addr) - @intCast(i64, source_addr + 4 + correction);
    return math.cast(i32, disp) orelse error.Overflow;
}

pub fn calcPcRelativeDisplacementArm64(source_addr: u64, target_addr: u64) error{Overflow}!i28 {
    const disp = @intCast(i64, target_addr) - @intCast(i64, source_addr);
    return math.cast(i28, disp) orelse error.Overflow;
}

pub fn calcNumberOfPages(source_addr: u64, target_addr: u64) i21 {
    const source_page = @intCast(i32, source_addr >> 12);
    const target_page = @intCast(i32, target_addr >> 12);
    const pages = @intCast(i21, target_page - source_page);
    return pages;
}

const PageOffsetInstKind = enum {
    arithmetic,
    load_store_8,
    load_store_16,
    load_store_32,
    load_store_64,
    load_store_128,
};

pub fn calcPageOffset(target_addr: u64, kind: PageOffsetInstKind) !u12 {
    const narrowed = @truncate(u12, target_addr);
    return switch (kind) {
        .arithmetic, .load_store_8 => narrowed,
        .load_store_16 => try math.divExact(u12, narrowed, 2),
        .load_store_32 => try math.divExact(u12, narrowed, 4),
        .load_store_64 => try math.divExact(u12, narrowed, 8),
        .load_store_128 => try math.divExact(u12, narrowed, 16),
    };
}

pub fn relocRequiresGot(zld: *Zld, rel: macho.relocation_info) bool {
    switch (zld.options.target.cpu.arch) {
        .aarch64 => switch (@intToEnum(macho.reloc_type_arm64, rel.r_type)) {
            .ARM64_RELOC_GOT_LOAD_PAGE21,
            .ARM64_RELOC_GOT_LOAD_PAGEOFF12,
            .ARM64_RELOC_POINTER_TO_GOT,
            => return true,
            else => return false,
        },
        .x86_64 => switch (@intToEnum(macho.reloc_type_x86_64, rel.r_type)) {
            .X86_64_RELOC_GOT,
            .X86_64_RELOC_GOT_LOAD,
            => return true,
            else => return false,
        },
        else => unreachable,
    }
}
