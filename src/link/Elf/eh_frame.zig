pub const Fde = struct {
    /// Includes 4byte size cell.
    offset: usize,
    size: usize,
    cie_index: u32,
    rel_index: u32 = 0,
    rel_num: u32 = 0,
    input_section_index: u32 = 0,
    file_index: u32 = 0,
    alive: bool = true,
    /// Includes 4byte size cell.
    out_offset: u64 = 0,

    pub fn address(fde: Fde, elf_file: *Elf) u64 {
        const base: u64 = if (elf_file.section_indexes.eh_frame) |shndx|
            elf_file.sections.items(.shdr)[shndx].sh_addr
        else
            0;
        return base + fde.out_offset;
    }

    pub fn data(fde: Fde, elf_file: *Elf) []u8 {
        const object = elf_file.file(fde.file_index).?.object;
        return object.eh_frame_data.items[fde.offset..][0..fde.calcSize()];
    }

    pub fn cie(fde: Fde, elf_file: *Elf) Cie {
        const object = elf_file.file(fde.file_index).?.object;
        return object.cies.items[fde.cie_index];
    }

    pub fn ciePointer(fde: Fde, elf_file: *Elf) u32 {
        const fde_data = fde.data(elf_file);
        return std.mem.readInt(u32, fde_data[4..8], .little);
    }

    pub fn calcSize(fde: Fde) usize {
        return fde.size + 4;
    }

    pub fn atom(fde: Fde, elf_file: *Elf) *Atom {
        const object = elf_file.file(fde.file_index).?.object;
        const rel = fde.relocs(elf_file)[0];
        const sym = object.symtab.items[rel.r_sym()];
        const atom_index = object.atoms_indexes.items[sym.st_shndx];
        return object.atom(atom_index).?;
    }

    pub fn relocs(fde: Fde, elf_file: *Elf) []align(1) const elf.Elf64_Rela {
        const object = elf_file.file(fde.file_index).?.object;
        return object.relocs.items[fde.rel_index..][0..fde.rel_num];
    }

    pub fn format(
        fde: Fde,
        comptime unused_fmt_string: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fde;
        _ = unused_fmt_string;
        _ = options;
        _ = writer;
        @compileError("do not format FDEs directly");
    }

    pub fn fmt(fde: Fde, elf_file: *Elf) std.fmt.Formatter(format2) {
        return .{ .data = .{
            .fde = fde,
            .elf_file = elf_file,
        } };
    }

    const FdeFormatContext = struct {
        fde: Fde,
        elf_file: *Elf,
    };

    fn format2(
        ctx: FdeFormatContext,
        comptime unused_fmt_string: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = unused_fmt_string;
        _ = options;
        const fde = ctx.fde;
        const elf_file = ctx.elf_file;
        const base_addr = fde.address(elf_file);
        const atom_name = fde.atom(elf_file).name(elf_file);
        try writer.print("@{x} : size({x}) : cie({d}) : {s}", .{
            base_addr + fde.out_offset,
            fde.calcSize(),
            fde.cie_index,
            atom_name,
        });
        if (!fde.alive) try writer.writeAll(" : [*]");
    }
};

