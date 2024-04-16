pub fn createThunks(shndx: u32, elf_file: *Elf) !void {
    const gpa = elf_file.base.comp.gpa;
    const cpu_arch = elf_file.getTarget().cpu.arch;
    const max_distance = maxAllowedDistance(cpu_arch);
    const shdr = &elf_file.shdrs.items[shndx];
    const atoms = elf_file.output_sections.get(shndx).?.items;
    assert(atoms.len > 0);

    for (atoms) |atom_index| {
        elf_file.atom(atom_index).?.value = -1;
    }

    var i: usize = 0;
    while (i < atoms.len) {
        const start = i;
        const start_atom = elf_file.atom(atoms[start]).?;
        assert(start_atom.flags.alive);
        start_atom.value = try advance(shdr, start_atom.size, start_atom.alignment);
        i += 1;

        while (i < atoms.len) : (i += 1) {
            const atom_index = atoms[i];
            const atom = elf_file.atom(atom_index).?;
            assert(atom.flags.alive);
            if (@as(i64, @intCast(atom.alignment.forward(shdr.sh_size))) - start_atom.value >= max_distance)
                break;
            atom.value = try advance(shdr, atom.size, atom.alignment);
        }

        // Insert a thunk at the group end
        const thunk_index = try elf_file.addThunk();
        const thunk = elf_file.thunk(thunk_index);
        thunk.output_section_index = shndx;

        // Scan relocs in the group and create trampolines for any unreachable callsite
        for (atoms[start..i]) |atom_index| {
            const atom = elf_file.atom(atom_index).?;
            const file = atom.file(elf_file).?;
            log.debug("atom({d}) {s}", .{ atom_index, atom.name(elf_file) });
            for (atom.relocs(elf_file)) |rel| {
                const is_reachable = switch (cpu_arch) {
                    .aarch64 => aarch64.isReachable(atom, rel, elf_file),
                    .x86_64, .riscv64 => unreachable,
                    else => @panic("unsupported arch"),
                };
                if (is_reachable) continue;
                const target = switch (file) {
                    .zig_object => |x| x.symbol(rel.r_sym()),
                    .object => |x| x.symbols.items[rel.r_sym()],
                    else => unreachable,
                };
                try thunk.symbols.put(gpa, target, {});
            }
            try atom.addExtra(.{ .thunk = thunk_index }, elf_file);
            atom.flags.thunk = true;
        }

        thunk.value = try advance(shdr, thunk.size(elf_file), Atom.Alignment.fromNonzeroByteUnits(2));

        log.debug("thunk({d}) : {}", .{ thunk_index, thunk.fmt(elf_file) });
    }
}

fn advance(shdr: *elf.Elf64_Shdr, size: u64, alignment: Atom.Alignment) !i64 {
    const offset = alignment.forward(shdr.sh_size);
    const padding = offset - shdr.sh_size;
    shdr.sh_size += padding + size;
    shdr.sh_addralign = @max(shdr.sh_addralign, alignment.toByteUnits() orelse 1);
    return @intCast(offset);
}

/// A branch will need an extender if its target is larger than
/// `2^(jump_bits - 1) - margin` where margin is some arbitrary number.
fn maxAllowedDistance(cpu_arch: std.Target.Cpu.Arch) u32 {
    return switch (cpu_arch) {
        .aarch64 => 0x500_000,
        .x86_64, .riscv64 => unreachable,
        else => @panic("unhandled arch"),
    };
}

