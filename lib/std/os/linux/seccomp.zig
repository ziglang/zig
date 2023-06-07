//! API bits for the Secure Computing facility in the Linux kernel, which allows
//! processes to restrict access to the system call API.
//!
//! Seccomp started life with a single "strict" mode, which only allowed calls
//! to read(2), write(2), _exit(2) and sigreturn(2). It turns out that this
//! isn't that useful for general-purpose applications, and so a mode that
//! utilizes user-supplied filters mode was added.
//!
//! Seccomp filters are classic BPF programs. Conceptually, a seccomp program
//! is attached to the kernel and is executed on each syscall. The "packet"
//! being validated is the `data` structure, and the verdict is an action that
//! the kernel performs on the calling process. The actions are variations on a
//! "pass" or "fail" result, where a pass allows the syscall to continue and a
//! fail blocks the syscall and returns some sort of error value. See the full
//! list of actions under ::RET for more information. Finally, only word-sized,
//! absolute loads (`ld [k]`) are supported to read from the `data` structure.
//!
//! There are some issues with the filter API that have traditionally made
//! writing them a pain:
//!
//! 1. Each CPU architecture supported by Linux has its own unique ABI and
//!    syscall API. It is not guaranteed that the syscall numbers and arguments
//!    are the same across architectures, or that they're even implemented. Thus,
//!    filters cannot be assumed to be portable without consulting documentation
//!    like syscalls(2) and testing on target hardware. This also requires
//!    checking the value of `data.arch` to make sure that a filter was compiled
//!    for the correct architecture.
//! 2. Many syscalls take an `unsigned long` or `size_t` argument, the size of
//!    which is dependant on the ABI. Since BPF programs execute in a 32-bit
//!    machine, validation of 64-bit arguments necessitates two load-and-compare
//!    instructions for the upper and lower words.
//! 3. A further wrinkle to the above is endianness. Unlike network packets,
//!    syscall data shares the endianness of the target machine. A filter
//!    compiled on a little-endian machine will not work on a big-endian one,
//!    and vice-versa. For example: Checking the upper 32-bits of `data.arg1`
//!    requires a load at `@offsetOf(data, "arg1") + 4` on big-endian systems
//!    and `@offsetOf(data, "arg1")` on little-endian systems. Endian-portable
//!    filters require adjusting these offsets at compile time, similar to how
//!    e.g. OpenSSH does[1].
//! 4. Syscalls with userspace implementations via the vDSO cannot be traced or
//!    filtered. The vDSO can be disabled or just ignored, which must be taken
//!    into account when writing filters.
//! 5. Software libraries -  especially dynamically loaded ones - tend to use
//!    more of the syscall API over time, thus filters must evolve with them.
//!    Static filters can result in reduced or even broken functionality when
//!    calling newer code from these libraries. This is known to happen with
//!    critical libraries like glibc[2].
//!
//! Some of these issues can be mitigated with help from Zig and the standard
//! library. Since the target CPU is known at compile time, the proper syscall
//! numbers are mixed into the `os` namespace under `std.os.SYS (see the code
//! for `arch_bits` in `os/linux.zig`). Referencing an unimplemented syscall
//! would be a compile error. Endian offsets can also be defined in a similar
//! manner to the OpenSSH example:
//!
//! ```zig
//! const offset = if (native_endian == .Little) struct {
//!     pub const low = 0;
//!     pub const high = @sizeOf(u32);
//! } else struct {
//!     pub const low = @sizeOf(u32);
//!     pub const high = 0;
//! };
//! ```
//!
//! Unfortunately, there is no easy solution for issue 5. The most reliable
//! strategy is to keep testing; test newer Zig versions, different libcs,
//! different distros, and design your filter to accommodate all of them.
//! Alternatively, you could inject a filter at runtime. Since filters are
//! preserved across execve(2), a filter could be setup before executing your
//! program, without your program having any knowledge of this happening. This
//! is the method used by systemd[3] and Cloudflare's sandbox library[4].
//!
//! [1]: https://github.com/openssh/openssh-portable/blob/master/sandbox-seccomp-filter.c#L81
//! [2]: https://sourceware.org/legacy-ml/libc-alpha/2017-11/msg00246.html
//! [3]: https://www.freedesktop.org/software/systemd/man/systemd.exec.html#SystemCallFilter=
//! [4]: https://github.com/cloudflare/sandbox
//!
//! See Also
//! - seccomp(2), seccomp_unotify(2)
//! - https://www.kernel.org/doc/html/latest/userspace-api/seccomp_filter.html
const IOCTL = @import("ioctl.zig");

