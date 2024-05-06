const std = @import("../../std.zig");
const elf = std.elf;
const linux = std.os.linux;
const mem = std.mem;
const maxInt = std.math.maxInt;

pub fn lookup(vername: []const u8, name: []const u8) usize {
    const vdso_addr = linux.getauxval(std.elf.AT_SYSINFO_EHDR);
    if (vdso_addr == 0) return 0;

    const eh = @as(*elf.Ehdr, @ptrFromInt(vdso_addr));
    var ph_addr: usize = vdso_addr + eh.e_phoff;

    var maybe_dynv: ?[*]usize = null;
    var base: usize = maxInt(usize);
    {
        var i: usize = 0;
        while (i < eh.e_phnum) : ({
            i += 1;
            ph_addr += eh.e_phentsize;
        }) {
            const this_ph = @as(*elf.Phdr, @ptrFromInt(ph_addr));
            switch (this_ph.p_type) {
                // On WSL1 as well as older kernels, the VDSO ELF image is pre-linked in the upper half
                // of the memory space (e.g. p_vaddr = 0xffffffffff700000 on WSL1).
                // Wrapping operations are used on this line as well as subsequent calculations relative to base
                // (lines 47, 78) to ensure no overflow check is tripped.
                elf.PT_LOAD => base = vdso_addr +% this_ph.p_offset -% this_ph.p_vaddr,
                elf.PT_DYNAMIC => maybe_dynv = @as([*]usize, @ptrFromInt(vdso_addr + this_ph.p_offset)),
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
                elf.DT_STRTAB => maybe_strings = @as([*]u8, @ptrFromInt(p)),
                elf.DT_SYMTAB => maybe_syms = @as([*]elf.Sym, @ptrFromInt(p)),
                elf.DT_HASH => maybe_hashtab = @as([*]linux.Elf_Symndx, @ptrFromInt(p)),
                elf.DT_VERSYM => maybe_versym = @as([*]u16, @ptrFromInt(p)),
                elf.DT_VERDEF => maybe_verdef = @as(*elf.Verdef, @ptrFromInt(p)),
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
        if (0 == (@as(u32, 1) << @as(u5, @intCast(syms[i].st_info & 0xf)) & OK_TYPES)) continue;
        if (0 == (@as(u32, 1) << @as(u5, @intCast(syms[i].st_info >> 4)) & OK_BINDS)) continue;
        if (0 == syms[i].st_shndx) continue;
        const sym_name = @as([*:0]u8, @ptrCast(strings + syms[i].st_name));
        if (!mem.eql(u8, name, mem.sliceTo(sym_name, 0))) continue;
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
    const vsym = @as(u32, @bitCast(vsym_arg)) & 0x7fff;
    while (true) {
        if (0 == (def.vd_flags & elf.VER_FLG_BASE) and (def.vd_ndx & 0x7fff) == vsym)
            break;
        if (def.vd_next == 0)
            return false;
        def = @as(*elf.Verdef, @ptrFromInt(@intFromPtr(def) + def.vd_next));
    }
    const aux = @as(*elf.Verdaux, @ptrFromInt(@intFromPtr(def) + def.vd_aux));
    const vda_name = @as([*:0]u8, @ptrCast(strings + aux.vda_name));
    return mem.eql(u8, vername, mem.sliceTo(vda_name, 0));
}
