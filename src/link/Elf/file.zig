pub const File = union(enum) {
    zig_module: *ZigModule,
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
            .zig_module => |x| try writer.print("{s}", .{x.path}),
            .linker_defined => try writer.writeAll("(linker defined)"),
            .object => |x| try writer.print("{}", .{x.fmtPath()}),
            .shared_object => |x| try writer.writeAll(x.path),
        }
    }

    pub fn isAlive(file: File) bool {
        return switch (file) {
            .zig_module => true,
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
        switch (file) {
            .linker_defined => unreachable,
            inline else => |x| x.resetGlobals(elf_file),
        }
    }

    pub fn setAlive(file: File) void {
        switch (file) {
            .zig_module, .linker_defined => {},
            inline else => |x| x.alive = true,
        }
    }

    pub fn markLive(file: File, elf_file: *Elf) void {
        switch (file) {
            .linker_defined => unreachable,
            inline else => |x| x.markLive(elf_file),
        }
    }

    pub fn atoms(file: File) []const Atom.Index {
        return switch (file) {
            .linker_defined => unreachable,
            .shared_object => unreachable,
            .zig_module => |x| x.atoms.items,
            .object => |x| x.atoms.items,
        };
    }

    pub fn locals(file: File) []const Symbol.Index {
        return switch (file) {
            .linker_defined => unreachable,
            .shared_object => unreachable,
            inline else => |x| x.locals(),
        };
    }

    pub fn globals(file: File) []const Symbol.Index {
        return switch (file) {
            inline else => |x| x.globals(),
        };
    }

    pub const Index = u32;

    pub const Entry = union(enum) {
        null: void,
        zig_module: ZigModule,
        linker_defined: LinkerDefined,
        object: Object,
        shared_object: SharedObject,
    };
};

const std = @import("std");
const elf = std.elf;

const Allocator = std.mem.Allocator;
const Atom = @import("Atom.zig");
const Elf = @import("../Elf.zig");
const LinkerDefined = @import("LinkerDefined.zig");
const Object = @import("Object.zig");
const SharedObject = @import("SharedObject.zig");
const Symbol = @import("Symbol.zig");
const ZigModule = @import("ZigModule.zig");
