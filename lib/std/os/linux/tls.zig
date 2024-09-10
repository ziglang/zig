//! This file implements the two TLS variants [1] used by ELF-based systems. Note that, in reality,
//! Variant I has two sub-variants.
//!
//! It is important to understand that the term TCB (Thread Control Block) is overloaded here.
//! Official ABI documentation uses it simply to mean the ABI TCB, i.e. a small area of ABI-defined
//! data, usually one or two words (see the `AbiTcb` type below). People will also often use TCB to
//! refer to the libc TCB, which can be any size and contain anything. (One could even omit it!) We
//! refer to the latter as the Zig TCB; see the `ZigTcb` type below.
//!
//! [1] https://www.akkadia.org/drepper/tls.pdf

const std = @import("std");
const mem = std.mem;
const elf = std.elf;
const math = std.math;
const assert = std.debug.assert;
const native_arch = @import("builtin").cpu.arch;
const linux = std.os.linux;
const posix = std.posix;

/// Represents an ELF TLS variant.
///
/// In all variants, the TP and the TLS blocks must be aligned to the `p_align` value in the
/// `PT_TLS` ELF program header. Everything else has natural alignment.
///
/// The location of the DTV does not actually matter. For simplicity, we put it in the TLS area, but
/// there is no actual ABI requirement that it reside there.
const Variant = enum {
    /// The original Variant I:
    ///
    /// ----------------------------------------
    /// | DTV | Zig TCB | ABI TCB | TLS Blocks |
    /// ----------------^-----------------------
    ///                 `-- The TP register points here.
    ///
    /// The layout in this variant necessitates separate alignment of both the TP and the TLS
    /// blocks.
    ///
    /// The first word in the ABI TCB points to the DTV. For some architectures, there may be a
    /// second word with an unspecified meaning.
    I_original,
    /// The modified Variant I:
    ///
    /// ---------------------------------------------------
    /// | DTV | Zig TCB | ABI TCB | [Offset] | TLS Blocks |
    /// -------------------------------------^-------------
    ///                                      `-- The TP register points here.
    ///
    /// The offset (which can be zero) is applied to the TP only; there is never physical gap
    /// between the ABI TCB and the TLS blocks. This implies that we only need to align the TP.
    ///
    /// The first (and only) word in the ABI TCB points to the DTV.
    I_modified,
    /// Variant II:
    ///
    /// ----------------------------------------
    /// | TLS Blocks | ABI TCB | Zig TCB | DTV |
    /// -------------^--------------------------
    ///              `-- The TP register points here.
    ///
    /// The first (and only) word in the ABI TCB points to the ABI TCB itself.
    II,
};

const current_variant: Variant = switch (native_arch) {
    .arc,
    .arm,
    .armeb,
    .aarch64,
    .aarch64_be,
    .csky,
    .thumb,
    .thumbeb,
    => .I_original,
    .loongarch32,
    .loongarch64,
    .m68k,
    .mips,
    .mipsel,
    .mips64,
    .mips64el,
    .powerpc,
    .powerpcle,
    .powerpc64,
    .powerpc64le,
    .riscv32,
    .riscv64,
    => .I_modified,
    .hexagon,
    .s390x,
    .sparc,
    .sparc64,
    .x86,
    .x86_64,
    => .II,
    else => @compileError("undefined TLS variant for this architecture"),
};

/// The Offset value for the modified Variant I.
const current_tp_offset = switch (native_arch) {
    .m68k,
    .mips,
    .mipsel,
    .mips64,
    .mips64el,
    .powerpc,
    .powerpcle,
    .powerpc64,
    .powerpc64le,
    => 0x7000,
    else => 0,
};

/// Usually only used by the modified Variant I.
const current_dtv_offset = switch (native_arch) {
    .m68k,
    .mips,
    .mipsel,
    .mips64,
    .mips64el,
    .powerpc,
    .powerpcle,
    .powerpc64,
    .powerpc64le,
    => 0x8000,
    .riscv32,
    .riscv64,
    => 0x800,
    else => 0,
};

/// Per-thread storage for the ELF TLS ABI.
const AbiTcb = switch (current_variant) {
    .I_original, .I_modified => switch (native_arch) {
        // ARM EABI mandates enough space for two pointers: the first one points to the DTV as
        // usual, while the second one is unspecified.
        .aarch64,
        .aarch64_be,
        .arm,
        .armeb,
        .thumb,
        .thumbeb,
        => extern struct {
            /// This is offset by `current_dtv_offset`.
            dtv: usize,
            reserved: ?*anyopaque,
        },
        else => extern struct {
            /// This is offset by `current_dtv_offset`.
            dtv: usize,
        },
    },
    .II => extern struct {
        /// This is self-referential.
        self: *AbiTcb,
    },
};