// Modes for the prctl(2) form `prctl(PR_SET_SECCOMP, mode)`
pub const MODE = struct {
    /// Seccomp not in use.
    pub const DISABLED = 0;
    /// Uses a hard-coded filter.
    pub const STRICT = 1;
    /// Uses a user-supplied filter.
    pub const FILTER = 2;
};

// Operations for the seccomp(2) form `seccomp(operation, flags, args)`
pub const SET_MODE_STRICT = 0;
pub const SET_MODE_FILTER = 1;
pub const GET_ACTION_AVAIL = 2;
pub const GET_NOTIF_SIZES = 3;

/// Bitflags for the SET_MODE_FILTER operation.
pub const FILTER_FLAG = struct {
    pub const TSYNC = 1 << 0;
    pub const LOG = 1 << 1;
    pub const SPEC_ALLOW = 1 << 2;
    pub const NEW_LISTENER = 1 << 3;
    pub const TSYNC_ESRCH = 1 << 4;
};

/// Action values for seccomp BPF programs.
/// The lower 16-bits are for optional return data.
/// The upper 16-bits are ordered from least permissive values to most.
pub const RET = struct {
    /// Kill the process.
    pub const KILL_PROCESS = 0x80000000;
    /// Kill the thread.
    pub const KILL_THREAD = 0x00000000;
    pub const KILL = KILL_THREAD;
    /// Disallow and force a SIGSYS.
    pub const TRAP = 0x00030000;
    /// Return an errno.
    pub const ERRNO = 0x00050000;
    /// Forward the syscall to a userspace supervisor to make a decision.
    pub const USER_NOTIF = 0x7fc00000;
    /// Pass to a tracer or disallow.
    pub const TRACE = 0x7ff00000;
    /// Allow after logging.
    pub const LOG = 0x7ffc0000;
    /// Allow.
    pub const ALLOW = 0x7fff0000;

    // Masks for the return value sections.
    pub const ACTION_FULL = 0xffff0000;
    pub const ACTION = 0x7fff0000;
    pub const DATA = 0x0000ffff;
};

pub const IOCTL_NOTIF = struct {
    pub const RECV = IOCTL.IOWR('!', 0, notif);
    pub const SEND = IOCTL.IOWR('!', 1, notif_resp);
    pub const ID_VALID = IOCTL.IOW('!', 2, u64);
    pub const ADDFD = IOCTL.IOW('!', 3, notif_addfd);
};

/// Tells the kernel that the supervisor allows the syscall to continue.
pub const USER_NOTIF_FLAG_CONTINUE = 1 << 0;

/// See seccomp_unotify(2).
pub const ADDFD_FLAG = struct {
    pub const SETFD = 1 << 0;
    pub const SEND = 1 << 1;
};

pub const data = extern struct {
    /// The system call number.
    nr: c_int,
    /// The CPU architecture/system call convention.
    /// One of the values defined in `std.os.linux.AUDIT`.
    arch: u32,
    instruction_pointer: u64,
    arg0: u64,
    arg1: u64,
    arg2: u64,
    arg3: u64,
    arg4: u64,
    arg5: u64,
};

/// Used with the ::GET_NOTIF_SIZES command to check if the kernel structures
/// have changed.
pub const notif_sizes = extern struct {
    /// Size of ::notif.
    notif: u16,
    /// Size of ::resp.
    notif_resp: u16,
    /// Size of ::data.
    data: u16,
};

pub const notif = extern struct {
    /// Unique notification cookie for each filter.
    id: u64,
    /// ID of the thread that triggered the notification.
    pid: u32,
    /// Bitmask for event information. Currently set to zero.
    flags: u32,
    /// The current system call data.
    data: data,
};

/// The decision payload the supervisor process sends to the kernel.
pub const notif_resp = extern struct {
    /// The filter cookie.
    id: u64,
    /// The return value for a spoofed syscall.
    val: i64,
    /// Set to zero for a spoofed success or a negative error number for a
    /// failure.
    @"error": i32,
    /// Bitmask containing the decision. Either USER_NOTIF_FLAG_CONTINUE to
    /// allow the syscall or zero to spoof the return values.
    flags: u32,
};

pub const notif_addfd = extern struct {
    id: u64,
    flags: u32,
    srcfd: u32,
    newfd: u32,
    newfd_flags: u32,
};
