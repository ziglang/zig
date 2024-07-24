const std = @import("std");
const builtin = @import("builtin");
const elf = std.elf;
const assert = std.debug.assert;

const R_AMD64_RELATIVE = 8;
const R_386_RELATIVE = 8;
const R_ARC_RELATIVE = 56;
const R_ARM_RELATIVE = 23;
const R_AARCH64_RELATIVE = 1027;
const R_CSKY_RELATIVE = 9;
const R_HEXAGON_RELATIVE = 35;
const R_LARCH_RELATIVE = 3;
const R_68K_RELATIVE = 22;
const R_MIPS_RELATIVE = 128;
const R_PPC_RELATIVE = 22;
const R_RISCV_RELATIVE = 3;
const R_390_RELATIVE = 12;
const R_SPARC_RELATIVE = 22;

const R_RELATIVE = switch (builtin.cpu.arch) {
    .x86 => R_386_RELATIVE,
    .x86_64 => R_AMD64_RELATIVE,
    .arc => R_ARC_RELATIVE,
    .arm, .armeb, .thumb, .thumbeb => R_ARM_RELATIVE,
    .aarch64, .aarch64_be => R_AARCH64_RELATIVE,
    .csky => R_CSKY_RELATIVE,
    .hexagon => R_HEXAGON_RELATIVE,
    .loongarch32, .loongarch64 => R_LARCH_RELATIVE,
    .m68k => R_68K_RELATIVE,
    .mips, .mipsel, .mips64, .mips64el => R_MIPS_RELATIVE,
    .powerpc, .powerpcle, .powerpc64, .powerpc64le => R_PPC_RELATIVE,
    .riscv32, .riscv64 => R_RISCV_RELATIVE,
    .s390x => R_390_RELATIVE,
    else => @compileError("Missing R_RELATIVE definition for this target"),
};

