const std = @import("std");
const builtin = @import("builtin");
const native_arch = builtin.target.cpu.arch;
const assert = std.debug.assert;
const AF = std.c.AF;
const PROT = std.c.PROT;
const fd_t = std.c.fd_t;
const iovec_const = std.posix.iovec_const;
const mode_t = std.c.mode_t;
const off_t = std.c.off_t;
const pid_t = std.c.pid_t;
const pthread_attr_t = std.c.pthread_attr_t;
const sigset_t = std.c.segset_t;
const timespec = std.c.timespec;
const sf_hdtr = std.c.sf_hdtr;

comptime {
    assert(builtin.os.tag.isDarwin()); // Prevent access of std.c symbols on wrong OS.
}

pub const mach_port_t = c_uint;

pub const THREAD_STATE_NONE = switch (native_arch) {
    .aarch64 => 5,
    .x86_64 => 13,
};

pub const EXC = enum(exception_type_t) {
    NULL = 0,
    /// Could not access memory
    BAD_ACCESS = 1,
    /// Instruction failed
    BAD_INSTRUCTION = 2,
    /// Arithmetic exception
    ARITHMETIC = 3,
    /// Emulation instruction
    EMULATION = 4,
    /// Software generated exception
    SOFTWARE = 5,
    /// Trace, breakpoint, etc.
    BREAKPOINT = 6,
    /// System calls.
    SYSCALL = 7,
    /// Mach system calls.
    MACH_SYSCALL = 8,
    /// RPC alert
    RPC_ALERT = 9,
    /// Abnormal process exit
    CRASH = 10,
    /// Hit resource consumption limit
    RESOURCE = 11,
    /// Violated guarded resource protections
    GUARD = 12,
    /// Abnormal process exited to corpse state
    CORPSE_NOTIFY = 13,

    pub const TYPES_COUNT = @typeInfo(EXC).Enum.fields.len;
    pub const SOFT_SIGNAL = 0x10003;

    pub const MASK = packed struct(u32) {
        BAD_ACCESS: bool = false,
        BAD_INSTRUCTION: bool = false,
        ARITHMETIC: bool = false,
        EMULATION: bool = false,
        SOFTWARE: bool = false,
        BREAKPOINT: bool = false,
        SYSCALL: bool = false,
        MACH_SYSCALL: bool = false,
        RPC_ALERT: bool = false,
        CRASH: bool = false,
        RESOURCE: bool = false,
        GUARD: bool = false,
        CORPSE_NOTIFY: bool = false,

        pub const MACHINE: MASK = @bitCast(@as(u32, 0));

        pub const ALL: MASK = .{
            .BAD_ACCESS = true,
            .BAD_INSTRUCTION = true,
            .ARITHMETIC = true,
            .EMULATION = true,
            .SOFTWARE = true,
            .BREAKPOINT = true,
            .SYSCALL = true,
            .MACH_SYSCALL = true,
            .RPC_ALERT = true,
            .CRASH = true,
            .RESOURCE = true,
            .GUARD = true,
            .CORPSE_NOTIFY = true,
        };
    };
};

pub const EXCEPTION = enum(u32) {
    /// Send a catch_exception_raise message including the identity.
    DEFAULT = 1,
    /// Send a catch_exception_raise_state message including the
    /// thread state.
    STATE = 2,
    /// Send a catch_exception_raise_state_identity message including
    /// the thread identity and state.
    STATE_IDENTITY = 3,
    /// Send a catch_exception_raise_identity_protected message including protected task
    /// and thread identity.
    IDENTITY_PROTECTED = 4,

    _,
};

/// Prefer sending a catch_exception_raice_backtrace message, if applicable.
pub const MACH_EXCEPTION_BACKTRACE_PREFERRED = 0x20000000;
/// include additional exception specific errors, not used yet.
pub const MACH_EXCEPTION_ERRORS = 0x40000000;
/// Send 64-bit code and subcode in the exception header */
pub const MACH_EXCEPTION_CODES = 0x80000000;

pub const MACH_EXCEPTION_MASK = MACH_EXCEPTION_CODES |
    MACH_EXCEPTION_ERRORS |
    MACH_EXCEPTION_BACKTRACE_PREFERRED;

pub const TASK_NULL: task_t = 0;
pub const THREAD_NULL: thread_t = 0;
pub const MACH_PORT_NULL: mach_port_t = 0;
pub const MACH_MSG_TIMEOUT_NONE: mach_msg_timeout_t = 0;

pub const MACH_MSG_OPTION_NONE = 0x00000000;

pub const MACH_SEND_MSG = 0x00000001;
pub const MACH_RCV_MSG = 0x00000002;

pub const MACH_RCV_LARGE = 0x00000004;
pub const MACH_RCV_LARGE_IDENTITY = 0x00000008;

pub const MACH_SEND_TIMEOUT = 0x00000010;
pub const MACH_SEND_OVERRIDE = 0x00000020;
pub const MACH_SEND_INTERRUPT = 0x00000040;
pub const MACH_SEND_NOTIFY = 0x00000080;
pub const MACH_SEND_ALWAYS = 0x00010000;
pub const MACH_SEND_FILTER_NONFATAL = 0x00010000;
pub const MACH_SEND_TRAILER = 0x00020000;
pub const MACH_SEND_NOIMPORTANCE = 0x00040000;
pub const MACH_SEND_NODENAP = MACH_SEND_NOIMPORTANCE;
pub const MACH_SEND_IMPORTANCE = 0x00080000;
pub const MACH_SEND_SYNC_OVERRIDE = 0x00100000;
pub const MACH_SEND_PROPAGATE_QOS = 0x00200000;
pub const MACH_SEND_SYNC_USE_THRPRI = MACH_SEND_PROPAGATE_QOS;
pub const MACH_SEND_KERNEL = 0x00400000;
pub const MACH_SEND_SYNC_BOOTSTRAP_CHECKIN = 0x00800000;

pub const MACH_RCV_TIMEOUT = 0x00000100;
pub const MACH_RCV_NOTIFY = 0x00000000;
pub const MACH_RCV_INTERRUPT = 0x00000400;
pub const MACH_RCV_VOUCHER = 0x00000800;
pub const MACH_RCV_OVERWRITE = 0x00000000;
pub const MACH_RCV_GUARDED_DESC = 0x00001000;
pub const MACH_RCV_SYNC_WAIT = 0x00004000;
pub const MACH_RCV_SYNC_PEEK = 0x00008000;

pub const MACH_MSG_STRICT_REPLY = 0x00000200;

pub const exception_type_t = c_int;

pub const mcontext_t = switch (native_arch) {
    .aarch64 => extern struct {
        es: exception_state,
        ss: thread_state,
        ns: neon_state,
    },
    .x86_64 => extern struct {
        es: exception_state,
        ss: thread_state,
        fs: float_state,
    },
    else => @compileError("unsupported arch"),
};

pub const exception_state = switch (native_arch) {
    .aarch64 => extern struct {
        far: u64, // Virtual Fault Address
        esr: u32, // Exception syndrome
        exception: u32, // Number of arm exception taken
    },
    .x86_64 => extern struct {
        trapno: u16,
        cpu: u16,
        err: u32,
        faultvaddr: u64,
    },
    else => @compileError("unsupported arch"),
};

pub const thread_state = switch (native_arch) {
    .aarch64 => extern struct {
        /// General purpose registers
        regs: [29]u64,
        /// Frame pointer x29
        fp: u64,
        /// Link register x30
        lr: u64,
        /// Stack pointer x31
        sp: u64,
        /// Program counter
        pc: u64,
        /// Current program status register
        cpsr: u32,
        __pad: u32,
    },
    .x86_64 => extern struct {
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
    },
    else => @compileError("unsupported arch"),
};

pub const neon_state = extern struct {
    q: [32]u128,
    fpsr: u32,
    fpcr: u32,
};

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

pub const stmm_reg = [16]u8;
pub const xmm_reg = [16]u8;

pub extern "c" fn NSVersionOfRunTimeLibrary(library_name: [*:0]const u8) u32;
pub extern "c" fn _NSGetExecutablePath(buf: [*:0]u8, bufsize: *u32) c_int;
pub extern "c" fn _dyld_image_count() u32;
pub extern "c" fn _dyld_get_image_header(image_index: u32) ?*mach_header;
pub extern "c" fn _dyld_get_image_vmaddr_slide(image_index: u32) usize;
pub extern "c" fn _dyld_get_image_name(image_index: u32) [*:0]const u8;

pub const COPYFILE = packed struct(u32) {
    ACL: bool = false,
    STAT: bool = false,
    XATTR: bool = false,
    DATA: bool = false,
    _: u28 = 0,
};

pub const copyfile_state_t = *opaque {};
pub extern "c" fn fcopyfile(from: fd_t, to: fd_t, state: ?copyfile_state_t, flags: COPYFILE) c_int;
pub extern "c" fn __getdirentries64(fd: c_int, buf_ptr: [*]u8, buf_len: usize, basep: *i64) isize;

pub extern "c" fn mach_absolute_time() u64;
pub extern "c" fn mach_continuous_time() u64;
pub extern "c" fn mach_timebase_info(tinfo: ?*mach_timebase_info_data) kern_return_t;

pub extern "c" fn kevent64(
    kq: c_int,
    changelist: [*]const kevent64_s,
    nchanges: c_int,
    eventlist: [*]kevent64_s,
    nevents: c_int,
    flags: c_uint,
    timeout: ?*const timespec,
) c_int;

pub const mach_hdr = if (@sizeOf(usize) == 8) mach_header_64 else mach_header;

pub const mach_header_64 = std.macho.mach_header_64;
pub const mach_header = std.macho.mach_header;

pub extern "c" fn @"close$NOCANCEL"(fd: fd_t) c_int;
pub extern "c" fn mach_host_self() mach_port_t;
pub extern "c" fn clock_get_time(clock_serv: clock_serv_t, cur_time: *mach_timespec_t) kern_return_t;

