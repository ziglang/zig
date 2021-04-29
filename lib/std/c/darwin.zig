// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../std.zig");
const assert = std.debug.assert;
const builtin = @import("builtin");
const macho = std.macho;
const native_arch = builtin.target.cpu.arch;

usingnamespace @import("../os/bits.zig");

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

pub extern "c" fn __getdirentries64(fd: c_int, buf_ptr: [*]u8, buf_len: usize, basep: *i64) isize;

extern "c" fn fstat(fd: fd_t, buf: *libc_stat) c_int;
/// On x86_64 Darwin, fstat has to be manully linked with $INODE64 suffix to force 64bit version.
/// Note that this is fixed on aarch64 and no longer necessary.
extern "c" fn @"fstat$INODE64"(fd: fd_t, buf: *libc_stat) c_int;
pub const _fstat = if (native_arch == .aarch64) fstat else @"fstat$INODE64";

extern "c" fn fstatat(dirfd: fd_t, path: [*:0]const u8, stat_buf: *libc_stat, flags: u32) c_int;
/// On x86_64 Darwin, fstatat has to be manully linked with $INODE64 suffix to force 64bit version.
/// Note that this is fixed on aarch64 and no longer necessary.
extern "c" fn @"fstatat$INODE64"(dirfd: fd_t, path_name: [*:0]const u8, buf: *libc_stat, flags: u32) c_int;
pub const _fstatat = if (native_arch == .aarch64) fstatat else @"fstatat$INODE64";

pub extern "c" fn mach_absolute_time() u64;
pub extern "c" fn mach_timebase_info(tinfo: ?*mach_timebase_info_data) void;

pub extern "c" fn malloc_size(?*const c_void) usize;
pub extern "c" fn posix_memalign(memptr: *?*c_void, alignment: usize, size: usize) c_int;

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
    if (std.Target.current.isDarwin()) {
        @export(dummy_execute_header, .{ .name = "_mh_execute_header", .linkage = .Weak });
    }
}

pub const mach_header_64 = macho.mach_header_64;
pub const mach_header = macho.mach_header;

pub const _errno = __error;

pub extern "c" fn @"close$NOCANCEL"(fd: fd_t) c_int;
pub extern "c" fn mach_host_self() mach_port_t;
pub extern "c" fn clock_get_time(clock_serv: clock_serv_t, cur_time: *mach_timespec_t) kern_return_t;
pub extern "c" fn host_get_clock_service(host: host_t, clock_id: clock_id_t, clock_serv: ?[*]clock_serv_t) kern_return_t;
pub extern "c" fn mach_port_deallocate(task: ipc_space_t, name: mach_port_name_t) kern_return_t;

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

/// get address to use bind()
pub const AI_PASSIVE = 0x00000001;

/// fill ai_canonname
pub const AI_CANONNAME = 0x00000002;

/// prevent host name resolution
pub const AI_NUMERICHOST = 0x00000004;

/// prevent service name resolution
pub const AI_NUMERICSERV = 0x00001000;

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

const pthread_t = std.c.pthread_t;
pub extern "c" fn pthread_threadid_np(thread: ?pthread_t, thread_id: *u64) c_int;

pub extern "c" fn arc4random_buf(buf: [*]u8, len: usize) void;

// Grand Central Dispatch is exposed by libSystem.
pub const dispatch_semaphore_t = *opaque {};
pub const dispatch_time_t = u64;
pub const DISPATCH_TIME_NOW = @as(dispatch_time_t, 0);
pub const DISPATCH_TIME_FOREVER = ~@as(dispatch_time_t, 0);
pub extern "c" fn dispatch_semaphore_create(value: isize) ?dispatch_semaphore_t;
pub extern "c" fn dispatch_semaphore_wait(dsema: dispatch_semaphore_t, timeout: dispatch_time_t) isize;
pub extern "c" fn dispatch_semaphore_signal(dsema: dispatch_semaphore_t) isize;

pub extern "c" fn dispatch_release(object: *c_void) void;
pub extern "c" fn dispatch_time(when: dispatch_time_t, delta: i64) dispatch_time_t;