pub const Thunk = struct {
    value: i64 = 0,
    output_section_index: u32 = 0,
    symbols: std.AutoArrayHashMapUnmanaged(Symbol.Index, void) = .{},
    output_symtab_ctx: Elf.SymtabCtx = .{},

    pub fn deinit(thunk: *Thunk, allocator: Allocator) void {
        thunk.symbols.deinit(allocator);
    }

    pub fn size(thunk: Thunk, elf_file: *Elf) usize {
        const cpu_arch = elf_file.getTarget().cpu.arch;
        return thunk.symbols.keys().len * trampolineSize(cpu_arch);
    }

    pub fn address(thunk: Thunk, elf_file: *Elf) i64 {
        const shdr = elf_file.shdrs.items[thunk.output_section_index];
        return @as(i64, @intCast(shdr.sh_addr)) + thunk.value;
    }

    pub fn targetAddress(thunk: Thunk, sym_index: Symbol.Index, elf_file: *Elf) i64 {
        const cpu_arch = elf_file.getTarget().cpu.arch;
        return thunk.address(elf_file) + @as(i64, @intCast(thunk.symbols.getIndex(sym_index).? * trampolineSize(cpu_arch)));
    }

    pub fn write(thunk: Thunk, elf_file: *Elf, writer: anytype) !void {
        switch (elf_file.getTarget().cpu.arch) {
            .aarch64 => try aarch64.write(thunk, elf_file, writer),
            .x86_64, .riscv64 => unreachable,
            else => @panic("unhandled arch"),
        }
    }

    pub fn calcSymtabSize(thunk: *Thunk, elf_file: *Elf) void {
        thunk.output_symtab_ctx.nlocals = @as(u32, @intCast(thunk.symbols.keys().len));
        for (thunk.symbols.keys()) |sym_index| {
            const sym = elf_file.symbol(sym_index);
            thunk.output_symtab_ctx.strsize += @as(u32, @intCast(sym.name(elf_file).len + "$thunk".len + 1));
        }
    }

    pub fn writeSymtab(thunk: Thunk, elf_file: *Elf) void {
        const cpu_arch = elf_file.getTarget().cpu.arch;
        for (thunk.symbols.keys(), thunk.output_symtab_ctx.ilocal..) |sym_index, ilocal| {
            const sym = elf_file.symbol(sym_index);
            const st_name = @as(u32, @intCast(elf_file.strtab.items.len));
            elf_file.strtab.appendSliceAssumeCapacity(sym.name(elf_file));
            elf_file.strtab.appendSliceAssumeCapacity("$thunk");
            elf_file.strtab.appendAssumeCapacity(0);
            elf_file.symtab.items[ilocal] = .{
                .st_name = st_name,
                .st_info = elf.STT_FUNC,
                .st_other = 0,
                .st_shndx = @intCast(thunk.output_section_index),
                .st_value = @intCast(thunk.targetAddress(sym_index, elf_file)),
                .st_size = trampolineSize(cpu_arch),
            };
        }
    }

    fn trampolineSize(cpu_arch: std.Target.Cpu.Arch) usize {
        return switch (cpu_arch) {
            .aarch64 => aarch64.trampoline_size,
            .x86_64, .riscv64 => unreachable,
            else => @panic("unhandled arch"),
        };
    }

    pub fn format(
        thunk: Thunk,
        comptime unused_fmt_string: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = thunk;
        _ = unused_fmt_string;
        _ = options;
        _ = writer;
        @compileError("do not format Thunk directly");
    }

    pub fn fmt(thunk: Thunk, elf_file: *Elf) std.fmt.Formatter(format2) {
        return .{ .data = .{
            .thunk = thunk,
            .elf_file = elf_file,
        } };
    }

    const FormatContext = struct {
        thunk: Thunk,
        elf_file: *Elf,
    };

    fn format2(
        ctx: FormatContext,
        comptime unused_fmt_string: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = options;
        _ = unused_fmt_string;
        const thunk = ctx.thunk;
        const elf_file = ctx.elf_file;
        try writer.print("@{x} : size({x})\n", .{ thunk.value, thunk.size(elf_file) });
        for (thunk.symbols.keys()) |index| {
            const sym = elf_file.symbol(index);
            try writer.print("  %{d} : {s} : @{x}\n", .{ index, sym.name(elf_file), sym.value });
        }
    }

    pub const Index = u32;
};

const aarch64 = struct {
    fn isReachable(atom: *const Atom, rel: elf.Elf64_Rela, elf_file: *Elf) bool {
        const r_type: elf.R_AARCH64 = @enumFromInt(rel.r_type());
        if (r_type != .CALL26 and r_type != .JUMP26) return true;
        const file = atom.file(elf_file).?;
        const target_index = switch (file) {
            .zig_object => |x| x.symbol(rel.r_sym()),
            .object => |x| x.symbols.items[rel.r_sym()],
            else => unreachable,
        };
        const target = elf_file.symbol(target_index);
        if (target.flags.has_plt) return false;
        if (atom.output_section_index != target.output_section_index) return false;
        const target_atom = target.atom(elf_file).?;
        if (target_atom.value == -1) return false;
        const saddr = atom.address(elf_file) + @as(i64, @intCast(rel.r_offset));
        const taddr = target.address(.{}, elf_file);
        _ = math.cast(i28, taddr + rel.r_addend - saddr) orelse return false;
        return true;
    }

    fn write(thunk: Thunk, elf_file: *Elf, writer: anytype) !void {
        for (thunk.symbols.keys(), 0..) |sym_index, i| {
            const sym = elf_file.symbol(sym_index);
            const saddr = thunk.address(elf_file) + @as(i64, @intCast(i * trampoline_size));
            const taddr = sym.address(.{}, elf_file);
            const pages = try util.calcNumberOfPages(saddr, taddr);
            try writer.writeInt(u32, Instruction.adrp(.x16, pages).toU32(), .little);
            const off: u12 = @truncate(@as(u64, @bitCast(taddr)));
            try writer.writeInt(u32, Instruction.add(.x16, .x16, off, false).toU32(), .little);
            try writer.writeInt(u32, Instruction.br(.x16).toU32(), .little);
        }
    }

    const trampoline_size = 3 * @sizeOf(u32);

    const util = @import("../aarch64.zig");
    const Instruction = util.Instruction;
};

const assert = std.debug.assert;
const elf = std.elf;
const log = std.log.scoped(.link);
const math = std.math;
const mem = std.mem;
const std = @import("std");

const Allocator = mem.Allocator;
const Atom = @import("Atom.zig");
const Elf = @import("../Elf.zig");
const Symbol = @import("Symbol.zig");
