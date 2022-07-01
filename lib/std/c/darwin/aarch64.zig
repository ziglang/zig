// See C headers in
// lib/libc/include/aarch64-macos.12-gnu/mach/arm/_structs.h

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