pub const exception_data_type_t = integer_t;
pub const exception_data_t = ?*mach_exception_data_type_t;
pub const mach_exception_data_type_t = i64;
pub const mach_exception_data_t = ?*mach_exception_data_type_t;
pub const vm_map_t = mach_port_t;
pub const vm_map_read_t = mach_port_t;
pub const vm_region_flavor_t = c_int;
pub const vm_region_info_t = *c_int;
pub const vm_region_recurse_info_t = *c_int;
pub const mach_vm_address_t = usize;
pub const vm_offset_t = usize;
pub const mach_vm_size_t = u64;
pub const mach_msg_bits_t = c_uint;
pub const mach_msg_id_t = integer_t;
pub const mach_msg_type_number_t = natural_t;
pub const mach_msg_type_name_t = c_uint;
pub const mach_msg_option_t = integer_t;
pub const mach_msg_size_t = natural_t;
pub const mach_msg_timeout_t = natural_t;
pub const mach_port_right_t = natural_t;
pub const task_t = mach_port_t;
pub const thread_port_t = task_t;
pub const thread_t = thread_port_t;
pub const exception_mask_t = c_uint;
pub const exception_mask_array_t = [*]exception_mask_t;
pub const exception_handler_t = mach_port_t;
pub const exception_handler_array_t = [*]exception_handler_t;
pub const exception_port_t = exception_handler_t;
pub const exception_port_array_t = exception_handler_array_t;
pub const exception_flavor_array_t = [*]thread_state_flavor_t;
pub const exception_behavior_t = c_uint;
pub const exception_behavior_array_t = [*]exception_behavior_t;
pub const thread_state_flavor_t = c_int;
pub const ipc_space_t = mach_port_t;
pub const ipc_space_port_t = ipc_space_t;

pub const MACH_PORT_RIGHT = enum(mach_port_right_t) {
    SEND = 0,
    RECEIVE = 1,
    SEND_ONCE = 2,
    PORT_SET = 3,
    DEAD_NAME = 4,
    /// Obsolete right
    LABELH = 5,
    /// Right not implemented
    NUMBER = 6,
};

pub const MACH_MSG_TYPE = enum(mach_msg_type_name_t) {
    /// Must hold receive right
    MOVE_RECEIVE = 16,

    /// Must hold send right(s)
    MOVE_SEND = 17,

    /// Must hold sendonce right
    MOVE_SEND_ONCE = 18,

    /// Must hold send right(s)
    COPY_SEND = 19,

    /// Must hold receive right
    MAKE_SEND = 20,

    /// Must hold receive right
    MAKE_SEND_ONCE = 21,

    /// NOT VALID
    COPY_RECEIVE = 22,

    /// Must hold receive right
    DISPOSE_RECEIVE = 24,

    /// Must hold send right(s)
    DISPOSE_SEND = 25,

    /// Must hold sendonce right
    DISPOSE_SEND_ONCE = 26,
};

extern "c" var mach_task_self_: mach_port_t;
pub fn mach_task_self() callconv(.C) mach_port_t {
    return mach_task_self_;
}

pub extern "c" fn mach_msg(
    msg: ?*mach_msg_header_t,
    option: mach_msg_option_t,
    send_size: mach_msg_size_t,
    rcv_size: mach_msg_size_t,
    rcv_name: mach_port_name_t,
    timeout: mach_msg_timeout_t,
    notify: mach_port_name_t,
) kern_return_t;

pub const mach_msg_header_t = extern struct {
    msgh_bits: mach_msg_bits_t,
    msgh_size: mach_msg_size_t,
    msgh_remote_port: mach_port_t,
    msgh_local_port: mach_port_t,
    msgh_voucher_port: mach_port_name_t,
    msgh_id: mach_msg_id_t,
};

pub extern "c" fn task_get_exception_ports(
    task: task_t,
    exception_mask: exception_mask_t,
    masks: exception_mask_array_t,
    masks_cnt: *mach_msg_type_number_t,
    old_handlers: exception_handler_array_t,
    old_behaviors: exception_behavior_array_t,
    old_flavors: exception_flavor_array_t,
) kern_return_t;
pub extern "c" fn task_set_exception_ports(
    task: task_t,
    exception_mask: exception_mask_t,
    new_port: mach_port_t,
    behavior: exception_behavior_t,
    new_flavor: thread_state_flavor_t,
) kern_return_t;

pub const task_read_t = mach_port_t;

pub extern "c" fn task_resume(target_task: task_read_t) kern_return_t;
pub extern "c" fn task_suspend(target_task: task_read_t) kern_return_t;

pub extern "c" fn task_for_pid(target_tport: mach_port_name_t, pid: pid_t, t: *mach_port_name_t) kern_return_t;
pub extern "c" fn pid_for_task(target_tport: mach_port_name_t, pid: *pid_t) kern_return_t;
pub extern "c" fn mach_vm_read(
    target_task: vm_map_read_t,
    address: mach_vm_address_t,
    size: mach_vm_size_t,
    data: *vm_offset_t,
    data_cnt: *mach_msg_type_number_t,
) kern_return_t;
pub extern "c" fn mach_vm_write(
    target_task: vm_map_t,
    address: mach_vm_address_t,
    data: vm_offset_t,
    data_cnt: mach_msg_type_number_t,
) kern_return_t;
pub extern "c" fn mach_vm_region(
    target_task: vm_map_t,
    address: *mach_vm_address_t,
    size: *mach_vm_size_t,
    flavor: vm_region_flavor_t,
    info: vm_region_info_t,
    info_cnt: *mach_msg_type_number_t,
    object_name: *mach_port_t,
) kern_return_t;
pub extern "c" fn mach_vm_region_recurse(
    target_task: vm_map_t,
    address: *mach_vm_address_t,
    size: *mach_vm_size_t,
    nesting_depth: *natural_t,
    info: vm_region_recurse_info_t,
    info_cnt: *mach_msg_type_number_t,
) kern_return_t;

pub const vm_inherit_t = u32;
pub const memory_object_offset_t = u64;
pub const vm_behavior_t = i32;
pub const vm32_object_id_t = u32;
pub const vm_object_id_t = u64;

pub const VM_INHERIT_SHARE: vm_inherit_t = 0;
pub const VM_INHERIT_COPY: vm_inherit_t = 1;
pub const VM_INHERIT_NONE: vm_inherit_t = 2;
pub const VM_INHERIT_DONATE_COPY: vm_inherit_t = 3;
pub const VM_INHERIT_DEFAULT = VM_INHERIT_COPY;

pub const VM_BEHAVIOR_DEFAULT: vm_behavior_t = 0;
pub const VM_BEHAVIOR_RANDOM: vm_behavior_t = 1;
pub const VM_BEHAVIOR_SEQUENTIAL: vm_behavior_t = 2;
pub const VM_BEHAVIOR_RSEQNTL: vm_behavior_t = 3;

pub const VM_BEHAVIOR_WILLNEED: vm_behavior_t = 4;
pub const VM_BEHAVIOR_DONTNEED: vm_behavior_t = 5;
pub const VM_BEHAVIOR_FREE: vm_behavior_t = 6;
pub const VM_BEHAVIOR_ZERO_WIRED_PAGES: vm_behavior_t = 7;
pub const VM_BEHAVIOR_REUSABLE: vm_behavior_t = 8;
pub const VM_BEHAVIOR_REUSE: vm_behavior_t = 9;
pub const VM_BEHAVIOR_CAN_REUSE: vm_behavior_t = 10;
pub const VM_BEHAVIOR_PAGEOUT: vm_behavior_t = 11;

pub const VM_REGION_BASIC_INFO_64 = 9;
pub const VM_REGION_EXTENDED_INFO = 13;
pub const VM_REGION_TOP_INFO = 12;
pub const VM_REGION_SUBMAP_INFO_COUNT_64: mach_msg_type_number_t = @sizeOf(vm_region_submap_info_64) / @sizeOf(natural_t);
pub const VM_REGION_SUBMAP_SHORT_INFO_COUNT_64: mach_msg_type_number_t = @sizeOf(vm_region_submap_short_info_64) / @sizeOf(natural_t);
pub const VM_REGION_BASIC_INFO_COUNT: mach_msg_type_number_t = @sizeOf(vm_region_basic_info_64) / @sizeOf(c_int);
pub const VM_REGION_EXTENDED_INFO_COUNT: mach_msg_type_number_t = @sizeOf(vm_region_extended_info) / @sizeOf(natural_t);
pub const VM_REGION_TOP_INFO_COUNT: mach_msg_type_number_t = @sizeOf(vm_region_top_info) / @sizeOf(natural_t);

pub fn VM_MAKE_TAG(tag: u8) u32 {
    return @as(u32, tag) << 24;
}

pub const vm_region_basic_info_64 = extern struct {
    protection: vm_prot_t,
    max_protection: vm_prot_t,
    inheritance: vm_inherit_t,
    shared: boolean_t,
    reserved: boolean_t,
    offset: memory_object_offset_t,
    behavior: vm_behavior_t,
    user_wired_count: u16,
};

pub const vm_region_extended_info = extern struct {
    protection: vm_prot_t,
    user_tag: u32,
    pages_resident: u32,
    pages_shared_now_private: u32,
    pages_swapped_out: u32,
    pages_dirtied: u32,
    ref_count: u32,
    shadow_depth: u16,
    external_pager: u8,
    share_mode: u8,
    pages_reusable: u32,
};

pub const vm_region_top_info = extern struct {
    obj_id: u32,
    ref_count: u32,
    private_pages_resident: u32,
    shared_pages_resident: u32,
    share_mode: u8,
};

