path: Path,
index: File.Index,

parsed: Parsed,

symbols: std.ArrayListUnmanaged(Symbol),
symbols_extra: std.ArrayListUnmanaged(u32),
symbols_resolver: std.ArrayListUnmanaged(Elf.SymbolResolver.Index),

aliases: ?std.ArrayListUnmanaged(u32),

needed: bool,
alive: bool,

output_symtab_ctx: Elf.SymtabCtx,

pub fn deinit(so: *SharedObject, gpa: Allocator) void {
    gpa.free(so.path.sub_path);
    so.parsed.deinit(gpa);
    so.symbols.deinit(gpa);
    so.symbols_extra.deinit(gpa);
    so.symbols_resolver.deinit(gpa);
    if (so.aliases) |*aliases| aliases.deinit(gpa);
    so.* = undefined;
}

pub const Header = struct {
    dynamic_table: []const elf.Elf64_Dyn,
    soname_index: ?u32,
    verdefnum: ?u32,

    sections: []const elf.Elf64_Shdr,
    dynsym_sect_index: ?u32,
    versym_sect_index: ?u32,
    verdef_sect_index: ?u32,

    stat: Stat,
    strtab: std.ArrayListUnmanaged(u8),

    pub fn deinit(header: *Header, gpa: Allocator) void {
        gpa.free(header.sections);
        gpa.free(header.dynamic_table);
        header.strtab.deinit(gpa);
        header.* = undefined;
    }

    pub fn soname(header: Header) ?[]const u8 {
        const i = header.soname_index orelse return null;
        return Elf.stringTableLookup(header.strtab.items, i);
    }
};

pub const Parsed = struct {
    stat: Stat,
    strtab: []const u8,
    soname_index: ?u32,
    sections: []const elf.Elf64_Shdr,

    /// Nonlocal symbols only.
    symtab: []const elf.Elf64_Sym,
    /// Version symtab contains version strings of the symbols if present.
    /// Nonlocal symbols only.
    versyms: []const elf.Versym,
    /// Nonlocal symbols only.
    symbols: []const Parsed.Symbol,

    verstrings: []const u32,

    const Symbol = struct {
        mangled_name: u32,
    };

    pub fn deinit(p: *Parsed, gpa: Allocator) void {
        gpa.free(p.strtab);
        gpa.free(p.symtab);
        gpa.free(p.versyms);
        gpa.free(p.symbols);
        gpa.free(p.verstrings);
        p.* = undefined;
    }

    pub fn versionString(p: Parsed, index: elf.Versym) [:0]const u8 {
        return versionStringLookup(p.strtab, p.verstrings, index);
    }

    pub fn soname(p: Parsed) ?[]const u8 {
        const i = p.soname_index orelse return null;
        return Elf.stringTableLookup(p.strtab, i);
    }
};

pub fn parseHeader(
    gpa: Allocator,
    diags: *Diags,
    file_path: Path,
    fs_file: std.fs.File,
    stat: Stat,
    target: std.Target,
) !Header {
    var ehdr: elf.Elf64_Ehdr = undefined;
    {
        const buf = mem.asBytes(&ehdr);
        const amt = try fs_file.preadAll(buf, 0);
        if (amt != buf.len) return error.UnexpectedEndOfFile;
    }
    if (!mem.eql(u8, ehdr.e_ident[0..4], "\x7fELF")) return error.BadMagic;
    if (ehdr.e_ident[elf.EI_VERSION] != 1) return error.BadElfVersion;
    if (ehdr.e_type != elf.ET.DYN) return error.NotSharedObject;

    if (target.toElfMachine() != ehdr.e_machine)
        return diags.failParse(file_path, "invalid ELF machine type: {s}", .{@tagName(ehdr.e_machine)});

    const shoff = std.math.cast(usize, ehdr.e_shoff) orelse return error.Overflow;
    const shnum = std.math.cast(u32, ehdr.e_shnum) orelse return error.Overflow;

    const sections = try gpa.alloc(elf.Elf64_Shdr, shnum);
    errdefer gpa.free(sections);
    {
        const buf = mem.sliceAsBytes(sections);
        const amt = try fs_file.preadAll(buf, shoff);
        if (amt != buf.len) return error.UnexpectedEndOfFile;
    }

    var dynsym_sect_index: ?u32 = null;
    var dynamic_sect_index: ?u32 = null;
    var versym_sect_index: ?u32 = null;
    var verdef_sect_index: ?u32 = null;
    for (sections, 0..) |shdr, i_usize| {
        const i: u32 = @intCast(i_usize);
        switch (shdr.sh_type) {
            elf.SHT_DYNSYM => dynsym_sect_index = i,
            elf.SHT_DYNAMIC => dynamic_sect_index = i,
            elf.SHT_GNU_VERSYM => versym_sect_index = i,
            elf.SHT_GNU_VERDEF => verdef_sect_index = i,
            else => continue,
        }
    }

    const dynamic_table: []elf.Elf64_Dyn = if (dynamic_sect_index) |index| dt: {
        const shdr = sections[index];
        const n = std.math.cast(usize, shdr.sh_size / @sizeOf(elf.Elf64_Dyn)) orelse return error.Overflow;
        const dynamic_table = try gpa.alloc(elf.Elf64_Dyn, n);
        errdefer gpa.free(dynamic_table);
        const buf = mem.sliceAsBytes(dynamic_table);
        const amt = try fs_file.preadAll(buf, shdr.sh_offset);
        if (amt != buf.len) return error.UnexpectedEndOfFile;
        break :dt dynamic_table;
    } else &.{};
    errdefer gpa.free(dynamic_table);

    var strtab: std.ArrayListUnmanaged(u8) = .empty;
    errdefer strtab.deinit(gpa);

    if (dynsym_sect_index) |index| {
        const dynsym_shdr = sections[index];
        if (dynsym_shdr.sh_link >= sections.len) return error.BadStringTableIndex;
        const strtab_shdr = sections[dynsym_shdr.sh_link];
        const n = std.math.cast(usize, strtab_shdr.sh_size) orelse return error.Overflow;
        const buf = try strtab.addManyAsSlice(gpa, n);
        const amt = try fs_file.preadAll(buf, strtab_shdr.sh_offset);
        if (amt != buf.len) return error.UnexpectedEndOfFile;
    }

    var soname_index: ?u32 = null;
    var verdefnum: ?u32 = null;
    for (dynamic_table) |entry| switch (entry.d_tag) {
        elf.DT_SONAME => {
            if (entry.d_val >= strtab.items.len) return error.BadSonameIndex;
            soname_index = @intCast(entry.d_val);
        },
        elf.DT_VERDEFNUM => {
            verdefnum = @intCast(entry.d_val);
        },
        else => continue,
    };

    return .{
        .dynamic_table = dynamic_table,
        .soname_index = soname_index,
        .verdefnum = verdefnum,
        .sections = sections,
        .dynsym_sect_index = dynsym_sect_index,
        .versym_sect_index = versym_sect_index,
        .verdef_sect_index = verdef_sect_index,
        .strtab = strtab,
        .stat = stat,
    };
}