pub const Cie = struct {
    /// Includes 4byte size cell.
    offset: usize,
    size: usize,
    rel_index: u32 = 0,
    rel_num: u32 = 0,
    input_section_index: u32 = 0,
    file_index: u32 = 0,
    /// Includes 4byte size cell.
    out_offset: u64 = 0,
    alive: bool = false,

    pub fn address(cie: Cie, elf_file: *Elf) u64 {
        const base: u64 = if (elf_file.section_indexes.eh_frame) |shndx|
            elf_file.sections.items(.shdr)[shndx].sh_addr
        else
            0;
        return base + cie.out_offset;
    }

    pub fn data(cie: Cie, elf_file: *Elf) []u8 {
        const object = elf_file.file(cie.file_index).?.object;
        return object.eh_frame_data.items[cie.offset..][0..cie.calcSize()];
    }

    pub fn calcSize(cie: Cie) usize {
        return cie.size + 4;
    }

    pub fn relocs(cie: Cie, elf_file: *Elf) []align(1) const elf.Elf64_Rela {
        const object = elf_file.file(cie.file_index).?.object;
        return object.relocs.items[cie.rel_index..][0..cie.rel_num];
    }

    pub fn eql(cie: Cie, other: Cie, elf_file: *Elf) bool {
        if (!std.mem.eql(u8, cie.data(elf_file), other.data(elf_file))) return false;

        const cie_relocs = cie.relocs(elf_file);
        const other_relocs = other.relocs(elf_file);
        if (cie_relocs.len != other_relocs.len) return false;

        for (cie_relocs, other_relocs) |cie_rel, other_rel| {
            if (cie_rel.r_offset - cie.offset != other_rel.r_offset - other.offset) return false;
            if (cie_rel.r_type() != other_rel.r_type()) return false;
            if (cie_rel.r_addend != other_rel.r_addend) return false;

            const cie_object = elf_file.file(cie.file_index).?.object;
            const cie_ref = cie_object.resolveSymbol(cie_rel.r_sym(), elf_file);
            const other_object = elf_file.file(other.file_index).?.object;
            const other_ref = other_object.resolveSymbol(other_rel.r_sym(), elf_file);
            if (!cie_ref.eql(other_ref)) return false;
        }
        return true;
    }

    pub fn format(
        cie: Cie,
        comptime unused_fmt_string: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = cie;
        _ = unused_fmt_string;
        _ = options;
        _ = writer;
        @compileError("do not format CIEs directly");
    }

    pub fn fmt(cie: Cie, elf_file: *Elf) std.fmt.Formatter(format2) {
        return .{ .data = .{
            .cie = cie,
            .elf_file = elf_file,
        } };
    }

    const CieFormatContext = struct {
        cie: Cie,
        elf_file: *Elf,
    };

    fn format2(
        ctx: CieFormatContext,
        comptime unused_fmt_string: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = unused_fmt_string;
        _ = options;
        const cie = ctx.cie;
        const elf_file = ctx.elf_file;
        const base_addr = cie.address(elf_file);
        try writer.print("@{x} : size({x})", .{
            base_addr + cie.out_offset,
            cie.calcSize(),
        });
        if (!cie.alive) try writer.writeAll(" : [*]");
    }
};

pub const Iterator = struct {
    data: []const u8,
    pos: usize = 0,

    pub const Record = struct {
        tag: enum { fde, cie },
        offset: usize,
        size: usize,
    };

    pub fn next(it: *Iterator) !?Record {
        if (it.pos >= it.data.len) return null;

        var stream = std.io.fixedBufferStream(it.data[it.pos..]);
        const reader = stream.reader();

        const size = try reader.readInt(u32, .little);
        if (size == 0) return null;
        if (size == 0xFFFFFFFF) @panic("TODO");

        const id = try reader.readInt(u32, .little);
        const record = Record{
            .tag = if (id == 0) .cie else .fde,
            .offset = it.pos,
            .size = size,
        };
        it.pos += size + 4;

        return record;
    }
};

pub fn calcEhFrameSize(elf_file: *Elf) !usize {
    const comp = elf_file.base.comp;
    const gpa = comp.gpa;

    var offset: usize = if (elf_file.zigObjectPtr()) |zo| blk: {
        const sym = zo.symbol(zo.eh_frame_index orelse break :blk 0);
        break :blk math.cast(usize, sym.atom(elf_file).?.size) orelse return error.Overflow;
    } else 0;

    var cies = std.ArrayList(Cie).init(gpa);
    defer cies.deinit();

    for (elf_file.objects.items) |index| {
        const object = elf_file.file(index).?.object;

        outer: for (object.cies.items) |*cie| {
            for (cies.items) |other| {
                if (other.eql(cie.*, elf_file)) {
                    // We already have a CIE record that has the exact same contents, so instead of
                    // duplicating them, we mark this one dead and set its output offset to be
                    // equal to that of the alive record. This way, we won't have to rewrite
                    // Fde.cie_index field when committing the records to file.
                    cie.out_offset = other.out_offset;
                    continue :outer;
                }
            }
            cie.alive = true;
            cie.out_offset = offset;
            offset += cie.calcSize();
            try cies.append(cie.*);
        }
    }

    for (elf_file.objects.items) |index| {
        const object = elf_file.file(index).?.object;
        for (object.fdes.items) |*fde| {
            if (!fde.alive) continue;
            fde.out_offset = offset;
            offset += fde.calcSize();
        }
    }

    if (!elf_file.base.isRelocatable()) {
        offset += 4; // NULL terminator
    }

    return offset;
}

pub fn calcEhFrameHdrSize(elf_file: *Elf) usize {
    var count: usize = 0;
    for (elf_file.objects.items) |index| {
        for (elf_file.file(index).?.object.fdes.items) |fde| {
            if (!fde.alive) continue;
            count += 1;
        }
    }
    return eh_frame_hdr_header_size + count * 8;
}