pub const vm_region_submap_info_64 = extern struct {
    // present across protection
    protection: vm_prot_t,
    // max avail through vm_prot
    max_protection: vm_prot_t,
    // behavior of map/obj on fork
    inheritance: vm_inherit_t,
    // offset into object/map
    offset: memory_object_offset_t,
    // user tag on map entry
    user_tag: u32,
    // only valid for objects
    pages_resident: u32,
    // only for objects
    pages_shared_now_private: u32,
    // only for objects
    pages_swapped_out: u32,
    // only for objects
    pages_dirtied: u32,
    // obj/map mappers, etc.
    ref_count: u32,
    // only for obj
    shadow_depth: u16,
    // only for obj
    external_pager: u8,
    // see enumeration
    share_mode: u8,
    // submap vs obj
    is_submap: boolean_t,
    // access behavior hint
    behavior: vm_behavior_t,
    // obj/map name, not a handle
    object_id: vm32_object_id_t,
    user_wired_count: u16,
    pages_reusable: u32,
    object_id_full: vm_object_id_t,
};

pub const vm_region_submap_short_info_64 = extern struct {
    // present access protection
    protection: vm_prot_t,
    // max avail through vm_prot
    max_protection: vm_prot_t,
    // behavior of map/obj on fork
    inheritance: vm_inherit_t,
    // offset into object/map
    offset: memory_object_offset_t,
    // user tag on map entry
    user_tag: u32,
    // obj/map mappers, etc
    ref_count: u32,
    // only for obj
    shadow_depth: u16,
    // only for obj
    external_pager: u8,
    // see enumeration
    share_mode: u8,
    //  submap vs obj
    is_submap: boolean_t,
    // access behavior hint
    behavior: vm_behavior_t,
    // obj/map name, not a handle
    object_id: vm32_object_id_t,
    user_wired_count: u16,
};

pub const thread_act_t = mach_port_t;
pub const thread_state_t = *natural_t;
pub const mach_port_array_t = [*]mach_port_t;

pub extern "c" fn task_threads(
    target_task: mach_port_t,
    init_port_set: *mach_port_array_t,
    init_port_count: *mach_msg_type_number_t,
) kern_return_t;
pub extern "c" fn thread_get_state(
    thread: thread_act_t,
    flavor: thread_flavor_t,
    state: thread_state_t,
    count: *mach_msg_type_number_t,
) kern_return_t;
pub extern "c" fn thread_set_state(
    thread: thread_act_t,
    flavor: thread_flavor_t,
    new_state: thread_state_t,
    count: mach_msg_type_number_t,
) kern_return_t;
pub extern "c" fn thread_info(
    thread: thread_act_t,
    flavor: thread_flavor_t,
    info: thread_info_t,
    count: *mach_msg_type_number_t,
) kern_return_t;
pub extern "c" fn thread_resume(thread: thread_act_t) kern_return_t;

pub const THREAD_BASIC_INFO = 3;
pub const THREAD_BASIC_INFO_COUNT: mach_msg_type_number_t = @sizeOf(thread_basic_info) / @sizeOf(natural_t);

pub const THREAD_IDENTIFIER_INFO = 4;
pub const THREAD_IDENTIFIER_INFO_COUNT: mach_msg_type_number_t = @sizeOf(thread_identifier_info) / @sizeOf(natural_t);

pub const thread_flavor_t = natural_t;
pub const thread_info_t = *integer_t;
pub const time_value_t = time_value;
pub const task_policy_flavor_t = natural_t;
pub const task_policy_t = *integer_t;
pub const policy_t = c_int;

pub const time_value = extern struct {
    seconds: integer_t,
    microseconds: integer_t,
};

pub const thread_basic_info = extern struct {
    // user run time
    user_time: time_value_t,
    // system run time
    system_time: time_value_t,
    // scaled cpu usage percentage
    cpu_usage: integer_t,
    // scheduling policy in effect
    policy: policy_t,
    // run state
    run_state: integer_t,
    // various flags
    flags: integer_t,
    // suspend count for thread
    suspend_count: integer_t,
    // number of seconds that thread has been sleeping
    sleep_time: integer_t,
};

pub const thread_identifier_info = extern struct {
    /// System-wide unique 64-bit thread id
    thread_id: u64,

    /// Handle to be used by libproc
    thread_handle: u64,

    /// libdispatch queue address
    dispatch_qaddr: u64,
};

/// Cachability
pub const MATTR_CACHE = 1;
/// Migrability
pub const MATTR_MIGRATE = 2;
/// Replicability
pub const MATTR_REPLICATE = 4;

/// (Generic) turn attribute off
pub const MATTR_VAL_OFF = 0;
/// (Generic) turn attribute on
pub const MATTR_VAL_ON = 1;
/// (Generic) return current value
pub const MATTR_VAL_GET = 2;
/// Flush from all caches
pub const MATTR_VAL_CACHE_FLUSH = 6;
/// Flush from data caches
pub const MATTR_VAL_DCACHE_FLUSH = 7;
/// Flush from instruction caches
pub const MATTR_VAL_ICACHE_FLUSH = 8;
/// Sync I+D caches
pub const MATTR_VAL_CACHE_SYNC = 9;
/// Get page info (stats)
pub const MATTR_VAL_GET_INFO = 10;

pub const TASK_VM_INFO = 22;
pub const TASK_VM_INFO_COUNT: mach_msg_type_number_t = @sizeOf(task_vm_info_data_t) / @sizeOf(natural_t);

pub const task_vm_info = extern struct {
    // virtual memory size (bytes)
    virtual_size: mach_vm_size_t,
    // number of memory regions
    region_count: integer_t,
    page_size: integer_t,
    // resident memory size (bytes)
    resident_size: mach_vm_size_t,
    // peak resident size (bytes)
    resident_size_peak: mach_vm_size_t,

    device: mach_vm_size_t,
    device_peak: mach_vm_size_t,
    internal: mach_vm_size_t,
    internal_peak: mach_vm_size_t,
    external: mach_vm_size_t,
    external_peak: mach_vm_size_t,
    reusable: mach_vm_size_t,
    reusable_peak: mach_vm_size_t,
    purgeable_volatile_pmap: mach_vm_size_t,
    purgeable_volatile_resident: mach_vm_size_t,
    purgeable_volatile_virtual: mach_vm_size_t,
    compressed: mach_vm_size_t,
    compressed_peak: mach_vm_size_t,
    compressed_lifetime: mach_vm_size_t,

    // added for rev1
    phys_footprint: mach_vm_size_t,

    // added for rev2
    min_address: mach_vm_address_t,
    max_address: mach_vm_address_t,

    // added for rev3
    ledger_phys_footprint_peak: i64,
    ledger_purgeable_nonvolatile: i64,
    ledger_purgeable_novolatile_compressed: i64,
    ledger_purgeable_volatile: i64,
    ledger_purgeable_volatile_compressed: i64,
    ledger_tag_network_nonvolatile: i64,
    ledger_tag_network_nonvolatile_compressed: i64,
    ledger_tag_network_volatile: i64,
    ledger_tag_network_volatile_compressed: i64,
    ledger_tag_media_footprint: i64,
    ledger_tag_media_footprint_compressed: i64,
    ledger_tag_media_nofootprint: i64,
    ledger_tag_media_nofootprint_compressed: i64,
    ledger_tag_graphics_footprint: i64,
    ledger_tag_graphics_footprint_compressed: i64,
    ledger_tag_graphics_nofootprint: i64,
    ledger_tag_graphics_nofootprint_compressed: i64,
    ledger_tag_neural_footprint: i64,
    ledger_tag_neural_footprint_compressed: i64,
    ledger_tag_neural_nofootprint: i64,
    ledger_tag_neural_nofootprint_compressed: i64,

    // added for rev4
    limit_bytes_remaining: u64,

    // added for rev5
    decompressions: integer_t,
};

pub const task_vm_info_data_t = task_vm_info;

pub const vm_prot_t = c_int;
pub const boolean_t = c_int;

pub extern "c" fn mach_vm_protect(
    target_task: vm_map_t,
    address: mach_vm_address_t,
    size: mach_vm_size_t,
    set_maximum: boolean_t,
    new_protection: vm_prot_t,
) kern_return_t;

pub extern "c" fn mach_port_allocate(
    task: ipc_space_t,
    right: mach_port_right_t,
    name: *mach_port_name_t,
) kern_return_t;
pub extern "c" fn mach_port_deallocate(task: ipc_space_t, name: mach_port_name_t) kern_return_t;
pub extern "c" fn mach_port_insert_right(
    task: ipc_space_t,
    name: mach_port_name_t,
    poly: mach_port_t,
    poly_poly: mach_msg_type_name_t,
) kern_return_t;

pub extern "c" fn task_info(
    target_task: task_name_t,
    flavor: task_flavor_t,
    task_info_out: task_info_t,
    task_info_outCnt: *mach_msg_type_number_t,
) kern_return_t;

pub const mach_task_basic_info = extern struct {
    /// Virtual memory size (bytes)
    virtual_size: mach_vm_size_t,

    /// Resident memory size (bytes)
    resident_size: mach_vm_size_t,

    /// Total user run time for terminated threads
    user_time: time_value_t,

    /// Total system run time for terminated threads
    system_time: time_value_t,

    /// Default policy for new threads
    policy: policy_t,

    /// Suspend count for task
    suspend_count: mach_vm_size_t,
};

pub const MACH_TASK_BASIC_INFO = 20;
pub const MACH_TASK_BASIC_INFO_COUNT: mach_msg_type_number_t = @sizeOf(mach_task_basic_info) / @sizeOf(natural_t);

pub extern "c" fn _host_page_size(task: mach_port_t, size: *vm_size_t) kern_return_t;
pub extern "c" fn vm_deallocate(target_task: vm_map_t, address: vm_address_t, size: vm_size_t) kern_return_t;
pub extern "c" fn vm_machine_attribute(
    target_task: vm_map_t,
    address: vm_address_t,
    size: vm_size_t,
    attribute: vm_machine_attribute_t,
    value: *vm_machine_attribute_val_t,
) kern_return_t;

pub extern "c" fn sendfile(
    in_fd: fd_t,
    out_fd: fd_t,
    offset: off_t,
    len: *off_t,
    sf_hdtr: ?*sf_hdtr,
    flags: u32,
) c_int;

pub fn sigaddset(set: *sigset_t, signo: u5) void {
    set.* |= @as(u32, 1) << (signo - 1);
}