/// Per-thread storage for Zig's use. Currently unused.
const ZigTcb = struct {
    dummy: usize,
};

/// Dynamic Thread Vector as specified in the ELF TLS ABI. Ordinarily, there is a block pointer per
/// dynamically-loaded module, but since we only support static TLS, we only need one block pointer.
const Dtv = extern struct {
    len: usize = 1,
    tls_block: [*]u8,
};

/// Describes a process's TLS area. The area encompasses the DTV, both TCBs, and the TLS block, with
/// the exact layout of these being dependent primarily on `current_variant`.
const AreaDesc = struct {
    size: usize,
    alignment: usize,

    dtv: struct {
        /// Offset into the TLS area.
        offset: usize,
    },

    abi_tcb: struct {
        /// Offset into the TLS area.
        offset: usize,
    },

    block: struct {
        /// The initial data to be copied into the TLS block. Note that this may be smaller than
        /// `size`, in which case any remaining data in the TLS block is simply left uninitialized.
        init: []const u8,
        /// Offset into the TLS area.
        offset: usize,
        /// This is the effective size of the TLS block, which may be greater than `init.len`.
        size: usize,
    },

    /// Only used on the 32-bit x86 architecture (not x86_64, nor x32).
    gdt_entry_number: usize,
};

pub var area_desc: AreaDesc = undefined;

pub fn setThreadPointer(addr: usize) void {
    @setRuntimeSafety(false);
    @disableInstrumentation();

    switch (native_arch) {
        .x86 => {
            var user_desc: linux.user_desc = .{
                .entry_number = area_desc.gdt_entry_number,
                .base_addr = addr,
                .limit = 0xfffff,
                .flags = .{
                    .seg_32bit = 1,
                    .contents = 0, // Data
                    .read_exec_only = 0,
                    .limit_in_pages = 1,
                    .seg_not_present = 0,
                    .useable = 1,
                },
            };
            const rc = @call(.always_inline, linux.syscall1, .{ .set_thread_area, @intFromPtr(&user_desc) });
            assert(rc == 0);

            const gdt_entry_number = user_desc.entry_number;
            // We have to keep track of our slot as it's also needed for clone()
            area_desc.gdt_entry_number = gdt_entry_number;
            // Update the %gs selector
            asm volatile ("movl %[gs_val], %%gs"
                :
                : [gs_val] "r" (gdt_entry_number << 3 | 3),
            );
        },
        .x86_64 => {
            const rc = @call(.always_inline, linux.syscall2, .{ .arch_prctl, linux.ARCH.SET_FS, addr });
            assert(rc == 0);
        },
        .aarch64, .aarch64_be => {
            asm volatile (
                \\ msr tpidr_el0, %[addr]
                :
                : [addr] "r" (addr),
            );
        },
        .arc => {
            // We apparently need to both set r25 (TP) *and* inform the kernel...
            asm volatile (
                \\ mov r25, %[addr]
                :
                : [addr] "r" (addr),
            );
            const rc = @call(.always_inline, linux.syscall1, .{ .arc_settls, addr });
            assert(rc == 0);
        },
        .arm, .armeb, .thumb, .thumbeb => {
            const rc = @call(.always_inline, linux.syscall1, .{ .set_tls, addr });
            assert(rc == 0);
        },
        .m68k => {
            const rc = linux.syscall1(.set_thread_area, addr);
            assert(rc == 0);
        },
        .hexagon => {
            asm volatile (
                \\ ugp = %[addr]
                :
                : [addr] "r" (addr),
            );
        },
        .loongarch32, .loongarch64 => {
            asm volatile (
                \\ move $tp, %[addr]
                :
                : [addr] "r" (addr),
            );
        },
        .riscv32, .riscv64 => {
            asm volatile (
                \\ mv tp, %[addr]
                :
                : [addr] "r" (addr),
            );
        },
        .csky, .mips, .mipsel, .mips64, .mips64el => {
            const rc = @call(.always_inline, linux.syscall1, .{ .set_thread_area, addr });
            assert(rc == 0);
        },
        .powerpc, .powerpcle => {
            asm volatile (
                \\ mr 2, %[addr]
                :
                : [addr] "r" (addr),
            );
        },
        .powerpc64, .powerpc64le => {
            asm volatile (
                \\ mr 13, %[addr]
                :
                : [addr] "r" (addr),
            );
        },
        .s390x => {
            asm volatile (
                \\ lgr %%r0, %[addr]
                \\ sar %%a1, %%r0
                \\ srlg %%r0, %%r0, 32
                \\ sar %%a0, %%r0
                :
                : [addr] "r" (addr),
                : "r0"
            );
        },
        .sparc, .sparc64 => {
            asm volatile (
                \\ mov %[addr], %%g7
                :
                : [addr] "r" (addr),
            );
        },
        else => @compileError("Unsupported architecture"),
    }
}

