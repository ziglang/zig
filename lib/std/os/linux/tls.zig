const std = @import("std");
const os = std.os;
const mem = std.mem;
const elf = std.elf;
const builtin = @import("builtin");
const assert = std.debug.assert;

// This file implements the two TLS variants [1] used by ELF-based systems.
//
// The variant I has the following layout in memory:
// -------------------------------------------------------
// |   DTV   |     Zig     |   DTV   | Alignment |  TLS  |
// | storage | thread data | pointer |           | block |
// ------------------------^------------------------------
//                         `-- The thread pointer register points here
//
// In this case we allocate additional space for our control structure that's
// placed _before_ the DTV pointer together with the DTV.
//
// NOTE: Some systems such as power64 or mips use this variant with a twist: the
// alignment is not present and the tp and DTV addresses are offset by a
// constant.
//
// On the other hand the variant II has the following layout in memory:
// ---------------------------------------
// |  TLS  | TCB |     Zig     |   DTV   |
// | block |     | thread data | storage |
// --------^------------------------------
//         `-- The thread pointer register points here
//
// The structure of the TCB is not defined by the ABI so we reserve enough space
// for a single pointer as some architectures such as i386 and x86_64 need a
// pointer to the TCB block itself at the address pointed by the tp.
//
// In this case the control structure and DTV are placed one after another right
// after the TLS block data.
//
// At the moment the DTV is very simple since we only support static TLS, all we
// need is a two word vector to hold the number of entries (1) and the address
// of the first TLS block.
//
// [1] https://www.akkadia.org/drepper/tls.pdf

const TLSVariant = enum {
    VariantI,
    VariantII,
};

const tls_variant = switch (builtin.arch) {
    .arm, .armeb, .aarch64, .aarch64_be, .riscv32, .riscv64, .mipsel => TLSVariant.VariantI,
    .x86_64, .i386 => TLSVariant.VariantII,
    else => @compileError("undefined tls_variant for this architecture"),
};

// Controls how many bytes are reserved for the Thread Control Block
const tls_tcb_size = switch (builtin.arch) {
    // ARM EABI mandates enough space for two pointers: the first one points to
    // the DTV while the second one is unspecified but reserved
    .arm, .armeb, .aarch64, .aarch64_be => 2 * @sizeOf(usize),
    else => @sizeOf(usize),
};

// Controls if the TCB should be aligned according to the TLS segment p_align
const tls_tcb_align_size = switch (builtin.arch) {
    .arm, .armeb, .aarch64, .aarch64_be => true,
    else => false,
};

// Controls if the TP points to the end of the TCB instead of its beginning
const tls_tp_points_past_tcb = switch (builtin.arch) {
    .riscv32, .riscv64, .mipsel, .powerpc64, .powerpc64le => true,
    else => false,
};

// Check if the architecture-specific parameters look correct
comptime {
    if (tls_tcb_align_size and tls_variant != TLSVariant.VariantI) {
        @compileError("tls_tcb_align_size is only meaningful for variant I TLS");
    }
}

// Some architectures add some offset to the tp and dtv addresses in order to
// make the generated code more efficient

const tls_tp_offset = switch (builtin.arch) {
    .mipsel => 0x7000,
    else => 0,
};

const tls_dtv_offset = switch (builtin.arch) {
    .mipsel => 0x8000,
    .riscv32, .riscv64 => 0x800,
    else => 0,
};

// Per-thread storage for Zig's use
const CustomData = packed struct {};

// Dynamic Thread Vector
const DTV = packed struct {
    entries: usize,
    tls_block: [1]usize,
};

// Holds all the information about the process TLS image
const TLSImage = struct {
    data_src: []u8,
    alloc_size: usize,
    tcb_offset: usize,
    dtv_offset: usize,
    data_offset: usize,
    // Only used on the i386 architecture
    gdt_entry_number: usize,
};

pub var tls_image: ?TLSImage = null;

pub fn setThreadPointer(addr: usize) void {
    switch (builtin.arch) {
        .i386 => {
            var user_desc = std.os.linux.user_desc{
                .entry_number = tls_image.?.gdt_entry_number,
                .base_addr = addr,
                .limit = 0xfffff,
                .seg_32bit = 1,
                .contents = 0, // Data
                .read_exec_only = 0,
                .limit_in_pages = 1,
                .seg_not_present = 0,
                .useable = 1,
            };
            const rc = std.os.linux.syscall1(std.os.linux.SYS_set_thread_area, @ptrToInt(&user_desc));
            assert(rc == 0);

            const gdt_entry_number = user_desc.entry_number;
            // We have to keep track of our slot as it's also needed for clone()
            tls_image.?.gdt_entry_number = gdt_entry_number;
            // Update the %gs selector
            asm volatile ("movl %[gs_val], %%gs"
                :
                : [gs_val] "r" (gdt_entry_number << 3 | 3)
            );
        },
        .x86_64 => {
            const rc = std.os.linux.syscall2(std.os.linux.SYS_arch_prctl, std.os.linux.ARCH_SET_FS, addr);
            assert(rc == 0);
        },
        .aarch64 => {
            asm volatile (
                \\ msr tpidr_el0, %[addr]
                :
                : [addr] "r" (addr)
            );
        },
        .arm => {
            const rc = std.os.linux.syscall1(std.os.linux.SYS_set_tls, addr);
            assert(rc == 0);
        },
        .riscv64 => {
            asm volatile (
                \\ mv tp, %[addr]
                :
                : [addr] "r" (addr)
            );
        },
        .mipsel => {
            const rc = std.os.linux.syscall1(std.os.linux.SYS_set_thread_area, addr);
            assert(rc == 0);
        },
        else => @compileError("Unsupported architecture"),
    }
}