pub const qos_class_t = enum(c_uint) {
    /// highest priority QOS class for critical tasks
    QOS_CLASS_USER_INTERACTIVE = 0x21,
    /// slightly more moderate priority QOS class
    QOS_CLASS_USER_INITIATED = 0x19,
    /// default QOS class when none is set
    QOS_CLASS_DEFAULT = 0x15,
    /// more energy efficient QOS class than default
    QOS_CLASS_UTILITY = 0x11,
    /// QOS class more appropriate for background tasks
    QOS_CLASS_BACKGROUND = 0x09,
    /// QOS class as a return value
    QOS_CLASS_UNSPECIFIED = 0x00,
};

// Grand Central Dispatch is exposed by libSystem.
pub extern "c" fn dispatch_release(object: *anyopaque) void;

pub const dispatch_semaphore_t = *opaque {};
pub extern "c" fn dispatch_semaphore_create(value: isize) ?dispatch_semaphore_t;
pub extern "c" fn dispatch_semaphore_wait(dsema: dispatch_semaphore_t, timeout: dispatch_time_t) isize;
pub extern "c" fn dispatch_semaphore_signal(dsema: dispatch_semaphore_t) isize;

pub const dispatch_time_t = u64;
pub const DISPATCH_TIME_NOW = @as(dispatch_time_t, 0);
pub const DISPATCH_TIME_FOREVER = ~@as(dispatch_time_t, 0);
pub extern "c" fn dispatch_time(when: dispatch_time_t, delta: i64) dispatch_time_t;

const dispatch_once_t = usize;
const dispatch_function_t = fn (?*anyopaque) callconv(.C) void;
pub extern fn dispatch_once_f(
    predicate: *dispatch_once_t,
    context: ?*anyopaque,
    function: dispatch_function_t,
) void;

/// Undocumented futex-like API available on darwin 16+
/// (macOS 10.12+, iOS 10.0+, tvOS 10.0+, watchOS 3.0+, catalyst 13.0+).
///
/// [ulock.h]: https://github.com/apple/darwin-xnu/blob/master/bsd/sys/ulock.h
/// [sys_ulock.c]: https://github.com/apple/darwin-xnu/blob/master/bsd/kern/sys_ulock.c
pub const UL = packed struct(u32) {
    op: Op,
    WAKE_ALL: bool = false,
    WAKE_THREAD: bool = false,
    _10: u6 = 0,
    WAIT_WORKQ_DATA_CONTENTION: bool = false,
    WAIT_CANCEL_POINT: bool = false,
    WAIT_ADAPTIVE_SPIN: bool = false,
    _19: u5 = 0,
    NO_ERRNO: bool = false,
    _: u7 = 0,

    pub const Op = enum(u8) {
        COMPARE_AND_WAIT = 1,
        UNFAIR_LOCK = 2,
        COMPARE_AND_WAIT_SHARED = 3,
        UNFAIR_LOCK64_SHARED = 4,
        COMPARE_AND_WAIT64 = 5,
        COMPARE_AND_WAIT64_SHARED = 6,
    };
};

pub extern "c" fn __ulock_wait2(op: UL, addr: ?*const anyopaque, val: u64, timeout_ns: u64, val2: u64) c_int;
pub extern "c" fn __ulock_wait(op: UL, addr: ?*const anyopaque, val: u64, timeout_us: u32) c_int;
pub extern "c" fn __ulock_wake(op: UL, addr: ?*const anyopaque, val: u64) c_int;

pub const os_unfair_lock_t = *os_unfair_lock;
pub const os_unfair_lock = extern struct {
    _os_unfair_lock_opaque: u32 = 0,
};

pub extern "c" fn os_unfair_lock_lock(o: os_unfair_lock_t) void;
pub extern "c" fn os_unfair_lock_unlock(o: os_unfair_lock_t) void;
pub extern "c" fn os_unfair_lock_trylock(o: os_unfair_lock_t) bool;
pub extern "c" fn os_unfair_lock_assert_owner(o: os_unfair_lock_t) void;
pub extern "c" fn os_unfair_lock_assert_not_owner(o: os_unfair_lock_t) void;

pub fn getKernError(err: kern_return_t) KernE {
    return @as(KernE, @enumFromInt(@as(u32, @truncate(@as(usize, @intCast(err))))));
}

pub fn unexpectedKernError(err: KernE) std.posix.UnexpectedError {
    if (std.posix.unexpected_error_tracing) {
        std.debug.print("unexpected error: {d}\n", .{@intFromEnum(err)});
        std.debug.dumpCurrentStackTrace(null);
    }
    return error.Unexpected;
}

pub const MachError = error{
    /// Not enough permissions held to perform the requested kernel
    /// call.
    PermissionDenied,
} || std.posix.UnexpectedError;

