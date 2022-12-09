//! An algorithm for dead stripping of unreferenced Atoms.

const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.dead_strip);
const macho = std.macho;
const math = std.math;
const mem = std.mem;

const Allocator = mem.Allocator;
const AtomIndex = @import("zld.zig").AtomIndex;
const Atom = @import("ZldAtom.zig");
const SymbolWithLoc = @import("zld.zig").SymbolWithLoc;
const Zld = @import("zld.zig").Zld;

const N_DEAD = @import("zld.zig").N_DEAD;

const AtomTable = std.AutoHashMap(AtomIndex, void);

pub fn gcAtoms(zld: *Zld, reverse_lookups: [][]u32) Allocator.Error!void {
    const gpa = zld.gpa;

    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();

    var roots = AtomTable.init(arena.allocator());
    try roots.ensureUnusedCapacity(@intCast(u32, zld.globals.items.len));

    var alive = AtomTable.init(arena.allocator());
    try alive.ensureTotalCapacity(@intCast(u32, zld.atoms.items.len));

    try collectRoots(zld, &roots);
    mark(zld, roots, &alive, reverse_lookups);
    prune(zld, alive);
}

fn collectRoots(zld: *Zld, roots: *AtomTable) !void {
    log.debug("collecting roots", .{});

    switch (zld.options.output_mode) {
        .Exe => {
            // Add entrypoint as GC root
            const global: SymbolWithLoc = zld.getEntryPoint();
            const object = zld.objects.items[global.getFile().?];
            const atom_index = object.getAtomIndexForSymbol(global.sym_index).?; // panic here means fatal error
            _ = try roots.getOrPut(atom_index);

            log.debug("root(ATOM({d}, %{d}, {d}))", .{
                atom_index,
                zld.getAtom(atom_index).sym_index,
                zld.getAtom(atom_index).file,
            });
        },
        else => |other| {
            assert(other == .Lib);
            // Add exports as GC roots
            for (zld.globals.items) |global| {
                const sym = zld.getSymbol(global);
                if (sym.undf()) continue;

                const file = global.getFile() orelse continue; // synthetic globals are atomless
                const object = zld.objects.items[file];
                const atom_index = object.getAtomIndexForSymbol(global.sym_index).?; // panic here means fatal error
                _ = try roots.getOrPut(atom_index);

                log.debug("root(ATOM({d}, %{d}, {d}))", .{
                    atom_index,
                    zld.getAtom(atom_index).sym_index,
                    zld.getAtom(atom_index).file,
                });
            }
        },
    }

    // TODO just a temp until we learn how to parse unwind records
    for (zld.globals.items) |global| {
        if (mem.eql(u8, "___gxx_personality_v0", zld.getSymbolName(global))) {
            const object = zld.objects.items[global.getFile().?];
            if (object.getAtomIndexForSymbol(global.sym_index)) |atom_index| {
                _ = try roots.getOrPut(atom_index);

                log.debug("root(ATOM({d}, %{d}, {d}))", .{
                    atom_index,
                    zld.getAtom(atom_index).sym_index,
                    zld.getAtom(atom_index).file,
                });
            }
            break;
        }
    }

    for (zld.objects.items) |object| {
        const has_subsections = object.header.flags & macho.MH_SUBSECTIONS_VIA_SYMBOLS != 0;

        for (object.atoms.items) |atom_index| {
            const is_gc_root = blk: {
                // Modelled after ld64 which treats each object file compiled without MH_SUBSECTIONS_VIA_SYMBOLS
                // as a root.
                if (!has_subsections) break :blk true;

                const atom = zld.getAtom(atom_index);
                const sect_id = if (object.getSourceSymbol(atom.sym_index)) |source_sym|
                    source_sym.n_sect - 1
                else sect_id: {
                    const nbase = @intCast(u32, object.in_symtab.?.len);
                    const sect_id = @intCast(u16, atom.sym_index - nbase);
                    break :sect_id sect_id;
                };
                const source_sect = object.getSourceSection(sect_id);
                if (source_sect.isDontDeadStrip()) break :blk true;
                switch (source_sect.type()) {
                    macho.S_MOD_INIT_FUNC_POINTERS,
                    macho.S_MOD_TERM_FUNC_POINTERS,
                    => break :blk true,
                    else => break :blk false,
                }
            };

            if (is_gc_root) {
                try roots.putNoClobber(atom_index, {});

                log.debug("root(ATOM({d}, %{d}, {d}))", .{
                    atom_index,
                    zld.getAtom(atom_index).sym_index,
                    zld.getAtom(atom_index).file,
                });
            }
        }
    }
}