fn computeAreaDesc(phdrs: []elf.Phdr) void {
    @setRuntimeSafety(false);
    @disableInstrumentation();

    var tls_phdr: ?*elf.Phdr = null;
    var img_base: usize = 0;

    for (phdrs) |*phdr| {
        switch (phdr.p_type) {
            elf.PT_PHDR => img_base = @intFromPtr(phdrs.ptr) - phdr.p_vaddr,
            elf.PT_TLS => tls_phdr = phdr,
            else => {},
        }
    }

    var align_factor: usize = undefined;
    var block_init: []const u8 = undefined;
    var block_size: usize = undefined;

    if (tls_phdr) |phdr| {
        align_factor = phdr.p_align;

        // The effective size in memory is represented by `p_memsz`; the length of the data stored
        // in the `PT_TLS` segment is `p_filesz` and may be less than the former.
        block_init = @as([*]u8, @ptrFromInt(img_base + phdr.p_vaddr))[0..phdr.p_filesz];
        block_size = phdr.p_memsz;
    } else {
        align_factor = @alignOf(usize);

        block_init = &[_]u8{};
        block_size = 0;
    }

    // Offsets into the allocated TLS area.
    var dtv_offset: usize = undefined;
    var abi_tcb_offset: usize = undefined;
    var block_offset: usize = undefined;

    // Compute the total size of the ABI-specific data plus our own `ZigTcb` structure. All the
    // offsets calculated here assume a well-aligned base address.
    const area_size = switch (current_variant) {
        .I_original => blk: {
            var l: usize = 0;
            dtv_offset = l;
            l += @sizeOf(Dtv);
            // Add some padding here so that the TP (`abi_tcb_offset`) is aligned to `align_factor`
            // and the `ZigTcb` structure can be found by simply subtracting `@sizeOf(ZigTcb)` from
            // the TP.
            const delta = (l + @sizeOf(ZigTcb)) & (align_factor - 1);
            if (delta > 0)
                l += align_factor - delta;
            l += @sizeOf(ZigTcb);
            abi_tcb_offset = l;
            l += alignForward(@sizeOf(AbiTcb), align_factor);
            block_offset = l;
            l += block_size;
            break :blk l;
        },
        .I_modified => blk: {
            var l: usize = 0;
            dtv_offset = l;
            l += @sizeOf(Dtv);
            // In this variant, the TLS blocks must begin immediately after the end of the ABI TCB,
            // with the TP pointing to the beginning of the TLS blocks. Add padding so that the TP
            // (`abi_tcb_offset`) is aligned to `align_factor` and the `ZigTcb` structure can be
            // found by subtracting `@sizeOf(AbiTcb) + @sizeOf(ZigTcb)` from the TP.
            const delta = (l + @sizeOf(ZigTcb) + @sizeOf(AbiTcb)) & (align_factor - 1);
            if (delta > 0)
                l += align_factor - delta;
            l += @sizeOf(ZigTcb);
            abi_tcb_offset = l;
            l += @sizeOf(AbiTcb);
            block_offset = l;
            l += block_size;
            break :blk l;
        },
        .II => blk: {
            var l: usize = 0;
            block_offset = l;
            l += alignForward(block_size, align_factor);
            // The TP is aligned to `align_factor`.
            abi_tcb_offset = l;
            l += @sizeOf(AbiTcb);
            // The `ZigTcb` structure is right after the `AbiTcb` with no padding in between so it
            // can be easily found.
            l += @sizeOf(ZigTcb);
            // It doesn't really matter where we put the DTV, so give it natural alignment.
            l = alignForward(l, @alignOf(Dtv));
            dtv_offset = l;
            l += @sizeOf(Dtv);
            break :blk l;
        },
    };

    area_desc = .{
        .size = area_size,
        .alignment = align_factor,

        .dtv = .{
            .offset = dtv_offset,
        },

        .abi_tcb = .{
            .offset = abi_tcb_offset,
        },

        .block = .{
            .init = block_init,
            .offset = block_offset,
            .size = block_size,
        },

        .gdt_entry_number = @as(usize, @bitCast(@as(isize, -1))),
    };
}

/// Inline because TLS is not set up yet.
inline fn alignForward(addr: usize, alignment: usize) usize {
    return alignBackward(addr + (alignment - 1), alignment);
}