pub const MachTask = extern struct {
    port: mach_port_name_t,

    pub fn isValid(self: MachTask) bool {
        return self.port != TASK_NULL;
    }

    pub fn pidForTask(self: MachTask) MachError!std.c.pid_t {
        var pid: std.c.pid_t = undefined;
        switch (getKernError(pid_for_task(self.port, &pid))) {
            .SUCCESS => return pid,
            .FAILURE => return error.PermissionDenied,
            else => |err| return unexpectedKernError(err),
        }
    }

    pub fn allocatePort(self: MachTask, right: MACH_PORT_RIGHT) MachError!MachTask {
        var out_port: mach_port_name_t = undefined;
        switch (getKernError(mach_port_allocate(
            self.port,
            @intFromEnum(right),
            &out_port,
        ))) {
            .SUCCESS => return .{ .port = out_port },
            .FAILURE => return error.PermissionDenied,
            else => |err| return unexpectedKernError(err),
        }
    }

    pub fn deallocatePort(self: MachTask, port: MachTask) void {
        _ = getKernError(mach_port_deallocate(self.port, port.port));
    }

    pub fn insertRight(self: MachTask, port: MachTask, msg: MACH_MSG_TYPE) !void {
        switch (getKernError(mach_port_insert_right(
            self.port,
            port.port,
            port.port,
            @intFromEnum(msg),
        ))) {
            .SUCCESS => return,
            .FAILURE => return error.PermissionDenied,
            else => |err| return unexpectedKernError(err),
        }
    }

    pub const PortInfo = struct {
        mask: exception_mask_t,
        masks: [EXC.TYPES_COUNT]exception_mask_t,
        ports: [EXC.TYPES_COUNT]mach_port_t,
        behaviors: [EXC.TYPES_COUNT]exception_behavior_t,
        flavors: [EXC.TYPES_COUNT]thread_state_flavor_t,
        count: mach_msg_type_number_t,
    };

    pub fn getExceptionPorts(self: MachTask, mask: exception_mask_t) !PortInfo {
        var info = PortInfo{
            .mask = mask,
            .masks = undefined,
            .ports = undefined,
            .behaviors = undefined,
            .flavors = undefined,
            .count = 0,
        };
        info.count = info.ports.len / @sizeOf(mach_port_t);

        switch (getKernError(task_get_exception_ports(
            self.port,
            info.mask,
            &info.masks,
            &info.count,
            &info.ports,
            &info.behaviors,
            &info.flavors,
        ))) {
            .SUCCESS => return info,
            .FAILURE => return error.PermissionDenied,
            else => |err| return unexpectedKernError(err),
        }
    }

    pub fn setExceptionPorts(
        self: MachTask,
        mask: exception_mask_t,
        new_port: MachTask,
        behavior: exception_behavior_t,
        new_flavor: thread_state_flavor_t,
    ) !void {
        switch (getKernError(task_set_exception_ports(
            self.port,
            mask,
            new_port.port,
            behavior,
            new_flavor,
        ))) {
            .SUCCESS => return,
            .FAILURE => return error.PermissionDenied,
            else => |err| return unexpectedKernError(err),
        }
    }

    pub const RegionInfo = struct {
        pub const Tag = enum {
            basic,
            extended,
            top,
        };

        base_addr: u64,
        tag: Tag,
        info: union {
            basic: vm_region_basic_info_64,
            extended: vm_region_extended_info,
            top: vm_region_top_info,
        },
    };

    pub fn getRegionInfo(
        task: MachTask,
        address: u64,
        len: usize,
        tag: RegionInfo.Tag,
    ) MachError!RegionInfo {
        var info: RegionInfo = .{
            .base_addr = address,
            .tag = tag,
            .info = undefined,
        };
        switch (tag) {
            .basic => info.info = .{ .basic = undefined },
            .extended => info.info = .{ .extended = undefined },
            .top => info.info = .{ .top = undefined },
        }
        var base_len: mach_vm_size_t = if (len == 1) 2 else len;
        var objname: mach_port_t = undefined;
        var count: mach_msg_type_number_t = switch (tag) {
            .basic => VM_REGION_BASIC_INFO_COUNT,
            .extended => VM_REGION_EXTENDED_INFO_COUNT,
            .top => VM_REGION_TOP_INFO_COUNT,
        };
        switch (getKernError(mach_vm_region(
            task.port,
            &info.base_addr,
            &base_len,
            switch (tag) {
                .basic => VM_REGION_BASIC_INFO_64,
                .extended => VM_REGION_EXTENDED_INFO,
                .top => VM_REGION_TOP_INFO,
            },
            switch (tag) {
                .basic => @as(vm_region_info_t, @ptrCast(&info.info.basic)),
                .extended => @as(vm_region_info_t, @ptrCast(&info.info.extended)),
                .top => @as(vm_region_info_t, @ptrCast(&info.info.top)),
            },
            &count,
            &objname,
        ))) {
            .SUCCESS => return info,
            .FAILURE => return error.PermissionDenied,
            else => |err| return unexpectedKernError(err),
        }
    }

    pub const RegionSubmapInfo = struct {
        pub const Tag = enum {
            short,
            full,
        };

        tag: Tag,
        base_addr: u64,
        info: union {
            short: vm_region_submap_short_info_64,
            full: vm_region_submap_info_64,
        },
    };

    pub fn getRegionSubmapInfo(
        task: MachTask,
        address: u64,
        len: usize,
        nesting_depth: u32,
        tag: RegionSubmapInfo.Tag,
    ) MachError!RegionSubmapInfo {
        var info: RegionSubmapInfo = .{
            .base_addr = address,
            .tag = tag,
            .info = undefined,
        };
        switch (tag) {
            .short => info.info = .{ .short = undefined },
            .full => info.info = .{ .full = undefined },
        }
        var nesting = nesting_depth;
        var base_len: mach_vm_size_t = if (len == 1) 2 else len;
        var count: mach_msg_type_number_t = switch (tag) {
            .short => VM_REGION_SUBMAP_SHORT_INFO_COUNT_64,
            .full => VM_REGION_SUBMAP_INFO_COUNT_64,
        };
        switch (getKernError(mach_vm_region_recurse(
            task.port,
            &info.base_addr,
            &base_len,
            &nesting,
            switch (tag) {
                .short => @as(vm_region_recurse_info_t, @ptrCast(&info.info.short)),
                .full => @as(vm_region_recurse_info_t, @ptrCast(&info.info.full)),
            },
            &count,
        ))) {
            .SUCCESS => return info,
            .FAILURE => return error.PermissionDenied,
            else => |err| return unexpectedKernError(err),
        }
    }

    pub fn getCurrProtection(task: MachTask, address: u64, len: usize) MachError!vm_prot_t {
        const info = try task.getRegionSubmapInfo(address, len, 0, .short);
        return info.info.short.protection;
    }

    pub fn setMaxProtection(task: MachTask, address: u64, len: usize, prot: vm_prot_t) MachError!void {
        return task.setProtectionImpl(address, len, true, prot);
    }

    pub fn setCurrProtection(task: MachTask, address: u64, len: usize, prot: vm_prot_t) MachError!void {
        return task.setProtectionImpl(address, len, false, prot);
    }

    fn setProtectionImpl(task: MachTask, address: u64, len: usize, set_max: bool, prot: vm_prot_t) MachError!void {
        switch (getKernError(mach_vm_protect(task.port, address, len, @intFromBool(set_max), prot))) {
            .SUCCESS => return,
            .FAILURE => return error.PermissionDenied,
            else => |err| return unexpectedKernError(err),
        }
    }

    /// Will write to VM even if current protection attributes specifically prohibit
    /// us from doing so, by temporarily setting protection level to a level with VM_PROT_COPY
    /// variant, and resetting after a successful or unsuccessful write.
    pub fn writeMemProtected(task: MachTask, address: u64, buf: []const u8, arch: std.Target.Cpu.Arch) MachError!usize {
        const curr_prot = try task.getCurrProtection(address, buf.len);
        try task.setCurrProtection(
            address,
            buf.len,
            PROT.READ | PROT.WRITE | PROT.COPY,
        );
        defer {
            task.setCurrProtection(address, buf.len, curr_prot) catch {};
        }
        return task.writeMem(address, buf, arch);
    }

    pub fn writeMem(task: MachTask, address: u64, buf: []const u8, arch: std.Target.Cpu.Arch) MachError!usize {
        const count = buf.len;
        var total_written: usize = 0;
        var curr_addr = address;
        const page_size = try getPageSize(task); // TODO we probably can assume value here
        var out_buf = buf[0..];

        while (total_written < count) {
            const curr_size = maxBytesLeftInPage(page_size, curr_addr, count - total_written);
            switch (getKernError(mach_vm_write(
                task.port,
                curr_addr,
                @intFromPtr(out_buf.ptr),
                @as(mach_msg_type_number_t, @intCast(curr_size)),
            ))) {
                .SUCCESS => {},
                .FAILURE => return error.PermissionDenied,
                else => |err| return unexpectedKernError(err),
            }

            switch (arch) {
                .aarch64 => {
                    var mattr_value: vm_machine_attribute_val_t = MATTR_VAL_CACHE_FLUSH;
                    switch (getKernError(vm_machine_attribute(
                        task.port,
                        curr_addr,
                        curr_size,
                        MATTR_CACHE,
                        &mattr_value,
                    ))) {
                        .SUCCESS => {},
                        .FAILURE => return error.PermissionDenied,
                        else => |err| return unexpectedKernError(err),
                    }
                },
                .x86_64 => {},
                else => unreachable,
            }

            out_buf = out_buf[curr_size..];
            total_written += curr_size;
            curr_addr += curr_size;
        }

        return total_written;
    }

    pub fn readMem(task: MachTask, address: u64, buf: []u8) MachError!usize {
        const count = buf.len;
        var total_read: usize = 0;
        var curr_addr = address;
        const page_size = try getPageSize(task); // TODO we probably can assume value here
        var out_buf = buf[0..];

        while (total_read < count) {
            const curr_size = maxBytesLeftInPage(page_size, curr_addr, count - total_read);
            var curr_bytes_read: mach_msg_type_number_t = 0;
            var vm_memory: vm_offset_t = undefined;
            switch (getKernError(mach_vm_read(task.port, curr_addr, curr_size, &vm_memory, &curr_bytes_read))) {
                .SUCCESS => {},
                .FAILURE => return error.PermissionDenied,
                else => |err| return unexpectedKernError(err),
            }

            @memcpy(out_buf[0..curr_bytes_read], @as([*]const u8, @ptrFromInt(vm_memory)));
            _ = vm_deallocate(mach_task_self(), vm_memory, curr_bytes_read);

            out_buf = out_buf[curr_bytes_read..];
            curr_addr += curr_bytes_read;
            total_read += curr_bytes_read;
        }

        return total_read;
    }

    fn maxBytesLeftInPage(page_size: usize, address: u64, count: usize) usize {
        var left = count;
        if (page_size > 0) {
            const page_offset = address % page_size;
            const bytes_left_in_page = page_size - page_offset;
            if (count > bytes_left_in_page) {
                left = bytes_left_in_page;
            }
        }
        return left;
    }

    fn getPageSize(task: MachTask) MachError!usize {
        if (task.isValid()) {
            var info_count = TASK_VM_INFO_COUNT;
            var vm_info: task_vm_info_data_t = undefined;
            switch (getKernError(task_info(
                task.port,
                TASK_VM_INFO,
                @as(task_info_t, @ptrCast(&vm_info)),
                &info_count,
            ))) {
                .SUCCESS => return @as(usize, @intCast(vm_info.page_size)),
                else => {},
            }
        }
        var page_size: vm_size_t = undefined;
        switch (getKernError(_host_page_size(mach_host_self(), &page_size))) {
            .SUCCESS => return page_size,
            else => |err| return unexpectedKernError(err),
        }
    }

    pub fn basicTaskInfo(task: MachTask) MachError!mach_task_basic_info {
        var info: mach_task_basic_info = undefined;
        var count = MACH_TASK_BASIC_INFO_COUNT;
        switch (getKernError(task_info(
            task.port,
            MACH_TASK_BASIC_INFO,
            @as(task_info_t, @ptrCast(&info)),
            &count,
        ))) {
            .SUCCESS => return info,
            else => |err| return unexpectedKernError(err),
        }
    }

    pub fn @"resume"(task: MachTask) MachError!void {
        switch (getKernError(task_resume(task.port))) {
            .SUCCESS => {},
            else => |err| return unexpectedKernError(err),
        }
    }

    pub fn @"suspend"(task: MachTask) MachError!void {
        switch (getKernError(task_suspend(task.port))) {
            .SUCCESS => {},
            else => |err| return unexpectedKernError(err),
        }
    }

    const ThreadList = struct {
        buf: []MachThread,

        pub fn deinit(list: ThreadList) void {
            const self_task = machTaskForSelf();
            _ = vm_deallocate(
                self_task.port,
                @intFromPtr(list.buf.ptr),
                @as(vm_size_t, @intCast(list.buf.len * @sizeOf(mach_port_t))),
            );
        }
    };

    pub fn getThreads(task: MachTask) MachError!ThreadList {
        var thread_list: mach_port_array_t = undefined;
        var thread_count: mach_msg_type_number_t = undefined;
        switch (getKernError(task_threads(task.port, &thread_list, &thread_count))) {
            .SUCCESS => return ThreadList{ .buf = @as([*]MachThread, @ptrCast(thread_list))[0..thread_count] },
            else => |err| return unexpectedKernError(err),
        }
    }
};

pub const MachThread = extern struct {
    port: mach_port_t,

    pub fn isValid(thread: MachThread) bool {
        return thread.port != THREAD_NULL;
    }

    pub fn getBasicInfo(thread: MachThread) MachError!thread_basic_info {
        var info: thread_basic_info = undefined;
        var count = THREAD_BASIC_INFO_COUNT;
        switch (getKernError(thread_info(
            thread.port,
            THREAD_BASIC_INFO,
            @as(thread_info_t, @ptrCast(&info)),
            &count,
        ))) {
            .SUCCESS => return info,
            else => |err| return unexpectedKernError(err),
        }
    }

    pub fn getIdentifierInfo(thread: MachThread) MachError!thread_identifier_info {
        var info: thread_identifier_info = undefined;
        var count = THREAD_IDENTIFIER_INFO_COUNT;
        switch (getKernError(thread_info(
            thread.port,
            THREAD_IDENTIFIER_INFO,
            @as(thread_info_t, @ptrCast(&info)),
            &count,
        ))) {
            .SUCCESS => return info,
            else => |err| return unexpectedKernError(err),
        }
    }
};

pub fn machTaskForPid(pid: std.c.pid_t) MachError!MachTask {
    var port: mach_port_name_t = undefined;
    switch (getKernError(task_for_pid(mach_task_self(), pid, &port))) {
        .SUCCESS => {},
        .FAILURE => return error.PermissionDenied,
        else => |err| return unexpectedKernError(err),
    }
    return MachTask{ .port = port };
}

pub fn machTaskForSelf() MachTask {
    return .{ .port = mach_task_self() };
}

pub const os_signpost_id_t = u64;

pub const OS_SIGNPOST_ID_NULL: os_signpost_id_t = 0;
pub const OS_SIGNPOST_ID_INVALID: os_signpost_id_t = !0;
pub const OS_SIGNPOST_ID_EXCLUSIVE: os_signpost_id_t = 0xeeeeb0b5b2b2eeee;

