const c = @import("../darwin.zig");

pub const exception_state = extern struct {
    trapno: u16,
    cpu: u16,
    err: u32,
    faultvaddr: u64,
};

pub const thread_state = extern struct {
    rax: u64,
    rbx: u64,
    rcx: u64,
    rdx: u64,
    rdi: u64,
    rsi: u64,
    rbp: u64,
    rsp: u64,
    r8: u64,
    r9: u64,
    r10: u64,
    r11: u64,
    r12: u64,
    r13: u64,
    r14: u64,
    r15: u64,
    rip: u64,
    rflags: u64,
    cs: u64,
    fs: u64,
    gs: u64,
};

pub const THREAD_STATE = 4;
pub const THREAD_STATE_COUNT: c.mach_msg_type_number_t = @sizeOf(thread_state) / @sizeOf(c_int);