// Obtain a pointer to the _DYNAMIC array.
// We have to compute its address as a PC-relative quantity not to require a
// relocation that, at this point, is not yet applied.
fn getDynamicSymbol() [*]elf.Dyn {
    return switch (builtin.cpu.arch) {
        .x86 => asm volatile (
            \\ .weak _DYNAMIC
            \\ .hidden _DYNAMIC
            \\ call 1f
            \\ 1: pop %[ret]
            \\ lea _DYNAMIC-1b(%[ret]), %[ret]
            : [ret] "=r" (-> [*]elf.Dyn),
        ),
        .x86_64 => asm volatile (
            \\ .weak _DYNAMIC
            \\ .hidden _DYNAMIC
            \\ lea _DYNAMIC(%%rip), %[ret]
            : [ret] "=r" (-> [*]elf.Dyn),
        ),
        .arc => asm volatile (
            \\ .weak _DYNAMIC
            \\ .hidden _DYNAMIC
            \\ add %[ret], pcl, _DYNAMIC@pcl
            : [ret] "=r" (-> [*]elf.Dyn),
        ),
        // Work around the limited offset range of `ldr`
        .arm, .armeb, .thumb, .thumbeb => asm volatile (
            \\ .weak _DYNAMIC
            \\ .hidden _DYNAMIC
            \\ ldr %[ret], 1f
            \\ add %[ret], pc
            \\ b 2f
            \\ 1: .word _DYNAMIC-1b
            \\ 2:
            : [ret] "=r" (-> [*]elf.Dyn),
        ),
        // A simple `adr` is not enough as it has a limited offset range
        .aarch64, .aarch64_be => asm volatile (
            \\ .weak _DYNAMIC
            \\ .hidden _DYNAMIC
            \\ adrp %[ret], _DYNAMIC
            \\ add %[ret], %[ret], #:lo12:_DYNAMIC
            : [ret] "=r" (-> [*]elf.Dyn),
        ),
        // The CSKY ABI requires the gb register to point to the GOT. Additionally, the first
        // entry in the GOT is defined to hold the address of _DYNAMIC.
        .csky => asm volatile (
            \\ mov %[ret], gb
            \\ ldw %[ret], %[ret]
            : [ret] "=r" (-> [*]elf.Dyn),
        ),
        .hexagon => asm volatile (
            \\ .weak _DYNAMIC
            \\ .hidden _DYNAMIC
            \\ jump 1f
            \\ .word _DYNAMIC - .
            \\ 1:
            \\ r1 = pc
            \\ r1 = add(r1, #-4)
            \\ %[ret] = memw(r1)
            \\ %[ret] = add(r1, %[ret])
            : [ret] "=r" (-> [*]elf.Dyn),
            :
            : "r1"
        ),
        .loongarch32, .loongarch64 => asm volatile (
            \\ .weak _DYNAMIC
            \\ .hidden _DYNAMIC
            \\ la.local %[ret], _DYNAMIC
            : [ret] "=r" (-> [*]elf.Dyn),
        ),
        // Note that the - 8 is needed because pc in the second lea instruction points into the
        // middle of that instruction. (The first lea is 6 bytes, the second is 4 bytes.)
        .m68k => asm volatile (
            \\ .weak _DYNAMIC
            \\ .hidden _DYNAMIC
            \\ lea _DYNAMIC - . - 8, %[ret]
            \\ lea (%[ret], %%pc), %[ret]
            : [ret] "=r" (-> [*]elf.Dyn),
        ),
        .mips, .mipsel => asm volatile (
            \\ .weak _DYNAMIC
            \\ .hidden _DYNAMIC
            \\ bal 1f
            \\ .gpword _DYNAMIC
            \\ 1:
            \\ lw %[ret], 0($ra)
            \\ addu %[ret], %[ret], $gp
            : [ret] "=r" (-> [*]elf.Dyn),
            :
            : "lr"
        ),
        .mips64, .mips64el => asm volatile (
            \\ .weak _DYNAMIC
            \\ .hidden _DYNAMIC
            \\ .balign 8
            \\ bal 1f
            \\ .gpdword _DYNAMIC
            \\ 1:
            \\ ld %[ret], 0($ra)
            \\ daddu %[ret], %[ret], $gp
            : [ret] "=r" (-> [*]elf.Dyn),
            :
            : "lr"
        ),
        .powerpc, .powerpcle => asm volatile (
            \\ .weak _DYNAMIC
            \\ .hidden _DYNAMIC
            \\ bl 1f
            \\ .long _DYNAMIC - .
            \\ 1:
            \\ mflr %[ret]
            \\ lwz 4, 0(%[ret])
            \\ add %[ret], 4, %[ret]
            : [ret] "=r" (-> [*]elf.Dyn),
            :
            : "lr", "r4"
        ),
        .powerpc64, .powerpc64le => asm volatile (
            \\ .weak _DYNAMIC
            \\ .hidden _DYNAMIC
            \\ bl 1f
            \\ .quad _DYNAMIC - .
            \\ 1:
            \\ mflr %[ret]
            \\ ld 4, 0(%[ret])
            \\ add %[ret], 4, %[ret]
            : [ret] "=r" (-> [*]elf.Dyn),
            :
            : "lr", "r4"
        ),
        .riscv32, .riscv64 => asm volatile (
            \\ .weak _DYNAMIC
            \\ .hidden _DYNAMIC
            \\ lla %[ret], _DYNAMIC
            : [ret] "=r" (-> [*]elf.Dyn),
        ),
        .s390x => asm volatile (
            \\ .weak _DYNAMIC
            \\ .hidden _DYNAMIC
            \\ larl %[ret], 1f
            \\ agf %[ret], 0(%[ret])
            \\ b 2f
            \\ 1: .long _DYNAMIC - .
            \\ 2:
            : [ret] "=r" (-> [*]elf.Dyn),
        ),
        else => {
            @compileError("PIE startup is not yet supported for this target!");
        },
    };
}

pub fn relocate(phdrs: []elf.Phdr) void {
    @setRuntimeSafety(false);
    @disableInstrumentation();

    const dynv = getDynamicSymbol();
    // Recover the delta applied by the loader by comparing the effective and
    // the theoretical load addresses for the `_DYNAMIC` symbol.
    const base_addr = base: {
        for (phdrs) |*phdr| {
            if (phdr.p_type != elf.PT_DYNAMIC) continue;
            break :base @intFromPtr(dynv) - phdr.p_vaddr;
        }
        // This is not supposed to happen for well-formed binaries.
        @trap();
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

    // Apply the relocations.
    if (rel_addr != 0) {
        const rel = std.mem.bytesAsSlice(elf.Rel, @as([*]u8, @ptrFromInt(rel_addr))[0..rel_size]);
        for (rel) |r| {
            if (r.r_type() != R_RELATIVE) continue;
            @as(*usize, @ptrFromInt(base_addr + r.r_offset)).* += base_addr;
        }
    }
    if (rela_addr != 0) {
        const rela = std.mem.bytesAsSlice(elf.Rela, @as([*]u8, @ptrFromInt(rela_addr))[0..rela_size]);
        for (rela) |r| {
            if (r.r_type() != R_RELATIVE) continue;
            @as(*usize, @ptrFromInt(base_addr + r.r_offset)).* = base_addr + @as(usize, @bitCast(r.r_addend));
        }
    }
}
