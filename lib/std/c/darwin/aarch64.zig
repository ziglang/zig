// See C headers in
// lib/libc/include/aarch64-macos.12-gnu/mach/arm/_structs.h
// lib/libc/include/aarch64-macos.13-none/arm/_mcontext.h

pub const mcontext_t = extern struct {
    es: exception_state,
    ss: thread_state,
    ns: neon_state,
};

pub const exception_state = extern struct {
    far: u64, // Virtual Fault Address
    esr: u32, // Exception syndrome
    exception: u32, // Number of arm exception taken
};

pub const thread_state = extern struct {
    regs: [29]u64, // General purpose registers
    fp: u64, // Frame pointer x29
    lr: u64, // Link register x30
    sp: u64, // Stack pointer x31
    pc: u64, // Program counter
    cpsr: u32, // Current program status register
    __pad: u32,
};

pub const neon_state = extern struct {
    q: [32]u128,
    fpsr: u32,
    fpcr: u32,
};

pub const EXC_TYPES_COUNT = 14;
pub const EXC_MASK_MACHINE = 0;

pub const ARM_THREAD_STATE = 1;
pub const ARM_UNIFIED_THREAD_STATE = ARM_THREAD_STATE;
pub const ARM_VFP_STATE = 2;
pub const ARM_EXCEPTION_STATE = 3;
pub const ARM_DEBUG_STATE = 4;
pub const THREAD_STATE_NONE = 5;
pub const ARM_THREAD_STATE64 = 6;
pub const ARM_EXCEPTION_STATE64 = 7;
pub const ARM_THREAD_STATE_LAST = 8;
pub const ARM_THREAD_STATE32 = 9;
pub const ARM_DEBUG_STATE32 = 14;
pub const ARM_DEBUG_STATE64 = 15;
pub const ARM_NEON_STATE = 16;
pub const ARM_NEON_STATE64 = 17;
pub const ARM_CPMU_STATE64 = 18;
pub const ARM_PAGEIN_STATE = 27;
