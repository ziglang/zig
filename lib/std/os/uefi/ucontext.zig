const builtin = @import("builtin");
const std = @import("../../std.zig");

pub const REG = switch (builtin.cpu.arch) {
    .x86_64 => struct {
        pub const RAX = 0;
        pub const RBX = 1;
        pub const RCX = 2;
        pub const RDX = 3;
        pub const RSI = 4;
        pub const RDI = 5;
        pub const RBP = 6;
        pub const RSP = 7;
        pub const R8 = 8;
        pub const R9 = 9;
        pub const R10 = 10;
        pub const R11 = 11;
        pub const R12 = 12;
        pub const R13 = 13;
        pub const R14 = 14;
        pub const R15 = 15;
        pub const RIP = 16;
        pub const EFL = 17;
    },
    else => @compileError("arch not supported"),
};

pub const fpregset = struct {
    fcw: u16,
    fsw: u16,
    ftw: u8,
    reserved1: u8,
    fop: u16,
    fip: u64,
    fdp: u64,
    mxcsr: u32,
    mxcsr_mask: u32,
    st: [8]u128,
    xmm: [16]u128,
    reserved2: [96]u8,
};

pub const mcontext_t = struct {
    gregs: [18]usize,
    fpregs: fpregset,
};

pub const ucontext_t = struct {
    mcontext: mcontext_t,
};

fn gpRegisterOffset(comptime reg_index: comptime_int) usize {
    return @offsetOf(ucontext_t, "mcontext") + @offsetOf(mcontext_t, "gregs") + @sizeOf(usize) * reg_index;
}

pub inline fn getcontext(context: *ucontext_t) usize {
    switch (builtin.cpu.arch) {
        .x86_64 => {
            asm volatile (
                \\ movq %%r8, %[r8_offset:c](%[context])
                \\ movq %%r9, %[r9_offset:c](%[context])
                \\ movq %%r10, %[r10_offset:c](%[context])
                \\ movq %%r11, %[r11_offset:c](%[context])
                \\ movq %%r12, %[r12_offset:c](%[context])
                \\ movq %%r13, %[r13_offset:c](%[context])
                \\ movq %%r14, %[r14_offset:c](%[context])
                \\ movq %%r15, %[r15_offset:c](%[context])
                \\ movq %%rdi, %[rdi_offset:c](%[context])
                \\ movq %%rsi, %[rsi_offset:c](%[context])
                \\ movq %%rbx, %[rbx_offset:c](%[context])
                \\ movq %%rdx, %[rdx_offset:c](%[context])
                \\ movq %%rax, %[rax_offset:c](%[context])
                \\ movq %%rcx, %[rcx_offset:c](%[context])
                \\ movq %%rbp, %[rbp_offset:c](%[context])
                \\ movq %%rsp, %[rsp_offset:c](%[context])
                \\ leaq (%%rip), %%rcx
                \\ movq %%rcx, %[rip_offset:c](%[context])
                \\ pushfq
                \\ popq %[efl_offset:c](%[context])
                :
                : [context] "{rdi}" (context),
                  [r8_offset] "i" (comptime gpRegisterOffset(REG.R8)),
                  [r9_offset] "i" (comptime gpRegisterOffset(REG.R9)),
                  [r10_offset] "i" (comptime gpRegisterOffset(REG.R10)),
                  [r11_offset] "i" (comptime gpRegisterOffset(REG.R11)),
                  [r12_offset] "i" (comptime gpRegisterOffset(REG.R12)),
                  [r13_offset] "i" (comptime gpRegisterOffset(REG.R13)),
                  [r14_offset] "i" (comptime gpRegisterOffset(REG.R14)),
                  [r15_offset] "i" (comptime gpRegisterOffset(REG.R15)),
                  [rax_offset] "i" (comptime gpRegisterOffset(REG.RAX)),
                  [rbx_offset] "i" (comptime gpRegisterOffset(REG.RBX)),
                  [rcx_offset] "i" (comptime gpRegisterOffset(REG.RCX)),
                  [rdx_offset] "i" (comptime gpRegisterOffset(REG.RDX)),
                  [rsi_offset] "i" (comptime gpRegisterOffset(REG.RSI)),
                  [rdi_offset] "i" (comptime gpRegisterOffset(REG.RDI)),
                  [rsp_offset] "i" (comptime gpRegisterOffset(REG.RSP)),
                  [rbp_offset] "i" (comptime gpRegisterOffset(REG.RBP)),
                  [rip_offset] "i" (comptime gpRegisterOffset(REG.RIP)),
                  [efl_offset] "i" (comptime gpRegisterOffset(REG.EFL)),
                : "cc", "memory", "rcx"
            );
        },
        else => {},
    }

    return 0;
}
