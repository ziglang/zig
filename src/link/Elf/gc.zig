pub fn gcAtoms(elf_file: *Elf) !void {
    const comp = elf_file.base.comp;
    const gpa = comp.gpa;
    const num_files = elf_file.objects.items.len + @intFromBool(elf_file.zig_object_index != null);
    var files = try std.ArrayList(File.Index).initCapacity(gpa, num_files);
    defer files.deinit();
    if (elf_file.zig_object_index) |index| files.appendAssumeCapacity(index);
    for (elf_file.objects.items) |index| files.appendAssumeCapacity(index);

    var roots = std.ArrayList(*Atom).init(gpa);
    defer roots.deinit();
    try collectRoots(&roots, files.items, elf_file);

    mark(roots, elf_file);
    prune(files.items, elf_file);
}

fn collectRoots(roots: *std.ArrayList(*Atom), files: []const File.Index, elf_file: *Elf) !void {
    if (elf_file.entry_index) |index| {
        const global = elf_file.symbol(index);
        try markSymbol(global, roots, elf_file);
    }

    for (files) |index| {
        for (elf_file.file(index).?.globals()) |global_index| {
            const global = elf_file.symbol(global_index);
            if (global.file(elf_file)) |file| {
                if (file.index() == index and global.flags.@"export")
                    try markSymbol(global, roots, elf_file);
            }
        }
    }

    for (files) |index| {
        const file = elf_file.file(index).?;

        for (file.atoms()) |atom_index| {
            const atom = elf_file.atom(atom_index) orelse continue;
            if (!atom.flags.alive) continue;

            const shdr = atom.inputShdr(elf_file);
            const name = atom.name(elf_file);
            const is_gc_root = blk: {
                if (shdr.sh_flags & elf.SHF_GNU_RETAIN != 0) break :blk true;
                if (shdr.sh_type == elf.SHT_NOTE) break :blk true;
                if (shdr.sh_type == elf.SHT_PREINIT_ARRAY) break :blk true;
                if (shdr.sh_type == elf.SHT_INIT_ARRAY) break :blk true;
                if (shdr.sh_type == elf.SHT_FINI_ARRAY) break :blk true;
                if (mem.startsWith(u8, name, ".ctors")) break :blk true;
                if (mem.startsWith(u8, name, ".dtors")) break :blk true;
                if (mem.startsWith(u8, name, ".init")) break :blk true;
                if (mem.startsWith(u8, name, ".fini")) break :blk true;
                if (Elf.isCIdentifier(name)) break :blk true;
                break :blk false;
            };
            if (is_gc_root and markAtom(atom)) try roots.append(atom);
            if (shdr.sh_flags & elf.SHF_ALLOC == 0) atom.flags.visited = true;
        }

        // Mark every atom referenced by CIE as alive.
        for (file.cies()) |cie| {
            for (cie.relocs(elf_file)) |rel| {
                const sym = elf_file.symbol(file.symbol(rel.r_sym()));
                try markSymbol(sym, roots, elf_file);
            }
        }
    }
}

fn markSymbol(sym: *Symbol, roots: *std.ArrayList(*Atom), elf_file: *Elf) !void {
    if (sym.mergeSubsection(elf_file)) |msub| {
        msub.alive = true;
        return;
    }
    const atom = sym.atom(elf_file) orelse return;
    if (markAtom(atom)) try roots.append(atom);
}

fn markAtom(atom: *Atom) bool {
    const already_visited = atom.flags.visited;
    atom.flags.visited = true;
    return atom.flags.alive and !already_visited;
}

fn markLive(atom: *Atom, elf_file: *Elf) void {
    if (@import("build_options").enable_logging) track_live_level.incr();

    assert(atom.flags.visited);
    const file = atom.file(elf_file).?;

    for (atom.fdes(elf_file)) |fde| {
        for (fde.relocs(elf_file)[1..]) |rel| {
            const target_sym = elf_file.symbol(file.symbol(rel.r_sym()));
            const target_atom = target_sym.atom(elf_file) orelse continue;
            target_atom.flags.alive = true;
            gc_track_live_log.debug("{}marking live atom({d})", .{ track_live_level, target_atom.atom_index });
            if (markAtom(target_atom)) markLive(target_atom, elf_file);
        }
    }

    for (atom.relocs(elf_file)) |rel| {
        const target_sym = elf_file.symbol(file.symbol(rel.r_sym()));
        if (target_sym.mergeSubsection(elf_file)) |msub| {
            msub.alive = true;
            continue;
        }
        const target_atom = target_sym.atom(elf_file) orelse continue;
        target_atom.flags.alive = true;
        gc_track_live_log.debug("{}marking live atom({d})", .{ track_live_level, target_atom.atom_index });
        if (markAtom(target_atom)) markLive(target_atom, elf_file);
    }
}

fn mark(roots: std.ArrayList(*Atom), elf_file: *Elf) void {
    for (roots.items) |root| {
        gc_track_live_log.debug("root atom({d})", .{root.atom_index});
        markLive(root, elf_file);
    }
}

fn prune(files: []const File.Index, elf_file: *Elf) void {
    for (files) |index| {
        for (elf_file.file(index).?.atoms()) |atom_index| {
            const atom = elf_file.atom(atom_index) orelse continue;
            if (atom.flags.alive and !atom.flags.visited) {
                atom.flags.alive = false;
                atom.markFdesDead(elf_file);
            }
        }
    }
}

pub fn dumpPrunedAtoms(elf_file: *Elf) !void {
    const stderr = std.io.getStdErr().writer();
    for (elf_file.objects.items) |index| {
        for (elf_file.file(index).?.object.atoms.items) |atom_index| {
            const atom = elf_file.atom(atom_index) orelse continue;
            if (!atom.flags.alive)
                // TODO should we simply print to stderr?
                try stderr.print("link: removing unused section '{s}' in file '{}'\n", .{
                    atom.name(elf_file),
                    atom.file(elf_file).?.fmtPath(),
                });
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

const std = @import("std");
const assert = std.debug.assert;
const elf = std.elf;
const gc_track_live_log = std.log.scoped(.gc_track_live);
const mem = std.mem;

const Allocator = mem.Allocator;
const Atom = @import("Atom.zig");
const Elf = @import("../Elf.zig");
const File = @import("file.zig").File;
const Symbol = @import("Symbol.zig");