pub fn initTLS() ?*elf.Phdr {
    var tls_phdr: ?*elf.Phdr = null;
    var img_base: usize = 0;

    const auxv = std.os.linux.elf_aux_maybe.?;
    var at_phent: usize = undefined;
    var at_phnum: usize = undefined;
    var at_phdr: usize = undefined;
    var at_hwcap: usize = undefined;

    var i: usize = 0;
    while (auxv[i].a_type != std.elf.AT_NULL) : (i += 1) {
        switch (auxv[i].a_type) {
            elf.AT_PHENT => at_phent = auxv[i].a_un.a_val,
            elf.AT_PHNUM => at_phnum = auxv[i].a_un.a_val,
            elf.AT_PHDR => at_phdr = auxv[i].a_un.a_val,
            elf.AT_HWCAP => at_hwcap = auxv[i].a_un.a_val,
            else => continue,
        }
    }

    // Sanity check
    assert(at_phent == @sizeOf(elf.Phdr));

    // Search the TLS section
    const phdrs = (@intToPtr([*]elf.Phdr, at_phdr))[0..at_phnum];

    var gnu_stack: ?*elf.Phdr = null;

    for (phdrs) |*phdr| {
        switch (phdr.p_type) {
            elf.PT_PHDR => img_base = at_phdr - phdr.p_vaddr,
            elf.PT_TLS => tls_phdr = phdr,
            elf.PT_GNU_STACK => gnu_stack = phdr,
            else => continue,
        }
    }

    if (tls_phdr) |phdr| {
        // If the cpu is arm-based, check if it supports the TLS register
        if (builtin.arch == .arm and at_hwcap & std.os.linux.HWCAP_TLS == 0) {
            // If the CPU does not support TLS via a coprocessor register,
            // a kernel helper function can be used instead on certain linux kernels.
            // See linux/arch/arm/include/asm/tls.h and musl/src/thread/arm/__set_thread_area.c.
            @panic("TODO: Implement ARM fallback TLS functionality");
        }

        // Offsets into the allocated TLS area
        var tcb_offset: usize = undefined;
        var dtv_offset: usize = undefined;
        var data_offset: usize = undefined;
        var thread_data_offset: usize = undefined;
        // Compute the total size of the ABI-specific data plus our own control
        // structures
        const alloc_size = switch (tls_variant) {
            .VariantI => blk: {
                var l: usize = 0;
                dtv_offset = l;
                l += @sizeOf(DTV);
                thread_data_offset = l;
                l += @sizeOf(CustomData);
                l = mem.alignForward(l, phdr.p_align);
                tcb_offset = l;
                if (tls_tcb_align_size) {
                    l += mem.alignForward(tls_tcb_size, phdr.p_align);
                } else {
                    l += tls_tcb_size;
                }
                data_offset = l;
                l += phdr.p_memsz;
                break :blk l;
            },
            .VariantII => blk: {
                var l: usize = 0;
                data_offset = l;
                l += phdr.p_memsz;
                l = mem.alignForward(l, phdr.p_align);
                tcb_offset = l;
                l += tls_tcb_size;
                thread_data_offset = l;
                l += @sizeOf(CustomData);
                dtv_offset = l;
                l += @sizeOf(DTV);
                break :blk l;
            },
        };

        tls_image = TLSImage{
            .data_src = @intToPtr([*]u8, phdr.p_vaddr + img_base)[0..phdr.p_filesz],
            .alloc_size = alloc_size,
            .tcb_offset = tcb_offset,
            .dtv_offset = dtv_offset,
            .data_offset = data_offset,
            .gdt_entry_number = @bitCast(usize, @as(isize, -1)),
        };
    }

    return gnu_stack;
}

pub fn copyTLS(addr: usize) usize {
    const tls_img = tls_image.?;

    // Be paranoid, clear the area we're going to use
    @memset(@intToPtr([*]u8, addr), 0, tls_img.alloc_size);
    // Prepare the DTV
    const dtv = @intToPtr(*DTV, addr + tls_img.dtv_offset);
    dtv.entries = 1;
    dtv.tls_block[0] = addr + tls_img.data_offset + tls_dtv_offset;
    // Set-up the TCB
    // Force the alignment to 1 byte as the TCB may start from a non-aligned
    // address under the variant II model
    const tcb_ptr = @intToPtr(*align(1) usize, addr + tls_img.tcb_offset);
    if (tls_variant == TLSVariant.VariantI) {
        tcb_ptr.* = addr + tls_img.dtv_offset;
    } else {
        tcb_ptr.* = addr + tls_img.tcb_offset;
    }
    // Copy the data
    @memcpy(@intToPtr([*]u8, addr + tls_img.data_offset), tls_img.data_src.ptr, tls_img.data_src.len);

    // Return the corrected (if needed) value for the tp register
    return addr + tls_tp_offset +
        if (tls_tp_points_past_tcb) tls_img.data_offset else tls_img.tcb_offset;
}

var main_thread_tls_buffer: [256]u8 align(32) = undefined;

pub fn allocateTLS(size: usize) usize {
    // Small TLS allocation, use our local buffer
    if (size < main_thread_tls_buffer.len) {
        return @ptrToInt(&main_thread_tls_buffer);
    }

    const slice = os.mmap(
        null,
        size,
        os.PROT_READ | os.PROT_WRITE,
        os.MAP_PRIVATE | os.MAP_ANONYMOUS,
        -1,
        0,
    ) catch @panic("out of memory");

    return @ptrToInt(slice.ptr);
}
