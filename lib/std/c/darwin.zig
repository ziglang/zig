const std = @import("../std.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const macho = std.macho;
const native_arch = builtin.target.cpu.arch;
const maxInt = std.math.maxInt;
const iovec_const = std.os.iovec_const;

pub const aarch64 = @import("darwin/aarch64.zig");
pub const x86_64 = @import("darwin/x86_64.zig");
pub const cssm = @import("darwin/cssm.zig");

const arch_bits = switch (native_arch) {
    .aarch64 => @import("darwin/aarch64.zig"),
    .x86_64 => @import("darwin/x86_64.zig"),
    else => struct {},
};

pub const EXC_TYPES_COUNT = arch_bits.EXC_TYPES_COUNT;
pub const THREAD_STATE_NONE = arch_bits.THREAD_STATE_NONE;

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
};

pub const EXC_SOFT_SIGNAL = 0x10003;

pub const EXC_MASK_BAD_ACCESS = 1 << @intFromEnum(EXC.BAD_ACCESS);
pub const EXC_MASK_BAD_INSTRUCTION = 1 << @intFromEnum(EXC.BAD_INSTRUCTION);
pub const EXC_MASK_ARITHMETIC = 1 << @intFromEnum(EXC.ARITHMETIC);
pub const EXC_MASK_EMULATION = 1 << @intFromEnum(EXC.EMULATION);
pub const EXC_MASK_SOFTWARE = 1 << @intFromEnum(EXC.SOFTWARE);
pub const EXC_MASK_BREAKPOINT = 1 << @intFromEnum(EXC.BREAKPOINT);
pub const EXC_MASK_SYSCALL = 1 << @intFromEnum(EXC.SYSCALL);
pub const EXC_MASK_MACH_SYSCALL = 1 << @intFromEnum(EXC.MACH_SYSCALL);
pub const EXC_MASK_RPC_ALERT = 1 << @intFromEnum(EXC.RPC_ALERT);
pub const EXC_MASK_CRASH = 1 << @intFromEnum(EXC.CRASH);
pub const EXC_MASK_RESOURCE = 1 << @intFromEnum(EXC.RESOURCE);
pub const EXC_MASK_GUARD = 1 << @intFromEnum(EXC.GUARD);
pub const EXC_MASK_CORPSE_NOTIFY = 1 << @intFromEnum(EXC.CORPSE_NOTIFY);
pub const EXC_MASK_MACHINE = arch_bits.EXC_MASK_MACHINE;

pub const EXC_MASK_ALL = EXC_MASK_BAD_ACCESS |
    EXC_MASK_BAD_INSTRUCTION |
    EXC_MASK_ARITHMETIC |
    EXC_MASK_EMULATION |
    EXC_MASK_SOFTWARE |
    EXC_MASK_BREAKPOINT |
    EXC_MASK_SYSCALL |
    EXC_MASK_MACH_SYSCALL |
    EXC_MASK_RPC_ALERT |
    EXC_MASK_RESOURCE |
    EXC_MASK_GUARD |
    EXC_MASK_MACHINE;

/// Send a catch_exception_raise message including the identity.
pub const EXCEPTION_DEFAULT = 1;
/// Send a catch_exception_raise_state message including the
/// thread state.
pub const EXCEPTION_STATE = 2;
/// Send a catch_exception_raise_state_identity message including
/// the thread identity and state.
pub const EXCEPTION_STATE_IDENTITY = 3;
/// Send a catch_exception_raise_identity_protected message including protected task
/// and thread identity.
pub const EXCEPTION_IDENTITY_PROTECTED = 4;
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

pub const ucontext_t = extern struct {
    onstack: c_int,
    sigmask: sigset_t,
    stack: stack_t,
    link: ?*ucontext_t,
    mcsize: u64,
    mcontext: *mcontext_t,
    __mcontext_data: mcontext_t,
};

pub const mcontext_t = arch_bits.mcontext_t;

extern "c" fn __error() *c_int;
pub extern "c" fn NSVersionOfRunTimeLibrary(library_name: [*:0]const u8) u32;
pub extern "c" fn _NSGetExecutablePath(buf: [*:0]u8, bufsize: *u32) c_int;
pub extern "c" fn _dyld_image_count() u32;
pub extern "c" fn _dyld_get_image_header(image_index: u32) ?*mach_header;
pub extern "c" fn _dyld_get_image_vmaddr_slide(image_index: u32) usize;
pub extern "c" fn _dyld_get_image_name(image_index: u32) [*:0]const u8;

pub const COPYFILE_ACL = 1 << 0;
pub const COPYFILE_STAT = 1 << 1;
pub const COPYFILE_XATTR = 1 << 2;
pub const COPYFILE_DATA = 1 << 3;

pub const copyfile_state_t = *opaque {};
pub extern "c" fn fcopyfile(from: fd_t, to: fd_t, state: ?copyfile_state_t, flags: u32) c_int;

pub extern "c" fn @"realpath$DARWIN_EXTSN"(noalias file_name: [*:0]const u8, noalias resolved_name: [*]u8) ?[*:0]u8;
pub const realpath = @"realpath$DARWIN_EXTSN";

pub extern "c" fn __getdirentries64(fd: c_int, buf_ptr: [*]u8, buf_len: usize, basep: *i64) isize;

const private = struct {
    extern "c" fn fstat(fd: fd_t, buf: *Stat) c_int;
    /// On x86_64 Darwin, fstat has to be manually linked with $INODE64 suffix to
    /// force 64bit version.
    /// Note that this is fixed on aarch64 and no longer necessary.
    extern "c" fn @"fstat$INODE64"(fd: fd_t, buf: *Stat) c_int;

    extern "c" fn fstatat(dirfd: fd_t, path: [*:0]const u8, stat_buf: *Stat, flags: u32) c_int;
    /// On x86_64 Darwin, fstatat has to be manually linked with $INODE64 suffix to
    /// force 64bit version.
    /// Note that this is fixed on aarch64 and no longer necessary.
    extern "c" fn @"fstatat$INODE64"(dirfd: fd_t, path_name: [*:0]const u8, buf: *Stat, flags: u32) c_int;

    extern "c" fn readdir(dir: *std.c.DIR) ?*dirent;
    extern "c" fn @"readdir$INODE64"(dir: *std.c.DIR) ?*dirent;
};
pub const fstat = if (native_arch == .aarch64) private.fstat else private.@"fstat$INODE64";
pub const fstatat = if (native_arch == .aarch64) private.fstatat else private.@"fstatat$INODE64";
pub const readdir = if (native_arch == .aarch64) private.readdir else private.@"readdir$INODE64";

pub extern "c" fn mach_absolute_time() u64;
pub extern "c" fn mach_continuous_time() u64;
pub extern "c" fn mach_timebase_info(tinfo: ?*mach_timebase_info_data) kern_return_t;

pub extern "c" fn malloc_size(?*const anyopaque) usize;
pub extern "c" fn posix_memalign(memptr: *?*anyopaque, alignment: usize, size: usize) c_int;

pub extern "c" fn kevent64(
    kq: c_int,
    changelist: [*]const kevent64_s,
    nchanges: c_int,
    eventlist: [*]kevent64_s,
    nevents: c_int,
    flags: c_uint,
    timeout: ?*const timespec,
) c_int;

const mach_hdr = if (@sizeOf(usize) == 8) mach_header_64 else mach_header;

/// The value of the link editor defined symbol _MH_EXECUTE_SYM is the address
/// of the mach header in a Mach-O executable file type.  It does not appear in
/// any file type other than a MH_EXECUTE file type.  The type of the symbol is
/// absolute as the header is not part of any section.
/// This symbol is populated when linking the system's libc, which is guaranteed
/// on this operating system. However when building object files or libraries,
/// the system libc won't be linked until the final executable. So we
/// export a weak symbol here, to be overridden by the real one.
var dummy_execute_header: mach_hdr = undefined;
pub extern var _mh_execute_header: mach_hdr;
comptime {
    if (builtin.target.isDarwin()) {
        @export(dummy_execute_header, .{ .name = "_mh_execute_header", .linkage = .Weak });
    }
}

pub const mach_header_64 = macho.mach_header_64;
pub const mach_header = macho.mach_header;

pub const _errno = __error;

pub extern "c" fn @"close$NOCANCEL"(fd: fd_t) c_int;
pub extern "c" fn mach_host_self() mach_port_t;
pub extern "c" fn clock_get_time(clock_serv: clock_serv_t, cur_time: *mach_timespec_t) kern_return_t;

pub const exception_type_t = c_int;
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

pub const sf_hdtr = extern struct {
    headers: [*]const iovec_const,
    hdr_cnt: c_int,
    trailers: [*]const iovec_const,
    trl_cnt: c_int,
};

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

pub extern "c" fn sigaltstack(ss: ?*stack_t, old_ss: ?*stack_t) c_int;

pub const IFNAMESIZE = 16;

