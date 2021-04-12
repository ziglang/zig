const std = @import("std");
const elf = std.elf;
const builtin = std.builtin;
const assert = std.debug.assert;

const R_AMD64_RELATIVE = 8;
const R_386_RELATIVE = 8;
const R_ARM_RELATIVE = 23;
const R_AARCH64_RELATIVE = 1027;
const R_RISCV_RELATIVE = 3;

const ARCH_RELATIVE_RELOC = switch (builtin.arch) {
    .i386 => R_386_RELATIVE,
    .x86_64 => R_AMD64_RELATIVE,
    .arm => R_ARM_RELATIVE,
    .aarch64 => R_AARCH64_RELATIVE,
    .riscv64 => R_RISCV_RELATIVE,
    else => @compileError("unsupported architecture"),
};

// Just a convoluted (but necessary) way to obtain the address of the _DYNAMIC[]
// vector as PC-relative so that we can use it before any relocation is applied
fn getDynamicSymbol() [*]elf.Dyn {
    const addr = switch (builtin.arch) {
        .i386 => asm volatile (
            \\ .weak _DYNAMIC
            \\ .hidden _DYNAMIC
            \\ call 1f
            \\ 1: pop %[ret]
            \\ lea _DYNAMIC-1b(%[ret]), %[ret]
            : [ret] "=r" (-> usize)
        ),
        .x86_64 => asm volatile (
            \\ .weak _DYNAMIC
            \\ .hidden _DYNAMIC
            \\ lea _DYNAMIC(%%rip), %[ret]
            : [ret] "=r" (-> usize)
        ),
        // Work around the limited offset range of `ldr`
        .arm => asm volatile (
            \\ .weak _DYNAMIC
            \\ .hidden _DYNAMIC
            \\ ldr %[ret], 1f
            \\ add %[ret], pc
            \\ b 2f
            \\ 1: .word _DYNAMIC-1b
            \\ 2:
            : [ret] "=r" (-> usize)
        ),
        // A simple `adr` is not enough as it has a limited offset range
        .aarch64 => asm volatile (
            \\ .weak _DYNAMIC
            \\ .hidden _DYNAMIC
            \\ adrp %[ret], _DYNAMIC
            \\ add %[ret], %[ret], #:lo12:_DYNAMIC
            : [ret] "=r" (-> usize)
        ),
        .riscv64 => asm volatile (
            \\ .weak _DYNAMIC
            \\ .hidden _DYNAMIC
            \\ lla %[ret], _DYNAMIC
            : [ret] "=r" (-> usize)
        ),
        else => @compileError("???"),
    };
    return @intToPtr([*]elf.Dyn, addr);
}

pub fn apply_relocations() void {
    @setRuntimeSafety(false);

    const dynv = getDynamicSymbol();
    const auxv = std.os.linux.elf_aux_maybe.?;
    var at_phent: usize = undefined;
    var at_phnum: usize = undefined;
    var at_phdr: usize = undefined;
    var at_hwcap: usize = undefined;

    {
        var i: usize = 0;
        while (auxv[i].a_type != std.elf.AT_NULL) : (i += 1) {
            switch (auxv[i].a_type) {
                elf.AT_PHENT => at_phent = auxv[i].a_un.a_val,
                elf.AT_PHNUM => at_phnum = auxv[i].a_un.a_val,
                elf.AT_PHDR => at_phdr = auxv[i].a_un.a_val,
                else => continue,
            }
        }
    }

    // Sanity check
    assert(at_phent == @sizeOf(elf.Phdr));

    // Search the TLS section
    const phdrs = (@intToPtr([*]elf.Phdr, at_phdr))[0..at_phnum];

    const base_addr = blk: {
        for (phdrs) |*phdr| {
            if (phdr.p_type == elf.PT_DYNAMIC) {
                break :blk @ptrToInt(&dynv[0]) - phdr.p_vaddr;
            }
        }
        unreachable;
    };

    var rel_addr: usize = 0;
    var rela_addr: usize = 0;
    var rel_size: usize = 0;
    var rela_size: usize = 0;

    {
        var i: usize = 0;
        while (dynv[i].d_tag != elf.DT_NULL) : (i += 1) {
            switch (dynv[i].d_tag) {
                elf.DT_REL => rel_addr = base_addr + dynv[i].d_val,
                elf.DT_RELA => rela_addr = base_addr + dynv[i].d_val,
                elf.DT_RELSZ => rel_size = dynv[i].d_val,
                elf.DT_RELASZ => rela_size = dynv[i].d_val,
                else => {},
            }
        }
    }

    // Perform the relocations
    if (rel_addr != 0) {
        const rel = std.mem.bytesAsSlice(elf.Rel, @intToPtr([*]u8, rel_addr)[0..rel_size]);
        for (rel) |r| {
            if (r.r_type() != ARCH_RELATIVE_RELOC) continue;
            @intToPtr(*usize, base_addr + r.r_offset).* += base_addr;
        }
    }
    if (rela_addr != 0) {
        const rela = std.mem.bytesAsSlice(elf.Rela, @intToPtr([*]u8, rela_addr)[0..rela_size]);
        for (rela) |r| {
            if (r.r_type() != ARCH_RELATIVE_RELOC) continue;
            @intToPtr(*usize, base_addr + r.r_offset).* += base_addr + @bitCast(usize, r.r_addend);
        }
    }
}