pub fn parse(
    gpa: Allocator,
    /// Moves resources from header. Caller may unconditionally deinit.
    header: *Header,
    fs_file: std.fs.File,
) !Parsed {
    const symtab = if (header.dynsym_sect_index) |index| st: {
        const shdr = header.sections[index];
        const n = std.math.cast(usize, shdr.sh_size / @sizeOf(elf.Elf64_Sym)) orelse return error.Overflow;
        const symtab = try gpa.alloc(elf.Elf64_Sym, n);
        errdefer gpa.free(symtab);
        const buf = mem.sliceAsBytes(symtab);
        const amt = try fs_file.preadAll(buf, shdr.sh_offset);
        if (amt != buf.len) return error.UnexpectedEndOfFile;
        break :st symtab;
    } else &.{};
    defer gpa.free(symtab);

    var verstrings: std.ArrayListUnmanaged(u32) = .empty;
    defer verstrings.deinit(gpa);

    if (header.verdef_sect_index) |shndx| {
        const shdr = header.sections[shndx];
        const verdefs = try Elf.preadAllAlloc(gpa, fs_file, shdr.sh_offset, shdr.sh_size);
        defer gpa.free(verdefs);

        var offset: u32 = 0;
        while (true) {
            const verdef = mem.bytesAsValue(elf.Verdef, verdefs[offset..][0..@sizeOf(elf.Verdef)]);
            if (verdef.ndx == .UNSPECIFIED) return error.VerDefSymbolTooLarge;

            if (verstrings.items.len <= @intFromEnum(verdef.ndx))
                try verstrings.appendNTimes(gpa, 0, @intFromEnum(verdef.ndx) + 1 - verstrings.items.len);

            const aux = mem.bytesAsValue(elf.Verdaux, verdefs[offset + verdef.aux ..][0..@sizeOf(elf.Verdaux)]);
            verstrings.items[@intFromEnum(verdef.ndx)] = aux.name;

            if (verdef.next == 0) break;
            offset += verdef.next;
        }
    }

    const versyms = if (header.versym_sect_index) |versym_sect_index| vs: {
        const shdr = header.sections[versym_sect_index];
        if (shdr.sh_size != symtab.len * @sizeOf(elf.Versym)) return error.BadVerSymSectionSize;

        const versyms = try gpa.alloc(elf.Versym, symtab.len);
        errdefer gpa.free(versyms);
        const buf = mem.sliceAsBytes(versyms);
        const amt = try fs_file.preadAll(buf, shdr.sh_offset);
        if (amt != buf.len) return error.UnexpectedEndOfFile;
        break :vs versyms;
    } else &.{};
    defer gpa.free(versyms);

    var nonlocal_esyms: std.ArrayListUnmanaged(elf.Elf64_Sym) = .empty;
    defer nonlocal_esyms.deinit(gpa);

    var nonlocal_versyms: std.ArrayListUnmanaged(elf.Versym) = .empty;
    defer nonlocal_versyms.deinit(gpa);

    var nonlocal_symbols: std.ArrayListUnmanaged(Parsed.Symbol) = .empty;
    defer nonlocal_symbols.deinit(gpa);

    var strtab = header.strtab;
    header.strtab = .empty;
    defer strtab.deinit(gpa);

    for (symtab, 0..) |sym, i| {
        const ver: elf.Versym = if (versyms.len == 0 or sym.st_shndx == elf.SHN_UNDEF)
            .GLOBAL
        else
            .{ .VERSION = versyms[i].VERSION, .HIDDEN = false };

        // https://github.com/ziglang/zig/issues/21678
        //if (ver == .LOCAL) continue;
        if (@as(u16, @bitCast(ver)) == 0) continue;

        try nonlocal_esyms.ensureUnusedCapacity(gpa, 1);
        try nonlocal_versyms.ensureUnusedCapacity(gpa, 1);
        try nonlocal_symbols.ensureUnusedCapacity(gpa, 1);

        const name = Elf.stringTableLookup(strtab.items, sym.st_name);
        const is_default = versyms.len == 0 or !versyms[i].HIDDEN;
        const mangled_name = if (is_default) sym.st_name else mn: {
            const off: u32 = @intCast(strtab.items.len);
            const version_string = versionStringLookup(strtab.items, verstrings.items, versyms[i]);
            try strtab.ensureUnusedCapacity(gpa, name.len + version_string.len + 2);
            // Reload since the string table might have been resized.
            const name2 = Elf.stringTableLookup(strtab.items, sym.st_name);
            const version_string2 = versionStringLookup(strtab.items, verstrings.items, versyms[i]);
            strtab.appendSliceAssumeCapacity(name2);
            strtab.appendAssumeCapacity('@');
            strtab.appendSliceAssumeCapacity(version_string2);
            strtab.appendAssumeCapacity(0);
            break :mn off;
        };

        nonlocal_esyms.appendAssumeCapacity(sym);
        nonlocal_versyms.appendAssumeCapacity(ver);
        nonlocal_symbols.appendAssumeCapacity(.{
            .mangled_name = mangled_name,
        });
    }

    const sections = header.sections;
    header.sections = &.{};
    errdefer gpa.free(sections);

    return .{
        .sections = sections,
        .stat = header.stat,
        .soname_index = header.soname_index,
        .strtab = try strtab.toOwnedSlice(gpa),
        .symtab = try nonlocal_esyms.toOwnedSlice(gpa),
        .versyms = try nonlocal_versyms.toOwnedSlice(gpa),
        .symbols = try nonlocal_symbols.toOwnedSlice(gpa),
        .verstrings = try verstrings.toOwnedSlice(gpa),
    };
}