pub fn calcEhFrameRelocs(elf_file: *Elf) usize {
    var count: usize = 0;
    if (elf_file.zigObjectPtr()) |zo| zo: {
        const sym_index = zo.eh_frame_index orelse break :zo;
        const sym = zo.symbol(sym_index);
        const atom_ptr = zo.atom(sym.ref.index).?;
        if (!atom_ptr.alive) break :zo;
        count += atom_ptr.relocs(elf_file).len;
    }
    for (elf_file.objects.items) |index| {
        const object = elf_file.file(index).?.object;
        for (object.cies.items) |cie| {
            if (!cie.alive) continue;
            count += cie.relocs(elf_file).len;
        }
        for (object.fdes.items) |fde| {
            if (!fde.alive) continue;
            count += fde.relocs(elf_file).len;
        }
    }
    return count;
}

fn resolveReloc(rec: anytype, sym: *const Symbol, rel: elf.Elf64_Rela, elf_file: *Elf, contents: []u8) !void {
    const cpu_arch = elf_file.getTarget().cpu.arch;
    const offset = std.math.cast(usize, rel.r_offset - rec.offset) orelse return error.Overflow;
    const P = math.cast(i64, rec.address(elf_file) + offset) orelse return error.Overflow;
    const S = math.cast(i64, sym.address(.{}, elf_file)) orelse return error.Overflow;
    const A = rel.r_addend;

    relocs_log.debug("  {s}: {x}: [{x} => {x}] ({s})", .{
        relocation.fmtRelocType(rel.r_type(), cpu_arch),
        offset,
        P,
        S + A,
        sym.name(elf_file),
    });

    switch (cpu_arch) {
        .x86_64 => try x86_64.resolveReloc(rec, elf_file, rel, P, S + A, contents[offset..]),
        .aarch64 => try aarch64.resolveReloc(rec, elf_file, rel, P, S + A, contents[offset..]),
        .riscv64 => try riscv.resolveReloc(rec, elf_file, rel, P, S + A, contents[offset..]),
        else => return error.UnsupportedCpuArch,
    }
}

pub fn writeEhFrame(elf_file: *Elf, writer: anytype) !void {
    relocs_log.debug("{x}: .eh_frame", .{
        elf_file.sections.items(.shdr)[elf_file.section_indexes.eh_frame.?].sh_addr,
    });

    var has_reloc_errors = false;

    for (elf_file.objects.items) |index| {
        const object = elf_file.file(index).?.object;

        for (object.cies.items) |cie| {
            if (!cie.alive) continue;

            const contents = cie.data(elf_file);

            for (cie.relocs(elf_file)) |rel| {
                const ref = object.resolveSymbol(rel.r_sym(), elf_file);
                const sym = elf_file.symbol(ref).?;
                resolveReloc(cie, sym, rel, elf_file, contents) catch |err| switch (err) {
                    error.RelocFailure => has_reloc_errors = true,
                    else => |e| return e,
                };
            }

            try writer.writeAll(contents);
        }
    }

    for (elf_file.objects.items) |index| {
        const object = elf_file.file(index).?.object;

        for (object.fdes.items) |fde| {
            if (!fde.alive) continue;

            const contents = fde.data(elf_file);

            std.mem.writeInt(
                i32,
                contents[4..8],
                @truncate(@as(i64, @intCast(fde.out_offset + 4)) - @as(i64, @intCast(fde.cie(elf_file).out_offset))),
                .little,
            );

            for (fde.relocs(elf_file)) |rel| {
                const ref = object.resolveSymbol(rel.r_sym(), elf_file);
                const sym = elf_file.symbol(ref).?;
                resolveReloc(fde, sym, rel, elf_file, contents) catch |err| switch (err) {
                    error.RelocFailure => has_reloc_errors = true,
                    else => |e| return e,
                };
            }

            try writer.writeAll(contents);
        }
    }

    try writer.writeInt(u32, 0, .little);

    if (has_reloc_errors) return error.RelocFailure;
}

pub fn writeEhFrameRelocatable(elf_file: *Elf, writer: anytype) !void {
    for (elf_file.objects.items) |index| {
        const object = elf_file.file(index).?.object;

        for (object.cies.items) |cie| {
            if (!cie.alive) continue;
            try writer.writeAll(cie.data(elf_file));
        }
    }

    for (elf_file.objects.items) |index| {
        const object = elf_file.file(index).?.object;

        for (object.fdes.items) |fde| {
            if (!fde.alive) continue;

            const contents = fde.data(elf_file);

            std.mem.writeInt(
                i32,
                contents[4..8],
                @truncate(@as(i64, @intCast(fde.out_offset + 4)) - @as(i64, @intCast(fde.cie(elf_file).out_offset))),
                .little,
            );

            try writer.writeAll(contents);
        }
    }
}

