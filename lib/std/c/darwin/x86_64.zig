const c = @import("../darwin.zig");

pub const mcontext_t = extern struct {
    es: exception_state,
    ss: thread_state,
    fs: float_state,
};

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

const stmm_reg = [16]u8;
const xmm_reg = [16]u8;
pub const float_state = extern struct {
    reserved: [2]c_int,
    fcw: u16,
    fsw: u16,
    ftw: u8,
    rsrv1: u8,
    fop: u16,
    ip: u32,
    cs: u16,
    rsrv2: u16,
    dp: u32,
    ds: u16,
    rsrv3: u16,
    mxcsr: u32,
    mxcsrmask: u32,
    stmm: [8]stmm_reg,
    xmm: [16]xmm_reg,
    rsrv4: [96]u8,
    reserved1: c_int,
};

pub const THREAD_STATE = 4;
pub const THREAD_STATE_COUNT: c.mach_msg_type_number_t = @sizeOf(thread_state) / @sizeOf(c_int);

pub const EXC_TYPES_COUNT = 14;
pub const EXC_MASK_MACHINE = 0;

pub const x86_THREAD_STATE32 = 1;
pub const x86_FLOAT_STATE32 = 2;
pub const x86_EXCEPTION_STATE32 = 3;
pub const x86_THREAD_STATE64 = 4;
pub const x86_FLOAT_STATE64 = 5;
pub const x86_EXCEPTION_STATE64 = 6;
pub const x86_THREAD_STATE = 7;
pub const x86_FLOAT_STATE = 8;
pub const x86_EXCEPTION_STATE = 9;
pub const x86_DEBUG_STATE32 = 10;
pub const x86_DEBUG_STATE64 = 11;
pub const x86_DEBUG_STATE = 12;
pub const THREAD_STATE_NONE = 13;
pub const x86_AVX_STATE32 = 16;
pub const x86_AVX_STATE64 = (x86_AVX_STATE32 + 1);
pub const x86_AVX_STATE = (x86_AVX_STATE32 + 2);
pub const x86_AVX512_STATE32 = 19;
pub const x86_AVX512_STATE64 = (x86_AVX512_STATE32 + 1);
pub const x86_AVX512_STATE = (x86_AVX512_STATE32 + 2);
pub const x86_PAGEIN_STATE = 22;
pub const x86_THREAD_FULL_STATE64 = 23;
pub const x86_INSTRUCTION_STATE = 24;
pub const x86_LAST_BRANCH_STATE = 25;
