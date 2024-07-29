index: File.Index,

symtab: std.ArrayListUnmanaged(elf.Elf64_Sym) = .{},
strtab: std.ArrayListUnmanaged(u8) = .{},
symbols: std.ArrayListUnmanaged(Symbol.Index) = .{},

entry_index: ?Symbol.Index = null,
dynamic_index: ?Symbol.Index = null,
ehdr_start_index: ?Symbol.Index = null,
init_array_start_index: ?Symbol.Index = null,
init_array_end_index: ?Symbol.Index = null,
fini_array_start_index: ?Symbol.Index = null,
fini_array_end_index: ?Symbol.Index = null,
preinit_array_start_index: ?Symbol.Index = null,
preinit_array_end_index: ?Symbol.Index = null,
got_index: ?Symbol.Index = null,
plt_index: ?Symbol.Index = null,
end_index: ?Symbol.Index = null,
gnu_eh_frame_hdr_index: ?Symbol.Index = null,
dso_handle_index: ?Symbol.Index = null,
rela_iplt_start_index: ?Symbol.Index = null,
rela_iplt_end_index: ?Symbol.Index = null,
global_pointer_index: ?Symbol.Index = null,
start_stop_indexes: std.ArrayListUnmanaged(u32) = .{},

output_symtab_ctx: Elf.SymtabCtx = .{},

pub fn deinit(self: *LinkerDefined, allocator: Allocator) void {
    self.symtab.deinit(allocator);
    self.strtab.deinit(allocator);
    self.symbols.deinit(allocator);
    self.start_stop_indexes.deinit(allocator);
}

pub fn init(self: *LinkerDefined, allocator: Allocator) !void {
    // Null byte in strtab
    try self.strtab.append(allocator, 0);
}

pub fn initSymbols(self: *LinkerDefined, elf_file: *Elf) !void {
    const gpa = elf_file.base.comp.gpa;

    // Look for entry address in objects if not set by the incremental compiler.
    if (self.entry_index == null) {
        if (elf_file.entry_name) |name| {
            self.entry_index = elf_file.globalByName(name);
        }
    }
    self.dynamic_index = try self.addGlobal("_DYNAMIC", elf_file);
    self.ehdr_start_index = try self.addGlobal("__ehdr_start", elf_file);
    self.init_array_start_index = try self.addGlobal("__init_array_start", elf_file);
    self.init_array_end_index = try self.addGlobal("__init_array_end", elf_file);
    self.fini_array_start_index = try self.addGlobal("__fini_array_start", elf_file);
    self.fini_array_end_index = try self.addGlobal("__fini_array_end", elf_file);
    self.preinit_array_start_index = try self.addGlobal("__preinit_array_start", elf_file);
    self.preinit_array_end_index = try self.addGlobal("__preinit_array_end", elf_file);
    self.got_index = try self.addGlobal("_GLOBAL_OFFSET_TABLE_", elf_file);
    self.plt_index = try self.addGlobal("_PROCEDURE_LINKAGE_TABLE_", elf_file);
    self.end_index = try self.addGlobal("_end", elf_file);

    if (elf_file.base.comp.link_eh_frame_hdr) {
        self.gnu_eh_frame_hdr_index = try self.addGlobal("__GNU_EH_FRAME_HDR", elf_file);
    }

    if (elf_file.globalByName("__dso_handle")) |index| {
        if (elf_file.symbol(index).file(elf_file) == null)
            self.dso_handle_index = try self.addGlobal("__dso_handle", elf_file);
    }

    self.rela_iplt_start_index = try self.addGlobal("__rela_iplt_start", elf_file);
    self.rela_iplt_end_index = try self.addGlobal("__rela_iplt_end", elf_file);

    for (elf_file.shdrs.items) |shdr| {
        if (elf_file.getStartStopBasename(shdr)) |name| {
            try self.start_stop_indexes.ensureUnusedCapacity(gpa, 2);

            const start = try std.fmt.allocPrintZ(gpa, "__start_{s}", .{name});
            defer gpa.free(start);
            const stop = try std.fmt.allocPrintZ(gpa, "__stop_{s}", .{name});
            defer gpa.free(stop);

            self.start_stop_indexes.appendAssumeCapacity(try self.addGlobal(start, elf_file));
            self.start_stop_indexes.appendAssumeCapacity(try self.addGlobal(stop, elf_file));
        }
    }

    if (elf_file.getTarget().cpu.arch.isRISCV() and elf_file.isEffectivelyDynLib()) {
        self.global_pointer_index = try self.addGlobal("__global_pointer$", elf_file);
    }

    self.resolveSymbols(elf_file);
}

