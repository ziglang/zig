const std = @import("std");
const arch = std.builtin.cpu.arch;
const os = std.builtin.os.tag;

// Ported from llvm-project d32170dbd5b0d54436537b6b75beaf44324e0c28

// The compiler generates calls to __clear_cache() when creating
// trampoline functions on the stack for use with nested functions.
// It is expected to invalidate the instruction cache for the
// specified range.

pub fn clear_cache(start: usize, end: usize) callconv(.C) void {
    const x86 = switch (arch) {
        .i386, .x86_64 => true,
        else => false,
    };
    const arm32 = switch (arch) {
        .arm, .armeb, .thumb, .thumbeb => true,
        else => false,
    };
    const arm64 = switch (arch) {
        .aarch64, .aarch64_be, .aarch64_32 => true,
        else => false,
    };
    const mips = switch (arch) {
        .mips, .mipsel, .mips64, .mips64el => true,
        else => false,
    };
    const powerpc64 = switch (arch) {
        .powerpc64, .powerpc64le => true,
        else => false,
    };
    const sparc = switch (arch) {
        .sparc, .sparcv9, .sparcel => true,
        else => false,
    };
    const apple = switch (os) {
        .ios, .macosx, .watchos, .tvos => true,
        else => false,
    };
    if (x86) {
        // Intel processors have a unified instruction and data cache
        // so there is nothing to do
    } else if (os == .windows and (arm32 or arm64)) {
        @compileError("TODO");
        // FlushInstructionCache(GetCurrentProcess(), start, end - start);
    } else if (arm32 and !apple) {
        @compileError("TODO");
        //#if defined(__FreeBSD__) || defined(__NetBSD__)
        //  struct arm_sync_icache_args arg;
        //
        //  arg.addr = (uintptr_t)start;
        //  arg.len = (uintptr_t)end - (uintptr_t)start;
        //
        //  sysarch(ARM_SYNC_ICACHE, &arg);
        //#elif defined(__linux__)
        //// We used to include asm/unistd.h for the __ARM_NR_cacheflush define, but
        //// it also brought many other unused defines, as well as a dependency on
        //// kernel headers to be installed.
        ////
        //// This value is stable at least since Linux 3.13 and should remain so for
        //// compatibility reasons, warranting it's re-definition here.
        //#define __ARM_NR_cacheflush 0x0f0002
        //  register int start_reg __asm("r0") = (int)(intptr_t)start;
        //  const register int end_reg __asm("r1") = (int)(intptr_t)end;
        //  const register int flags __asm("r2") = 0;
        //  const register int syscall_nr __asm("r7") = __ARM_NR_cacheflush;
        //  __asm __volatile("svc 0x0"
        //                   : "=r"(start_reg)
        //                   : "r"(syscall_nr), "r"(start_reg), "r"(end_reg), "r"(flags));
        //  assert(start_reg == 0 && "Cache flush syscall failed.");
        //#else
        //  compilerrt_abort();
        //#endif
    } else if (os == .linux and mips) {
        @compileError("TODO");
        //const uintptr_t start_int = (uintptr_t)start;
        //const uintptr_t end_int = (uintptr_t)end;
        //syscall(__NR_cacheflush, start, (end_int - start_int), BCACHE);
    } else if (mips and os == .openbsd) {
        @compileError("TODO");
        //cacheflush(start, (uintptr_t)end - (uintptr_t)start, BCACHE);
    } else if (arm64 and !apple) {
        // Get Cache Type Info.
        // TODO memoize this?
        var ctr_el0: u64 = 0;
        asm volatile (
            \\mrs %[x], ctr_el0
            \\
            : [x] "=r" (ctr_el0)
        );
        // The DC and IC instructions must use 64-bit registers so we don't use
        // uintptr_t in case this runs in an IPL32 environment.
        var addr: u64 = undefined;
        // If CTR_EL0.IDC is set, data cache cleaning to the point of unification
        // is not required for instruction to data coherence.
        if (((ctr_el0 >> 28) & 0x1) == 0x0) {
            const dcache_line_size: usize = @as(usize, 4) << @intCast(u6, (ctr_el0 >> 16) & 15);
            addr = start & ~(dcache_line_size - 1);
            while (addr < end) : (addr += dcache_line_size) {
                asm volatile ("dc cvau, %[addr]"
                    :
                    : [addr] "r" (addr)
                );
            }
        }
        asm volatile ("dsb ish");
        // If CTR_EL0.DIC is set, instruction cache invalidation to the point of
        // unification is not required for instruction to data coherence.
        if (((ctr_el0 >> 29) & 0x1) == 0x0) {
            const icache_line_size: usize = @as(usize, 4) << @intCast(u6, (ctr_el0 >> 0) & 15);
            addr = start & ~(icache_line_size - 1);
            while (addr < end) : (addr += icache_line_size) {
                asm volatile ("ic ivau, %[addr]"
                    :
                    : [addr] "r" (addr)
                );
            }
        }
        asm volatile ("isb sy");
    } else if (powerpc64) {
        @compileError("TODO");
        //const size_t line_size = 32;
        //const size_t len = (uintptr_t)end - (uintptr_t)start;
        //
        //const uintptr_t mask = ~(line_size - 1);
        //const uintptr_t start_line = ((uintptr_t)start) & mask;
        //const uintptr_t end_line = ((uintptr_t)start + len + line_size - 1) & mask;
        //
        //for (uintptr_t line = start_line; line < end_line; line += line_size)
        //  __asm__ volatile("dcbf 0, %0" : : "r"(line));
        //__asm__ volatile("sync");
        //
        //for (uintptr_t line = start_line; line < end_line; line += line_size)
        //  __asm__ volatile("icbi 0, %0" : : "r"(line));
        //__asm__ volatile("isync");
    } else if (sparc) {
        @compileError("TODO");
        //const size_t dword_size = 8;
        //const size_t len = (uintptr_t)end - (uintptr_t)start;
        //
        //const uintptr_t mask = ~(dword_size - 1);
        //const uintptr_t start_dword = ((uintptr_t)start) & mask;
        //const uintptr_t end_dword = ((uintptr_t)start + len + dword_size - 1) & mask;
        //
        //for (uintptr_t dword = start_dword; dword < end_dword; dword += dword_size)
        //  __asm__ volatile("flush %0" : : "r"(dword));
    } else if (apple) {
        // On Darwin, sys_icache_invalidate() provides this functionality
        sys_icache_invalidate(start, end - start);
    } else {
        @compileError("no __clear_cache implementation available for this target");
    }
}

// Darwin-only
extern fn sys_icache_invalidate(start: usize, len: usize) void;
