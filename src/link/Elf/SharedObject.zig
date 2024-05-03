path: []const u8,
index: File.Index,

header: ?elf.Elf64_Ehdr = null,
shdrs: std.ArrayListUnmanaged(elf.Elf64_Shdr) = .{},

symtab: std.ArrayListUnmanaged(elf.Elf64_Sym) = .{},
strtab: std.ArrayListUnmanaged(u8) = .{},
/// Version symtab contains version strings of the symbols if present.
versyms: std.ArrayListUnmanaged(elf.Elf64_Versym) = .{},
verstrings: std.ArrayListUnmanaged(u32) = .{},

symbols: std.ArrayListUnmanaged(Symbol.Index) = .{},
aliases: ?std.ArrayListUnmanaged(u32) = null,
dynamic_table: std.ArrayListUnmanaged(elf.Elf64_Dyn) = .{},

needed: bool,
alive: bool,

output_symtab_ctx: Elf.SymtabCtx = .{},

pub fn isSharedObject(path: []const u8) !bool {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const reader = file.reader();
    const header = reader.readStruct(elf.Elf64_Ehdr) catch return false;
    if (!mem.eql(u8, header.e_ident[0..4], "\x7fELF")) return false;
    if (header.e_ident[elf.EI_VERSION] != 1) return false;
    if (header.e_type != elf.ET.DYN) return false;
    return true;
}

pub fn deinit(self: *SharedObject, allocator: Allocator) void {
    allocator.free(self.path);
    self.shdrs.deinit(allocator);
    self.symtab.deinit(allocator);
    self.strtab.deinit(allocator);
    self.versyms.deinit(allocator);
    self.verstrings.deinit(allocator);
    self.symbols.deinit(allocator);
    if (self.aliases) |*aliases| aliases.deinit(allocator);
    self.dynamic_table.deinit(allocator);
}

pub fn parse(self: *SharedObject, elf_file: *Elf, handle: std.fs.File) !void {
    const comp = elf_file.base.comp;
    const gpa = comp.gpa;
    const file_size = (try handle.stat()).size;

    const header_buffer = try Elf.preadAllAlloc(gpa, handle, 0, @sizeOf(elf.Elf64_Ehdr));
    defer gpa.free(header_buffer);
    self.header = @as(*align(1) const elf.Elf64_Ehdr, @ptrCast(header_buffer)).*;

    const target = elf_file.base.comp.root_mod.resolved_target.result;
    if (target.cpu.arch != self.header.?.e_machine.toTargetCpuArch().?) {
        try elf_file.reportParseError2(
            self.index,
            "invalid cpu architecture: {s}",
            .{@tagName(self.header.?.e_machine.toTargetCpuArch().?)},
        );
        return error.InvalidCpuArch;
    }

    const shoff = std.math.cast(usize, self.header.?.e_shoff) orelse return error.Overflow;
    const shnum = std.math.cast(usize, self.header.?.e_shnum) orelse return error.Overflow;
    const shsize = shnum * @sizeOf(elf.Elf64_Shdr);
    if (file_size < shoff or file_size < shoff + shsize) {
        try elf_file.reportParseError2(
            self.index,
            "corrupted header: section header table extends past the end of file",
            .{},
        );
        return error.MalformedObject;
    }

    const shdrs_buffer = try Elf.preadAllAlloc(gpa, handle, shoff, shsize);
    defer gpa.free(shdrs_buffer);
    const shdrs = @as([*]align(1) const elf.Elf64_Shdr, @ptrCast(shdrs_buffer.ptr))[0..shnum];
    try self.shdrs.appendUnalignedSlice(gpa, shdrs);

    var dynsym_sect_index: ?u32 = null;
    var dynamic_sect_index: ?u32 = null;
    var versym_sect_index: ?u32 = null;
    var verdef_sect_index: ?u32 = null;
    for (self.shdrs.items, 0..) |shdr, i| {
        if (shdr.sh_type != elf.SHT_NOBITS) {
            if (file_size < shdr.sh_offset or file_size < shdr.sh_offset + shdr.sh_size) {
                try elf_file.reportParseError2(self.index, "corrupted section header", .{});
                return error.MalformedObject;
            }
        }
        switch (shdr.sh_type) {
            elf.SHT_DYNSYM => dynsym_sect_index = @intCast(i),
            elf.SHT_DYNAMIC => dynamic_sect_index = @intCast(i),
            elf.SHT_GNU_VERSYM => versym_sect_index = @intCast(i),
            elf.SHT_GNU_VERDEF => verdef_sect_index = @intCast(i),
            else => {},
        }
    }

    if (dynamic_sect_index) |index| {
        const shdr = self.shdrs.items[index];
        const raw = try Elf.preadAllAlloc(gpa, handle, shdr.sh_offset, shdr.sh_size);
        defer gpa.free(raw);
        const num = @divExact(raw.len, @sizeOf(elf.Elf64_Dyn));
        const dyntab = @as([*]align(1) const elf.Elf64_Dyn, @ptrCast(raw.ptr))[0..num];
        try self.dynamic_table.appendUnalignedSlice(gpa, dyntab);
    }

    const symtab = if (dynsym_sect_index) |index| blk: {
        const shdr = self.shdrs.items[index];
        const buffer = try Elf.preadAllAlloc(gpa, handle, shdr.sh_offset, shdr.sh_size);
        const nsyms = @divExact(buffer.len, @sizeOf(elf.Elf64_Sym));
        break :blk @as([*]align(1) const elf.Elf64_Sym, @ptrCast(buffer.ptr))[0..nsyms];
    } else &[0]elf.Elf64_Sym{};
    defer gpa.free(symtab);

    const strtab = if (dynsym_sect_index) |index| blk: {
        const symtab_shdr = self.shdrs.items[index];
        const shdr = self.shdrs.items[symtab_shdr.sh_link];
        const buffer = try Elf.preadAllAlloc(gpa, handle, shdr.sh_offset, shdr.sh_size);
        break :blk buffer;
    } else &[0]u8{};
    defer gpa.free(strtab);

    try self.parseVersions(elf_file, handle, .{
        .symtab = symtab,
        .verdef_sect_index = verdef_sect_index,
        .versym_sect_index = versym_sect_index,
    });

    try self.initSymtab(elf_file, .{
        .symtab = symtab,
        .strtab = strtab,
    });
}

