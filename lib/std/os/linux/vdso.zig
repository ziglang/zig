// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../../std.zig");
const elf = std.elf;
const linux = std.os.linux;
const mem = std.mem;
const maxInt = std.math.maxInt;

pub fn lookup(vername: []const u8, name: []const u8) usize {
    const vdso_addr = std.os.system.getauxval(std.elf.AT_SYSINFO_EHDR);
    if (vdso_addr == 0) return 0;

    const eh = @intToPtr(*elf.Ehdr, vdso_addr);
    var ph_addr: usize = vdso_addr + eh.e_phoff;

    var maybe_dynv: ?[*]usize = null;
    var base: usize = maxInt(usize);
    {
        var i: usize = 0;
        while (i < eh.e_phnum) : ({
            i += 1;
            ph_addr += eh.e_phentsize;
        }) {
            const this_ph = @intToPtr(*elf.Phdr, ph_addr);
            switch (this_ph.p_type) {
                // On WSL1 as well as older kernels, the VDSO ELF image is pre-linked in the upper half
                // of the memory space (e.g. p_vaddr = 0xffffffffff700000 on WSL1).
                // Wrapping operations are used on this line as well as subsequent calculations relative to base
                // (lines 47, 78) to ensure no overflow check is tripped.
                elf.PT_LOAD => base = vdso_addr +% this_ph.p_offset -% this_ph.p_vaddr,
                elf.PT_DYNAMIC => maybe_dynv = @intToPtr([*]usize, vdso_addr + this_ph.p_offset),
                else => {},
            }
        }
    }
    const dynv = maybe_dynv orelse return 0;
    if (base == maxInt(usize)) return 0;

    var maybe_strings: ?[*]u8 = null;
    var maybe_syms: ?[*]elf.Sym = null;
    var maybe_hashtab: ?[*]linux.Elf_Symndx = null;
    var maybe_versym: ?[*]u16 = null;
    var maybe_verdef: ?*elf.Verdef = null;

    {
        var i: usize = 0;
        while (dynv[i] != 0) : (i += 2) {
            const p = base +% dynv[i + 1];
            switch (dynv[i]) {
                elf.DT_STRTAB => maybe_strings = @intToPtr([*]u8, p),
                elf.DT_SYMTAB => maybe_syms = @intToPtr([*]elf.Sym, p),
                elf.DT_HASH => maybe_hashtab = @intToPtr([*]linux.Elf_Symndx, p),
                elf.DT_VERSYM => maybe_versym = @intToPtr([*]u16, p),
                elf.DT_VERDEF => maybe_verdef = @intToPtr(*elf.Verdef, p),
                else => {},
            }
        }
    }

    const strings = maybe_strings orelse return 0;
    const syms = maybe_syms orelse return 0;
    const hashtab = maybe_hashtab orelse return 0;
    if (maybe_verdef == null) maybe_versym = null;

    const OK_TYPES = (1 << elf.STT_NOTYPE | 1 << elf.STT_OBJECT | 1 << elf.STT_FUNC | 1 << elf.STT_COMMON);
    const OK_BINDS = (1 << elf.STB_GLOBAL | 1 << elf.STB_WEAK | 1 << elf.STB_GNU_UNIQUE);

    var i: usize = 0;
    while (i < hashtab[1]) : (i += 1) {
        if (0 == (@as(u32, 1) << @intCast(u5, syms[i].st_info & 0xf) & OK_TYPES)) continue;
        if (0 == (@as(u32, 1) << @intCast(u5, syms[i].st_info >> 4) & OK_BINDS)) continue;
        if (0 == syms[i].st_shndx) continue;
        const sym_name = std.meta.assumeSentinel(strings + syms[i].st_name, 0);
        if (!mem.eql(u8, name, mem.spanZ(sym_name))) continue;
        if (maybe_versym) |versym| {
            if (!checkver(maybe_verdef.?, versym[i], vername, strings))
                continue;
        }
        return base +% syms[i].st_value;
    }

    return 0;
}

fn checkver(def_arg: *elf.Verdef, vsym_arg: i32, vername: []const u8, strings: [*]u8) bool {
    var def = def_arg;
    const vsym = @bitCast(u32, vsym_arg) & 0x7fff;
    while (true) {
        if (0 == (def.vd_flags & elf.VER_FLG_BASE) and (def.vd_ndx & 0x7fff) == vsym)
            break;
        if (def.vd_next == 0)
            return false;
        def = @intToPtr(*elf.Verdef, @ptrToInt(def) + def.vd_next);
    }
    const aux = @intToPtr(*elf.Verdaux, @ptrToInt(def) + def.vd_aux);
    const vda_name = std.meta.assumeSentinel(strings + aux.vda_name, 0);
    return mem.eql(u8, vername, mem.spanZ(vda_name));
}
