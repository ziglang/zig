const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.dead_strip);
const macho = std.macho;
const math = std.math;
const mem = std.mem;

const Allocator = mem.Allocator;
const Atom = @import("Atom.zig");
const MachO = @import("../MachO.zig");

pub fn gcAtoms(macho_file: *MachO) !void {
    const gpa = macho_file.base.allocator;
    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    var roots = std.AutoHashMap(*Atom, void).init(arena);
    try collectRoots(&roots, macho_file);

    var alive = std.AutoHashMap(*Atom, void).init(arena);
    try mark(roots, &alive, macho_file);

    try prune(arena, alive, macho_file);
}

fn removeAtomFromSection(atom: *Atom, match: u8, macho_file: *MachO) void {
    var section = macho_file.sections.get(match);

    // If we want to enable GC for incremental codepath, we need to take into
    // account any padding that might have been left here.
    section.header.size -= atom.size;

    if (atom.prev) |prev| {
        prev.next = atom.next;
    }
    if (atom.next) |next| {
        next.prev = atom.prev;
    } else {
        if (atom.prev) |prev| {
            section.last_atom = prev;
        } else {
            // The section will be GCed in the next step.
            section.last_atom = null;
            section.header.size = 0;
        }
    }

    macho_file.sections.set(match, section);
}

fn collectRoots(roots: *std.AutoHashMap(*Atom, void), macho_file: *MachO) !void {
    const output_mode = macho_file.base.options.output_mode;

    switch (output_mode) {
        .Exe => {
            // Add entrypoint as GC root
            const global = try macho_file.getEntryPoint();
            const atom = macho_file.getAtomForSymbol(global).?; // panic here means fatal error
            _ = try roots.getOrPut(atom);
        },
        else => |other| {
            assert(other == .Lib);
            // Add exports as GC roots
            for (macho_file.globals.items) |global| {
                const sym = macho_file.getSymbol(global);
                if (!sym.sect()) continue;
                const atom = macho_file.getAtomForSymbol(global) orelse {
                    log.debug("skipping {s}", .{macho_file.getSymbolName(global)});
                    continue;
                };
                _ = try roots.getOrPut(atom);
                log.debug("adding root", .{});
                macho_file.logAtom(atom);
            }
        },
    }

    // TODO just a temp until we learn how to parse unwind records
    if (macho_file.getGlobal("___gxx_personality_v0")) |global| {
        if (macho_file.getAtomForSymbol(global)) |atom| {
            _ = try roots.getOrPut(atom);
            log.debug("adding root", .{});
            macho_file.logAtom(atom);
        }
    }

    for (macho_file.objects.items) |object| {
        for (object.managed_atoms.items) |atom| {
            const source_sym = object.getSourceSymbol(atom.sym_index) orelse continue;
            if (source_sym.tentative()) continue;
            const source_sect = object.getSourceSection(source_sym.n_sect - 1);
            const is_gc_root = blk: {
                if (source_sect.isDontDeadStrip()) break :blk true;
                if (mem.eql(u8, "__StaticInit", source_sect.sectName())) break :blk true;
                switch (source_sect.@"type"()) {
                    macho.S_MOD_INIT_FUNC_POINTERS,
                    macho.S_MOD_TERM_FUNC_POINTERS,
                    => break :blk true,
                    else => break :blk false,
                }
            };
            if (is_gc_root) {
                try roots.putNoClobber(atom, {});
                log.debug("adding root", .{});
                macho_file.logAtom(atom);
            }
        }
    }
}

fn markLive(atom: *Atom, alive: *std.AutoHashMap(*Atom, void), macho_file: *MachO) anyerror!void {
    const gop = try alive.getOrPut(atom);
    if (gop.found_existing) return;

    log.debug("marking live", .{});
    macho_file.logAtom(atom);

    for (atom.relocs.items) |rel| {
        const target_atom = rel.getTargetAtom(macho_file) orelse continue;
        try markLive(target_atom, alive, macho_file);
    }
}

fn refersLive(atom: *Atom, alive: std.AutoHashMap(*Atom, void), macho_file: *MachO) bool {
    for (atom.relocs.items) |rel| {
        const target_atom = rel.getTargetAtom(macho_file) orelse continue;
        if (alive.contains(target_atom)) return true;
    }
    return false;
}

fn refersDead(atom: *Atom, macho_file: *MachO) bool {
    for (atom.relocs.items) |rel| {
        const target_atom = rel.getTargetAtom(macho_file) orelse continue;
        const target_sym = target_atom.getSymbol(macho_file);
        if (target_sym.n_desc == MachO.N_DESC_GCED) return true;
    }
    return false;
}

fn mark(
    roots: std.AutoHashMap(*Atom, void),
    alive: *std.AutoHashMap(*Atom, void),
    macho_file: *MachO,
) !void {
    try alive.ensureUnusedCapacity(roots.count());

    var it = roots.keyIterator();
    while (it.next()) |root| {
        try markLive(root.*, alive, macho_file);
    }

    var loop: bool = true;
    while (loop) {
        loop = false;

        for (macho_file.objects.items) |object| {
            for (object.managed_atoms.items) |atom| {
                if (alive.contains(atom)) continue;
                const source_sym = object.getSourceSymbol(atom.sym_index) orelse continue;
                if (source_sym.tentative()) continue;
                const source_sect = object.getSourceSection(source_sym.n_sect - 1);
                if (source_sect.isDontDeadStripIfReferencesLive() and refersLive(atom, alive.*, macho_file)) {
                    try markLive(atom, alive, macho_file);
                    loop = true;
                }
            }
        }
    }
}