fn parseVersions(self: *SharedObject, elf_file: *Elf, handle: std.fs.File, opts: struct {
    symtab: []align(1) const elf.Elf64_Sym,
    verdef_sect_index: ?u32,
    versym_sect_index: ?u32,
}) !void {
    const comp = elf_file.base.comp;
    const gpa = comp.gpa;

    try self.verstrings.resize(gpa, 2);
    self.verstrings.items[elf.VER_NDX_LOCAL] = 0;
    self.verstrings.items[elf.VER_NDX_GLOBAL] = 0;

    if (opts.verdef_sect_index) |shndx| {
        const shdr = self.shdrs.items[shndx];
        const verdefs = try Elf.preadAllAlloc(gpa, handle, shdr.sh_offset, shdr.sh_size);
        defer gpa.free(verdefs);
        const nverdefs = self.verdefNum();
        try self.verstrings.resize(gpa, self.verstrings.items.len + nverdefs);

        var i: u32 = 0;
        var offset: u32 = 0;
        while (i < nverdefs) : (i += 1) {
            const verdef = @as(*align(1) const elf.Elf64_Verdef, @ptrCast(verdefs.ptr + offset)).*;
            defer offset += verdef.vd_next;
            if (verdef.vd_flags == elf.VER_FLG_BASE) continue; // Skip BASE entry
            const vda_name = if (verdef.vd_cnt > 0)
                @as(*align(1) const elf.Elf64_Verdaux, @ptrCast(verdefs.ptr + offset + verdef.vd_aux)).vda_name
            else
                0;
            self.verstrings.items[verdef.vd_ndx] = vda_name;
        }
    }

    try self.versyms.ensureTotalCapacityPrecise(gpa, opts.symtab.len);

    if (opts.versym_sect_index) |shndx| {
        const shdr = self.shdrs.items[shndx];
        const versyms_raw = try Elf.preadAllAlloc(gpa, handle, shdr.sh_offset, shdr.sh_size);
        defer gpa.free(versyms_raw);
        const nversyms = @divExact(versyms_raw.len, @sizeOf(elf.Elf64_Versym));
        const versyms = @as([*]align(1) const elf.Elf64_Versym, @ptrCast(versyms_raw.ptr))[0..nversyms];
        for (versyms) |ver| {
            const normalized_ver = if (ver & elf.VERSYM_VERSION >= self.verstrings.items.len - 1)
                elf.VER_NDX_GLOBAL
            else
                ver;
            self.versyms.appendAssumeCapacity(normalized_ver);
        }
    } else for (0..opts.symtab.len) |_| {
        self.versyms.appendAssumeCapacity(elf.VER_NDX_GLOBAL);
    }
}

