pub fn gcAtoms(elf_file: *Elf) !void {
    const comp = elf_file.base.comp;
    const gpa = comp.gpa;
    var roots = std.ArrayList(*Atom).init(gpa);
    defer roots.deinit();
    try collectRoots(&roots, elf_file);
    mark(roots, elf_file);
    prune(elf_file);
}

fn collectRoots(roots: *std.ArrayList(*Atom), elf_file: *Elf) !void {
    if (elf_file.linkerDefinedPtr()) |obj| {
        if (obj.entrySymbol(elf_file)) |sym| {
            try markSymbol(sym, roots, elf_file);
        }
    }

    if (elf_file.zigObjectPtr()) |zo| {
        for (0..zo.global_symbols.items.len) |i| {
            const ref = zo.resolveSymbol(@intCast(i | ZigObject.global_symbol_bit), elf_file);
            const sym = elf_file.symbol(ref) orelse continue;
            if (sym.file(elf_file).?.index() != zo.index) continue;
            if (sym.flags.@"export") {
                try markSymbol(sym, roots, elf_file);
            }
        }
    }

    for (elf_file.objects.items) |index| {
        const object = elf_file.file(index).?.object;
        for (0..object.globals().len) |i| {
            const ref = object.resolveSymbol(@intCast(i), elf_file);
            const sym = elf_file.symbol(ref) orelse continue;
            if (sym.file(elf_file).?.index() != object.index) continue;
            if (sym.flags.@"export") {
                try markSymbol(sym, roots, elf_file);
            }
        }
    }

    const atomRoots = struct {
        fn atomRoots(file: File, rs: anytype, ef: *Elf) !void {
            for (file.atoms()) |atom_index| {
                const atom = file.atom(atom_index) orelse continue;
                if (!atom.alive) continue;

                const shdr = atom.inputShdr(ef);
                const name = atom.name(ef);
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
                if (is_gc_root and markAtom(atom)) try rs.append(atom);
                if (shdr.sh_flags & elf.SHF_ALLOC == 0) atom.visited = true;
            }

            // Mark every atom referenced by CIE as alive.
            for (file.cies()) |cie| {
                for (cie.relocs(ef)) |rel| {
                    const ref = file.resolveSymbol(rel.r_sym(), ef);
                    const sym = ef.symbol(ref) orelse continue;
                    try markSymbol(sym, rs, ef);
                }
            }
        }
    }.atomRoots;

    if (elf_file.zigObjectPtr()) |zo| {
        try atomRoots(zo.asFile(), roots, elf_file);
    }
    for (elf_file.objects.items) |index| {
        try atomRoots(elf_file.file(index).?, roots, elf_file);
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
    const already_visited = atom.visited;
    atom.visited = true;
    return atom.alive and !already_visited;
}

fn markLive(atom: *Atom, elf_file: *Elf) void {
    if (@import("build_options").enable_logging) track_live_level.incr();

    assert(atom.visited);
    const file = atom.file(elf_file).?;

    switch (file) {
        .object => |object| {
            for (atom.fdes(object)) |fde| {
                for (fde.relocs(object)[1..]) |rel| {
                    const ref = file.resolveSymbol(rel.r_sym(), elf_file);
                    const target_sym = elf_file.symbol(ref) orelse continue;
                    const target_atom = target_sym.atom(elf_file) orelse continue;
                    target_atom.alive = true;
                    gc_track_live_log.debug("{}marking live atom({d})", .{ track_live_level, target_atom.atom_index });
                    if (markAtom(target_atom)) markLive(target_atom, elf_file);
                }
            }
        },
        else => {},
    }

    for (atom.relocs(elf_file)) |rel| {
        const ref = file.resolveSymbol(rel.r_sym(), elf_file);
        const target_sym = elf_file.symbol(ref) orelse continue;
        if (target_sym.mergeSubsection(elf_file)) |msub| {
            msub.alive = true;
            continue;
        }
        const target_atom = target_sym.atom(elf_file) orelse continue;
        target_atom.alive = true;
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

fn pruneInFile(file: File) void {
    for (file.atoms()) |atom_index| {
        const atom = file.atom(atom_index) orelse continue;
        if (atom.alive and !atom.visited) {
            atom.alive = false;
            switch (file) {
                .object => |object| atom.markFdesDead(object),
                else => {},
            }
        }
    }
}

fn prune(elf_file: *Elf) void {
    if (elf_file.zigObjectPtr()) |zo| {
        pruneInFile(zo.asFile());
    }
    for (elf_file.objects.items) |index| {
        pruneInFile(elf_file.file(index).?);
    }
}

pub fn dumpPrunedAtoms(elf_file: *Elf) !void {
    const stderr = std.io.getStdErr().writer();
    for (elf_file.objects.items) |index| {
        const file = elf_file.file(index).?;
        for (file.atoms()) |atom_index| {
            const atom = file.atom(atom_index) orelse continue;
            if (!atom.alive)
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
const ZigObject = @import("ZigObject.zig");