pub const AI = struct {
    /// get address to use bind()
    pub const PASSIVE = 0x00000001;
    /// fill ai_canonname
    pub const CANONNAME = 0x00000002;
    /// prevent host name resolution
    pub const NUMERICHOST = 0x00000004;
    /// prevent service name resolution
    pub const NUMERICSERV = 0x00001000;
};

pub const EAI = enum(c_int) {
    /// address family for hostname not supported
    ADDRFAMILY = 1,

    /// temporary failure in name resolution
    AGAIN = 2,

    /// invalid value for ai_flags
    BADFLAGS = 3,

    /// non-recoverable failure in name resolution
    FAIL = 4,

    /// ai_family not supported
    FAMILY = 5,

    /// memory allocation failure
    MEMORY = 6,

    /// no address associated with hostname
    NODATA = 7,

    /// hostname nor servname provided, or not known
    NONAME = 8,

    /// servname not supported for ai_socktype
    SERVICE = 9,

    /// ai_socktype not supported
    SOCKTYPE = 10,

    /// system error returned in errno
    SYSTEM = 11,

    /// invalid value for hints
    BADHINTS = 12,

    /// resolved protocol is unknown
    PROTOCOL = 13,

    /// argument buffer overflow
    OVERFLOW = 14,

    _,
};

pub const EAI_MAX = 15;

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

pub const pthread_mutex_t = extern struct {
    __sig: c_long = 0x32AAABA7,
    __opaque: [__PTHREAD_MUTEX_SIZE__]u8 = [_]u8{0} ** __PTHREAD_MUTEX_SIZE__,
};
pub const pthread_cond_t = extern struct {
    __sig: c_long = 0x3CB0B1BB,
    __opaque: [__PTHREAD_COND_SIZE__]u8 = [_]u8{0} ** __PTHREAD_COND_SIZE__,
};
pub const pthread_rwlock_t = extern struct {
    __sig: c_long = 0x2DA8B3B4,
    __opaque: [192]u8 = [_]u8{0} ** 192,
};
pub const sem_t = c_int;
const __PTHREAD_MUTEX_SIZE__ = if (@sizeOf(usize) == 8) 56 else 40;
const __PTHREAD_COND_SIZE__ = if (@sizeOf(usize) == 8) 40 else 24;

pub const pthread_attr_t = extern struct {
    __sig: c_long,
    __opaque: [56]u8,
};

pub extern "c" fn pthread_threadid_np(thread: ?std.c.pthread_t, thread_id: *u64) c_int;
pub extern "c" fn pthread_setname_np(name: [*:0]const u8) E;
pub extern "c" fn pthread_getname_np(thread: std.c.pthread_t, name: [*:0]u8, len: usize) E;
pub extern "c" fn pthread_attr_set_qos_class_np(attr: *pthread_attr_t, qos_class: qos_class_t, relative_priority: c_int) c_int;
pub extern "c" fn pthread_attr_get_qos_class_np(attr: *pthread_attr_t, qos_class: *qos_class_t, relative_priority: *c_int) c_int;
pub extern "c" fn pthread_set_qos_class_self_np(qos_class: qos_class_t, relative_priority: c_int) c_int;
pub extern "c" fn pthread_get_qos_class_np(pthread: std.c.pthread_t, qos_class: *qos_class_t, relative_priority: *c_int) c_int;

pub extern "c" fn arc4random_buf(buf: [*]u8, len: usize) void;

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

// Undocumented futex-like API available on darwin 16+
// (macOS 10.12+, iOS 10.0+, tvOS 10.0+, watchOS 3.0+, catalyst 13.0+).
//
// [ulock.h]: https://github.com/apple/darwin-xnu/blob/master/bsd/sys/ulock.h
// [sys_ulock.c]: https://github.com/apple/darwin-xnu/blob/master/bsd/kern/sys_ulock.c

pub const UL_COMPARE_AND_WAIT = 1;
pub const UL_UNFAIR_LOCK = 2;

// Obsolete/deprecated
pub const UL_OSSPINLOCK = UL_COMPARE_AND_WAIT;
pub const UL_HANDOFFLOCK = UL_UNFAIR_LOCK;

pub const ULF_WAKE_ALL = 0x100;
pub const ULF_WAKE_THREAD = 0x200;
pub const ULF_WAIT_WORKQ_DATA_CONTENTION = 0x10000;
pub const ULF_WAIT_CANCEL_POINT = 0x20000;
pub const ULF_NO_ERRNO = 0x1000000;

// The following are only supported on darwin 19+
// (macOS 10.15+, iOS 13.0+)
pub const UL_COMPARE_AND_WAIT_SHARED = 3;
pub const UL_UNFAIR_LOCK64_SHARED = 4;
pub const UL_COMPARE_AND_WAIT64 = 5;
pub const UL_COMPARE_AND_WAIT64_SHARED = 6;
pub const ULF_WAIT_ADAPTIVE_SPIN = 0x40000;

pub extern "c" fn __ulock_wait2(op: u32, addr: ?*const anyopaque, val: u64, timeout_ns: u64, val2: u64) c_int;
pub extern "c" fn __ulock_wait(op: u32, addr: ?*const anyopaque, val: u64, timeout_us: u32) c_int;
pub extern "c" fn __ulock_wake(op: u32, addr: ?*const anyopaque, val: u64) c_int;

pub const OS_UNFAIR_LOCK_INIT = os_unfair_lock{};
pub const os_unfair_lock_t = *os_unfair_lock;
pub const os_unfair_lock = extern struct {
    _os_unfair_lock_opaque: u32 = 0,
};

pub extern "c" fn os_unfair_lock_lock(o: os_unfair_lock_t) void;
pub extern "c" fn os_unfair_lock_unlock(o: os_unfair_lock_t) void;
pub extern "c" fn os_unfair_lock_trylock(o: os_unfair_lock_t) bool;
pub extern "c" fn os_unfair_lock_assert_owner(o: os_unfair_lock_t) void;
pub extern "c" fn os_unfair_lock_assert_not_owner(o: os_unfair_lock_t) void;

// XXX: close -> close$NOCANCEL
// XXX: getdirentries -> _getdirentries64

// See: https://opensource.apple.com/source/xnu/xnu-6153.141.1/bsd/sys/_types.h.auto.html
// TODO: audit mode_t/pid_t, should likely be u16/i32
pub const blkcnt_t = i64;
pub const blksize_t = i32;
pub const dev_t = i32;
pub const fd_t = c_int;
pub const pid_t = c_int;
pub const mode_t = c_uint;
pub const uid_t = u32;
pub const gid_t = u32;

// machine/_types.h
pub const clock_t = c_ulong;
pub const time_t = c_long;

pub const in_port_t = u16;
pub const sa_family_t = u8;
pub const socklen_t = u32;
pub const sockaddr = extern struct {
    len: u8,
    family: sa_family_t,
    data: [14]u8,

    pub const SS_MAXSIZE = 128;
    pub const storage = extern struct {
        len: u8 align(8),
        family: sa_family_t,
        padding: [126]u8 = undefined,

        comptime {
            assert(@sizeOf(storage) == SS_MAXSIZE);
            assert(@alignOf(storage) == 8);
        }
    };
    pub const in = extern struct {
        len: u8 = @sizeOf(in),
        family: sa_family_t = AF.INET,
        port: in_port_t,
        addr: u32,
        zero: [8]u8 = [8]u8{ 0, 0, 0, 0, 0, 0, 0, 0 },
    };
    pub const in6 = extern struct {
        len: u8 = @sizeOf(in6),
        family: sa_family_t = AF.INET6,
        port: in_port_t,
        flowinfo: u32,
        addr: [16]u8,
        scope_id: u32,
    };

    /// UNIX domain socket
    pub const un = extern struct {
        len: u8 = @sizeOf(un),
        family: sa_family_t = AF.UNIX,
        path: [104]u8,
    };
};
pub const timeval = extern struct {
    tv_sec: c_long,
    tv_usec: i32,
};

pub const timezone = extern struct {
    tz_minuteswest: i32,
    tz_dsttime: i32,
};

pub const mach_timebase_info_data = extern struct {
    numer: u32,
    denom: u32,
};

pub const off_t = i64;
pub const ino_t = u64;

pub const Flock = extern struct {
    start: off_t,
    len: off_t,
    pid: pid_t,
    type: i16,
    whence: i16,
};

pub const Stat = extern struct {
    dev: i32,
    mode: u16,
    nlink: u16,
    ino: ino_t,
    uid: uid_t,
    gid: gid_t,
    rdev: i32,
    atimespec: timespec,
    mtimespec: timespec,
    ctimespec: timespec,
    birthtimespec: timespec,
    size: off_t,
    blocks: i64,
    blksize: i32,
    flags: u32,
    gen: u32,
    lspare: i32,
    qspare: [2]i64,

    pub fn atime(self: @This()) timespec {
        return self.atimespec;
    }

    pub fn mtime(self: @This()) timespec {
        return self.mtimespec;
    }

    pub fn ctime(self: @This()) timespec {
        return self.ctimespec;
    }

    pub fn birthtime(self: @This()) timespec {
        return self.birthtimespec;
    }
};