pub const os_log_t = opaque {};
pub const os_log_type_t = enum(u8) {
    /// default messages always captures
    OS_LOG_TYPE_DEFAULT = 0x00,
    /// messages with additional infos
    OS_LOG_TYPE_INFO = 0x01,
    /// debug messages
    OS_LOG_TYPE_DEBUG = 0x02,
    /// error messages
    OS_LOG_TYPE_ERROR = 0x10,
    /// unexpected conditions messages
    OS_LOG_TYPE_FAULT = 0x11,
};

pub const OS_LOG_CATEGORY_POINTS_OF_INTEREST: *const u8 = "PointsOfInterest";
pub const OS_LOG_CATEGORY_DYNAMIC_TRACING: *const u8 = "DynamicTracing";
pub const OS_LOG_CATEGORY_DYNAMIC_STACK_TRACING: *const u8 = "DynamicStackTracing";

pub extern "c" fn os_log_create(subsystem: [*]const u8, category: [*]const u8) os_log_t;
pub extern "c" fn os_log_type_enabled(log: os_log_t, tpe: os_log_type_t) bool;
pub extern "c" fn os_signpost_id_generate(log: os_log_t) os_signpost_id_t;
pub extern "c" fn os_signpost_interval_begin(log: os_log_t, signpos: os_signpost_id_t, func: [*]const u8, ...) void;
pub extern "c" fn os_signpost_interval_end(log: os_log_t, signpos: os_signpost_id_t, func: [*]const u8, ...) void;
pub extern "c" fn os_signpost_id_make_with_pointer(log: os_log_t, ptr: ?*anyopaque) os_signpost_id_t;
pub extern "c" fn os_signpost_enabled(log: os_log_t) bool;

pub extern "c" fn pthread_setname_np(name: [*:0]const u8) c_int;
pub extern "c" fn pthread_attr_set_qos_class_np(attr: *pthread_attr_t, qos_class: qos_class_t, relative_priority: c_int) c_int;
pub extern "c" fn pthread_attr_get_qos_class_np(attr: *pthread_attr_t, qos_class: *qos_class_t, relative_priority: *c_int) c_int;
pub extern "c" fn pthread_set_qos_class_self_np(qos_class: qos_class_t, relative_priority: c_int) c_int;
pub extern "c" fn pthread_get_qos_class_np(pthread: std.c.pthread_t, qos_class: *qos_class_t, relative_priority: *c_int) c_int;

pub const mach_timebase_info_data = extern struct {
    numer: u32,
    denom: u32,
};

pub const kevent64_s = extern struct {
    ident: u64,
    filter: i16,
    flags: u16,
    fflags: u32,
    data: i64,
    udata: u64,
    ext: [2]u64,
};

// sys/types.h on macos uses #pragma pack() so these checks are
// to make sure the struct is laid out the same. These values were
// produced from C code using the offsetof macro.
comptime {
    if (builtin.target.isDarwin()) {
        assert(@offsetOf(kevent64_s, "ident") == 0);
        assert(@offsetOf(kevent64_s, "filter") == 8);
        assert(@offsetOf(kevent64_s, "flags") == 10);
        assert(@offsetOf(kevent64_s, "fflags") == 12);
        assert(@offsetOf(kevent64_s, "data") == 16);
        assert(@offsetOf(kevent64_s, "udata") == 24);
        assert(@offsetOf(kevent64_s, "ext") == 32);
    }
}

pub const clock_serv_t = mach_port_t;
pub const clock_res_t = c_int;
pub const mach_port_name_t = natural_t;
pub const natural_t = c_uint;
pub const mach_timespec_t = extern struct {
    sec: c_uint,
    nsec: clock_res_t,
};
pub const kern_return_t = c_int;
pub const host_t = mach_port_t;
pub const integer_t = c_int;
pub const task_flavor_t = natural_t;
pub const task_info_t = *integer_t;
pub const task_name_t = mach_port_name_t;
pub const vm_address_t = vm_offset_t;
pub const vm_size_t = mach_vm_size_t;
pub const vm_machine_attribute_t = usize;
pub const vm_machine_attribute_val_t = isize;

pub const CALENDAR_CLOCK = 1;

/// no flag value
pub const KEVENT_FLAG_NONE = 0x000;
/// immediate timeout
pub const KEVENT_FLAG_IMMEDIATE = 0x001;
/// output events only include change
pub const KEVENT_FLAG_ERROR_EVENTS = 0x002;

pub const SYSPROTO_EVENT = 1;
pub const SYSPROTO_CONTROL = 2;
/// Kernel return values
pub const KernE = enum(u32) {
    SUCCESS = 0,
    /// Specified address is not currently valid
    INVALID_ADDRESS = 1,
    /// Specified memory is valid, but does not permit the
    /// required forms of access.
    PROTECTION_FAILURE = 2,
    /// The address range specified is already in use, or
    /// no address range of the size specified could be
    /// found.
    NO_SPACE = 3,
    /// The function requested was not applicable to this
    /// type of argument, or an argument is invalid
    INVALID_ARGUMENT = 4,
    /// The function could not be performed.  A catch-all.
    FAILURE = 5,
    /// A system resource could not be allocated to fulfill
    /// this request.  This failure may not be permanent.
    RESOURCE_SHORTAGE = 6,
    /// The task in question does not hold receive rights
    /// for the port argument.
    NOT_RECEIVER = 7,
    /// Bogus access restriction.
    NO_ACCESS = 8,
    /// During a page fault, the target address refers to a
    /// memory object that has been destroyed.  This
    /// failure is permanent.
    MEMORY_FAILURE = 9,
    /// During a page fault, the memory object indicated
    /// that the data could not be returned.  This failure
    /// may be temporary; future attempts to access this
    /// same data may succeed, as defined by the memory
    /// object.
    MEMORY_ERROR = 10,
    /// The receive right is already a member of the portset.
    ALREADY_IN_SET = 11,
    /// The receive right is not a member of a port set.
    NOT_IN_SET = 12,
    /// The name already denotes a right in the task.
    NAME_EXISTS = 13,
    /// The operation was aborted.  Ipc code will
    /// catch this and reflect it as a message error.
    ABORTED = 14,
    /// The name doesn't denote a right in the task.
    INVALID_NAME = 15,
    /// Target task isn't an active task.
    INVALID_TASK = 16,
    /// The name denotes a right, but not an appropriate right.
    INVALID_RIGHT = 17,
    /// A blatant range error.
    INVALID_VALUE = 18,
    /// Operation would overflow limit on user-references.
    UREFS_OVERFLOW = 19,
    /// The supplied (port) capability is improper.
    INVALID_CAPABILITY = 20,
    /// The task already has send or receive rights
    /// for the port under another name.
    RIGHT_EXISTS = 21,
    /// Target host isn't actually a host.
    INVALID_HOST = 22,
    /// An attempt was made to supply "precious" data
    /// for memory that is already present in a
    /// memory object.
    MEMORY_PRESENT = 23,
    /// A page was requested of a memory manager via
    /// memory_object_data_request for an object using
    /// a MEMORY_OBJECT_COPY_CALL strategy, with the
    /// VM_PROT_WANTS_COPY flag being used to specify
    /// that the page desired is for a copy of the
    /// object, and the memory manager has detected
    /// the page was pushed into a copy of the object
    /// while the kernel was walking the shadow chain
    /// from the copy to the object. This error code
    /// is delivered via memory_object_data_error
    /// and is handled by the kernel (it forces the
    /// kernel to restart the fault). It will not be
    /// seen by users.
    MEMORY_DATA_MOVED = 24,
    /// A strategic copy was attempted of an object
    /// upon which a quicker copy is now possible.
    /// The caller should retry the copy using
    /// vm_object_copy_quickly. This error code
    /// is seen only by the kernel.
    MEMORY_RESTART_COPY = 25,
    /// An argument applied to assert processor set privilege
    /// was not a processor set control port.
    INVALID_PROCESSOR_SET = 26,
    /// The specified scheduling attributes exceed the thread's
    /// limits.
    POLICY_LIMIT = 27,
    /// The specified scheduling policy is not currently
    /// enabled for the processor set.
    INVALID_POLICY = 28,
    /// The external memory manager failed to initialize the
    /// memory object.
    INVALID_OBJECT = 29,
    /// A thread is attempting to wait for an event for which
    /// there is already a waiting thread.
    ALREADY_WAITING = 30,
    /// An attempt was made to destroy the default processor
    /// set.
    DEFAULT_SET = 31,
    /// An attempt was made to fetch an exception port that is
    /// protected, or to abort a thread while processing a
    /// protected exception.
    EXCEPTION_PROTECTED = 32,
    /// A ledger was required but not supplied.
    INVALID_LEDGER = 33,
    /// The port was not a memory cache control port.
    INVALID_MEMORY_CONTROL = 34,
    /// An argument supplied to assert security privilege
    /// was not a host security port.
    INVALID_SECURITY = 35,
    /// thread_depress_abort was called on a thread which
    /// was not currently depressed.
    NOT_DEPRESSED = 36,
    /// Object has been terminated and is no longer available
    TERMINATED = 37,
    /// Lock set has been destroyed and is no longer available.
    LOCK_SET_DESTROYED = 38,
    /// The thread holding the lock terminated before releasing
    /// the lock
    LOCK_UNSTABLE = 39,
    /// The lock is already owned by another thread
    LOCK_OWNED = 40,
    /// The lock is already owned by the calling thread
    LOCK_OWNED_SELF = 41,
    /// Semaphore has been destroyed and is no longer available.
    SEMAPHORE_DESTROYED = 42,
    /// Return from RPC indicating the target server was
    /// terminated before it successfully replied
    RPC_SERVER_TERMINATED = 43,
    /// Terminate an orphaned activation.
    RPC_TERMINATE_ORPHAN = 44,
    /// Allow an orphaned activation to continue executing.
    RPC_CONTINUE_ORPHAN = 45,
    /// Empty thread activation (No thread linked to it)
    NOT_SUPPORTED = 46,
    /// Remote node down or inaccessible.
    NODE_DOWN = 47,
    /// A signalled thread was not actually waiting.
    NOT_WAITING = 48,
    /// Some thread-oriented operation (semaphore_wait) timed out
    OPERATION_TIMED_OUT = 49,
    /// During a page fault, indicates that the page was rejected
    /// as a result of a signature check.
    CODESIGN_ERROR = 50,
    /// The requested property cannot be changed at this time.
    POLICY_STATIC = 51,
    /// The provided buffer is of insufficient size for the requested data.
    INSUFFICIENT_BUFFER_SIZE = 52,
    /// Denied by security policy
    DENIED = 53,
    /// The KC on which the function is operating is missing
    MISSING_KC = 54,
    /// The KC on which the function is operating is invalid
    INVALID_KC = 55,
    /// A search or query operation did not return a result
    NOT_FOUND = 56,
    _,
};