fn emitReloc(elf_file: *Elf, r_offset: u64, sym: *const Symbol, rel: elf.Elf64_Rela) elf.Elf64_Rela {
    const cpu_arch = elf_file.getTarget().cpu.arch;
    const r_type = rel.r_type();
    var r_addend = rel.r_addend;
    var r_sym: u32 = 0;
    switch (sym.type(elf_file)) {
        elf.STT_SECTION => {
            r_addend += @intCast(sym.address(.{}, elf_file));
            r_sym = sym.outputShndx(elf_file).?;
        },
        else => {
            r_sym = sym.outputSymtabIndex(elf_file) orelse 0;
        },
    }

    relocs_log.debug("  {s}: [{x} => {d}({s})] + {x}", .{
        relocation.fmtRelocType(r_type, cpu_arch),
        r_offset,
        r_sym,
        sym.name(elf_file),
        r_addend,
    });

    return .{
        .r_offset = r_offset,
        .r_addend = r_addend,
        .r_info = (@as(u64, @intCast(r_sym)) << 32) | r_type,
    };
}

pub fn writeEhFrameRelocs(elf_file: *Elf, writer: anytype) !void {
    relocs_log.debug("{x}: .eh_frame", .{
        elf_file.sections.items(.shdr)[elf_file.section_indexes.eh_frame.?].sh_addr,
    });

    if (elf_file.zigObjectPtr()) |zo| zo: {
        const sym_index = zo.eh_frame_index orelse break :zo;
        const sym = zo.symbol(sym_index);
        const atom_ptr = zo.atom(sym.ref.index).?;
        if (!atom_ptr.alive) break :zo;
        for (atom_ptr.relocs(elf_file)) |rel| {
            const ref = zo.resolveSymbol(rel.r_sym(), elf_file);
            const target = elf_file.symbol(ref).?;
            const out_rel = emitReloc(elf_file, rel.r_offset, target, rel);
            try writer.writeStruct(out_rel);
        }
    }

    for (elf_file.objects.items) |index| {
        const object = elf_file.file(index).?.object;

        for (object.cies.items) |cie| {
            if (!cie.alive) continue;
            for (cie.relocs(elf_file)) |rel| {
                const ref = object.resolveSymbol(rel.r_sym(), elf_file);
                const sym = elf_file.symbol(ref).?;
                const r_offset = cie.address(elf_file) + rel.r_offset - cie.offset;
                const out_rel = emitReloc(elf_file, r_offset, sym, rel);
                try writer.writeStruct(out_rel);
            }
        }

        for (object.fdes.items) |fde| {
            if (!fde.alive) continue;
            for (fde.relocs(elf_file)) |rel| {
                const ref = object.resolveSymbol(rel.r_sym(), elf_file);
                const sym = elf_file.symbol(ref).?;
                const r_offset = fde.address(elf_file) + rel.r_offset - fde.offset;
                const out_rel = emitReloc(elf_file, r_offset, sym, rel);
                try writer.writeStruct(out_rel);
            }
        }
    }
}

pub fn writeEhFrameHdr(elf_file: *Elf, writer: anytype) !void {
    const comp = elf_file.base.comp;
    const gpa = comp.gpa;

    try writer.writeByte(1); // version
    try writer.writeByte(DW_EH_PE.pcrel | DW_EH_PE.sdata4);
    try writer.writeByte(DW_EH_PE.udata4);
    try writer.writeByte(DW_EH_PE.datarel | DW_EH_PE.sdata4);

    const shdrs = elf_file.sections.items(.shdr);
    const eh_frame_shdr = shdrs[elf_file.section_indexes.eh_frame.?];
    const eh_frame_hdr_shdr = shdrs[elf_file.section_indexes.eh_frame_hdr.?];
    const num_fdes = @as(u32, @intCast(@divExact(eh_frame_hdr_shdr.sh_size - eh_frame_hdr_header_size, 8)));
    const existing_size = existing_size: {
        const zo = elf_file.zigObjectPtr() orelse break :existing_size 0;
        const sym = zo.symbol(zo.eh_frame_index orelse break :existing_size 0);
        break :existing_size sym.atom(elf_file).?.size;
    };
    try writer.writeInt(
        u32,
        @as(u32, @bitCast(@as(
            i32,
            @truncate(@as(i64, @intCast(eh_frame_shdr.sh_addr + existing_size)) - @as(i64, @intCast(eh_frame_hdr_shdr.sh_addr)) - 4),
        ))),
        .little,
    );
    try writer.writeInt(u32, num_fdes, .little);

    const Entry = struct {
        init_addr: u32,
        fde_addr: u32,

        pub fn lessThan(ctx: void, lhs: @This(), rhs: @This()) bool {
            _ = ctx;
            return lhs.init_addr < rhs.init_addr;
        }
    };

    var entries = std.ArrayList(Entry).init(gpa);
    defer entries.deinit();
    try entries.ensureTotalCapacityPrecise(num_fdes);

    for (elf_file.objects.items) |index| {
        const object = elf_file.file(index).?.object;
        for (object.fdes.items) |fde| {
            if (!fde.alive) continue;

            const relocs = fde.relocs(elf_file);
            assert(relocs.len > 0); // Should this be an error? Things are completely broken anyhow if this trips...
            const rel = relocs[0];
            const ref = object.resolveSymbol(rel.r_sym(), elf_file);
            const sym = elf_file.symbol(ref).?;
            const P = @as(i64, @intCast(fde.address(elf_file)));
            const S = @as(i64, @intCast(sym.address(.{}, elf_file)));
            const A = rel.r_addend;
            entries.appendAssumeCapacity(.{
                .init_addr = @bitCast(@as(i32, @truncate(S + A - @as(i64, @intCast(eh_frame_hdr_shdr.sh_addr))))),
                .fde_addr = @as(
                    u32,
                    @bitCast(@as(i32, @truncate(P - @as(i64, @intCast(eh_frame_hdr_shdr.sh_addr))))),
                ),
            });
        }
    }

    std.mem.sort(Entry, entries.items, {}, Entry.lessThan);
    try writer.writeAll(std.mem.sliceAsBytes(entries.items));
}

