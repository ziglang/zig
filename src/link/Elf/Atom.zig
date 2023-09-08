/// Address allocated for this Atom.
value: u64 = 0,

/// Name of this Atom.
name_offset: u32 = 0,

/// Index into linker's input file table.
file_index: File.Index = 0,

/// Size of this atom
size: u64 = 0,

/// Alignment of this atom as a power of two.
alignment: u8 = 0,

/// Index of the input section.
input_section_index: u16 = 0,

/// Index of the output section.
output_section_index: u16 = 0,

/// Index of the input section containing this atom's relocs.
relocs_section_index: u16 = 0,

/// Index of this atom in the linker's atoms table.
atom_index: Index = 0,

/// Specifies whether this atom is alive or has been garbage collected.
alive: bool = true,

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

pub fn name(self: Atom, elf_file: *Elf) []const u8 {
    return elf_file.strtab.getAssumeExists(self.name_offset);
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

pub fn addRelocation(elf_file: *Elf, atom_index: Index, reloc: Reloc) !void {
    const gpa = elf_file.base.allocator;
    const gop = try elf_file.relocs.getOrPut(gpa, atom_index);
    if (!gop.found_existing) {
        gop.value_ptr.* = .{};
    }
    try gop.value_ptr.append(gpa, reloc);
}

pub fn freeRelocations(elf_file: *Elf, atom_index: Index) void {
    var removed_relocs = elf_file.relocs.fetchRemove(atom_index);
    if (removed_relocs) |*relocs| relocs.value.deinit(elf_file.base.allocator);
}

pub fn allocate(self: *Atom, elf_file: *Elf) !void {
    const phdr_index = elf_file.sections.items(.phdr_index)[self.output_section_index];
    const phdr = &elf_file.program_headers.items[phdr_index];
    const shdr = &elf_file.sections.items(.shdr)[self.output_section_index];
    const free_list = &elf_file.sections.items(.free_list)[self.output_section_index];
    const last_atom_index = &elf_file.sections.items(.last_atom_index)[self.output_section_index];
    const new_atom_ideal_capacity = Elf.padToIdeal(self.size);
    const alignment = try std.math.powi(u64, 2, self.alignment);

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
            const new_start_vaddr = std.mem.alignBackward(u64, new_start_vaddr_unaligned, alignment);
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
            const new_start_vaddr = std.mem.alignForward(u64, ideal_capacity_end_vaddr, alignment);
            // Set up the metadata to be updated, after errors are no longer possible.
            atom_placement = last.atom_index;
            break :blk new_start_vaddr;
        } else {
            break :blk phdr.p_vaddr;
        }
    };

    const expand_section = if (atom_placement) |placement_index|
        elf_file.atom(placement_index).?.next_index == 0
    else
        true;
    if (expand_section) {
        const needed_size = (self.value + self.size) - phdr.p_vaddr;
        try elf_file.growAllocSection(self.output_section_index, needed_size);
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
    shdr.sh_addralign = @max(shdr.sh_addralign, alignment);

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
    const alignment = try std.math.powi(u64, 2, self.alignment);
    const align_ok = std.mem.alignBackward(u64, self.value, alignment) == self.value;
    const need_realloc = !align_ok or self.size > self.capacity(elf_file);
    if (need_realloc) try self.allocate(elf_file);
}

pub fn free(self: *Atom, elf_file: *Elf) void {
    log.debug("freeAtom {d} ({s})", .{ self.atom_index, self.name(elf_file) });

    Atom.freeRelocations(elf_file, self.atom_index);

    const gpa = elf_file.base.allocator;
    const shndx = self.output_section_index;
    const free_list = &elf_file.sections.items(.free_list)[shndx];
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

    const last_atom_index = &elf_file.sections.items(.last_atom_index)[shndx];
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

    self.* = .{};
}

pub const Index = u32;

pub const Reloc = struct {
    target: u32,
    offset: u64,
    addend: u32,
    prev_vaddr: u64,
};

const std = @import("std");
const assert = std.debug.assert;
const elf = std.elf;
const log = std.log.scoped(.link);

const Atom = @This();
const Elf = @import("../Elf.zig");
const File = @import("file.zig").File;