pub const mach_msg_return_t = kern_return_t;

pub fn getMachMsgError(err: mach_msg_return_t) MachMsgE {
    return @as(MachMsgE, @enumFromInt(@as(u32, @truncate(@as(usize, @intCast(err))))));
}

/// All special error code bits defined below.
pub const MACH_MSG_MASK: u32 = 0x3e00;
/// No room in IPC name space for another capability name.
pub const MACH_MSG_IPC_SPACE: u32 = 0x2000;
/// No room in VM address space for out-of-line memory.
pub const MACH_MSG_VM_SPACE: u32 = 0x1000;
/// Kernel resource shortage handling out-of-line memory.
pub const MACH_MSG_IPC_KERNEL: u32 = 0x800;
/// Kernel resource shortage handling an IPC capability.
pub const MACH_MSG_VM_KERNEL: u32 = 0x400;

/// Mach msg return values
pub const MachMsgE = enum(u32) {
    SUCCESS = 0x00000000,

    /// Thread is waiting to send.  (Internal use only.)
    SEND_IN_PROGRESS = 0x10000001,
    /// Bogus in-line data.
    SEND_INVALID_DATA = 0x10000002,
    /// Bogus destination port.
    SEND_INVALID_DEST = 0x10000003,
    ///  Message not sent before timeout expired.
    SEND_TIMED_OUT = 0x10000004,
    ///  Bogus voucher port.
    SEND_INVALID_VOUCHER = 0x10000005,
    ///  Software interrupt.
    SEND_INTERRUPTED = 0x10000007,
    ///  Data doesn't contain a complete message.
    SEND_MSG_TOO_SMALL = 0x10000008,
    ///  Bogus reply port.
    SEND_INVALID_REPLY = 0x10000009,
    ///  Bogus port rights in the message body.
    SEND_INVALID_RIGHT = 0x1000000a,
    ///  Bogus notify port argument.
    SEND_INVALID_NOTIFY = 0x1000000b,
    ///  Invalid out-of-line memory pointer.
    SEND_INVALID_MEMORY = 0x1000000c,
    ///  No message buffer is available.
    SEND_NO_BUFFER = 0x1000000d,
    ///  Send is too large for port
    SEND_TOO_LARGE = 0x1000000e,
    ///  Invalid msg-type specification.
    SEND_INVALID_TYPE = 0x1000000f,
    ///  A field in the header had a bad value.
    SEND_INVALID_HEADER = 0x10000010,
    ///  The trailer to be sent does not match kernel format.
    SEND_INVALID_TRAILER = 0x10000011,
    ///  The sending thread context did not match the context on the dest port
    SEND_INVALID_CONTEXT = 0x10000012,
    ///  compatibility: no longer a returned error
    SEND_INVALID_RT_OOL_SIZE = 0x10000015,
    ///  The destination port doesn't accept ports in body
    SEND_NO_GRANT_DEST = 0x10000016,
    ///  Message send was rejected by message filter
    SEND_MSG_FILTERED = 0x10000017,

    ///  Thread is waiting for receive.  (Internal use only.)
    RCV_IN_PROGRESS = 0x10004001,
    ///  Bogus name for receive port/port-set.
    RCV_INVALID_NAME = 0x10004002,
    ///  Didn't get a message within the timeout value.
    RCV_TIMED_OUT = 0x10004003,
    ///  Message buffer is not large enough for inline data.
    RCV_TOO_LARGE = 0x10004004,
    ///  Software interrupt.
    RCV_INTERRUPTED = 0x10004005,
    ///  compatibility: no longer a returned error
    RCV_PORT_CHANGED = 0x10004006,
    ///  Bogus notify port argument.
    RCV_INVALID_NOTIFY = 0x10004007,
    ///  Bogus message buffer for inline data.
    RCV_INVALID_DATA = 0x10004008,
    ///  Port/set was sent away/died during receive.
    RCV_PORT_DIED = 0x10004009,
    ///  compatibility: no longer a returned error
    RCV_IN_SET = 0x1000400a,
    ///  Error receiving message header.  See special bits.
    RCV_HEADER_ERROR = 0x1000400b,
    ///  Error receiving message body.  See special bits.
    RCV_BODY_ERROR = 0x1000400c,
    ///  Invalid msg-type specification in scatter list.
    RCV_INVALID_TYPE = 0x1000400d,
    ///  Out-of-line overwrite region is not large enough
    RCV_SCATTER_SMALL = 0x1000400e,
    ///  trailer type or number of trailer elements not supported
    RCV_INVALID_TRAILER = 0x1000400f,
    ///  Waiting for receive with timeout. (Internal use only.)
    RCV_IN_PROGRESS_TIMED = 0x10004011,
    ///  invalid reply port used in a STRICT_REPLY message
    RCV_INVALID_REPLY = 0x10004012,
};

pub const FCNTL_FS_SPECIFIC_BASE = 0x00010000;

/// Max open files per process
/// https://opensource.apple.com/source/xnu/xnu-4903.221.2/bsd/sys/syslimits.h.auto.html
pub const OPEN_MAX = 10240;

// CPU families mapping
pub const CPUFAMILY = enum(u32) {
    UNKNOWN = 0,
    POWERPC_G3 = 0xcee41549,
    POWERPC_G4 = 0x77c184ae,
    POWERPC_G5 = 0xed76d8aa,
    INTEL_6_13 = 0xaa33392b,
    INTEL_PENRYN = 0x78ea4fbc,
    INTEL_NEHALEM = 0x6b5a4cd2,
    INTEL_WESTMERE = 0x573b5eec,
    INTEL_SANDYBRIDGE = 0x5490b78c,
    INTEL_IVYBRIDGE = 0x1f65e835,
    INTEL_HASWELL = 0x10b282dc,
    INTEL_BROADWELL = 0x582ed09c,
    INTEL_SKYLAKE = 0x37fc219f,
    INTEL_KABYLAKE = 0x0f817246,
    ARM_9 = 0xe73283ae,
    ARM_11 = 0x8ff620d8,
    ARM_XSCALE = 0x53b005f5,
    ARM_12 = 0xbd1b0ae9,
    ARM_13 = 0x0cc90e64,
    ARM_14 = 0x96077ef1,
    ARM_15 = 0xa8511bca,
    ARM_SWIFT = 0x1e2d6381,
    ARM_CYCLONE = 0x37a09642,
    ARM_TYPHOON = 0x2c91a47e,
    ARM_TWISTER = 0x92fb37c8,
    ARM_HURRICANE = 0x67ceee93,
    ARM_MONSOON_MISTRAL = 0xe81e7ef6,
    ARM_VORTEX_TEMPEST = 0x07d34b9f,
    ARM_LIGHTNING_THUNDER = 0x462504d2,
    ARM_FIRESTORM_ICESTORM = 0x1b588bb3,
    ARM_BLIZZARD_AVALANCHE = 0xda33d83d,
    ARM_EVEREST_SAWTOOTH = 0x8765edea,
    _,
};

pub const PT = struct {
    pub const TRACE_ME = 0;
    pub const READ_I = 1;
    pub const READ_D = 2;
    pub const READ_U = 3;
    pub const WRITE_I = 4;
    pub const WRITE_D = 5;
    pub const WRITE_U = 6;
    pub const CONTINUE = 7;
    pub const KILL = 8;
    pub const STEP = 9;
    pub const DETACH = 11;
    pub const SIGEXC = 12;
    pub const THUPDATE = 13;
    pub const ATTACHEXC = 14;
    pub const FORCEQUOTA = 30;
    pub const DENY_ATTACH = 31;
};

pub const caddr_t = ?[*]u8;

pub extern "c" fn ptrace(request: c_int, pid: pid_t, addr: caddr_t, data: c_int) c_int;

pub const POSIX_SPAWN = struct {
    pub const RESETIDS = 0x0001;
    pub const SETPGROUP = 0x0002;
    pub const SETSIGDEF = 0x0004;
    pub const SETSIGMASK = 0x0008;
    pub const SETEXEC = 0x0040;
    pub const START_SUSPENDED = 0x0080;
    pub const DISABLE_ASLR = 0x0100;
    pub const SETSID = 0x0400;
    pub const RESLIDE = 0x0800;
    pub const CLOEXEC_DEFAULT = 0x4000;
};