const eh_frame_hdr_header_size: usize = 12;

const x86_64 = struct {
    fn resolveReloc(rec: anytype, elf_file: *Elf, rel: elf.Elf64_Rela, source: i64, target: i64, data: []u8) !void {
        const r_type: elf.R_X86_64 = @enumFromInt(rel.r_type());
        switch (r_type) {
            .NONE => {},
            .@"32" => std.mem.writeInt(i32, data[0..4], @as(i32, @truncate(target)), .little),
            .@"64" => std.mem.writeInt(i64, data[0..8], target, .little),
            .PC32 => std.mem.writeInt(i32, data[0..4], @as(i32, @intCast(target - source)), .little),
            .PC64 => std.mem.writeInt(i64, data[0..8], target - source, .little),
            else => try reportInvalidReloc(rec, elf_file, rel),
        }
    }
};

const aarch64 = struct {
    fn resolveReloc(rec: anytype, elf_file: *Elf, rel: elf.Elf64_Rela, source: i64, target: i64, data: []u8) !void {
        const r_type: elf.R_AARCH64 = @enumFromInt(rel.r_type());
        switch (r_type) {
            .NONE => {},
            .ABS64 => std.mem.writeInt(i64, data[0..8], target, .little),
            .PREL32 => std.mem.writeInt(i32, data[0..4], @as(i32, @intCast(target - source)), .little),
            .PREL64 => std.mem.writeInt(i64, data[0..8], target - source, .little),
            else => try reportInvalidReloc(rec, elf_file, rel),
        }
    }
};

const riscv = struct {
    fn resolveReloc(rec: anytype, elf_file: *Elf, rel: elf.Elf64_Rela, source: i64, target: i64, data: []u8) !void {
        const r_type: elf.R_RISCV = @enumFromInt(rel.r_type());
        switch (r_type) {
            .NONE => {},
            .@"32_PCREL" => std.mem.writeInt(i32, data[0..4], @as(i32, @intCast(target - source)), .little),
            else => try reportInvalidReloc(rec, elf_file, rel),
        }
    }
};

fn reportInvalidReloc(rec: anytype, elf_file: *Elf, rel: elf.Elf64_Rela) !void {
    const diags = &elf_file.base.comp.link_diags;
    var err = try diags.addErrorWithNotes(1);
    try err.addMsg("invalid relocation type {} at offset 0x{x}", .{
        relocation.fmtRelocType(rel.r_type(), elf_file.getTarget().cpu.arch),
        rel.r_offset,
    });
    try err.addNote("in {}:.eh_frame", .{elf_file.file(rec.file_index).?.fmtPath()});
    return error.RelocFailure;
}

const std = @import("std");
const assert = std.debug.assert;
const elf = std.elf;
const math = std.math;
const relocs_log = std.log.scoped(.link_relocs);
const relocation = @import("relocation.zig");

const Allocator = std.mem.Allocator;
const Atom = @import("Atom.zig");
const DW_EH_PE = std.dwarf.EH.PE;
const Elf = @import("../Elf.zig");
const Object = @import("Object.zig");
const Symbol = @import("Symbol.zig");
