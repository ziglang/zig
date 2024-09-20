path: []const u8,
index: File.Index,

header: ?elf.Elf64_Ehdr = null,
shdrs: std.ArrayListUnmanaged(elf.Elf64_Shdr) = .empty,

symtab: std.ArrayListUnmanaged(elf.Elf64_Sym) = .empty,
strtab: std.ArrayListUnmanaged(u8) = .empty,
/// Version symtab contains version strings of the symbols if present.
versyms: std.ArrayListUnmanaged(elf.Elf64_Versym) = .empty,
verstrings: std.ArrayListUnmanaged(u32) = .empty,

symbols: std.ArrayListUnmanaged(Symbol) = .empty,
symbols_extra: std.ArrayListUnmanaged(u32) = .empty,
symbols_resolver: std.ArrayListUnmanaged(Elf.SymbolResolver.Index) = .empty,

aliases: ?std.ArrayListUnmanaged(u32) = null,
dynamic_table: std.ArrayListUnmanaged(elf.Elf64_Dyn) = .empty,

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
    self.symbols_extra.deinit(allocator);
    self.symbols_resolver.deinit(allocator);
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

    const em = elf_file.base.comp.root_mod.resolved_target.result.toElfMachine();
    if (em != self.header.?.e_machine) {
        try elf_file.reportParseError2(
            self.index,
            "invalid ELF machine type: {s}",
            .{@tagName(self.header.?.e_machine)},
        );
        return error.InvalidMachineType;
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

    try self.initSymbols(elf_file, .{
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

fn initSymbols(self: *SharedObject, elf_file: *Elf, opts: struct {
    symtab: []align(1) const elf.Elf64_Sym,
    strtab: []const u8,
}) !void {
    const gpa = elf_file.base.comp.gpa;
    const nsyms = opts.symtab.len;

    try self.strtab.appendSlice(gpa, opts.strtab);
    try self.symtab.ensureTotalCapacityPrecise(gpa, nsyms);
    try self.symbols.ensureTotalCapacityPrecise(gpa, nsyms);
    try self.symbols_extra.ensureTotalCapacityPrecise(gpa, nsyms * @sizeOf(Symbol.Extra));
    try self.symbols_resolver.ensureTotalCapacityPrecise(gpa, nsyms);
    self.symbols_resolver.resize(gpa, nsyms) catch unreachable;
    @memset(self.symbols_resolver.items, 0);

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
            break :blk try self.addString(gpa, mangled);
        } else sym.st_name;
        const out_esym_index: u32 = @intCast(self.symtab.items.len);
        const out_esym = self.symtab.addOneAssumeCapacity();
        out_esym.* = sym;
        out_esym.st_name = name_off;
        const out_sym_index = self.addSymbolAssumeCapacity();
        const out_sym = &self.symbols.items[out_sym_index];
        out_sym.value = @intCast(out_esym.st_value);
        out_sym.name_offset = name_off;
        out_sym.ref = .{ .index = 0, .file = 0 };
        out_sym.esym_index = out_esym_index;
        out_sym.version_index = self.versyms.items[out_esym_index];
        out_sym.extra_index = self.addSymbolExtraAssumeCapacity(.{});
    }
}

pub fn resolveSymbols(self: *SharedObject, elf_file: *Elf) !void {
    const gpa = elf_file.base.comp.gpa;

    for (self.symtab.items, self.symbols_resolver.items, 0..) |esym, *resolv, i| {
        const gop = try elf_file.resolver.getOrPut(gpa, .{
            .index = @intCast(i),
            .file = self.index,
        }, elf_file);
        if (!gop.found_existing) {
            gop.ref.* = .{ .index = 0, .file = 0 };
        }
        resolv.* = gop.index;

        if (esym.st_shndx == elf.SHN_UNDEF) continue;
        if (elf_file.symbol(gop.ref.*) == null) {
            gop.ref.* = .{ .index = @intCast(i), .file = self.index };
            continue;
        }

        if (self.asFile().symbolRank(esym, false) < elf_file.symbol(gop.ref.*).?.symbolRank(elf_file)) {
            gop.ref.* = .{ .index = @intCast(i), .file = self.index };
        }
    }
}

pub fn markLive(self: *SharedObject, elf_file: *Elf) void {
    for (self.symtab.items, 0..) |esym, i| {
        if (esym.st_shndx != elf.SHN_UNDEF) continue;

        const ref = self.resolveSymbol(@intCast(i), elf_file);
        const sym = elf_file.symbol(ref) orelse continue;
        const file = sym.file(elf_file).?;
        const should_drop = switch (file) {
            .shared_object => |sh| !sh.needed and esym.st_bind() == elf.STB_WEAK,
            else => false,
        };
        if (!should_drop and !file.isAlive()) {
            file.setAlive();
            file.markLive(elf_file);
        }
    }
}

pub fn markImportExports(self: *SharedObject, elf_file: *Elf) void {
    for (0..self.symbols.items.len) |i| {
        const ref = self.resolveSymbol(@intCast(i), elf_file);
        const ref_sym = elf_file.symbol(ref) orelse continue;
        const ref_file = ref_sym.file(elf_file).?;
        const vis = @as(elf.STV, @enumFromInt(ref_sym.elfSym(elf_file).st_other));
        if (ref_file != .shared_object and vis != .HIDDEN) ref_sym.flags.@"export" = true;
    }
}

pub fn updateSymtabSize(self: *SharedObject, elf_file: *Elf) void {
    for (self.symbols.items, self.symbols_resolver.items) |*global, resolv| {
        const ref = elf_file.resolver.get(resolv).?;
        const ref_sym = elf_file.symbol(ref) orelse continue;
        if (ref_sym.file(elf_file).?.index() != self.index) continue;
        if (global.isLocal(elf_file)) continue;
        global.flags.output_symtab = true;
        global.addExtra(.{ .symtab = self.output_symtab_ctx.nglobals }, elf_file);
        self.output_symtab_ctx.nglobals += 1;
        self.output_symtab_ctx.strsize += @as(u32, @intCast(global.name(elf_file).len)) + 1;
    }
}

pub fn writeSymtab(self: *SharedObject, elf_file: *Elf) void {
    for (self.symbols.items, self.symbols_resolver.items) |global, resolv| {
        const ref = elf_file.resolver.get(resolv).?;
        const ref_sym = elf_file.symbol(ref) orelse continue;
        if (ref_sym.file(elf_file).?.index() != self.index) continue;
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
        so: *SharedObject,
        ef: *Elf,

        pub fn lessThan(ctx: @This(), lhs: Symbol.Index, rhs: Symbol.Index) bool {
            const lhs_sym = ctx.so.symbols.items[lhs].elfSym(ctx.ef);
            const rhs_sym = ctx.so.symbols.items[rhs].elfSym(ctx.ef);
            return lhs_sym.st_value < rhs_sym.st_value;
        }
    };

    const comp = elf_file.base.comp;
    const gpa = comp.gpa;
    var aliases = std.ArrayList(Symbol.Index).init(gpa);
    defer aliases.deinit();
    try aliases.ensureTotalCapacityPrecise(self.symbols.items.len);

    for (self.symbols_resolver.items, 0..) |resolv, index| {
        const ref = elf_file.resolver.get(resolv).?;
        const ref_sym = elf_file.symbol(ref) orelse continue;
        if (ref_sym.file(elf_file).?.index() != self.index) continue;
        aliases.appendAssumeCapacity(@intCast(index));
    }

    std.mem.sort(u32, aliases.items, SortAlias{ .so = self, .ef = elf_file }, SortAlias.lessThan);

    self.aliases = aliases.moveToUnmanaged();
}

pub fn symbolAliases(self: *SharedObject, index: u32, elf_file: *Elf) []const u32 {
    assert(self.aliases != null);

    const symbol = self.symbols.items[index].elfSym(elf_file);
    const aliases = self.aliases.?;

    const start = for (aliases.items, 0..) |alias, i| {
        const alias_sym = self.symbols.items[alias].elfSym(elf_file);
        if (symbol.st_value == alias_sym.st_value) break i;
    } else aliases.items.len;

    const end = for (aliases.items[start..], 0..) |alias, i| {
        const alias_sym = self.symbols.items[alias].elfSym(elf_file);
        if (symbol.st_value < alias_sym.st_value) break i + start;
    } else aliases.items.len;

    return aliases.items[start..end];
}

fn addString(self: *SharedObject, allocator: Allocator, str: []const u8) !u32 {
    const off: u32 = @intCast(self.strtab.items.len);
    try self.strtab.ensureUnusedCapacity(allocator, str.len + 1);
    self.strtab.appendSliceAssumeCapacity(str);
    self.strtab.appendAssumeCapacity(0);
    return off;
}

pub fn getString(self: SharedObject, off: u32) [:0]const u8 {
    assert(off < self.strtab.items.len);
    return mem.sliceTo(@as([*:0]const u8, @ptrCast(self.strtab.items.ptr + off)), 0);
}

pub fn resolveSymbol(self: SharedObject, index: Symbol.Index, elf_file: *Elf) Elf.Ref {
    const resolv = self.symbols_resolver.items[index];
    return elf_file.resolver.get(resolv).?;
}

fn addSymbol(self: *SharedObject, allocator: Allocator) !Symbol.Index {
    try self.symbols.ensureUnusedCapacity(allocator, 1);
    return self.addSymbolAssumeCapacity();
}

fn addSymbolAssumeCapacity(self: *SharedObject) Symbol.Index {
    const index: Symbol.Index = @intCast(self.symbols.items.len);
    self.symbols.appendAssumeCapacity(.{ .file_index = self.index });
    return index;
}

pub fn addSymbolExtra(self: *SharedObject, allocator: Allocator, extra: Symbol.Extra) !u32 {
    const fields = @typeInfo(Symbol.Extra).@"struct".fields;
    try self.symbols_extra.ensureUnusedCapacity(allocator, fields.len);
    return self.addSymbolExtraAssumeCapacity(extra);
}

pub fn addSymbolExtraAssumeCapacity(self: *SharedObject, extra: Symbol.Extra) u32 {
    const index = @as(u32, @intCast(self.symbols_extra.items.len));
    const fields = @typeInfo(Symbol.Extra).@"struct".fields;
    inline for (fields) |field| {
        self.symbols_extra.appendAssumeCapacity(switch (field.type) {
            u32 => @field(extra, field.name),
            else => @compileError("bad field type"),
        });
    }
    return index;
}

pub fn symbolExtra(self: *SharedObject, index: u32) Symbol.Extra {
    const fields = @typeInfo(Symbol.Extra).@"struct".fields;
    var i: usize = index;
    var result: Symbol.Extra = undefined;
    inline for (fields) |field| {
        @field(result, field.name) = switch (field.type) {
            u32 => self.symbols_extra.items[i],
            else => @compileError("bad field type"),
        };
        i += 1;
    }
    return result;
}

pub fn setSymbolExtra(self: *SharedObject, index: u32, extra: Symbol.Extra) void {
    const fields = @typeInfo(Symbol.Extra).@"struct".fields;
    inline for (fields, 0..) |field, i| {
        self.symbols_extra.items[index + i] = switch (field.type) {
            u32 => @field(extra, field.name),
            else => @compileError("bad field type"),
        };
    }
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
    const elf_file = ctx.elf_file;
    try writer.writeAll("  globals\n");
    for (shared.symbols.items, 0..) |sym, i| {
        const ref = shared.resolveSymbol(@intCast(i), elf_file);
        if (elf_file.symbol(ref)) |ref_sym| {
            try writer.print("    {}\n", .{ref_sym.fmt(elf_file)});
        } else {
            try writer.print("    {s} : unclaimed\n", .{sym.name(elf_file)});
        }
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