pub const timespec = extern struct {
    tv_sec: isize,
    tv_nsec: isize,
};

pub const sigset_t = u32;
pub const empty_sigset: sigset_t = 0;

pub const SIG = struct {
    pub const ERR = @as(?Sigaction.handler_fn, @ptrFromInt(maxInt(usize)));
    pub const DFL = @as(?Sigaction.handler_fn, @ptrFromInt(0));
    pub const IGN = @as(?Sigaction.handler_fn, @ptrFromInt(1));
    pub const HOLD = @as(?Sigaction.handler_fn, @ptrFromInt(5));

    /// block specified signal set
    pub const BLOCK = 1;
    /// unblock specified signal set
    pub const UNBLOCK = 2;
    /// set specified signal set
    pub const SETMASK = 3;
    /// hangup
    pub const HUP = 1;
    /// interrupt
    pub const INT = 2;
    /// quit
    pub const QUIT = 3;
    /// illegal instruction (not reset when caught)
    pub const ILL = 4;
    /// trace trap (not reset when caught)
    pub const TRAP = 5;
    /// abort()
    pub const ABRT = 6;
    /// pollable event ([XSR] generated, not supported)
    pub const POLL = 7;
    /// compatibility
    pub const IOT = ABRT;
    /// EMT instruction
    pub const EMT = 7;
    /// floating point exception
    pub const FPE = 8;
    /// kill (cannot be caught or ignored)
    pub const KILL = 9;
    /// bus error
    pub const BUS = 10;
    /// segmentation violation
    pub const SEGV = 11;
    /// bad argument to system call
    pub const SYS = 12;
    /// write on a pipe with no one to read it
    pub const PIPE = 13;
    /// alarm clock
    pub const ALRM = 14;
    /// software termination signal from kill
    pub const TERM = 15;
    /// urgent condition on IO channel
    pub const URG = 16;
    /// sendable stop signal not from tty
    pub const STOP = 17;
    /// stop signal from tty
    pub const TSTP = 18;
    /// continue a stopped process
    pub const CONT = 19;
    /// to parent on child stop or exit
    pub const CHLD = 20;
    /// to readers pgrp upon background tty read
    pub const TTIN = 21;
    /// like TTIN for output if (tp->t_local&LTOSTOP)
    pub const TTOU = 22;
    /// input/output possible signal
    pub const IO = 23;
    /// exceeded CPU time limit
    pub const XCPU = 24;
    /// exceeded file size limit
    pub const XFSZ = 25;
    /// virtual time alarm
    pub const VTALRM = 26;
    /// profiling time alarm
    pub const PROF = 27;
    /// window size changes
    pub const WINCH = 28;
    /// information request
    pub const INFO = 29;
    /// user defined signal 1
    pub const USR1 = 30;
    /// user defined signal 2
    pub const USR2 = 31;
};

pub const siginfo_t = extern struct {
    signo: c_int,
    errno: c_int,
    code: c_int,
    pid: pid_t,
    uid: uid_t,
    status: c_int,
    addr: *anyopaque,
    value: extern union {
        int: c_int,
        ptr: *anyopaque,
    },
    si_band: c_long,
    _pad: [7]c_ulong,
};

/// Renamed from `sigaction` to `Sigaction` to avoid conflict with function name.
pub const Sigaction = extern struct {
    pub const handler_fn = *const fn (c_int) align(1) callconv(.C) void;
    pub const sigaction_fn = *const fn (c_int, *const siginfo_t, ?*const anyopaque) callconv(.C) void;

    handler: extern union {
        handler: ?handler_fn,
        sigaction: ?sigaction_fn,
    },
    mask: sigset_t,
    flags: c_uint,
};

pub const dirent = extern struct {
    d_ino: u64,
    d_seekoff: u64,
    d_reclen: u16,
    d_namlen: u16,
    d_type: u8,
    d_name: [1024]u8,

    pub fn reclen(self: dirent) u16 {
        return self.d_reclen;
    }
};

/// Renamed from `kevent` to `Kevent` to avoid conflict with function name.
pub const Kevent = extern struct {
    ident: usize,
    filter: i16,
    flags: u16,
    fflags: u32,
    data: isize,
    udata: usize,
};

// sys/types.h on macos uses #pragma pack(4) so these checks are
// to make sure the struct is laid out the same. These values were
// produced from C code using the offsetof macro.
comptime {
    if (builtin.target.isDarwin()) {
        assert(@offsetOf(Kevent, "ident") == 0);
        assert(@offsetOf(Kevent, "filter") == 8);
        assert(@offsetOf(Kevent, "flags") == 10);
        assert(@offsetOf(Kevent, "fflags") == 12);
        assert(@offsetOf(Kevent, "data") == 16);
        assert(@offsetOf(Kevent, "udata") == 24);
    }
}

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

