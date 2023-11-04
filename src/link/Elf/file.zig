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
            .zig_object => |x| try writer.print("{s}", .{x.path}),
            .linker_defined => try writer.writeAll("(linker defined)"),
            .object => |x| try writer.print("{}", .{x.fmtPath()}),
            .shared_object => |x| try writer.writeAll(x.path),
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

    pub fn resolveSymbols(file: File, elf_file: *Elf) void {
        switch (file) {
            inline else => |x| x.resolveSymbols(elf_file),
        }
    }

    pub fn resetGlobals(file: File, elf_file: *Elf) void {
        for (file.globals()) |global_index| {
            const global = elf_file.symbol(global_index);
            const name_offset = global.name_offset;
            global.* = .{};
            global.name_offset = name_offset;
            global.flags.global = true;
        }
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

    pub fn atoms(file: File) []const Atom.Index {
        return switch (file) {
            .linker_defined, .shared_object => &[0]Atom.Index{},
            .zig_object => |x| x.atoms.items,
            .object => |x| x.atoms.items,
        };
    }

    pub fn cies(file: File) []const Cie {
        return switch (file) {
            .zig_object => &[0]Cie{},
            .object => |x| x.cies.items,
            inline else => unreachable,
        };
    }

    pub fn symbol(file: File, ind: Symbol.Index) Symbol.Index {
        return switch (file) {
            .zig_object => |x| x.symbol(ind),
            inline else => |x| x.symbols.items[ind],
        };
    }

    pub fn locals(file: File) []const Symbol.Index {
        return switch (file) {
            .linker_defined, .shared_object => &[0]Symbol.Index{},
            inline else => |x| x.locals(),
        };
    }

    pub fn globals(file: File) []const Symbol.Index {
        return switch (file) {
            inline else => |x| x.globals(),
        };
    }

    pub fn updateSymtabSize(file: File, elf_file: *Elf) void {
        const output_symtab_size = switch (file) {
            inline else => |x| &x.output_symtab_size,
        };
        for (file.locals()) |local_index| {
            const local = elf_file.symbol(local_index);
            if (local.atom(elf_file)) |atom| if (!atom.flags.alive) continue;
            const esym = local.elfSym(elf_file);
            switch (esym.st_type()) {
                elf.STT_SECTION => if (!elf_file.isRelocatable()) continue,
                elf.STT_NOTYPE => continue,
                else => {},
            }
            local.flags.output_symtab = true;
            output_symtab_size.nlocals += 1;
            output_symtab_size.strsize += @as(u32, @intCast(local.name(elf_file).len)) + 1;
        }

        for (file.globals()) |global_index| {
            const global = elf_file.symbol(global_index);
            const file_ptr = global.file(elf_file) orelse continue;
            if (file_ptr.index() != file.index()) continue;
            if (global.atom(elf_file)) |atom| if (!atom.flags.alive) continue;
            global.flags.output_symtab = true;
            if (global.isLocal(elf_file)) {
                output_symtab_size.nlocals += 1;
            } else {
                output_symtab_size.nglobals += 1;
            }
            output_symtab_size.strsize += @as(u32, @intCast(global.name(elf_file).len)) + 1;
        }
    }

    pub fn writeSymtab(file: File, elf_file: *Elf, ctx: anytype) void {
        var ilocal = ctx.ilocal;
        for (file.locals()) |local_index| {
            const local = elf_file.symbol(local_index);
            if (!local.flags.output_symtab) continue;
            const out_sym = &elf_file.symtab.items[ilocal];
            out_sym.st_name = @intCast(elf_file.strtab.items.len);
            elf_file.strtab.appendSliceAssumeCapacity(local.name(elf_file));
            elf_file.strtab.appendAssumeCapacity(0);
            local.setOutputSym(elf_file, out_sym);
            ilocal += 1;
        }

        var iglobal = ctx.iglobal;
        for (file.globals()) |global_index| {
            const global = elf_file.symbol(global_index);
            const file_ptr = global.file(elf_file) orelse continue;
            if (file_ptr.index() != file.index()) continue;
            if (!global.flags.output_symtab) continue;
            const st_name = @as(u32, @intCast(elf_file.strtab.items.len));
            elf_file.strtab.appendSliceAssumeCapacity(global.name(elf_file));
            elf_file.strtab.appendAssumeCapacity(0);
            if (global.isLocal(elf_file)) {
                const out_sym = &elf_file.symtab.items[ilocal];
                out_sym.st_name = st_name;
                global.setOutputSym(elf_file, out_sym);
                ilocal += 1;
            } else {
                const out_sym = &elf_file.symtab.items[iglobal];
                out_sym.st_name = st_name;
                global.setOutputSym(elf_file, out_sym);
                iglobal += 1;
            }
        }
    }

    pub fn updateArSymtab(file: File, ar_symtab: *Archive.ArSymtab, elf_file: *Elf) !void {
        return switch (file) {
            .zig_object => |x| x.updateArSymtab(ar_symtab, elf_file),
            .object => @panic("TODO"),
            inline else => unreachable,
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
};

const std = @import("std");
const elf = std.elf;

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
