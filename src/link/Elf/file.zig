pub const File = union(enum) {
    zig_object: *ZigObject,
    linker_defined: *LinkerDefined,
    object: *Object,
    shared_object: *SharedObject,

    pub fn index(file: File) Index {
        return switch (file) {
            inline else => |x| x.index,
        };
    }

    pub fn fmtPath(file: File) std.fmt.Formatter(formatPath) {
        return .{ .data = file };
    }

    fn formatPath(
        file: File,
        comptime unused_fmt_string: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = unused_fmt_string;
        _ = options;
        switch (file) {
            .zig_object => |zo| try writer.writeAll(zo.basename),
            .linker_defined => try writer.writeAll("(linker defined)"),
            .object => |x| try writer.print("{}", .{x.fmtPath()}),
            .shared_object => |x| try writer.print("{}", .{@as(Path, x.path)}),
        }
    }

    pub fn isAlive(file: File) bool {
        return switch (file) {
            .zig_object => true,
            .linker_defined => true,
            inline else => |x| x.alive,
        };
    }

    /// Encodes symbol rank so that the following ordering applies:
    /// * strong defined
    /// * weak defined
    /// * strong in lib (dso/archive)
    /// * weak in lib (dso/archive)
    /// * common
    /// * common in lib (archive)
    /// * unclaimed
    pub fn symbolRank(file: File, sym: elf.Elf64_Sym, in_archive: bool) u32 {
        const base: u3 = blk: {
            if (sym.st_shndx == elf.SHN_COMMON) break :blk if (in_archive) 6 else 5;
            if (file == .shared_object or in_archive) break :blk switch (sym.st_bind()) {
                elf.STB_GLOBAL => 3,
                else => 4,
            };
            break :blk switch (sym.st_bind()) {
                elf.STB_GLOBAL => 1,
                else => 2,
            };
        };
        return (@as(u32, base) << 24) + file.index();
    }

    pub fn resolveSymbols(file: File, elf_file: *Elf) !void {
        return switch (file) {
            inline else => |x| x.resolveSymbols(elf_file),
        };
    }

    pub fn setAlive(file: File) void {
        switch (file) {
            .zig_object, .linker_defined => {},
            inline else => |x| x.alive = true,
        }
    }

    pub fn markLive(file: File, elf_file: *Elf) void {
        switch (file) {
            .linker_defined => {},
            inline else => |x| x.markLive(elf_file),
        }
    }

    pub fn scanRelocs(file: File, elf_file: *Elf, undefs: anytype) !void {
        switch (file) {
            .linker_defined, .shared_object => unreachable,
            inline else => |x| try x.scanRelocs(elf_file, undefs),
        }
    }

    pub fn createSymbolIndirection(file: File, elf_file: *Elf) !void {
        const impl = struct {
            fn impl(sym: *Symbol, ref: Elf.Ref, ef: *Elf) !void {
                if (!sym.isLocal(ef) and !sym.flags.has_dynamic) {
                    log.debug("'{s}' is non-local", .{sym.name(ef)});
                    try ef.dynsym.addSymbol(ref, ef);
                }
                if (sym.flags.needs_got and !sym.flags.has_got) {
                    log.debug("'{s}' needs GOT", .{sym.name(ef)});
                    _ = try ef.got.addGotSymbol(ref, ef);
                }
                if (sym.flags.needs_plt) {
                    if (sym.flags.is_canonical and !sym.flags.has_plt) {
                        log.debug("'{s}' needs CPLT", .{sym.name(ef)});
                        sym.flags.@"export" = true;
                        try ef.plt.addSymbol(ref, ef);
                    } else if (sym.flags.needs_got and !sym.flags.has_pltgot) {
                        log.debug("'{s}' needs PLTGOT", .{sym.name(ef)});
                        try ef.plt_got.addSymbol(ref, ef);
                    } else if (!sym.flags.has_plt) {
                        log.debug("'{s}' needs PLT", .{sym.name(ef)});
                        try ef.plt.addSymbol(ref, ef);
                    }
                }
                if (sym.flags.needs_copy_rel and !sym.flags.has_copy_rel) {
                    log.debug("'{s}' needs COPYREL", .{sym.name(ef)});
                    try ef.copy_rel.addSymbol(ref, ef);
                }
                if (sym.flags.needs_tlsgd and !sym.flags.has_tlsgd) {
                    log.debug("'{s}' needs TLSGD", .{sym.name(ef)});
                    try ef.got.addTlsGdSymbol(ref, ef);
                }
                if (sym.flags.needs_gottp and !sym.flags.has_gottp) {
                    log.debug("'{s}' needs GOTTP", .{sym.name(ef)});
                    try ef.got.addGotTpSymbol(ref, ef);
                }
                if (sym.flags.needs_tlsdesc and !sym.flags.has_tlsdesc) {
                    log.debug("'{s}' needs TLSDESC", .{sym.name(ef)});
                    try ef.got.addTlsDescSymbol(ref, ef);
                }
            }
        }.impl;

        switch (file) {
            .zig_object => |x| {
                for (x.local_symbols.items, 0..) |idx, i| {
                    const sym = &x.symbols.items[idx];
                    const ref = x.resolveSymbol(@intCast(i), elf_file);
                    const ref_sym = elf_file.symbol(ref) orelse continue;
                    if (ref_sym.file(elf_file).?.index() != x.index) continue;
                    try impl(sym, ref, elf_file);
                }
                for (x.global_symbols.items, 0..) |idx, i| {
                    const sym = &x.symbols.items[idx];
                    const ref = x.resolveSymbol(@intCast(i | ZigObject.global_symbol_bit), elf_file);
                    const ref_sym = elf_file.symbol(ref) orelse continue;
                    if (ref_sym.file(elf_file).?.index() != x.index) continue;
                    try impl(sym, ref, elf_file);
                }
            },
            inline else => |x| {
                for (x.symbols.items, 0..) |*sym, i| {
                    const ref = x.resolveSymbol(@intCast(i), elf_file);
                    const ref_sym = elf_file.symbol(ref) orelse continue;
                    if (ref_sym.file(elf_file).?.index() != x.index) continue;
                    try impl(sym, ref, elf_file);
                }
            },
        }
    }

    pub fn atom(file: File, atom_index: Atom.Index) ?*Atom {
        return switch (file) {
            .shared_object => unreachable,
            .linker_defined => null,
            inline else => |x| x.atom(atom_index),
        };
    }

    pub fn atoms(file: File) []const Atom.Index {
        return switch (file) {
            .shared_object => unreachable,
            .linker_defined => &[0]Atom.Index{},
            .zig_object => |x| x.atoms_indexes.items,
            .object => |x| x.atoms_indexes.items,
        };
    }

    pub fn atomExtra(file: File, extra_index: u32) Atom.Extra {
        return switch (file) {
            .shared_object, .linker_defined => unreachable,
            inline else => |x| x.atomExtra(extra_index),
        };
    }

    pub fn setAtomExtra(file: File, extra_index: u32, extra: Atom.Extra) void {
        return switch (file) {
            .shared_object, .linker_defined => unreachable,
            inline else => |x| x.setAtomExtra(extra_index, extra),
        };
    }

    pub fn cies(file: File) []const Cie {
        return switch (file) {
            .zig_object => &[0]Cie{},
            .object => |x| x.cies.items,
            inline else => unreachable,
        };
    }

    pub fn comdatGroup(file: File, ind: Elf.ComdatGroup.Index) *Elf.ComdatGroup {
        return switch (file) {
            .linker_defined, .shared_object, .zig_object => unreachable,
            .object => |x| x.comdatGroup(ind),
        };
    }

    pub fn resolveSymbol(file: File, ind: Symbol.Index, elf_file: *Elf) Elf.Ref {
        return switch (file) {
            inline else => |x| x.resolveSymbol(ind, elf_file),
        };
    }

    pub fn symbol(file: File, ind: Symbol.Index) *Symbol {
        return switch (file) {
            .zig_object => |x| x.symbol(ind),
            inline else => |x| &x.symbols.items[ind],
        };
    }

    pub fn getString(file: File, off: u32) [:0]const u8 {
        return switch (file) {
            inline else => |x| x.getString(off),
        };
    }

    pub fn updateSymtabSize(file: File, elf_file: *Elf) !void {
        return switch (file) {
            inline else => |x| x.updateSymtabSize(elf_file),
        };
    }

    pub fn writeSymtab(file: File, elf_file: *Elf) void {
        return switch (file) {
            inline else => |x| x.writeSymtab(elf_file),
        };
    }

    pub fn updateArSymtab(file: File, ar_symtab: *Archive.ArSymtab, elf_file: *Elf) !void {
        return switch (file) {
            .zig_object => |x| x.updateArSymtab(ar_symtab, elf_file),
            .object => |x| x.updateArSymtab(ar_symtab, elf_file),
            else => unreachable,
        };
    }

    pub fn updateArStrtab(file: File, allocator: Allocator, ar_strtab: *Archive.ArStrtab) !void {
        switch (file) {
            .zig_object => |zo| {
                const basename = zo.basename;
                if (basename.len <= Archive.max_member_name_len) return;
                zo.output_ar_state.name_off = try ar_strtab.insert(allocator, basename);
            },
            .object => |o| {
                const basename = std.fs.path.basename(o.path.sub_path);
                if (basename.len <= Archive.max_member_name_len) return;
                o.output_ar_state.name_off = try ar_strtab.insert(allocator, basename);
            },
            else => unreachable,
        }
    }

    pub fn updateArSize(file: File, elf_file: *Elf) !void {
        return switch (file) {
            .zig_object => |x| x.updateArSize(),
            .object => |x| x.updateArSize(elf_file),
            else => unreachable,
        };
    }

    pub fn writeAr(file: File, elf_file: *Elf, writer: anytype) !void {
        return switch (file) {
            .zig_object => |x| x.writeAr(writer),
            .object => |x| x.writeAr(elf_file, writer),
            else => unreachable,
        };
    }

    pub const Index = u32;

    pub const Entry = union(enum) {
        null: void,
        zig_object: ZigObject,
        linker_defined: LinkerDefined,
        object: Object,
        shared_object: SharedObject,
    };

    pub const Handle = std.fs.File;
    pub const HandleIndex = Index;
};

const std = @import("std");
const elf = std.elf;
const log = std.log.scoped(.link);
const Path = std.Build.Cache.Path;
const Allocator = std.mem.Allocator;

const Archive = @import("Archive.zig");
const Atom = @import("Atom.zig");
const Cie = @import("eh_frame.zig").Cie;
const Elf = @import("../Elf.zig");
const LinkerDefined = @import("LinkerDefined.zig");
const Object = @import("Object.zig");
const SharedObject = @import("SharedObject.zig");
const Symbol = @import("Symbol.zig");
const ZigObject = @import("ZigObject.zig");