fn markLive(
    zld: *Zld,
    atom_index: AtomIndex,
    alive: *AtomTable,
    reverse_lookups: [][]u32,
) void {
    if (alive.contains(atom_index)) return;

    const atom = zld.getAtom(atom_index);
    const sym_loc = atom.getSymbolWithLoc();

    log.debug("mark(ATOM({d}, %{d}, {d}))", .{ atom_index, sym_loc.sym_index, sym_loc.file });

    alive.putAssumeCapacityNoClobber(atom_index, {});

    const cpu_arch = zld.options.target.cpu.arch;

    const sym = zld.getSymbol(atom.getSymbolWithLoc());
    const header = zld.sections.items(.header)[sym.n_sect - 1];
    if (header.isZerofill()) return;

    const relocs = Atom.getAtomRelocs(zld, atom_index);
    const reverse_lookup = reverse_lookups[atom.getFile().?];
    for (relocs) |rel| {
        const target = switch (cpu_arch) {
            .aarch64 => switch (@intToEnum(macho.reloc_type_arm64, rel.r_type)) {
                .ARM64_RELOC_ADDEND => continue,
                else => Atom.parseRelocTarget(zld, atom_index, rel, reverse_lookup),
            },
            .x86_64 => Atom.parseRelocTarget(zld, atom_index, rel, reverse_lookup),
            else => unreachable,
        };
        const target_sym = zld.getSymbol(target);

        if (target_sym.undf()) continue;
        if (target.getFile() == null) {
            const target_sym_name = zld.getSymbolName(target);
            if (mem.eql(u8, "__mh_execute_header", target_sym_name)) continue;
            if (mem.eql(u8, "___dso_handle", target_sym_name)) continue;

            unreachable; // referenced symbol not found
        }

        const object = zld.objects.items[target.getFile().?];
        const target_atom_index = object.getAtomIndexForSymbol(target.sym_index).?;
        log.debug("  following ATOM({d}, %{d}, {d})", .{
            target_atom_index,
            zld.getAtom(target_atom_index).sym_index,
            zld.getAtom(target_atom_index).file,
        });

        markLive(zld, target_atom_index, alive, reverse_lookups);
    }
}

fn refersLive(zld: *Zld, atom_index: AtomIndex, alive: AtomTable, reverse_lookups: [][]u32) bool {
    const atom = zld.getAtom(atom_index);
    const sym_loc = atom.getSymbolWithLoc();

    log.debug("refersLive(ATOM({d}, %{d}, {d}))", .{ atom_index, sym_loc.sym_index, sym_loc.file });

    const cpu_arch = zld.options.target.cpu.arch;

    const sym = zld.getSymbol(sym_loc);
    const header = zld.sections.items(.header)[sym.n_sect - 1];
    assert(!header.isZerofill());

    const relocs = Atom.getAtomRelocs(zld, atom_index);
    const reverse_lookup = reverse_lookups[atom.getFile().?];
    for (relocs) |rel| {
        const target = switch (cpu_arch) {
            .aarch64 => switch (@intToEnum(macho.reloc_type_arm64, rel.r_type)) {
                .ARM64_RELOC_ADDEND => continue,
                else => Atom.parseRelocTarget(zld, atom_index, rel, reverse_lookup),
            },
            .x86_64 => Atom.parseRelocTarget(zld, atom_index, rel, reverse_lookup),
            else => unreachable,
        };

        const object = zld.objects.items[target.getFile().?];
        const target_atom_index = object.getAtomIndexForSymbol(target.sym_index) orelse {
            log.debug("atom for symbol '{s}' not found; skipping...", .{zld.getSymbolName(target)});
            continue;
        };
        if (alive.contains(target_atom_index)) {
            log.debug("  refers live ATOM({d}, %{d}, {d})", .{
                target_atom_index,
                zld.getAtom(target_atom_index).sym_index,
                zld.getAtom(target_atom_index).file,
            });
            return true;
        }
    }

    return false;
}