pub fn resolveSymbols(self: *SharedObject, elf_file: *Elf) !void {
    const gpa = elf_file.base.comp.gpa;

    for (self.parsed.symtab, self.symbols_resolver.items, 0..) |esym, *resolv, i| {
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
    for (self.parsed.symtab, 0..) |esym, i| {
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

pub fn versionString(self: SharedObject, index: elf.Versym) [:0]const u8 {
    return self.parsed.versionString(index);
}

fn versionStringLookup(strtab: []const u8, verstrings: []const u32, index: elf.Versym) [:0]const u8 {
    const off = verstrings[index.VERSION];
    return Elf.stringTableLookup(strtab, off);
}

pub fn asFile(self: *SharedObject) File {
    return .{ .shared_object = self };
}

pub fn soname(self: *SharedObject) []const u8 {
    return self.parsed.soname() orelse self.path.basename();
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

    mem.sort(u32, aliases.items, SortAlias{ .so = self, .ef = elf_file }, SortAlias.lessThan);

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

pub fn getString(self: SharedObject, off: u32) [:0]const u8 {
    return Elf.stringTableLookup(self.parsed.strtab, off);
}

pub fn resolveSymbol(self: SharedObject, index: Symbol.Index, elf_file: *Elf) Elf.Ref {
    const resolv = self.symbols_resolver.items[index];
    return elf_file.resolver.get(resolv).?;
}

pub fn addSymbolAssumeCapacity(self: *SharedObject) Symbol.Index {
    const index: Symbol.Index = @intCast(self.symbols.items.len);
    self.symbols.appendAssumeCapacity(.{ .file_index = self.index });
    return index;
}

pub fn addSymbolExtraAssumeCapacity(self: *SharedObject, extra: Symbol.Extra) u32 {
    const index: u32 = @intCast(self.symbols_extra.items.len);
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
    @compileError("unreachable");
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
const Path = std.Build.Cache.Path;
const Stat = std.Build.Cache.File.Stat;
const Allocator = mem.Allocator;

const Elf = @import("../Elf.zig");
const File = @import("file.zig").File;
const Symbol = @import("Symbol.zig");
const Diags = @import("../../link.zig").Diags;