fn addGlobal(self: *LinkerDefined, name: [:0]const u8, elf_file: *Elf) !u32 {
    const comp = elf_file.base.comp;
    const gpa = comp.gpa;
    try self.symtab.ensureUnusedCapacity(gpa, 1);
    try self.symbols.ensureUnusedCapacity(gpa, 1);
    const name_off = @as(u32, @intCast(self.strtab.items.len));
    try self.strtab.writer(gpa).print("{s}\x00", .{name});
    self.symtab.appendAssumeCapacity(.{
        .st_name = name_off,
        .st_info = elf.STB_GLOBAL << 4,
        .st_other = @intFromEnum(elf.STV.HIDDEN),
        .st_shndx = elf.SHN_ABS,
        .st_value = 0,
        .st_size = 0,
    });
    const gop = try elf_file.getOrPutGlobal(name);
    self.symbols.addOneAssumeCapacity().* = gop.index;
    return gop.index;
}

pub fn resolveSymbols(self: *LinkerDefined, elf_file: *Elf) void {
    for (self.symbols.items, 0..) |index, i| {
        const sym_idx = @as(Symbol.Index, @intCast(i));
        const this_sym = self.symtab.items[sym_idx];

        if (this_sym.st_shndx == elf.SHN_UNDEF) continue;

        const global = elf_file.symbol(index);
        if (self.asFile().symbolRank(this_sym, false) < global.symbolRank(elf_file)) {
            global.value = 0;
            global.ref = .{ .index = 0, .file = 0 };
            global.file_index = self.index;
            global.esym_index = sym_idx;
            global.version_index = elf_file.default_sym_version;
        }
    }
}

pub fn allocateSymbols(self: *LinkerDefined, elf_file: *Elf) void {
    const comp = elf_file.base.comp;
    const link_mode = comp.config.link_mode;

    // _DYNAMIC
    if (elf_file.dynamic_section_index) |shndx| {
        const shdr = &elf_file.shdrs.items[shndx];
        const symbol_ptr = elf_file.symbol(self.dynamic_index.?);
        symbol_ptr.value = @intCast(shdr.sh_addr);
        symbol_ptr.output_section_index = shndx;
    }

    // __ehdr_start
    {
        const symbol_ptr = elf_file.symbol(self.ehdr_start_index.?);
        symbol_ptr.value = @intCast(elf_file.image_base);
        symbol_ptr.output_section_index = 1;
    }

    // __init_array_start, __init_array_end
    if (elf_file.sectionByName(".init_array")) |shndx| {
        const start_sym = elf_file.symbol(self.init_array_start_index.?);
        const end_sym = elf_file.symbol(self.init_array_end_index.?);
        const shdr = &elf_file.shdrs.items[shndx];
        start_sym.output_section_index = shndx;
        start_sym.value = @intCast(shdr.sh_addr);
        end_sym.output_section_index = shndx;
        end_sym.value = @intCast(shdr.sh_addr + shdr.sh_size);
    }

    // __fini_array_start, __fini_array_end
    if (elf_file.sectionByName(".fini_array")) |shndx| {
        const start_sym = elf_file.symbol(self.fini_array_start_index.?);
        const end_sym = elf_file.symbol(self.fini_array_end_index.?);
        const shdr = &elf_file.shdrs.items[shndx];
        start_sym.output_section_index = shndx;
        start_sym.value = @intCast(shdr.sh_addr);
        end_sym.output_section_index = shndx;
        end_sym.value = @intCast(shdr.sh_addr + shdr.sh_size);
    }

    // __preinit_array_start, __preinit_array_end
    if (elf_file.sectionByName(".preinit_array")) |shndx| {
        const start_sym = elf_file.symbol(self.preinit_array_start_index.?);
        const end_sym = elf_file.symbol(self.preinit_array_end_index.?);
        const shdr = &elf_file.shdrs.items[shndx];
        start_sym.output_section_index = shndx;
        start_sym.value = @intCast(shdr.sh_addr);
        end_sym.output_section_index = shndx;
        end_sym.value = @intCast(shdr.sh_addr + shdr.sh_size);
    }

    // _GLOBAL_OFFSET_TABLE_
    if (elf_file.getTarget().cpu.arch == .x86_64) {
        if (elf_file.got_plt_section_index) |shndx| {
            const shdr = elf_file.shdrs.items[shndx];
            const sym = elf_file.symbol(self.got_index.?);
            sym.value = @intCast(shdr.sh_addr);
            sym.output_section_index = shndx;
        }
    } else {
        if (elf_file.got_section_index) |shndx| {
            const shdr = elf_file.shdrs.items[shndx];
            const sym = elf_file.symbol(self.got_index.?);
            sym.value = @intCast(shdr.sh_addr);
            sym.output_section_index = shndx;
        }
    }

    // _PROCEDURE_LINKAGE_TABLE_
    if (elf_file.plt_section_index) |shndx| {
        const shdr = &elf_file.shdrs.items[shndx];
        const symbol_ptr = elf_file.symbol(self.plt_index.?);
        symbol_ptr.value = @intCast(shdr.sh_addr);
        symbol_ptr.output_section_index = shndx;
    }

    // __dso_handle
    if (self.dso_handle_index) |index| {
        const shdr = &elf_file.shdrs.items[1];
        const symbol_ptr = elf_file.symbol(index);
        symbol_ptr.value = @intCast(shdr.sh_addr);
        symbol_ptr.output_section_index = 0;
    }

    // __GNU_EH_FRAME_HDR
    if (elf_file.eh_frame_hdr_section_index) |shndx| {
        const shdr = &elf_file.shdrs.items[shndx];
        const symbol_ptr = elf_file.symbol(self.gnu_eh_frame_hdr_index.?);
        symbol_ptr.value = @intCast(shdr.sh_addr);
        symbol_ptr.output_section_index = shndx;
    }

    // __rela_iplt_start, __rela_iplt_end
    if (elf_file.rela_dyn_section_index) |shndx| blk: {
        if (link_mode != .static or comp.config.pie) break :blk;
        const shdr = &elf_file.shdrs.items[shndx];
        const end_addr = shdr.sh_addr + shdr.sh_size;
        const start_addr = end_addr - elf_file.calcNumIRelativeRelocs() * @sizeOf(elf.Elf64_Rela);
        const start_sym = elf_file.symbol(self.rela_iplt_start_index.?);
        const end_sym = elf_file.symbol(self.rela_iplt_end_index.?);
        start_sym.value = @intCast(start_addr);
        start_sym.output_section_index = shndx;
        end_sym.value = @intCast(end_addr);
        end_sym.output_section_index = shndx;
    }

    // _end
    {
        const end_symbol = elf_file.symbol(self.end_index.?);
        for (elf_file.shdrs.items, 0..) |shdr, shndx| {
            if (shdr.sh_flags & elf.SHF_ALLOC != 0) {
                end_symbol.value = @intCast(shdr.sh_addr + shdr.sh_size);
                end_symbol.output_section_index = @intCast(shndx);
            }
        }
    }

    // __start_*, __stop_*
    {
        var index: usize = 0;
        while (index < self.start_stop_indexes.items.len) : (index += 2) {
            const start = elf_file.symbol(self.start_stop_indexes.items[index]);
            const name = start.name(elf_file);
            const stop = elf_file.symbol(self.start_stop_indexes.items[index + 1]);
            const shndx = elf_file.sectionByName(name["__start_".len..]).?;
            const shdr = &elf_file.shdrs.items[shndx];
            start.value = @intCast(shdr.sh_addr);
            start.output_section_index = shndx;
            stop.value = @intCast(shdr.sh_addr + shdr.sh_size);
            stop.output_section_index = shndx;
        }
    }

    // __global_pointer$
    if (self.global_pointer_index) |index| {
        const sym = elf_file.symbol(index);
        if (elf_file.sectionByName(".sdata")) |shndx| {
            const shdr = elf_file.shdrs.items[shndx];
            sym.value = @intCast(shdr.sh_addr + 0x800);
            sym.output_section_index = shndx;
        } else {
            sym.value = 0;
            sym.output_section_index = 0;
        }
    }
}

