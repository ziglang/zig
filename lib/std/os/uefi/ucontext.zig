const builtin = @import("builtin");

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
    xmm: [16]usize,
};

pub const mcontext_t = struct {
    gregs: [23]usize,
    fpregs: fpregset,
};

pub const ucontext_t = struct {
    mcontext: mcontext_t,
};

fn gpRegisterOffset(comptime reg_index: comptime_int) usize {
    return @offsetOf(ucontext_t, "mcontext") + @offsetOf(mcontext_t, "gregs") + @sizeOf(usize) * reg_index;
}

fn getContextInternal_x86_64() callconv(.Naked) void {
    asm volatile (
        \\ movq %%r8, %[r8_offset:c](%%rdi)
        \\ movq %%r9, %[r9_offset:c](%%rdi)
        \\ movq %%r10, %[r10_offset:c](%%rdi)
        \\ movq %%r11, %[r11_offset:c](%%rdi)
        \\ movq %%r12, %[r12_offset:c](%%rdi)
        \\ movq %%r13, %[r13_offset:c](%%rdi)
        \\ movq %%r14, %[r14_offset:c](%%rdi)
        \\ movq %%r15, %[r15_offset:c](%%rdi)
        \\ movq %%rax, %[rax_offset:c](%%rdi)
        \\ movq %%rbx, %[rbx_offset:c](%%rdi)
        \\ movq %%rcx, %[rcx_offset:c](%%rdi)
        \\ movq %%rdx, %[rdx_offset:c](%%rdi)
        \\ movq %%rsi, %[rsi_offset:c](%%rdi)
        \\ movq %%rdi, %[rdi_offset:c](%%rdi)
        \\ movq %%rbp, %[rbp_offset:c](%%rdi)
        \\ movq (%%rsp), %%rcx
        \\ movq %%rcx, %[rip_offset:c](%%rdi)
        \\ leaq 8(%%rsp), %%rcx
        \\ movq %%rcx, %[efl_offset:c](%%rdi)
        \\ pushfq
        \\ popq %[efl_offset:c](%%rdi)
        \\ retq
        :
        : [r8_offset] "i" (comptime gpRegisterOffset(REG.R8)),
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
          [rbp_offset] "i" (comptime gpRegisterOffset(REG.RBP)),
          [rip_offset] "i" (comptime gpRegisterOffset(REG.RIP)),
          [efl_offset] "i" (comptime gpRegisterOffset(REG.EFL)),
        : "cc", "memory", "rcx"
    );
}

inline fn getContext_x86_64(context: *ucontext_t) usize {
    var clobber_rdi: usize = undefined;
    asm volatile (
        \\ callq %[getContextInternal:P]
        : [_] "={rdi}" (clobber_rdi),
        : [_] "{rdi}" (context),
          [getContextInternal] "X" (&getContextInternal_x86_64),
        : "cc", "memory", "rcx", "rdx", "rsi", "r8", "r10", "r11"
    );
    
    return 0;
}

pub fn getcontext(context: *ucontext_t) usize {
    switch (builtin.cpu.arch) {
        .x86_64 => return getContext_x86_64(context),
        else => {},
    }

    return 1;
}