fn mark(zld: *Zld, roots: AtomTable, alive: *AtomTable, reverse_lookups: [][]u32) void {
    var it = roots.keyIterator();
    while (it.next()) |root| {
        markLive(zld, root.*, alive, reverse_lookups);
    }

    var loop: bool = true;
    while (loop) {
        loop = false;

        for (zld.objects.items) |object| {
            for (object.atoms.items) |atom_index| {
                if (alive.contains(atom_index)) continue;

                const atom = zld.getAtom(atom_index);
                const sect_id = if (object.getSourceSymbol(atom.sym_index)) |source_sym|
                    source_sym.n_sect - 1
                else blk: {
                    const nbase = @intCast(u32, object.in_symtab.?.len);
                    const sect_id = @intCast(u16, atom.sym_index - nbase);
                    break :blk sect_id;
                };
                const source_sect = object.getSourceSection(sect_id);

                if (source_sect.isDontDeadStripIfReferencesLive()) {
                    if (refersLive(zld, atom_index, alive.*, reverse_lookups)) {
                        markLive(zld, atom_index, alive, reverse_lookups);
                        loop = true;
                    }
                }
            }
        }
    }
}

fn prune(zld: *Zld, alive: AtomTable) void {
    log.debug("pruning dead atoms", .{});
    for (zld.objects.items) |*object| {
        var i: usize = 0;
        while (i < object.atoms.items.len) {
            const atom_index = object.atoms.items[i];
            if (alive.contains(atom_index)) {
                i += 1;
                continue;
            }

            const atom = zld.getAtom(atom_index);
            const sym_loc = atom.getSymbolWithLoc();

            log.debug("prune(ATOM({d}, %{d}, {d}))", .{
                atom_index,
                sym_loc.sym_index,
                sym_loc.file,
            });
            log.debug("  {s} in {s}", .{ zld.getSymbolName(sym_loc), object.name });

            const sym = zld.getSymbolPtr(sym_loc);
            const sect_id = sym.n_sect - 1;
            var section = zld.sections.get(sect_id);
            section.header.size -= atom.size;

            if (atom.prev_index) |prev_index| {
                const prev = zld.getAtomPtr(prev_index);
                prev.next_index = atom.next_index;
            } else {
                if (atom.next_index) |next_index| {
                    section.first_atom_index = next_index;
                }
            }
            if (atom.next_index) |next_index| {
                const next = zld.getAtomPtr(next_index);
                next.prev_index = atom.prev_index;
            } else {
                if (atom.prev_index) |prev_index| {
                    section.last_atom_index = prev_index;
                } else {
                    assert(section.header.size == 0);
                    section.first_atom_index = undefined;
                    section.last_atom_index = undefined;
                }
            }

            zld.sections.set(sect_id, section);
            _ = object.atoms.swapRemove(i);

            sym.n_desc = N_DEAD;

            var inner_sym_it = Atom.getInnerSymbolsIterator(zld, atom_index);
            while (inner_sym_it.next()) |inner| {
                const inner_sym = zld.getSymbolPtr(inner);
                inner_sym.n_desc = N_DEAD;
            }

            if (Atom.getSectionAlias(zld, atom_index)) |alias| {
                const alias_sym = zld.getSymbolPtr(alias);
                alias_sym.n_desc = N_DEAD;
            }
        }
    }
}
