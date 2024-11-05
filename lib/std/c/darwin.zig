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
const sigset_t = std.c.sigset_t;
const timespec = std.c.timespec;
const sf_hdtr = std.c.sf_hdtr;

comptime {
    assert(builtin.os.tag.isDarwin()); // Prevent access of std.c symbols on wrong OS.
}

pub const mach_port_t = c_uint;

pub const THREAD_STATE_NONE = switch (native_arch) {
    .aarch64 => 5,
    .x86_64 => 13,
    else => @compileError("unsupported arch"),
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

    pub const TYPES_COUNT = @typeInfo(EXC).@"enum".fields.len;
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

pub const VM = struct {
    pub const INHERIT = struct {
        pub const SHARE: vm_inherit_t = 0;
        pub const COPY: vm_inherit_t = 1;
        pub const NONE: vm_inherit_t = 2;
        pub const DONATE_COPY: vm_inherit_t = 3;
        pub const DEFAULT = COPY;
    };

    pub const BEHAVIOR = struct {
        pub const DEFAULT: vm_behavior_t = 0;
        pub const RANDOM: vm_behavior_t = 1;
        pub const SEQUENTIAL: vm_behavior_t = 2;
        pub const RSEQNTL: vm_behavior_t = 3;
        pub const WILLNEED: vm_behavior_t = 4;
        pub const DONTNEED: vm_behavior_t = 5;
        pub const FREE: vm_behavior_t = 6;
        pub const ZERO_WIRED_PAGES: vm_behavior_t = 7;
        pub const REUSABLE: vm_behavior_t = 8;
        pub const REUSE: vm_behavior_t = 9;
        pub const CAN_REUSE: vm_behavior_t = 10;
        pub const PAGEOUT: vm_behavior_t = 11;
    };

    pub const REGION = struct {
        pub const BASIC_INFO_64 = 9;
        pub const EXTENDED_INFO = 13;
        pub const TOP_INFO = 12;
        pub const SUBMAP_INFO_COUNT_64: mach_msg_type_number_t = @sizeOf(vm_region_submap_info_64) / @sizeOf(natural_t);
        pub const SUBMAP_SHORT_INFO_COUNT_64: mach_msg_type_number_t = @sizeOf(vm_region_submap_short_info_64) / @sizeOf(natural_t);
        pub const BASIC_INFO_COUNT: mach_msg_type_number_t = @sizeOf(vm_region_basic_info_64) / @sizeOf(c_int);
        pub const EXTENDED_INFO_COUNT: mach_msg_type_number_t = @sizeOf(vm_region_extended_info) / @sizeOf(natural_t);
        pub const TOP_INFO_COUNT: mach_msg_type_number_t = @sizeOf(vm_region_top_info) / @sizeOf(natural_t);
    };

    pub fn MAKE_TAG(tag: u8) u32 {
        return @as(u32, tag) << 24;
    }
};

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

pub const MATTR = struct {
    /// Cachability
    pub const CACHE = 1;
    /// Migrability
    pub const MIGRATE = 2;
    /// Replicability
    pub const REPLICATE = 4;
    /// (Generic) turn attribute off
    pub const VAL_OFF = 0;
    /// (Generic) turn attribute on
    pub const VAL_ON = 1;
    /// (Generic) return current value
    pub const VAL_GET = 2;
    /// Flush from all caches
    pub const VAL_CACHE_FLUSH = 6;
    /// Flush from data caches
    pub const VAL_DCACHE_FLUSH = 7;
    /// Flush from instruction caches
    pub const VAL_ICACHE_FLUSH = 8;
    /// Sync I+D caches
    pub const VAL_CACHE_SYNC = 9;
    /// Get page info (stats)
    pub const VAL_GET_INFO = 10;
};

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
    ARM_COLL = 0x2876f5b5,
    ARM_IBIZA = 0xfa33415e,
    ARM_LOBOS = 0x5f4dea93,
    ARM_PALMA = 0x72015832,
    ARM_DONAN = 0x6f5129ac,
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