fn prune(arena: Allocator, alive: std.AutoHashMap(*Atom, void), macho_file: *MachO) !void {
    // Any section that ends up here will be updated, that is,
    // its size and alignment recalculated.
    var gc_sections = std.AutoHashMap(u8, void).init(arena);
    var loop: bool = true;
    while (loop) {
        loop = false;

        for (macho_file.objects.items) |object| {
            const in_symtab = object.in_symtab orelse continue;

            for (in_symtab) |_, source_index| {
                const atom = object.getAtomForSymbol(@intCast(u32, source_index)) orelse continue;
                if (alive.contains(atom)) continue;

                const global = atom.getSymbolWithLoc();
                const sym = atom.getSymbolPtr(macho_file);
                const match = sym.n_sect - 1;

                if (sym.n_desc == MachO.N_DESC_GCED) continue;
                if (!sym.ext() and !refersDead(atom, macho_file)) continue;

                macho_file.logAtom(atom);
                sym.n_desc = MachO.N_DESC_GCED;
                removeAtomFromSection(atom, match, macho_file);
                _ = try gc_sections.put(match, {});

                for (atom.contained.items) |sym_off| {
                    const inner = macho_file.getSymbolPtr(.{
                        .sym_index = sym_off.sym_index,
                        .file = atom.file,
                    });
                    inner.n_desc = MachO.N_DESC_GCED;
                }

                if (macho_file.got_entries_table.contains(global)) {
                    const got_atom = macho_file.getGotAtomForSymbol(global).?;
                    const got_sym = got_atom.getSymbolPtr(macho_file);
                    got_sym.n_desc = MachO.N_DESC_GCED;
                }

                if (macho_file.stubs_table.contains(global)) {
                    const stubs_atom = macho_file.getStubsAtomForSymbol(global).?;
                    const stubs_sym = stubs_atom.getSymbolPtr(macho_file);
                    stubs_sym.n_desc = MachO.N_DESC_GCED;
                }

                if (macho_file.tlv_ptr_entries_table.contains(global)) {
                    const tlv_ptr_atom = macho_file.getTlvPtrAtomForSymbol(global).?;
                    const tlv_ptr_sym = tlv_ptr_atom.getSymbolPtr(macho_file);
                    tlv_ptr_sym.n_desc = MachO.N_DESC_GCED;
                }

                loop = true;
            }
        }
    }

    for (macho_file.got_entries.items) |entry| {
        const sym = entry.getSymbol(macho_file);
        if (sym.n_desc != MachO.N_DESC_GCED) continue;

        // TODO tombstone
        const atom = entry.getAtom(macho_file).?;
        const match = sym.n_sect - 1;
        removeAtomFromSection(atom, match, macho_file);
        _ = try gc_sections.put(match, {});
        _ = macho_file.got_entries_table.remove(entry.target);
    }

    for (macho_file.stubs.items) |entry| {
        const sym = entry.getSymbol(macho_file);
        if (sym.n_desc != MachO.N_DESC_GCED) continue;

        // TODO tombstone
        const atom = entry.getAtom(macho_file).?;
        const match = sym.n_sect - 1;
        removeAtomFromSection(atom, match, macho_file);
        _ = try gc_sections.put(match, {});
        _ = macho_file.stubs_table.remove(entry.target);
    }

    for (macho_file.tlv_ptr_entries.items) |entry| {
        const sym = entry.getSymbol(macho_file);
        if (sym.n_desc != MachO.N_DESC_GCED) continue;

        // TODO tombstone
        const atom = entry.getAtom(macho_file).?;
        const match = sym.n_sect - 1;
        removeAtomFromSection(atom, match, macho_file);
        _ = try gc_sections.put(match, {});
        _ = macho_file.tlv_ptr_entries_table.remove(entry.target);
    }

    var gc_sections_it = gc_sections.iterator();
    while (gc_sections_it.next()) |entry| {
        const match = entry.key_ptr.*;
        var section = macho_file.sections.get(match);
        if (section.header.size == 0) continue; // Pruning happens automatically in next step.

        section.header.@"align" = 0;
        section.header.size = 0;

        var atom = section.last_atom.?;

        while (atom.prev) |prev| {
            atom = prev;
        }

        while (true) {
            const atom_alignment = try math.powi(u32, 2, atom.alignment);
            const aligned_end_addr = mem.alignForwardGeneric(u64, section.header.size, atom_alignment);
            const padding = aligned_end_addr - section.header.size;
            section.header.size += padding + atom.size;
            section.header.@"align" = @maximum(section.header.@"align", atom.alignment);

            if (atom.next) |next| {
                atom = next;
            } else break;
        }

        macho_file.sections.set(match, section);
    }
}