pub const posix_spawnattr_t = *opaque {};
pub const posix_spawn_file_actions_t = *opaque {};
pub extern "c" fn posix_spawnattr_init(attr: *posix_spawnattr_t) c_int;
pub extern "c" fn posix_spawnattr_destroy(attr: *posix_spawnattr_t) c_int;
pub extern "c" fn posix_spawnattr_setflags(attr: *posix_spawnattr_t, flags: c_short) c_int;
pub extern "c" fn posix_spawnattr_getflags(attr: *const posix_spawnattr_t, flags: *c_short) c_int;
pub extern "c" fn posix_spawn_file_actions_init(actions: *posix_spawn_file_actions_t) c_int;
pub extern "c" fn posix_spawn_file_actions_destroy(actions: *posix_spawn_file_actions_t) c_int;
pub extern "c" fn posix_spawn_file_actions_addclose(actions: *posix_spawn_file_actions_t, filedes: fd_t) c_int;
pub extern "c" fn posix_spawn_file_actions_addopen(
    actions: *posix_spawn_file_actions_t,
    filedes: fd_t,
    path: [*:0]const u8,
    oflag: c_int,
    mode: mode_t,
) c_int;
pub extern "c" fn posix_spawn_file_actions_adddup2(
    actions: *posix_spawn_file_actions_t,
    filedes: fd_t,
    newfiledes: fd_t,
) c_int;
pub extern "c" fn posix_spawn_file_actions_addinherit_np(actions: *posix_spawn_file_actions_t, filedes: fd_t) c_int;
pub extern "c" fn posix_spawn_file_actions_addchdir_np(actions: *posix_spawn_file_actions_t, path: [*:0]const u8) c_int;
pub extern "c" fn posix_spawn_file_actions_addfchdir_np(actions: *posix_spawn_file_actions_t, filedes: fd_t) c_int;
pub extern "c" fn posix_spawn(
    pid: *pid_t,
    path: [*:0]const u8,
    actions: ?*const posix_spawn_file_actions_t,
    attr: ?*const posix_spawnattr_t,
    argv: [*:null]?[*:0]const u8,
    env: [*:null]?[*:0]const u8,
) c_int;
pub extern "c" fn posix_spawnp(
    pid: *pid_t,
    path: [*:0]const u8,
    actions: ?*const posix_spawn_file_actions_t,
    attr: ?*const posix_spawnattr_t,
    argv: [*:null]?[*:0]const u8,
    env: [*:null]?[*:0]const u8,
) c_int;

pub const E = enum(u16) {
    /// No error occurred.
    SUCCESS = 0,
    /// Operation not permitted
    PERM = 1,
    /// No such file or directory
    NOENT = 2,
    /// No such process
    SRCH = 3,
    /// Interrupted system call
    INTR = 4,
    /// Input/output error
    IO = 5,
    /// Device not configured
    NXIO = 6,
    /// Argument list too long
    @"2BIG" = 7,
    /// Exec format error
    NOEXEC = 8,
    /// Bad file descriptor
    BADF = 9,
    /// No child processes
    CHILD = 10,
    /// Resource deadlock avoided
    DEADLK = 11,
    /// Cannot allocate memory
    NOMEM = 12,
    /// Permission denied
    ACCES = 13,
    /// Bad address
    FAULT = 14,
    /// Block device required
    NOTBLK = 15,
    /// Device / Resource busy
    BUSY = 16,
    /// File exists
    EXIST = 17,
    /// Cross-device link
    XDEV = 18,
    /// Operation not supported by device
    NODEV = 19,
    /// Not a directory
    NOTDIR = 20,
    /// Is a directory
    ISDIR = 21,
    /// Invalid argument
    INVAL = 22,
    /// Too many open files in system
    NFILE = 23,
    /// Too many open files
    MFILE = 24,
    /// Inappropriate ioctl for device
    NOTTY = 25,
    /// Text file busy
    TXTBSY = 26,
    /// File too large
    FBIG = 27,
    /// No space left on device
    NOSPC = 28,
    /// Illegal seek
    SPIPE = 29,
    /// Read-only file system
    ROFS = 30,
    /// Too many links
    MLINK = 31,
    /// Broken pipe
    PIPE = 32,
    // math software
    /// Numerical argument out of domain
    DOM = 33,
    /// Result too large
    RANGE = 34,
    // non-blocking and interrupt i/o
    /// Resource temporarily unavailable
    /// This is the same code used for `WOULDBLOCK`.
    AGAIN = 35,
    /// Operation now in progress
    INPROGRESS = 36,
    /// Operation already in progress
    ALREADY = 37,
    // ipc/network software -- argument errors
    /// Socket operation on non-socket
    NOTSOCK = 38,
    /// Destination address required
    DESTADDRREQ = 39,
    /// Message too long
    MSGSIZE = 40,
    /// Protocol wrong type for socket
    PROTOTYPE = 41,
    /// Protocol not available
    NOPROTOOPT = 42,
    /// Protocol not supported
    PROTONOSUPPORT = 43,
    /// Socket type not supported
    SOCKTNOSUPPORT = 44,
    /// Operation not supported
    /// The same code is used for `NOTSUP`.
    OPNOTSUPP = 45,
    /// Protocol family not supported
    PFNOSUPPORT = 46,
    /// Address family not supported by protocol family
    AFNOSUPPORT = 47,
    /// Address already in use
    ADDRINUSE = 48,
    /// Can't assign requested address
    // ipc/network software -- operational errors
    ADDRNOTAVAIL = 49,
    /// Network is down
    NETDOWN = 50,
    /// Network is unreachable
    NETUNREACH = 51,
    /// Network dropped connection on reset
    NETRESET = 52,
    /// Software caused connection abort
    CONNABORTED = 53,
    /// Connection reset by peer
    CONNRESET = 54,
    /// No buffer space available
    NOBUFS = 55,
    /// Socket is already connected
    ISCONN = 56,
    /// Socket is not connected
    NOTCONN = 57,
    /// Can't send after socket shutdown
    SHUTDOWN = 58,
    /// Too many references: can't splice
    TOOMANYREFS = 59,
    /// Operation timed out
    TIMEDOUT = 60,
    /// Connection refused
    CONNREFUSED = 61,
    /// Too many levels of symbolic links
    LOOP = 62,
    /// File name too long
    NAMETOOLONG = 63,
    /// Host is down
    HOSTDOWN = 64,
    /// No route to host
    HOSTUNREACH = 65,
    /// Directory not empty
    // quotas & mush
    NOTEMPTY = 66,
    /// Too many processes
    PROCLIM = 67,
    /// Too many users
    USERS = 68,
    /// Disc quota exceeded
    // Network File System
    DQUOT = 69,
    /// Stale NFS file handle
    STALE = 70,
    /// Too many levels of remote in path
    REMOTE = 71,
    /// RPC struct is bad
    BADRPC = 72,
    /// RPC version wrong
    RPCMISMATCH = 73,
    /// RPC prog. not avail
    PROGUNAVAIL = 74,
    /// Program version wrong
    PROGMISMATCH = 75,
    /// Bad procedure for program
    PROCUNAVAIL = 76,
    /// No locks available
    NOLCK = 77,
    /// Function not implemented
    NOSYS = 78,
    /// Inappropriate file type or format
    FTYPE = 79,
    /// Authentication error
    AUTH = 80,
    /// Need authenticator
    NEEDAUTH = 81,
    // Intelligent device errors
    /// Device power is off
    PWROFF = 82,
    /// Device error, e.g. paper out
    DEVERR = 83,
    /// Value too large to be stored in data type
    OVERFLOW = 84,
    // Program loading errors
    /// Bad executable
    BADEXEC = 85,
    /// Bad CPU type in executable
    BADARCH = 86,
    /// Shared library version mismatch
    SHLIBVERS = 87,
    /// Malformed Macho file
    BADMACHO = 88,
    /// Operation canceled
    CANCELED = 89,
    /// Identifier removed
    IDRM = 90,
    /// No message of desired type
    NOMSG = 91,
    /// Illegal byte sequence
    ILSEQ = 92,
    /// Attribute not found
    NOATTR = 93,
    /// Bad message
    BADMSG = 94,
    /// Reserved
    MULTIHOP = 95,
    /// No message available on STREAM
    NODATA = 96,
    /// Reserved
    NOLINK = 97,
    /// No STREAM resources
    NOSR = 98,
    /// Not a STREAM
    NOSTR = 99,
    /// Protocol error
    PROTO = 100,
    /// STREAM ioctl timeout
    TIME = 101,
    /// No such policy registered
    NOPOLICY = 103,
    /// State not recoverable
    NOTRECOVERABLE = 104,
    /// Previous owner died
    OWNERDEAD = 105,
    /// Interface output queue is full
    QFULL = 106,
    _,
};

/// From Common Security Services Manager
/// Security.framework/Headers/cssm*.h
pub const DB_RECORDTYPE = enum(u32) {
    // Record Types defined in the Schema Management Name Space
    SCHEMA_INFO = SCHEMA_START + 0,
    SCHEMA_INDEXES = SCHEMA_START + 1,
    SCHEMA_ATTRIBUTES = SCHEMA_START + 2,
    SCHEMA_PARSING_MODULE = SCHEMA_START + 3,

    // Record Types defined in the Open Group Application Name Space
    ANY = OPEN_GROUP_START + 0,
    CERT = OPEN_GROUP_START + 1,
    CRL = OPEN_GROUP_START + 2,
    POLICY = OPEN_GROUP_START + 3,
    GENERIC = OPEN_GROUP_START + 4,
    PUBLIC_KEY = OPEN_GROUP_START + 5,
    PRIVATE_KEY = OPEN_GROUP_START + 6,
    SYMMETRIC_KEY = OPEN_GROUP_START + 7,
    ALL_KEYS = OPEN_GROUP_START + 8,

    // AppleFileDL record types
    GENERIC_PASSWORD = APP_DEFINED_START + 0,
    INTERNET_PASSWORD = APP_DEFINED_START + 1,
    APPLESHARE_PASSWORD = APP_DEFINED_START + 2,

    X509_CERTIFICATE = APP_DEFINED_START + 0x1000,
    USER_TRUST,
    X509_CRL,
    UNLOCK_REFERRAL,
    EXTENDED_ATTRIBUTE,
    METADATA = APP_DEFINED_START + 0x8000,

    _,

    // Schema Management Name Space Range Definition
    pub const SCHEMA_START = 0x00000000;
    pub const SCHEMA_END = SCHEMA_START + 4;

    // Open Group Application Name Space Range Definition
    pub const OPEN_GROUP_START = 0x0000000A;
    pub const OPEN_GROUP_END = OPEN_GROUP_START + 8;

    // Industry At Large Application Name Space Range Definition
    pub const APP_DEFINED_START = 0x80000000;
    pub const APP_DEFINED_END = 0xffffffff;
};
