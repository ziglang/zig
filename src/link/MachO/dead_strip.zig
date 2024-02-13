pub fn gcAtoms(macho_file: *MachO) !void {
    const gpa = macho_file.base.comp.gpa;

    var objects = try std.ArrayList(File.Index).initCapacity(gpa, macho_file.objects.items.len + 1);
    defer objects.deinit();
    for (macho_file.objects.items) |index| objects.appendAssumeCapacity(index);
    if (macho_file.internal_object) |index| objects.appendAssumeCapacity(index);

    var roots = std.ArrayList(*Atom).init(gpa);
    defer roots.deinit();

    try collectRoots(&roots, objects.items, macho_file);
    mark(roots.items, objects.items, macho_file);
    prune(objects.items, macho_file);
}

fn collectRoots(roots: *std.ArrayList(*Atom), objects: []const File.Index, macho_file: *MachO) !void {
    for (objects) |index| {
        const object = macho_file.getFile(index).?;
        for (object.getSymbols()) |sym_index| {
            const sym = macho_file.getSymbol(sym_index);
            const file = sym.getFile(macho_file) orelse continue;
            if (file.getIndex() != index) continue;
            if (sym.flags.no_dead_strip or (macho_file.base.isDynLib() and sym.visibility == .global))
                try markSymbol(sym, roots, macho_file);
        }

        for (object.getAtoms()) |atom_index| {
            const atom = macho_file.getAtom(atom_index).?;
            const isec = atom.getInputSection(macho_file);
            switch (isec.type()) {
                macho.S_MOD_INIT_FUNC_POINTERS,
                macho.S_MOD_TERM_FUNC_POINTERS,
                => if (markAtom(atom)) try roots.append(atom),

                else => if (isec.isDontDeadStrip() and markAtom(atom)) {
                    try roots.append(atom);
                },
            }
        }
    }

    for (macho_file.objects.items) |index| {
        for (macho_file.getFile(index).?.object.unwind_records.items) |cu_index| {
            const cu = macho_file.getUnwindRecord(cu_index);
            if (!cu.alive) continue;
            if (cu.getFde(macho_file)) |fde| {
                if (fde.getCie(macho_file).getPersonality(macho_file)) |sym| try markSymbol(sym, roots, macho_file);
            } else if (cu.getPersonality(macho_file)) |sym| try markSymbol(sym, roots, macho_file);
        }
    }

    for (macho_file.undefined_symbols.items) |sym_index| {
        const sym = macho_file.getSymbol(sym_index);
        try markSymbol(sym, roots, macho_file);
    }

    for (&[_]?Symbol.Index{
        macho_file.entry_index,
        macho_file.dyld_stub_binder_index,
        macho_file.objc_msg_send_index,
    }) |index| {
        if (index) |idx| {
            const sym = macho_file.getSymbol(idx);
            try markSymbol(sym, roots, macho_file);
        }
    }
}

fn markSymbol(sym: *Symbol, roots: *std.ArrayList(*Atom), macho_file: *MachO) !void {
    const atom = sym.getAtom(macho_file) orelse return;
    if (markAtom(atom)) try roots.append(atom);
}

fn markAtom(atom: *Atom) bool {
    const already_visited = atom.flags.visited;
    atom.flags.visited = true;
    return atom.flags.alive and !already_visited;
}

fn mark(roots: []*Atom, objects: []const File.Index, macho_file: *MachO) void {
    for (roots) |root| {
        markLive(root, macho_file);
    }

    var loop: bool = true;
    while (loop) {
        loop = false;

        for (objects) |index| {
            for (macho_file.getFile(index).?.getAtoms()) |atom_index| {
                const atom = macho_file.getAtom(atom_index).?;
                const isec = atom.getInputSection(macho_file);
                if (isec.isDontDeadStripIfReferencesLive() and
                    !(mem.eql(u8, isec.sectName(), "__eh_frame") or
                    mem.eql(u8, isec.sectName(), "__compact_unwind") or
                    isec.attrs() & macho.S_ATTR_DEBUG != 0) and
                    !atom.flags.alive and refersLive(atom, macho_file))
                {
                    markLive(atom, macho_file);
                    loop = true;
                }
            }
        }
    }
}

fn markLive(atom: *Atom, macho_file: *MachO) void {
    assert(atom.flags.visited);
    atom.flags.alive = true;
    track_live_log.debug("{}marking live atom({d},{s})", .{
        track_live_level,
        atom.atom_index,
        atom.getName(macho_file),
    });

    if (build_options.enable_logging)
        track_live_level.incr();

    for (atom.getRelocs(macho_file)) |rel| {
        const target_atom = switch (rel.tag) {
            .local => rel.getTargetAtom(macho_file),
            .@"extern" => rel.getTargetSymbol(macho_file).getAtom(macho_file),
        };
        if (target_atom) |ta| {
            if (markAtom(ta)) markLive(ta, macho_file);
        }
    }

    for (atom.getUnwindRecords(macho_file)) |cu_index| {
        const cu = macho_file.getUnwindRecord(cu_index);
        const cu_atom = cu.getAtom(macho_file);
        if (markAtom(cu_atom)) markLive(cu_atom, macho_file);

        if (cu.getLsdaAtom(macho_file)) |lsda| {
            if (markAtom(lsda)) markLive(lsda, macho_file);
        }
        if (cu.getFde(macho_file)) |fde| {
            const fde_atom = fde.getAtom(macho_file);
            if (markAtom(fde_atom)) markLive(fde_atom, macho_file);

            if (fde.getLsdaAtom(macho_file)) |lsda| {
                if (markAtom(lsda)) markLive(lsda, macho_file);
            }
        }
    }
}

fn refersLive(atom: *Atom, macho_file: *MachO) bool {
    for (atom.getRelocs(macho_file)) |rel| {
        const target_atom = switch (rel.tag) {
            .local => rel.getTargetAtom(macho_file),
            .@"extern" => rel.getTargetSymbol(macho_file).getAtom(macho_file),
        };
        if (target_atom) |ta| {
            if (ta.flags.alive) return true;
        }
    }
    return false;
}

fn prune(objects: []const File.Index, macho_file: *MachO) void {
    for (objects) |index| {
        for (macho_file.getFile(index).?.getAtoms()) |atom_index| {
            const atom = macho_file.getAtom(atom_index).?;
            if (atom.flags.alive and !atom.flags.visited) {
                atom.flags.alive = false;
                atom.markUnwindRecordsDead(macho_file);
            }
        }
    }
}

const Level = struct {
    value: usize = 0,

    fn incr(self: *@This()) void {
        self.value += 1;
    }

    pub fn format(
        self: *const @This(),
        comptime unused_fmt_string: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = unused_fmt_string;
        _ = options;
        try writer.writeByteNTimes(' ', self.value);
    }
};

var track_live_level: Level = .{};

const assert = std.debug.assert;
const build_options = @import("build_options");
const log = std.log.scoped(.dead_strip);
const macho = std.macho;
const math = std.math;
const mem = std.mem;
const trace = @import("../../tracy.zig").trace;
const track_live_log = std.log.scoped(.dead_strip_track_live);
const std = @import("std");

const Allocator = mem.Allocator;
const Atom = @import("Atom.zig");
const File = @import("file.zig").File;
const MachO = @import("../MachO.zig");
const Symbol = @import("Symbol.zig");
