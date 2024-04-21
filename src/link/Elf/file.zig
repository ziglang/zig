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

    pub fn scanRelocs(file: File, elf_file: *Elf, undefs: anytype) !void {
        switch (file) {
            .linker_defined, .shared_object => unreachable,
            inline else => |x| try x.scanRelocs(elf_file, undefs),
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
            inline else => unreachable,
        };
    }

    pub fn updateArStrtab(file: File, allocator: Allocator, ar_strtab: *Archive.ArStrtab) !void {
        const path = switch (file) {
            .zig_object => |x| x.path,
            .object => |x| x.path,
            inline else => unreachable,
        };
        const state = switch (file) {
            .zig_object => |x| &x.output_ar_state,
            .object => |x| &x.output_ar_state,
            inline else => unreachable,
        };
        if (path.len <= Archive.max_member_name_len) return;
        state.name_off = try ar_strtab.insert(allocator, path);
    }

    pub fn updateArSize(file: File, elf_file: *Elf) !void {
        return switch (file) {
            .zig_object => |x| x.updateArSize(),
            .object => |x| x.updateArSize(elf_file),
            inline else => unreachable,
        };
    }

    pub fn writeAr(file: File, elf_file: *Elf, writer: anytype) !void {
        return switch (file) {
            .zig_object => |x| x.writeAr(writer),
            .object => |x| x.writeAr(elf_file, writer),
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

    pub const Handle = std.fs.File;
    pub const HandleIndex = Index;
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