fn initSymtab(self: *SharedObject, elf_file: *Elf, opts: struct {
    symtab: []align(1) const elf.Elf64_Sym,
    strtab: []const u8,
}) !void {
    const comp = elf_file.base.comp;
    const gpa = comp.gpa;

    try self.strtab.appendSlice(gpa, opts.strtab);
    try self.symtab.ensureTotalCapacityPrecise(gpa, opts.symtab.len);
    try self.symbols.ensureTotalCapacityPrecise(gpa, opts.symtab.len);

    for (opts.symtab, 0..) |sym, i| {
        const hidden = self.versyms.items[i] & elf.VERSYM_HIDDEN != 0;
        const name = self.getString(sym.st_name);
        // We need to garble up the name so that we don't pick this symbol
        // during symbol resolution. Thank you GNU!
        const name_off = if (hidden) blk: {
            const mangled = try std.fmt.allocPrint(gpa, "{s}@{s}", .{
                name,
                self.versionString(self.versyms.items[i]),
            });
            defer gpa.free(mangled);
            const name_off = @as(u32, @intCast(self.strtab.items.len));
            try self.strtab.writer(gpa).print("{s}\x00", .{mangled});
            break :blk name_off;
        } else sym.st_name;
        const out_sym = self.symtab.addOneAssumeCapacity();
        out_sym.* = sym;
        out_sym.st_name = name_off;
        const gop = try elf_file.getOrPutGlobal(self.getString(name_off));
        self.symbols.addOneAssumeCapacity().* = gop.index;
    }
}

pub fn resolveSymbols(self: *SharedObject, elf_file: *Elf) void {
    for (self.globals(), 0..) |index, i| {
        const esym_index = @as(u32, @intCast(i));
        const this_sym = self.symtab.items[esym_index];

        if (this_sym.st_shndx == elf.SHN_UNDEF) continue;

        const global = elf_file.symbol(index);
        if (self.asFile().symbolRank(this_sym, false) < global.symbolRank(elf_file)) {
            global.value = @intCast(this_sym.st_value);
            global.atom_index = 0;
            global.esym_index = esym_index;
            global.version_index = self.versyms.items[esym_index];
            global.file_index = self.index;
        }
    }
}

pub fn markLive(self: *SharedObject, elf_file: *Elf) void {
    for (self.globals(), 0..) |index, i| {
        const sym = self.symtab.items[i];
        if (sym.st_shndx != elf.SHN_UNDEF) continue;

        const global = elf_file.symbol(index);
        const file = global.file(elf_file) orelse continue;
        const should_drop = switch (file) {
            .shared_object => |sh| !sh.needed and sym.st_bind() == elf.STB_WEAK,
            else => false,
        };
        if (!should_drop and !file.isAlive()) {
            file.setAlive();
            file.markLive(elf_file);
        }
    }
}

pub fn globals(self: SharedObject) []const Symbol.Index {
    return self.symbols.items;
}

pub fn updateSymtabSize(self: *SharedObject, elf_file: *Elf) !void {
    for (self.globals()) |global_index| {
        const global = elf_file.symbol(global_index);
        const file_ptr = global.file(elf_file) orelse continue;
        if (file_ptr.index() != self.index) continue;
        if (global.isLocal(elf_file)) continue;
        global.flags.output_symtab = true;
        try global.addExtra(.{ .symtab = self.output_symtab_ctx.nglobals }, elf_file);
        self.output_symtab_ctx.nglobals += 1;
        self.output_symtab_ctx.strsize += @as(u32, @intCast(global.name(elf_file).len)) + 1;
    }
}

pub fn writeSymtab(self: SharedObject, elf_file: *Elf) void {
    for (self.globals()) |global_index| {
        const global = elf_file.symbol(global_index);
        const file_ptr = global.file(elf_file) orelse continue;
        if (file_ptr.index() != self.index) continue;
        const idx = global.outputSymtabIndex(elf_file) orelse continue;
        const st_name = @as(u32, @intCast(elf_file.strtab.items.len));
        elf_file.strtab.appendSliceAssumeCapacity(global.name(elf_file));
        elf_file.strtab.appendAssumeCapacity(0);
        const out_sym = &elf_file.symtab.items[idx];
        out_sym.st_name = st_name;
        global.setOutputSym(elf_file, out_sym);
    }
}