pub const mach_port_t = c_uint;
pub const clock_serv_t = mach_port_t;
pub const clock_res_t = c_int;
pub const mach_port_name_t = natural_t;
pub const natural_t = c_uint;
pub const mach_timespec_t = extern struct {
    tv_sec: c_uint,
    tv_nsec: clock_res_t,
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

pub const PATH_MAX = 1024;
pub const NAME_MAX = 255;
pub const IOV_MAX = 16;

pub const STDIN_FILENO = 0;
pub const STDOUT_FILENO = 1;
pub const STDERR_FILENO = 2;

pub const PROT = struct {
    /// [MC2] no permissions
    pub const NONE: vm_prot_t = 0x00;
    /// [MC2] pages can be read
    pub const READ: vm_prot_t = 0x01;
    /// [MC2] pages can be written
    pub const WRITE: vm_prot_t = 0x02;
    /// [MC2] pages can be executed
    pub const EXEC: vm_prot_t = 0x04;
    /// When a caller finds that they cannot obtain write permission on a
    /// mapped entry, the following flag can be used. The entry will be
    /// made "needs copy" effectively copying the object (using COW),
    /// and write permission will be added to the maximum protections for
    /// the associated entry.
    pub const COPY: vm_prot_t = 0x10;
};

pub const MAP = struct {
    /// allocated from memory, swap space
    pub const ANONYMOUS = 0x1000;
    /// map from file (default)
    pub const FILE = 0x0000;
    /// interpret addr exactly
    pub const FIXED = 0x0010;
    /// region may contain semaphores
    pub const HASSEMAPHORE = 0x0200;
    /// changes are private
    pub const PRIVATE = 0x0002;
    /// share changes
    pub const SHARED = 0x0001;
    /// don't cache pages for this mapping
    pub const NOCACHE = 0x0400;
    /// don't reserve needed swap area
    pub const NORESERVE = 0x0040;
    pub const FAILED = @as(*anyopaque, @ptrFromInt(maxInt(usize)));
};

pub const MSF = struct {
    pub const ASYNC = 0x1;
    pub const INVALIDATE = 0x2;
    // invalidate, leave mapped
    pub const KILLPAGES = 0x4;
    // deactivate, leave mapped
    pub const DEACTIVATE = 0x8;
    pub const SYNC = 0x10;
};

pub const SA = struct {
    /// take signal on signal stack
    pub const ONSTACK = 0x0001;
    /// restart system on signal return
    pub const RESTART = 0x0002;
    /// reset to SIG.DFL when taking signal
    pub const RESETHAND = 0x0004;
    /// do not generate SIG.CHLD on child stop
    pub const NOCLDSTOP = 0x0008;
    /// don't mask the signal we're delivering
    pub const NODEFER = 0x0010;
    /// don't keep zombies around
    pub const NOCLDWAIT = 0x0020;
    /// signal handler with SIGINFO args
    pub const SIGINFO = 0x0040;
    /// do not bounce off kernel's sigtramp
    pub const USERTRAMP = 0x0100;
    /// signal handler with SIGINFO args with 64bit regs information
    pub const @"64REGSET" = 0x0200;
};

pub const F_OK = 0;
pub const X_OK = 1;
pub const W_OK = 2;
pub const R_OK = 4;

pub const O = struct {
    pub const PATH = 0x0000;
    /// open for reading only
    pub const RDONLY = 0x0000;
    /// open for writing only
    pub const WRONLY = 0x0001;
    /// open for reading and writing
    pub const RDWR = 0x0002;
    /// do not block on open or for data to become available
    pub const NONBLOCK = 0x0004;
    /// append on each write
    pub const APPEND = 0x0008;
    /// create file if it does not exist
    pub const CREAT = 0x0200;
    /// truncate size to 0
    pub const TRUNC = 0x0400;
    /// error if CREAT and the file exists
    pub const EXCL = 0x0800;
    /// atomically obtain a shared lock
    pub const SHLOCK = 0x0010;
    /// atomically obtain an exclusive lock
    pub const EXLOCK = 0x0020;
    /// do not follow symlinks
    pub const NOFOLLOW = 0x0100;
    /// allow open of symlinks
    pub const SYMLINK = 0x200000;
    /// descriptor requested for event notifications only
    pub const EVTONLY = 0x8000;
    /// mark as close-on-exec
    pub const CLOEXEC = 0x1000000;
    pub const ACCMODE = 3;
    pub const ALERT = 536870912;
    pub const ASYNC = 64;
    pub const DIRECTORY = 1048576;
    pub const DP_GETRAWENCRYPTED = 1;
    pub const DP_GETRAWUNENCRYPTED = 2;
    pub const DSYNC = 4194304;
    pub const FSYNC = SYNC;
    pub const NOCTTY = 131072;
    pub const POPUP = 2147483648;
    pub const SYNC = 128;
};

pub const SEEK = struct {
    pub const SET = 0x0;
    pub const CUR = 0x1;
    pub const END = 0x2;
};

pub const DT = struct {
    pub const UNKNOWN = 0;
    pub const FIFO = 1;
    pub const CHR = 2;
    pub const DIR = 4;
    pub const BLK = 6;
    pub const REG = 8;
    pub const LNK = 10;
    pub const SOCK = 12;
    pub const WHT = 14;
};

/// no flag value
pub const KEVENT_FLAG_NONE = 0x000;

/// immediate timeout
pub const KEVENT_FLAG_IMMEDIATE = 0x001;

/// output events only include change
pub const KEVENT_FLAG_ERROR_EVENTS = 0x002;

/// add event to kq (implies enable)
pub const EV_ADD = 0x0001;

/// delete event from kq
pub const EV_DELETE = 0x0002;

/// enable event
pub const EV_ENABLE = 0x0004;

/// disable event (not reported)
pub const EV_DISABLE = 0x0008;

/// only report one occurrence
pub const EV_ONESHOT = 0x0010;

/// clear event state after reporting
pub const EV_CLEAR = 0x0020;

/// force immediate event output
/// ... with or without EV_ERROR
/// ... use KEVENT_FLAG_ERROR_EVENTS
///     on syscalls supporting flags
pub const EV_RECEIPT = 0x0040;

/// disable event after reporting
pub const EV_DISPATCH = 0x0080;

/// unique kevent per udata value
pub const EV_UDATA_SPECIFIC = 0x0100;

/// ... in combination with EV_DELETE
/// will defer delete until udata-specific
/// event enabled. EINPROGRESS will be
/// returned to indicate the deferral
pub const EV_DISPATCH2 = EV_DISPATCH | EV_UDATA_SPECIFIC;

/// report that source has vanished
/// ... only valid with EV_DISPATCH2
pub const EV_VANISHED = 0x0200;

/// reserved by system
pub const EV_SYSFLAGS = 0xF000;

/// filter-specific flag
pub const EV_FLAG0 = 0x1000;

/// filter-specific flag
pub const EV_FLAG1 = 0x2000;

/// EOF detected
pub const EV_EOF = 0x8000;

/// error, data contains errno
pub const EV_ERROR = 0x4000;

pub const EV_POLL = EV_FLAG0;
pub const EV_OOBAND = EV_FLAG1;

pub const EVFILT_READ = -1;
pub const EVFILT_WRITE = -2;

/// attached to aio requests
pub const EVFILT_AIO = -3;

/// attached to vnodes
pub const EVFILT_VNODE = -4;

/// attached to struct proc
pub const EVFILT_PROC = -5;

/// attached to struct proc
pub const EVFILT_SIGNAL = -6;

/// timers
pub const EVFILT_TIMER = -7;

/// Mach portsets
pub const EVFILT_MACHPORT = -8;

/// Filesystem events
pub const EVFILT_FS = -9;

/// User events
pub const EVFILT_USER = -10;

/// Virtual memory events
pub const EVFILT_VM = -12;

/// Exception events
pub const EVFILT_EXCEPT = -15;

pub const EVFILT_SYSCOUNT = 17;

/// On input, NOTE_TRIGGER causes the event to be triggered for output.
pub const NOTE_TRIGGER = 0x01000000;

/// ignore input fflags
pub const NOTE_FFNOP = 0x00000000;

/// and fflags
pub const NOTE_FFAND = 0x40000000;

/// or fflags
pub const NOTE_FFOR = 0x80000000;

/// copy fflags
pub const NOTE_FFCOPY = 0xc0000000;

/// mask for operations
pub const NOTE_FFCTRLMASK = 0xc0000000;
pub const NOTE_FFLAGSMASK = 0x00ffffff;

/// low water mark
pub const NOTE_LOWAT = 0x00000001;

/// OOB data
pub const NOTE_OOB = 0x00000002;

/// vnode was removed
pub const NOTE_DELETE = 0x00000001;

/// data contents changed
pub const NOTE_WRITE = 0x00000002;

/// size increased
pub const NOTE_EXTEND = 0x00000004;

/// attributes changed
pub const NOTE_ATTRIB = 0x00000008;

/// link count changed
pub const NOTE_LINK = 0x00000010;

/// vnode was renamed
pub const NOTE_RENAME = 0x00000020;

/// vnode access was revoked
pub const NOTE_REVOKE = 0x00000040;

/// No specific vnode event: to test for EVFILT_READ      activation
pub const NOTE_NONE = 0x00000080;

/// vnode was unlocked by flock(2)
pub const NOTE_FUNLOCK = 0x00000100;

/// process exited
pub const NOTE_EXIT = 0x80000000;

/// process forked
pub const NOTE_FORK = 0x40000000;

/// process exec'd
pub const NOTE_EXEC = 0x20000000;

/// shared with EVFILT_SIGNAL
pub const NOTE_SIGNAL = 0x08000000;

/// exit status to be returned, valid for child       process only
pub const NOTE_EXITSTATUS = 0x04000000;

/// provide details on reasons for exit
pub const NOTE_EXIT_DETAIL = 0x02000000;

/// mask for signal & exit status
pub const NOTE_PDATAMASK = 0x000fffff;
pub const NOTE_PCTRLMASK = (~NOTE_PDATAMASK);

pub const NOTE_EXIT_DETAIL_MASK = 0x00070000;
pub const NOTE_EXIT_DECRYPTFAIL = 0x00010000;
pub const NOTE_EXIT_MEMORY = 0x00020000;
pub const NOTE_EXIT_CSERROR = 0x00040000;

/// will react on memory          pressure
pub const NOTE_VM_PRESSURE = 0x80000000;

/// will quit on memory       pressure, possibly after cleaning up dirty state
pub const NOTE_VM_PRESSURE_TERMINATE = 0x40000000;

/// will quit immediately on      memory pressure
pub const NOTE_VM_PRESSURE_SUDDEN_TERMINATE = 0x20000000;

/// there was an error
pub const NOTE_VM_ERROR = 0x10000000;

/// data is seconds
pub const NOTE_SECONDS = 0x00000001;

/// data is microseconds
pub const NOTE_USECONDS = 0x00000002;

/// data is nanoseconds
pub const NOTE_NSECONDS = 0x00000004;

/// absolute timeout
pub const NOTE_ABSOLUTE = 0x00000008;

/// ext[1] holds leeway for power aware timers
pub const NOTE_LEEWAY = 0x00000010;

/// system does minimal timer coalescing
pub const NOTE_CRITICAL = 0x00000020;

/// system does maximum timer coalescing
pub const NOTE_BACKGROUND = 0x00000040;
pub const NOTE_MACH_CONTINUOUS_TIME = 0x00000080;

/// data is mach absolute time units
pub const NOTE_MACHTIME = 0x00000100;

pub const AF = struct {
    pub const UNSPEC = 0;
    pub const LOCAL = 1;
    pub const UNIX = LOCAL;
    pub const INET = 2;
    pub const SYS_CONTROL = 2;
    pub const IMPLINK = 3;
    pub const PUP = 4;
    pub const CHAOS = 5;
    pub const NS = 6;
    pub const ISO = 7;
    pub const OSI = ISO;
    pub const ECMA = 8;
    pub const DATAKIT = 9;
    pub const CCITT = 10;
    pub const SNA = 11;
    pub const DECnet = 12;
    pub const DLI = 13;
    pub const LAT = 14;
    pub const HYLINK = 15;
    pub const APPLETALK = 16;
    pub const ROUTE = 17;
    pub const LINK = 18;
    pub const XTP = 19;
    pub const COIP = 20;
    pub const CNT = 21;
    pub const RTIP = 22;
    pub const IPX = 23;
    pub const SIP = 24;
    pub const PIP = 25;
    pub const ISDN = 28;
    pub const E164 = ISDN;
    pub const KEY = 29;
    pub const INET6 = 30;
    pub const NATM = 31;
    pub const SYSTEM = 32;
    pub const NETBIOS = 33;
    pub const PPP = 34;
    pub const MAX = 40;
};

pub const PF = struct {
    pub const UNSPEC = AF.UNSPEC;
    pub const LOCAL = AF.LOCAL;
    pub const UNIX = PF.LOCAL;
    pub const INET = AF.INET;
    pub const IMPLINK = AF.IMPLINK;
    pub const PUP = AF.PUP;
    pub const CHAOS = AF.CHAOS;
    pub const NS = AF.NS;
    pub const ISO = AF.ISO;
    pub const OSI = AF.ISO;
    pub const ECMA = AF.ECMA;
    pub const DATAKIT = AF.DATAKIT;
    pub const CCITT = AF.CCITT;
    pub const SNA = AF.SNA;
    pub const DECnet = AF.DECnet;
    pub const DLI = AF.DLI;
    pub const LAT = AF.LAT;
    pub const HYLINK = AF.HYLINK;
    pub const APPLETALK = AF.APPLETALK;
    pub const ROUTE = AF.ROUTE;
    pub const LINK = AF.LINK;
    pub const XTP = AF.XTP;
    pub const COIP = AF.COIP;
    pub const CNT = AF.CNT;
    pub const SIP = AF.SIP;
    pub const IPX = AF.IPX;
    pub const RTIP = AF.RTIP;
    pub const PIP = AF.PIP;
    pub const ISDN = AF.ISDN;
    pub const KEY = AF.KEY;
    pub const INET6 = AF.INET6;
    pub const NATM = AF.NATM;
    pub const SYSTEM = AF.SYSTEM;
    pub const NETBIOS = AF.NETBIOS;
    pub const PPP = AF.PPP;
    pub const MAX = AF.MAX;
};

pub const SYSPROTO_EVENT = 1;
pub const SYSPROTO_CONTROL = 2;

pub const SOCK = struct {
    pub const STREAM = 1;
    pub const DGRAM = 2;
    pub const RAW = 3;
    pub const RDM = 4;
    pub const SEQPACKET = 5;
    pub const MAXADDRLEN = 255;

    /// Not actually supported by Darwin, but Zig supplies a shim.
    /// This numerical value is not ABI-stable. It need only not conflict
    /// with any other `SOCK` bits.
    pub const CLOEXEC = 1 << 15;
    /// Not actually supported by Darwin, but Zig supplies a shim.
    /// This numerical value is not ABI-stable. It need only not conflict
    /// with any other `SOCK` bits.
    pub const NONBLOCK = 1 << 16;
};

pub const IPPROTO = struct {
    pub const ICMP = 1;
    pub const ICMPV6 = 58;
    pub const TCP = 6;
    pub const UDP = 17;
    pub const IP = 0;
    pub const IPV6 = 41;
};

pub const SOL = struct {
    pub const SOCKET = 0xffff;
};

pub const SO = struct {
    pub const DEBUG = 0x0001;
    pub const ACCEPTCONN = 0x0002;
    pub const REUSEADDR = 0x0004;
    pub const KEEPALIVE = 0x0008;
    pub const DONTROUTE = 0x0010;
    pub const BROADCAST = 0x0020;
    pub const USELOOPBACK = 0x0040;
    pub const LINGER = 0x1080;
    pub const OOBINLINE = 0x0100;
    pub const REUSEPORT = 0x0200;
    pub const ACCEPTFILTER = 0x1000;
    pub const SNDBUF = 0x1001;
    pub const RCVBUF = 0x1002;
    pub const SNDLOWAT = 0x1003;
    pub const RCVLOWAT = 0x1004;
    pub const SNDTIMEO = 0x1005;
    pub const RCVTIMEO = 0x1006;
    pub const ERROR = 0x1007;
    pub const TYPE = 0x1008;

    pub const NREAD = 0x1020;
    pub const NKE = 0x1021;
    pub const NOSIGPIPE = 0x1022;
    pub const NOADDRERR = 0x1023;
    pub const NWRITE = 0x1024;
    pub const REUSESHAREUID = 0x1025;
};

pub const W = struct {
    /// [XSI] no hang in wait/no child to reap
    pub const NOHANG = 0x00000001;
    /// [XSI] notify on stop, untraced child
    pub const UNTRACED = 0x00000002;

    pub fn EXITSTATUS(x: u32) u8 {
        return @as(u8, @intCast(x >> 8));
    }
    pub fn TERMSIG(x: u32) u32 {
        return status(x);
    }
    pub fn STOPSIG(x: u32) u32 {
        return x >> 8;
    }
    pub fn IFEXITED(x: u32) bool {
        return status(x) == 0;
    }
    pub fn IFSTOPPED(x: u32) bool {
        return status(x) == stopped and STOPSIG(x) != 0x13;
    }
    pub fn IFSIGNALED(x: u32) bool {
        return status(x) != stopped and status(x) != 0;
    }

    fn status(x: u32) u32 {
        return x & 0o177;
    }
    const stopped = 0o177;
};

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

pub const SIGSTKSZ = 131072;
pub const MINSIGSTKSZ = 32768;

pub const SS_ONSTACK = 1;
pub const SS_DISABLE = 4;

pub const stack_t = extern struct {
    sp: [*]u8,
    size: isize,
    flags: i32,
};

pub const S = struct {
    pub const IFMT = 0o170000;

    pub const IFIFO = 0o010000;
    pub const IFCHR = 0o020000;
    pub const IFDIR = 0o040000;
    pub const IFBLK = 0o060000;
    pub const IFREG = 0o100000;
    pub const IFLNK = 0o120000;
    pub const IFSOCK = 0o140000;
    pub const IFWHT = 0o160000;

    pub const ISUID = 0o4000;
    pub const ISGID = 0o2000;
    pub const ISVTX = 0o1000;
    pub const IRWXU = 0o700;
    pub const IRUSR = 0o400;
    pub const IWUSR = 0o200;
    pub const IXUSR = 0o100;
    pub const IRWXG = 0o070;
    pub const IRGRP = 0o040;
    pub const IWGRP = 0o020;
    pub const IXGRP = 0o010;
    pub const IRWXO = 0o007;
    pub const IROTH = 0o004;
    pub const IWOTH = 0o002;
    pub const IXOTH = 0o001;

    pub fn ISFIFO(m: u32) bool {
        return m & IFMT == IFIFO;
    }

    pub fn ISCHR(m: u32) bool {
        return m & IFMT == IFCHR;
    }

    pub fn ISDIR(m: u32) bool {
        return m & IFMT == IFDIR;
    }

    pub fn ISBLK(m: u32) bool {
        return m & IFMT == IFBLK;
    }

    pub fn ISREG(m: u32) bool {
        return m & IFMT == IFREG;
    }

    pub fn ISLNK(m: u32) bool {
        return m & IFMT == IFLNK;
    }

    pub fn ISSOCK(m: u32) bool {
        return m & IFMT == IFSOCK;
    }

    pub fn IWHT(m: u32) bool {
        return m & IFMT == IFWHT;
    }
};

pub const HOST_NAME_MAX = 72;

pub const AT = struct {
    pub const FDCWD = -2;
    /// Use effective ids in access check
    pub const EACCESS = 0x0010;
    /// Act on the symlink itself not the target
    pub const SYMLINK_NOFOLLOW = 0x0020;
    /// Act on target of symlink
    pub const SYMLINK_FOLLOW = 0x0040;
    /// Path refers to directory
    pub const REMOVEDIR = 0x0080;
};

pub const addrinfo = extern struct {
    flags: i32,
    family: i32,
    socktype: i32,
    protocol: i32,
    addrlen: socklen_t,
    canonname: ?[*:0]u8,
    addr: ?*sockaddr,
    next: ?*addrinfo,
};

pub const RTLD = struct {
    pub const LAZY = 0x1;
    pub const NOW = 0x2;
    pub const LOCAL = 0x4;
    pub const GLOBAL = 0x8;
    pub const NOLOAD = 0x10;
    pub const NODELETE = 0x80;
    pub const FIRST = 0x100;

    pub const NEXT = @as(*anyopaque, @ptrFromInt(@as(usize, @bitCast(@as(isize, -1)))));
    pub const DEFAULT = @as(*anyopaque, @ptrFromInt(@as(usize, @bitCast(@as(isize, -2)))));
    pub const SELF = @as(*anyopaque, @ptrFromInt(@as(usize, @bitCast(@as(isize, -3)))));
    pub const MAIN_ONLY = @as(*anyopaque, @ptrFromInt(@as(usize, @bitCast(@as(isize, -5)))));
};

pub const F = struct {
    /// duplicate file descriptor
    pub const DUPFD = 0;
    /// get file descriptor flags
    pub const GETFD = 1;
    /// set file descriptor flags
    pub const SETFD = 2;
    /// get file status flags
    pub const GETFL = 3;
    /// set file status flags
    pub const SETFL = 4;
    /// get SIGIO/SIGURG proc/pgrp
    pub const GETOWN = 5;
    /// set SIGIO/SIGURG proc/pgrp
    pub const SETOWN = 6;
    /// get record locking information
    pub const GETLK = 7;
    /// set record locking information
    pub const SETLK = 8;
    /// F.SETLK; wait if blocked
    pub const SETLKW = 9;
    /// F.SETLK; wait if blocked, return on timeout
    pub const SETLKWTIMEOUT = 10;
    pub const FLUSH_DATA = 40;
    /// Used for regression test
    pub const CHKCLEAN = 41;
    /// Preallocate storage
    pub const PREALLOCATE = 42;
    /// Truncate a file without zeroing space
    pub const SETSIZE = 43;
    /// Issue an advisory read async with no copy to user
    pub const RDADVISE = 44;
    /// turn read ahead off/on for this fd
    pub const RDAHEAD = 45;
    /// turn data caching off/on for this fd
    pub const NOCACHE = 48;
    /// file offset to device offset
    pub const LOG2PHYS = 49;
    /// return the full path of the fd
    pub const GETPATH = 50;
    /// fsync + ask the drive to flush to the media
    pub const FULLFSYNC = 51;
    /// find which component (if any) is a package
    pub const PATHPKG_CHECK = 52;
    /// "freeze" all fs operations
    pub const FREEZE_FS = 53;
    /// "thaw" all fs operations
    pub const THAW_FS = 54;
    /// turn data caching off/on (globally) for this file
    pub const GLOBAL_NOCACHE = 55;
    /// add detached signatures
    pub const ADDSIGS = 59;
    /// add signature from same file (used by dyld for shared libs)
    pub const ADDFILESIGS = 61;
    /// used in conjunction with F.NOCACHE to indicate that DIRECT, synchronous writes
    /// should not be used (i.e. its ok to temporaily create cached pages)
    pub const NODIRECT = 62;
    ///Get the protection class of a file from the EA, returns int
    pub const GETPROTECTIONCLASS = 63;
    ///Set the protection class of a file for the EA, requires int
    pub const SETPROTECTIONCLASS = 64;
    ///file offset to device offset, extended
    pub const LOG2PHYS_EXT = 65;
    ///get record locking information, per-process
    pub const GETLKPID = 66;
    ///Mark the file as being the backing store for another filesystem
    pub const SETBACKINGSTORE = 70;
    ///return the full path of the FD, but error in specific mtmd circumstances
    pub const GETPATH_MTMINFO = 71;
    ///Returns the code directory, with associated hashes, to the caller
    pub const GETCODEDIR = 72;
    ///No SIGPIPE generated on EPIPE
    pub const SETNOSIGPIPE = 73;
    ///Status of SIGPIPE for this fd
    pub const GETNOSIGPIPE = 74;
    ///For some cases, we need to rewrap the key for AKS/MKB
    pub const TRANSCODEKEY = 75;
    ///file being written to a by single writer... if throttling enabled, writes
    ///may be broken into smaller chunks with throttling in between
    pub const SINGLE_WRITER = 76;
    ///Get the protection version number for this filesystem
    pub const GETPROTECTIONLEVEL = 77;
    ///Add detached code signatures (used by dyld for shared libs)
    pub const FINDSIGS = 78;
    ///Add signature from same file, only if it is signed by Apple (used by dyld for simulator)
    pub const ADDFILESIGS_FOR_DYLD_SIM = 83;
    ///fsync + issue barrier to drive
    pub const BARRIERFSYNC = 85;
    ///Add signature from same file, return end offset in structure on success
    pub const ADDFILESIGS_RETURN = 97;
    ///Check if Library Validation allows this Mach-O file to be mapped into the calling process
    pub const CHECK_LV = 98;
    ///Deallocate a range of the file
    pub const PUNCHHOLE = 99;
    ///Trim an active file
    pub const TRIM_ACTIVE_FILE = 100;
    ///mark the dup with FD_CLOEXEC
    pub const DUPFD_CLOEXEC = 67;
    /// shared or read lock
    pub const RDLCK = 1;
    /// unlock
    pub const UNLCK = 2;
    /// exclusive or write lock
    pub const WRLCK = 3;
};

pub const FCNTL_FS_SPECIFIC_BASE = 0x00010000;

///close-on-exec flag
pub const FD_CLOEXEC = 1;

pub const LOCK = struct {
    pub const SH = 1;
    pub const EX = 2;
    pub const UN = 8;
    pub const NB = 4;
};

pub const nfds_t = u32;
pub const pollfd = extern struct {
    fd: fd_t,
    events: i16,
    revents: i16,
};

pub const POLL = struct {
    pub const IN = 0x001;
    pub const PRI = 0x002;
    pub const OUT = 0x004;
    pub const RDNORM = 0x040;
    pub const WRNORM = OUT;
    pub const RDBAND = 0x080;
    pub const WRBAND = 0x100;

    pub const EXTEND = 0x0200;
    pub const ATTRIB = 0x0400;
    pub const NLINK = 0x0800;
    pub const WRITE = 0x1000;

    pub const ERR = 0x008;
    pub const HUP = 0x010;
    pub const NVAL = 0x020;

    pub const STANDARD = IN | PRI | OUT | RDNORM | RDBAND | WRBAND | ERR | HUP | NVAL;
};

pub const CLOCK = struct {
    pub const REALTIME = 0;
    pub const MONOTONIC = 6;
    pub const MONOTONIC_RAW = 4;
    pub const MONOTONIC_RAW_APPROX = 5;
    pub const UPTIME_RAW = 8;
    pub const UPTIME_RAW_APPROX = 9;
    pub const PROCESS_CPUTIME_ID = 12;
    pub const THREAD_CPUTIME_ID = 16;
};

/// Max open files per process
/// https://opensource.apple.com/source/xnu/xnu-4903.221.2/bsd/sys/syslimits.h.auto.html
pub const OPEN_MAX = 10240;

pub const rusage = extern struct {
    utime: timeval,
    stime: timeval,
    maxrss: isize,
    ixrss: isize,
    idrss: isize,
    isrss: isize,
    minflt: isize,
    majflt: isize,
    nswap: isize,
    inblock: isize,
    oublock: isize,
    msgsnd: isize,
    msgrcv: isize,
    nsignals: isize,
    nvcsw: isize,
    nivcsw: isize,

    pub const SELF = 0;
    pub const CHILDREN = -1;
};

pub const rlimit_resource = enum(c_int) {
    CPU = 0,
    FSIZE = 1,
    DATA = 2,
    STACK = 3,
    CORE = 4,
    RSS = 5,
    MEMLOCK = 6,
    NPROC = 7,
    NOFILE = 8,
    _,

    pub const AS: rlimit_resource = .RSS;
};

pub const rlim_t = u64;

pub const RLIM = struct {
    /// No limit
    pub const INFINITY: rlim_t = (1 << 63) - 1;

    pub const SAVED_MAX = INFINITY;
    pub const SAVED_CUR = INFINITY;
};

pub const rlimit = extern struct {
    /// Soft limit
    cur: rlim_t,
    /// Hard limit
    max: rlim_t,
};

pub const SHUT = struct {
    pub const RD = 0;
    pub const WR = 1;
    pub const RDWR = 2;
};

// Term
pub const V = struct {
    pub const EOF = 0;
    pub const EOL = 1;
    pub const EOL2 = 2;
    pub const ERASE = 3;
    pub const WERASE = 4;
    pub const KILL = 5;
    pub const REPRINT = 6;
    pub const INTR = 8;
    pub const QUIT = 9;
    pub const SUSP = 10;
    pub const DSUSP = 11;
    pub const START = 12;
    pub const STOP = 13;
    pub const LNEXT = 14;
    pub const DISCARD = 15;
    pub const MIN = 16;
    pub const TIME = 17;
    pub const STATUS = 18;
};

pub const NCCS = 20; // 2 spares (7, 19)

pub const cc_t = u8;
pub const speed_t = u64;
pub const tcflag_t = u64;

pub const IGNBRK: tcflag_t = 0x00000001; // ignore BREAK condition
pub const BRKINT: tcflag_t = 0x00000002; // map BREAK to SIGINTR
pub const IGNPAR: tcflag_t = 0x00000004; // ignore (discard) parity errors
pub const PARMRK: tcflag_t = 0x00000008; // mark parity and framing errors
pub const INPCK: tcflag_t = 0x00000010; // enable checking of parity errors
pub const ISTRIP: tcflag_t = 0x00000020; // strip 8th bit off chars
pub const INLCR: tcflag_t = 0x00000040; // map NL into CR
pub const IGNCR: tcflag_t = 0x00000080; // ignore CR
pub const ICRNL: tcflag_t = 0x00000100; // map CR to NL (ala CRMOD)
pub const IXON: tcflag_t = 0x00000200; // enable output flow control
pub const IXOFF: tcflag_t = 0x00000400; // enable input flow control
pub const IXANY: tcflag_t = 0x00000800; // any char will restart after stop
pub const IMAXBEL: tcflag_t = 0x00002000; // ring bell on input queue full
pub const IUTF8: tcflag_t = 0x00004000; // maintain state for UTF-8 VERASE

pub const OPOST: tcflag_t = 0x00000001; //enable following output processing
pub const ONLCR: tcflag_t = 0x00000002; // map NL to CR-NL (ala CRMOD)
pub const OXTABS: tcflag_t = 0x00000004; // expand tabs to spaces
pub const ONOEOT: tcflag_t = 0x00000008; // discard EOT's (^D) on output)

pub const OCRNL: tcflag_t = 0x00000010; // map CR to NL on output
pub const ONOCR: tcflag_t = 0x00000020; // no CR output at column 0
pub const ONLRET: tcflag_t = 0x00000040; // NL performs CR function
pub const OFILL: tcflag_t = 0x00000080; // use fill characters for delay
pub const NLDLY: tcflag_t = 0x00000300; // \n delay
pub const TABDLY: tcflag_t = 0x00000c04; // horizontal tab delay
pub const CRDLY: tcflag_t = 0x00003000; // \r delay
pub const FFDLY: tcflag_t = 0x00004000; // form feed delay
pub const BSDLY: tcflag_t = 0x00008000; // \b delay
pub const VTDLY: tcflag_t = 0x00010000; // vertical tab delay
pub const OFDEL: tcflag_t = 0x00020000; // fill is DEL, else NUL

pub const NL0: tcflag_t = 0x00000000;
pub const NL1: tcflag_t = 0x00000100;
pub const NL2: tcflag_t = 0x00000200;
pub const NL3: tcflag_t = 0x00000300;
pub const TAB0: tcflag_t = 0x00000000;
pub const TAB1: tcflag_t = 0x00000400;
pub const TAB2: tcflag_t = 0x00000800;
pub const TAB3: tcflag_t = 0x00000004;
pub const CR0: tcflag_t = 0x00000000;
pub const CR1: tcflag_t = 0x00001000;
pub const CR2: tcflag_t = 0x00002000;
pub const CR3: tcflag_t = 0x00003000;
pub const FF0: tcflag_t = 0x00000000;
pub const FF1: tcflag_t = 0x00004000;
pub const BS0: tcflag_t = 0x00000000;
pub const BS1: tcflag_t = 0x00008000;
pub const VT0: tcflag_t = 0x00000000;
pub const VT1: tcflag_t = 0x00010000;

pub const CIGNORE: tcflag_t = 0x00000001; // ignore control flags
pub const CSIZE: tcflag_t = 0x00000300; // character size mask
pub const CS5: tcflag_t = 0x00000000; //    5 bits (pseudo)
pub const CS6: tcflag_t = 0x00000100; //    6 bits
pub const CS7: tcflag_t = 0x00000200; //    7 bits
pub const CS8: tcflag_t = 0x00000300; //    8 bits
pub const CSTOPB: tcflag_t = 0x0000040; // send 2 stop bits
pub const CREAD: tcflag_t = 0x00000800; // enable receiver
pub const PARENB: tcflag_t = 0x00001000; // parity enable
pub const PARODD: tcflag_t = 0x00002000; // odd parity, else even
pub const HUPCL: tcflag_t = 0x00004000; // hang up on last close
pub const CLOCAL: tcflag_t = 0x00008000; // ignore modem status lines
pub const CCTS_OFLOW: tcflag_t = 0x00010000; // CTS flow control of output
pub const CRTSCTS: tcflag_t = (CCTS_OFLOW | CRTS_IFLOW);
pub const CRTS_IFLOW: tcflag_t = 0x00020000; // RTS flow control of input
pub const CDTR_IFLOW: tcflag_t = 0x00040000; // DTR flow control of input
pub const CDSR_OFLOW: tcflag_t = 0x00080000; // DSR flow control of output
pub const CCAR_OFLOW: tcflag_t = 0x00100000; // DCD flow control of output
pub const MDMBUF: tcflag_t = 0x00100000; // old name for CCAR_OFLOW

pub const ECHOKE: tcflag_t = 0x00000001; // visual erase for line kill
pub const ECHOE: tcflag_t = 0x00000002; // visually erase chars
pub const ECHOK: tcflag_t = 0x00000004; // echo NL after line kill
pub const ECHO: tcflag_t = 0x00000008; // enable echoing
pub const ECHONL: tcflag_t = 0x00000010; // echo NL even if ECHO is off
pub const ECHOPRT: tcflag_t = 0x00000020; // visual erase mode for hardcopy
pub const ECHOCTL: tcflag_t = 0x00000040; // echo control chars as ^(Char)
pub const ISIG: tcflag_t = 0x00000080; // enable signals INTR, QUIT, [D]SUSP
pub const ICANON: tcflag_t = 0x00000100; // canonicalize input lines
pub const ALTWERASE: tcflag_t = 0x00000200; // use alternate WERASE algorithm
pub const IEXTEN: tcflag_t = 0x00000400; // enable DISCARD and LNEXT
pub const EXTPROC: tcflag_t = 0x00000800; // external processing
pub const TOSTOP: tcflag_t = 0x00400000; // stop background jobs from output
pub const FLUSHO: tcflag_t = 0x00800000; // output being flushed (state)
pub const NOKERNINFO: tcflag_t = 0x02000000; // no kernel output from VSTATUS
pub const PENDIN: tcflag_t = 0x20000000; // XXX retype pending input (state)
pub const NOFLSH: tcflag_t = 0x80000000; // don't flush after interrupt

pub const TCSANOW: tcflag_t = 0; // make change immediate
pub const TCSADRAIN: tcflag_t = 1; // drain output, then change
pub const TCSAFLUSH: tcflag_t = 2; // drain output, flush input
pub const TCSASOFT: tcflag_t = 0x10; // flag - don't alter h.w. state
pub const TCSA = enum(c_uint) {
    NOW,
    DRAIN,
    FLUSH,
    _,
};

pub const B0: tcflag_t = 0;
pub const B50: tcflag_t = 50;
pub const B75: tcflag_t = 75;
pub const B110: tcflag_t = 110;
pub const B134: tcflag_t = 134;
pub const B150: tcflag_t = 150;
pub const B200: tcflag_t = 200;
pub const B300: tcflag_t = 300;
pub const B600: tcflag_t = 600;
pub const B1200: tcflag_t = 1200;
pub const B1800: tcflag_t = 1800;
pub const B2400: tcflag_t = 2400;
pub const B4800: tcflag_t = 4800;
pub const B9600: tcflag_t = 9600;
pub const B19200: tcflag_t = 19200;
pub const B38400: tcflag_t = 38400;
pub const B7200: tcflag_t = 7200;
pub const B14400: tcflag_t = 14400;
pub const B28800: tcflag_t = 28800;
pub const B57600: tcflag_t = 57600;
pub const B76800: tcflag_t = 76800;
pub const B115200: tcflag_t = 115200;
pub const B230400: tcflag_t = 230400;
pub const EXTA: tcflag_t = 19200;
pub const EXTB: tcflag_t = 38400;

pub const TCIFLUSH: tcflag_t = 1;
pub const TCOFLUSH: tcflag_t = 2;
pub const TCIOFLUSH: tcflag_t = 3;
pub const TCOOFF: tcflag_t = 1;
pub const TCOON: tcflag_t = 2;
pub const TCIOFF: tcflag_t = 3;
pub const TCION: tcflag_t = 4;

pub const termios = extern struct {
    iflag: tcflag_t, // input flags
    oflag: tcflag_t, // output flags
    cflag: tcflag_t, // control flags
    lflag: tcflag_t, // local flags
    cc: [NCCS]cc_t, // control chars
    ispeed: speed_t align(8), // input speed
    ospeed: speed_t, // output speed
};

pub const winsize = extern struct {
    ws_row: u16,
    ws_col: u16,
    ws_xpixel: u16,
    ws_ypixel: u16,
};

pub const T = struct {
    pub const IOCGWINSZ = ior(0x40000000, 't', 104, @sizeOf(winsize));
};
pub const IOCPARM_MASK = 0x1fff;

fn ior(inout: u32, group: usize, num: usize, len: usize) usize {
    return (inout | ((len & IOCPARM_MASK) << 16) | ((group) << 8) | (num));
}

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

pub const PosixSpawn = struct {
    const errno = std.os.errno;
    const unexpectedErrno = std.os.unexpectedErrno;

    pub const Error = error{
        SystemResources,
        InvalidFileDescriptor,
        NameTooLong,
        TooBig,
        PermissionDenied,
        InputOutput,
        FileSystem,
        FileNotFound,
        InvalidExe,
        NotDir,
        FileBusy,
        /// Returned when the child fails to execute either in the pre-exec() initialization step, or
        /// when exec(3) is invoked.
        ChildExecFailed,
    } || std.os.UnexpectedError;

    pub const Attr = struct {
        attr: posix_spawnattr_t,

        pub fn init() Error!Attr {
            var attr: posix_spawnattr_t = undefined;
            switch (errno(posix_spawnattr_init(&attr))) {
                .SUCCESS => return Attr{ .attr = attr },
                .NOMEM => return error.SystemResources,
                .INVAL => unreachable,
                else => |err| return unexpectedErrno(err),
            }
        }

        pub fn deinit(self: *Attr) void {
            defer self.* = undefined;
            switch (errno(posix_spawnattr_destroy(&self.attr))) {
                .SUCCESS => return,
                .INVAL => unreachable, // Invalid parameters.
                else => unreachable,
            }
        }

        pub fn get(self: Attr) Error!u16 {
            var flags: c_short = undefined;
            switch (errno(posix_spawnattr_getflags(&self.attr, &flags))) {
                .SUCCESS => return @as(u16, @bitCast(flags)),
                .INVAL => unreachable,
                else => |err| return unexpectedErrno(err),
            }
        }

        pub fn set(self: *Attr, flags: u16) Error!void {
            switch (errno(posix_spawnattr_setflags(&self.attr, @as(c_short, @bitCast(flags))))) {
                .SUCCESS => return,
                .INVAL => unreachable,
                else => |err| return unexpectedErrno(err),
            }
        }
    };

    pub const Actions = struct {
        actions: posix_spawn_file_actions_t,

        pub fn init() Error!Actions {
            var actions: posix_spawn_file_actions_t = undefined;
            switch (errno(posix_spawn_file_actions_init(&actions))) {
                .SUCCESS => return Actions{ .actions = actions },
                .NOMEM => return error.SystemResources,
                .INVAL => unreachable,
                else => |err| return unexpectedErrno(err),
            }
        }

        pub fn deinit(self: *Actions) void {
            defer self.* = undefined;
            switch (errno(posix_spawn_file_actions_destroy(&self.actions))) {
                .SUCCESS => return,
                .INVAL => unreachable, // Invalid parameters.
                else => unreachable,
            }
        }

        pub fn open(self: *Actions, fd: fd_t, path: []const u8, flags: u32, mode: mode_t) Error!void {
            const posix_path = try std.os.toPosixPath(path);
            return self.openZ(fd, &posix_path, flags, mode);
        }

        pub fn openZ(self: *Actions, fd: fd_t, path: [*:0]const u8, flags: u32, mode: mode_t) Error!void {
            switch (errno(posix_spawn_file_actions_addopen(&self.actions, fd, path, @as(c_int, @bitCast(flags)), mode))) {
                .SUCCESS => return,
                .BADF => return error.InvalidFileDescriptor,
                .NOMEM => return error.SystemResources,
                .NAMETOOLONG => return error.NameTooLong,
                .INVAL => unreachable, // the value of file actions is invalid
                else => |err| return unexpectedErrno(err),
            }
        }

        pub fn close(self: *Actions, fd: fd_t) Error!void {
            switch (errno(posix_spawn_file_actions_addclose(&self.actions, fd))) {
                .SUCCESS => return,
                .BADF => return error.InvalidFileDescriptor,
                .NOMEM => return error.SystemResources,
                .INVAL => unreachable, // the value of file actions is invalid
                .NAMETOOLONG => unreachable,
                else => |err| return unexpectedErrno(err),
            }
        }

        pub fn dup2(self: *Actions, fd: fd_t, newfd: fd_t) Error!void {
            switch (errno(posix_spawn_file_actions_adddup2(&self.actions, fd, newfd))) {
                .SUCCESS => return,
                .BADF => return error.InvalidFileDescriptor,
                .NOMEM => return error.SystemResources,
                .INVAL => unreachable, // the value of file actions is invalid
                .NAMETOOLONG => unreachable,
                else => |err| return unexpectedErrno(err),
            }
        }

        pub fn inherit(self: *Actions, fd: fd_t) Error!void {
            switch (errno(posix_spawn_file_actions_addinherit_np(&self.actions, fd))) {
                .SUCCESS => return,
                .BADF => return error.InvalidFileDescriptor,
                .NOMEM => return error.SystemResources,
                .INVAL => unreachable, // the value of file actions is invalid
                .NAMETOOLONG => unreachable,
                else => |err| return unexpectedErrno(err),
            }
        }

        pub fn chdir(self: *Actions, path: []const u8) Error!void {
            const posix_path = try std.os.toPosixPath(path);
            return self.chdirZ(&posix_path);
        }

        pub fn chdirZ(self: *Actions, path: [*:0]const u8) Error!void {
            switch (errno(posix_spawn_file_actions_addchdir_np(&self.actions, path))) {
                .SUCCESS => return,
                .NOMEM => return error.SystemResources,
                .NAMETOOLONG => return error.NameTooLong,
                .BADF => unreachable,
                .INVAL => unreachable, // the value of file actions is invalid
                else => |err| return unexpectedErrno(err),
            }
        }

        pub fn fchdir(self: *Actions, fd: fd_t) Error!void {
            switch (errno(posix_spawn_file_actions_addfchdir_np(&self.actions, fd))) {
                .SUCCESS => return,
                .BADF => return error.InvalidFileDescriptor,
                .NOMEM => return error.SystemResources,
                .INVAL => unreachable, // the value of file actions is invalid
                .NAMETOOLONG => unreachable,
                else => |err| return unexpectedErrno(err),
            }
        }
    };

    pub fn spawn(
        path: []const u8,
        actions: ?Actions,
        attr: ?Attr,
        argv: [*:null]?[*:0]const u8,
        envp: [*:null]?[*:0]const u8,
    ) Error!pid_t {
        const posix_path = try std.os.toPosixPath(path);
        return spawnZ(&posix_path, actions, attr, argv, envp);
    }

    pub fn spawnZ(
        path: [*:0]const u8,
        actions: ?Actions,
        attr: ?Attr,
        argv: [*:null]?[*:0]const u8,
        envp: [*:null]?[*:0]const u8,
    ) Error!pid_t {
        var pid: pid_t = undefined;
        switch (errno(posix_spawn(
            &pid,
            path,
            if (actions) |a| &a.actions else null,
            if (attr) |a| &a.attr else null,
            argv,
            envp,
        ))) {
            .SUCCESS => return pid,
            .@"2BIG" => return error.TooBig,
            .NOMEM => return error.SystemResources,
            .BADF => return error.InvalidFileDescriptor,
            .ACCES => return error.PermissionDenied,
            .IO => return error.InputOutput,
            .LOOP => return error.FileSystem,
            .NAMETOOLONG => return error.NameTooLong,
            .NOENT => return error.FileNotFound,
            .NOEXEC => return error.InvalidExe,
            .NOTDIR => return error.NotDir,
            .TXTBSY => return error.FileBusy,
            .BADARCH => return error.InvalidExe,
            .BADEXEC => return error.InvalidExe,
            .FAULT => unreachable,
            .INVAL => unreachable,
            else => |err| return unexpectedErrno(err),
        }
    }

    pub fn waitpid(pid: pid_t, flags: u32) Error!std.os.WaitPidResult {
        var status: c_int = undefined;
        while (true) {
            const rc = waitpid(pid, &status, @as(c_int, @intCast(flags)));
            switch (errno(rc)) {
                .SUCCESS => return std.os.WaitPidResult{
                    .pid = @as(pid_t, @intCast(rc)),
                    .status = @as(u32, @bitCast(status)),
                },
                .INTR => continue,
                .CHILD => return error.ChildExecFailed,
                .INVAL => unreachable, // Invalid flags.
                else => unreachable,
            }
        }
    }
};

pub fn getKernError(err: kern_return_t) KernE {
    return @as(KernE, @enumFromInt(@as(u32, @truncate(@as(usize, @intCast(err))))));
}

pub fn unexpectedKernError(err: KernE) std.os.UnexpectedError {
    if (std.os.unexpected_error_tracing) {
        std.debug.print("unexpected error: {d}\n", .{@intFromEnum(err)});
        std.debug.dumpCurrentStackTrace(null);
    }
    return error.Unexpected;
}

pub const MachError = error{
    /// Not enough permissions held to perform the requested kernel
    /// call.
    PermissionDenied,
} || std.os.UnexpectedError;

pub const MachTask = extern struct {
    port: mach_port_name_t,

    pub fn isValid(self: MachTask) bool {
        return self.port != TASK_NULL;
    }

    pub fn pidForTask(self: MachTask) MachError!std.os.pid_t {
        var pid: std.os.pid_t = undefined;
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
        masks: [EXC_TYPES_COUNT]exception_mask_t,
        ports: [EXC_TYPES_COUNT]mach_port_t,
        behaviors: [EXC_TYPES_COUNT]exception_behavior_t,
        flavors: [EXC_TYPES_COUNT]thread_state_flavor_t,
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

pub fn machTaskForPid(pid: std.os.pid_t) MachError!MachTask {
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
