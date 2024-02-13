pub const File = union(enum) {
    zig_object: *ZigObject,
    internal: *InternalObject,
    object: *Object,
    dylib: *Dylib,

    pub fn getIndex(file: File) Index {
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
            .zig_object => |x| try writer.writeAll(x.path),
            .internal => try writer.writeAll(""),
            .object => |x| try writer.print("{}", .{x.fmtPath()}),
            .dylib => |x| try writer.writeAll(x.path),
        }
    }

    pub fn resolveSymbols(file: File, macho_file: *MachO) void {
        switch (file) {
            .internal => unreachable,
            inline else => |x| x.resolveSymbols(macho_file),
        }
    }

    pub fn resetGlobals(file: File, macho_file: *MachO) void {
        switch (file) {
            .internal => unreachable,
            inline else => |x| x.resetGlobals(macho_file),
        }
    }

    pub fn claimUnresolved(file: File, macho_file: *MachO) error{OutOfMemory}!void {
        assert(file == .object or file == .zig_object);

        for (file.getSymbols(), 0..) |sym_index, i| {
            const nlist_idx = @as(Symbol.Index, @intCast(i));
            const nlist = switch (file) {
                .object => |x| x.symtab.items(.nlist)[nlist_idx],
                .zig_object => |x| x.symtab.items(.nlist)[nlist_idx],
                else => unreachable,
            };
            if (!nlist.ext()) continue;
            if (!nlist.undf()) continue;

            const sym = macho_file.getSymbol(sym_index);
            if (sym.getFile(macho_file) != null) continue;

            const is_import = switch (macho_file.undefined_treatment) {
                .@"error" => false,
                .warn, .suppress => nlist.weakRef(),
                .dynamic_lookup => true,
            };
            if (is_import) {
                sym.value = 0;
                sym.atom = 0;
                sym.nlist_idx = 0;
                sym.file = macho_file.internal_object.?;
                sym.flags.weak = false;
                sym.flags.weak_ref = nlist.weakRef();
                sym.flags.import = is_import;
                sym.visibility = .global;
                try macho_file.getInternalObject().?.symbols.append(macho_file.base.comp.gpa, sym_index);
            }
        }
    }

    pub fn claimUnresolvedRelocatable(file: File, macho_file: *MachO) void {
        assert(file == .object or file == .zig_object);

        for (file.getSymbols(), 0..) |sym_index, i| {
            const nlist_idx = @as(Symbol.Index, @intCast(i));
            const nlist = switch (file) {
                .object => |x| x.symtab.items(.nlist)[nlist_idx],
                .zig_object => |x| x.symtab.items(.nlist)[nlist_idx],
                else => unreachable,
            };
            if (!nlist.ext()) continue;
            if (!nlist.undf()) continue;

            const sym = macho_file.getSymbol(sym_index);
            if (sym.getFile(macho_file) != null) continue;

            sym.value = 0;
            sym.atom = 0;
            sym.nlist_idx = nlist_idx;
            sym.file = file.getIndex();
            sym.flags.weak_ref = nlist.weakRef();
            sym.flags.import = true;
            sym.visibility = .global;
        }
    }

    pub fn markImportsExports(file: File, macho_file: *MachO) void {
        assert(file == .object or file == .zig_object);

        for (file.getSymbols()) |sym_index| {
            const sym = macho_file.getSymbol(sym_index);
            const other_file = sym.getFile(macho_file) orelse continue;
            if (sym.visibility != .global) continue;
            if (other_file == .dylib and !sym.flags.abs) {
                sym.flags.import = true;
                continue;
            }
            if (other_file.getIndex() == file.getIndex()) {
                sym.flags.@"export" = true;
            }
        }
    }

    pub fn markExportsRelocatable(file: File, macho_file: *MachO) void {
        assert(file == .object or file == .zig_object);

        for (file.getSymbols()) |sym_index| {
            const sym = macho_file.getSymbol(sym_index);
            const other_file = sym.getFile(macho_file) orelse continue;
            if (sym.visibility != .global) continue;
            if (other_file.getIndex() == file.getIndex()) {
                sym.flags.@"export" = true;
            }
        }
    }

    /// Encodes symbol rank so that the following ordering applies:
    /// * strong in object
    /// * weak in object
    /// * tentative in object
    /// * strong in archive/dylib
    /// * weak in archive/dylib
    /// * tentative in archive
    /// * unclaimed
    pub fn getSymbolRank(file: File, args: struct {
        archive: bool = false,
        weak: bool = false,
        tentative: bool = false,
    }) u32 {
        if (file == .object and !args.archive) {
            const base: u32 = blk: {
                if (args.tentative) break :blk 3;
                break :blk if (args.weak) 2 else 1;
            };
            return (base << 16) + file.getIndex();
        }
        const base: u32 = blk: {
            if (args.tentative) break :blk 3;
            break :blk if (args.weak) 2 else 1;
        };
        return base + (file.getIndex() << 24);
    }

    pub fn getSymbols(file: File) []const Symbol.Index {
        return switch (file) {
            inline else => |x| x.symbols.items,
        };
    }

    pub fn getAtoms(file: File) []const Atom.Index {
        return switch (file) {
            .dylib => unreachable,
            inline else => |x| x.atoms.items,
        };
    }

    pub fn updateArSymtab(file: File, ar_symtab: *Archive.ArSymtab, macho_file: *MachO) error{OutOfMemory}!void {
        return switch (file) {
            .dylib, .internal => unreachable,
            inline else => |x| x.updateArSymtab(ar_symtab, macho_file),
        };
    }

    pub fn updateArSize(file: File, macho_file: *MachO) !void {
        return switch (file) {
            .dylib, .internal => unreachable,
            .zig_object => |x| x.updateArSize(),
            .object => |x| x.updateArSize(macho_file),
        };
    }

    pub fn writeAr(file: File, ar_format: Archive.Format, macho_file: *MachO, writer: anytype) !void {
        return switch (file) {
            .dylib, .internal => unreachable,
            .zig_object => |x| x.writeAr(ar_format, writer),
            .object => |x| x.writeAr(ar_format, macho_file, writer),
        };
    }

    pub fn calcSymtabSize(file: File, macho_file: *MachO) !void {
        return switch (file) {
            inline else => |x| x.calcSymtabSize(macho_file),
        };
    }

    pub fn writeSymtab(file: File, macho_file: *MachO, ctx: anytype) !void {
        return switch (file) {
            inline else => |x| x.writeSymtab(macho_file, ctx),
        };
    }

    pub const Index = u32;

    pub const Entry = union(enum) {
        null: void,
        zig_object: ZigObject,
        internal: InternalObject,
        object: Object,
        dylib: Dylib,
    };

    pub const Handle = std.fs.File;
    pub const HandleIndex = Index;
};

const assert = std.debug.assert;
const macho = std.macho;
const std = @import("std");

const Allocator = std.mem.Allocator;
const Archive = @import("Archive.zig");
const Atom = @import("Atom.zig");
const InternalObject = @import("InternalObject.zig");
const MachO = @import("../MachO.zig");
const Object = @import("Object.zig");
const Dylib = @import("Dylib.zig");
const Symbol = @import("Symbol.zig");
const ZigObject = @import("ZigObject.zig");
