const std = @import("../std.zig");
const assert = std.debug.assert;
const builtin = @import("builtin");
const O = std.c.O;
const clockid_t = std.c.clockid_t;
const pid_t = std.c.pid_t;
const timespec = std.c.timespec;

comptime {
    assert(builtin.os.tag == .serenity); // Prevent access of std.c symbols on wrong OS.
}

// https://github.com/SerenityOS/serenity/blob/ec492a1a0819e6239ea44156825c4ee7234ca3db/Kernel/API/POSIX/futex.h#L46-L53
pub const FUTEX = struct {
    pub const WAIT = 1;
    pub const WAKE = 2;
    pub const REQUEUE = 3;
    pub const CMP_REQUEUE = 4;
    pub const WAKE_OP = 5;
    pub const WAIT_BITSET = 9;
    pub const WAKE_BITSET = 10;

    pub const CLOCK_REALTIME = 1 << 8;
    pub const PRIVATE_FLAG = 1 << 9;
};

// https://github.com/SerenityOS/serenity/blob/54e79aa1d90bbcb69014255a59afb085802719d3/Kernel/API/POSIX/serenity.h#L18-L36
pub const PERF_EVENT = packed struct(c_int) {
    SAMPLE: bool = false,
    MALLOC: bool = false,
    FREE: bool = false,
    MMAP: bool = false,
    MUNMAP: bool = false,
    PROCESS_CREATE: bool = false,
    PROCESS_EXEC: bool = false,
    PROCESS_EXIT: bool = false,
    THREAD_CREATE: bool = false,
    THREAD_EXIT: bool = false,
    CONTEXT_SWITCH: bool = false,
    KMALLOC: bool = false,
    KFREE: bool = false,
    PAGE_FAULT: bool = false,
    SYSCALL: bool = false,
    SIGNPOST: bool = false,
    FILESYSTEM: bool = false,
};

// https://github.com/SerenityOS/serenity/blob/abc150085f532f123b598949218893cb272ccc4c/Userland/Libraries/LibC/serenity.h

pub extern "c" fn disown(pid: pid_t) c_int;

pub extern "c" fn profiling_enable(pid: pid_t, event_mask: PERF_EVENT) c_int;
pub extern "c" fn profiling_disable(pid: pid_t) c_int;
pub extern "c" fn profiling_free_buffer(pid: pid_t) c_int;

pub extern "c" fn futex(userspace_address: *u32, futex_op: c_int, value: u32, timeout: *const timespec, userspace_address2: *u32, value3: u32) c_int;
pub extern "c" fn futex_wait(userspace_address: *u32, value: u32, abstime: *const timespec, clockid: clockid_t, process_shared: c_int) c_int;
pub extern "c" fn futex_wake(userspace_address: *u32, count: u32, process_shared: c_int) c_int;

pub extern "c" fn purge(mode: c_int) c_int;

pub extern "c" fn perf_event(type: PERF_EVENT, arg1: usize, arg2: usize) c_int;
pub extern "c" fn perf_register_string(string: [*]const u8, string_length: usize) c_int;

pub extern "c" fn get_stack_bounds(user_stack_base: *usize, user_stack_size: *usize) c_int;

pub extern "c" fn anon_create(size: usize, options: O) c_int;

pub extern "c" fn serenity_readlink(path: [*]const u8, path_length: usize, buffer: [*]u8, buffer_size: usize) c_int;
pub extern "c" fn serenity_open(path: [*]const u8, path_length: usize, options: c_int, ...) c_int;

pub extern "c" fn getkeymap(name_buffer: [*]u8, name_buffer_size: usize, map: [*]u32, shift_map: [*]u32, alt_map: [*]u32, altgr_map: [*]u32, shift_altgr_map: [*]u32) c_int;
pub extern "c" fn setkeymap(name: [*]const u8, map: [*]const u32, shift_map: [*]const u32, alt_map: [*]const u32, altgr_map: [*]const u32, shift_altgr_map: [*]const u32) c_int;

pub extern "c" fn internet_checksum(ptr: *const anyopaque, count: usize) u16;