pub fn versionString(self: SharedObject, index: elf.Elf64_Versym) [:0]const u8 {
    const off = self.verstrings.items[index & elf.VERSYM_VERSION];
    return self.getString(off);
}

pub fn asFile(self: *SharedObject) File {
    return .{ .shared_object = self };
}

fn verdefNum(self: *SharedObject) u32 {
    for (self.dynamic_table.items) |entry| switch (entry.d_tag) {
        elf.DT_VERDEFNUM => return @as(u32, @intCast(entry.d_val)),
        else => {},
    };
    return 0;
}

pub fn soname(self: *SharedObject) []const u8 {
    for (self.dynamic_table.items) |entry| switch (entry.d_tag) {
        elf.DT_SONAME => return self.getString(@as(u32, @intCast(entry.d_val))),
        else => {},
    };
    return std.fs.path.basename(self.path);
}

pub fn initSymbolAliases(self: *SharedObject, elf_file: *Elf) !void {
    assert(self.aliases == null);

    const SortAlias = struct {
        pub fn lessThan(ctx: *Elf, lhs: Symbol.Index, rhs: Symbol.Index) bool {
            const lhs_sym = ctx.symbol(lhs).elfSym(ctx);
            const rhs_sym = ctx.symbol(rhs).elfSym(ctx);
            return lhs_sym.st_value < rhs_sym.st_value;
        }
    };

    const comp = elf_file.base.comp;
    const gpa = comp.gpa;
    var aliases = std.ArrayList(Symbol.Index).init(gpa);
    defer aliases.deinit();
    try aliases.ensureTotalCapacityPrecise(self.globals().len);

    for (self.globals()) |index| {
        const global = elf_file.symbol(index);
        const global_file = global.file(elf_file) orelse continue;
        if (global_file.index() != self.index) continue;
        aliases.appendAssumeCapacity(index);
    }

    std.mem.sort(u32, aliases.items, elf_file, SortAlias.lessThan);

    self.aliases = aliases.moveToUnmanaged();
}

pub fn symbolAliases(self: *SharedObject, index: u32, elf_file: *Elf) []const u32 {
    assert(self.aliases != null);

    const symbol = elf_file.symbol(index).elfSym(elf_file);
    const aliases = self.aliases.?;

    const start = for (aliases.items, 0..) |alias, i| {
        const alias_sym = elf_file.symbol(alias).elfSym(elf_file);
        if (symbol.st_value == alias_sym.st_value) break i;
    } else aliases.items.len;

    const end = for (aliases.items[start..], 0..) |alias, i| {
        const alias_sym = elf_file.symbol(alias).elfSym(elf_file);
        if (symbol.st_value < alias_sym.st_value) break i + start;
    } else aliases.items.len;

    return aliases.items[start..end];
}

pub fn getString(self: SharedObject, off: u32) [:0]const u8 {
    assert(off < self.strtab.items.len);
    return mem.sliceTo(@as([*:0]const u8, @ptrCast(self.strtab.items.ptr + off)), 0);
}

pub fn format(
    self: SharedObject,
    comptime unused_fmt_string: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = self;
    _ = unused_fmt_string;
    _ = options;
    _ = writer;
    @compileError("do not format shared objects directly");
}

pub fn fmtSymtab(self: SharedObject, elf_file: *Elf) std.fmt.Formatter(formatSymtab) {
    return .{ .data = .{
        .shared = self,
        .elf_file = elf_file,
    } };
}

const FormatContext = struct {
    shared: SharedObject,
    elf_file: *Elf,
};

fn formatSymtab(
    ctx: FormatContext,
    comptime unused_fmt_string: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = unused_fmt_string;
    _ = options;
    const shared = ctx.shared;
    try writer.writeAll("  globals\n");
    for (shared.symbols.items) |index| {
        const global = ctx.elf_file.symbol(index);
        try writer.print("    {}\n", .{global.fmt(ctx.elf_file)});
    }
}

const SharedObject = @This();

const std = @import("std");
const assert = std.debug.assert;
const elf = std.elf;
const log = std.log.scoped(.elf);
const mem = std.mem;

const Allocator = mem.Allocator;
const Elf = @import("../Elf.zig");
const File = @import("file.zig").File;
const Symbol = @import("Symbol.zig");