pub fn globals(self: LinkerDefined) []const Symbol.Index {
    return self.symbols.items;
}

pub fn updateSymtabSize(self: *LinkerDefined, elf_file: *Elf) !void {
    for (self.globals()) |global_index| {
        const global = elf_file.symbol(global_index);
        const file_ptr = global.file(elf_file) orelse continue;
        if (file_ptr.index() != self.index) continue;
        global.flags.output_symtab = true;
        if (global.isLocal(elf_file)) {
            try global.addExtra(.{ .symtab = self.output_symtab_ctx.nlocals }, elf_file);
            self.output_symtab_ctx.nlocals += 1;
        } else {
            try global.addExtra(.{ .symtab = self.output_symtab_ctx.nglobals }, elf_file);
            self.output_symtab_ctx.nglobals += 1;
        }
        self.output_symtab_ctx.strsize += @as(u32, @intCast(global.name(elf_file).len)) + 1;
    }
}

pub fn writeSymtab(self: LinkerDefined, elf_file: *Elf) void {
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

pub fn asFile(self: *LinkerDefined) File {
    return .{ .linker_defined = self };
}

pub fn getString(self: LinkerDefined, off: u32) [:0]const u8 {
    assert(off < self.strtab.items.len);
    return mem.sliceTo(@as([*:0]const u8, @ptrCast(self.strtab.items.ptr + off)), 0);
}

pub fn fmtSymtab(self: *LinkerDefined, elf_file: *Elf) std.fmt.Formatter(formatSymtab) {
    return .{ .data = .{
        .self = self,
        .elf_file = elf_file,
    } };
}

const FormatContext = struct {
    self: *LinkerDefined,
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
    try writer.writeAll("  globals\n");
    for (ctx.self.globals()) |index| {
        const global = ctx.elf_file.symbol(index);
        try writer.print("    {}\n", .{global.fmt(ctx.elf_file)});
    }
}

const assert = std.debug.assert;
const elf = std.elf;
const mem = std.mem;
const std = @import("std");

const Allocator = mem.Allocator;
const Atom = @import("Atom.zig");
const Elf = @import("../Elf.zig");
const File = @import("file.zig").File;
const LinkerDefined = @This();
const Symbol = @import("Symbol.zig");