/// Inline because TLS is not set up yet.
inline fn alignBackward(addr: usize, alignment: usize) usize {
    return addr & ~(alignment - 1);
}

/// Inline because TLS is not set up yet.
inline fn alignPtrCast(comptime T: type, ptr: [*]u8) *T {
    return @ptrCast(@alignCast(ptr));
}

/// Initializes all the fields of the static TLS area and returns the computed architecture-specific
/// value of the TP register.
pub fn prepareArea(area: []u8) usize {
    @setRuntimeSafety(false);
    @disableInstrumentation();

    // Clear the area we're going to use, just to be safe.
    @memset(area, 0);

    // Prepare the ABI TCB.
    const abi_tcb = alignPtrCast(AbiTcb, area.ptr + area_desc.abi_tcb.offset);
    switch (current_variant) {
        .I_original, .I_modified => abi_tcb.dtv = @intFromPtr(area.ptr + area_desc.dtv.offset),
        .II => abi_tcb.self = abi_tcb,
    }

    // Prepare the DTV.
    const dtv = alignPtrCast(Dtv, area.ptr + area_desc.dtv.offset);
    dtv.len = 1;
    dtv.tls_block = area.ptr + current_dtv_offset + area_desc.block.offset;

    // Copy the initial data.
    @memcpy(area[area_desc.block.offset..][0..area_desc.block.init.len], area_desc.block.init);

    // Return the corrected value (if needed) for the TP register. Overflow here is not a problem;
    // the pointer arithmetic involving the TP is done with wrapping semantics.
    return @intFromPtr(area.ptr) +% switch (current_variant) {
        .I_original, .II => area_desc.abi_tcb.offset,
        .I_modified => area_desc.block.offset +% current_tp_offset,
    };
}

// The main motivation for the size chosen here is that this is how much ends up being requested for
// the thread-local variables of the `std.crypto.random` implementation. I'm not sure why it ends up
// being so much; the struct itself is only 64 bytes. I think it has to do with being page-aligned
// and LLVM or LLD is not smart enough to lay out the TLS data in a space-conserving way. Anyway, I
// think it's fine because it's less than 3 pages of memory, and putting it in the ELF like this is
// equivalent to moving the `mmap` call below into the kernel, avoiding syscall overhead.
var main_thread_area_buffer: [0x2100]u8 align(mem.page_size) = undefined;

/// Computes the layout of the static TLS area, allocates the area, initializes all of its fields,
/// and assigns the architecture-specific value to the TP register.
pub fn initStatic(phdrs: []elf.Phdr) void {
    @setRuntimeSafety(false);
    @disableInstrumentation();

    computeAreaDesc(phdrs);

    const area = blk: {
        // Fast path for the common case where the TLS data is really small, avoid an allocation and
        // use our local buffer.
        if (area_desc.alignment <= mem.page_size and area_desc.size <= main_thread_area_buffer.len) {
            break :blk main_thread_area_buffer[0..area_desc.size];
        }

        const begin_addr = mmap(
            null,
            area_desc.size + area_desc.alignment - 1,
            posix.PROT.READ | posix.PROT.WRITE,
            .{ .TYPE = .PRIVATE, .ANONYMOUS = true },
            -1,
            0,
        );
        if (@as(isize, @bitCast(begin_addr)) < 0) @trap();

        const area_ptr: [*]align(mem.page_size) u8 = @ptrFromInt(begin_addr);

        // Make sure the slice is correctly aligned.
        const begin_aligned_addr = alignForward(begin_addr, area_desc.alignment);
        const start = begin_aligned_addr - begin_addr;
        break :blk area_ptr[start..][0..area_desc.size];
    };

    const tp_value = prepareArea(area);
    setThreadPointer(tp_value);
}

inline fn mmap(address: ?[*]u8, length: usize, prot: usize, flags: linux.MAP, fd: i32, offset: i64) usize {
    if (@hasField(linux.SYS, "mmap2")) {
        return @call(.always_inline, linux.syscall6, .{
            .mmap2,
            @intFromPtr(address),
            length,
            prot,
            @as(u32, @bitCast(flags)),
            @as(usize, @bitCast(@as(isize, fd))),
            @as(usize, @truncate(@as(u64, @bitCast(offset)) / linux.MMAP2_UNIT)),
        });
    } else {
        return @call(.always_inline, linux.syscall6, .{
            .mmap,
            @intFromPtr(address),
            length,
            prot,
            @as(u32, @bitCast(flags)),
            @as(usize, @bitCast(@as(isize, fd))),
            @as(u64, @bitCast(offset)),
        });
    }
}
