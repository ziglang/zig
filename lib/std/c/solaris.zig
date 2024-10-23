const builtin = @import("builtin");
const std = @import("../std.zig");
const assert = std.debug.assert;
const SO = std.c.SO;
const fd_t = std.c.fd_t;
const gid_t = std.c.gid_t;
const ino_t = std.c.ino_t;
const mode_t = std.c.mode_t;
const off_t = std.c.off_t;
const pid_t = std.c.pid_t;
const pthread_t = std.c.pthread_t;
const sockaddr = std.c.sockaddr;
const socklen_t = std.c.socklen_t;
const timespec = std.c.timespec;
const uid_t = std.c.uid_t;
const IFNAMESIZE = std.c.IFNAMESIZE;

comptime {
    assert(builtin.os.tag == .solaris or builtin.os.tag == .illumos); // Prevent access of std.c symbols on wrong OS.
}

pub extern "c" fn pthread_setname_np(thread: pthread_t, name: [*:0]const u8, arg: ?*anyopaque) c_int;
pub extern "c" fn sysconf(sc: c_int) i64;

pub const major_t = u32;
pub const minor_t = u32;
pub const id_t = i32;
pub const taskid_t = id_t;
pub const projid_t = id_t;
pub const poolid_t = id_t;
pub const zoneid_t = id_t;
pub const ctid_t = id_t;

pub const cmsghdr = extern struct {
    len: socklen_t,
    level: i32,
    type: i32,
};

pub const SCM = struct {
    pub const UCRED = 0x1012;
    pub const RIGHTS = 0x1010;
    pub const TIMESTAMP = SO.TIMESTAMP;
};

pub const fpregset_t = extern union {
    regs: [130]u32,
    chip_state: extern struct {
        cw: u16,
        sw: u16,
        fctw: u8,
        __fx_rsvd: u8,
        fop: u16,
        rip: u64,
        rdp: u64,
        mxcsr: u32,
        mxcsr_mask: u32,
        st: [8]extern union {
            fpr_16: [5]u16,
            __fpr_pad: u128,
        },
        xmm: [16]u128,
        __fx_ign2: [6]u128,
        status: u32,
        xstatus: u32,
    },
};

pub const GETCONTEXT = 0;
pub const SETCONTEXT = 1;
pub const GETUSTACK = 2;
pub const SETUSTACK = 3;

pub const POSIX_FADV = struct {
    pub const NORMAL = 0;
    pub const RANDOM = 1;
    pub const SEQUENTIAL = 2;
    pub const WILLNEED = 3;
    pub const DONTNEED = 4;
    pub const NOREUSE = 5;
};

pub const priority = enum(c_int) {
    PROCESS = 0,
    PGRP = 1,
    USER = 2,
    GROUP = 3,
    SESSION = 4,
    LWP = 5,
    TASK = 6,
    PROJECT = 7,
    ZONE = 8,
    CONTRACT = 9,
};

/// Extensions to the ELF auxiliary vector.
pub const AT_SUN = struct {
    /// effective user id
    pub const UID = 2000;
    /// real user id
    pub const RUID = 2001;
    /// effective group id
    pub const GID = 2002;
    /// real group id
    pub const RGID = 2003;
    /// dynamic linker's ELF header
    pub const LDELF = 2004;
    /// dynamic linker's section headers
    pub const LDSHDR = 2005;
    /// name of dynamic linker
    pub const LDNAME = 2006;
    /// large pagesize
    pub const LPAGESZ = 2007;
    /// platform name
    pub const PLATFORM = 2008;
    /// hints about hardware capabilities.
    pub const HWCAP = 2009;
    pub const HWCAP2 = 2023;
    /// flush icache?
    pub const IFLUSH = 2010;
    /// cpu name
    pub const CPU = 2011;
    /// exec() path name in the auxv, null terminated.
    pub const EXECNAME = 2014;
    /// mmu module name
    pub const MMU = 2015;
    /// dynamic linkers data segment
    pub const LDDATA = 2016;
    /// AF_SUN_ flags passed from the kernel
    pub const AUXFLAGS = 2017;
    /// name of the emulation binary for the linker
    pub const EMULATOR = 2018;
    /// name of the brand library for the linker
    pub const BRANDNAME = 2019;
    /// vectors for brand modules.
    pub const BRAND_AUX1 = 2020;
    pub const BRAND_AUX2 = 2021;
    pub const BRAND_AUX3 = 2022;
    pub const BRAND_AUX4 = 2025;
    pub const BRAND_NROOT = 2024;
    /// vector for comm page.
    pub const COMMPAGE = 2026;
    /// information about the x86 FPU.
    pub const FPTYPE = 2027;
    pub const FPSIZE = 2028;
};

/// ELF auxiliary vector flags.
pub const AF_SUN = struct {
    /// tell ld.so.1 to run "secure" and ignore the environment.
    pub const SETUGID = 0x00000001;
    /// hardware capabilities can be verified against AT_SUN_HWCAP
    pub const HWCAPVERIFY = 0x00000002;
    pub const NOPLM = 0x00000004;
};

pub const _SC = struct {
    pub const NPROCESSORS_ONLN = 15;
};

pub const procfs = struct {
    pub const misc_header = extern struct {
        size: u32,
        type: enum(u32) {
            Pathname,
            Socketname,
            Peersockname,
            SockoptsBoolOpts,
            SockoptLinger,
            SockoptSndbuf,
            SockoptRcvbuf,
            SockoptIpNexthop,
            SockoptIpv6Nexthop,
            SockoptType,
            SockoptTcpCongestion,
            SockfiltersPriv = 14,
        },
    };

    pub const fdinfo = extern struct {
        fd: fd_t,
        mode: mode_t,
        ino: ino_t,
        size: off_t,
        offset: off_t,
        uid: uid_t,
        gid: gid_t,
        dev_major: major_t,
        dev_minor: minor_t,
        special_major: major_t,
        special_minor: minor_t,
        fileflags: i32,
        fdflags: i32,
        locktype: i16,
        lockpid: pid_t,
        locksysid: i32,
        peerpid: pid_t,
        __filler: [25]c_int,
        peername: [15:0]u8,
        misc: [1]u8,
    };
};

pub const SFD = struct {
    pub const CLOEXEC = 0o2000000;
    pub const NONBLOCK = 0o4000;
};

pub const signalfd_siginfo = extern struct {
    signo: u32,
    errno: i32,
    code: i32,
    pid: u32,
    uid: uid_t,
    fd: i32,
    tid: u32, // unused
    band: u32,
    overrun: u32, // unused
    trapno: u32,
    status: i32,
    int: i32, // unused
    ptr: u64, // unused
    utime: u64,
    stime: u64,
    addr: u64,
    __pad: [48]u8,
};

pub const PORT_SOURCE = struct {
    pub const AIO = 1;
    pub const TIMER = 2;
    pub const USER = 3;
    pub const FD = 4;
    pub const ALERT = 5;
    pub const MQ = 6;
    pub const FILE = 7;
};

pub const PORT_ALERT = struct {
    pub const SET = 0x01;
    pub const UPDATE = 0x02;
};

/// User watchable file events.
pub const FILE_EVENT = struct {
    pub const ACCESS = 0x00000001;
    pub const MODIFIED = 0x00000002;
    pub const ATTRIB = 0x00000004;
    pub const DELETE = 0x00000010;
    pub const RENAME_TO = 0x00000020;
    pub const RENAME_FROM = 0x00000040;
    pub const TRUNC = 0x00100000;
    pub const NOFOLLOW = 0x10000000;
    /// The filesystem holding the watched file was unmounted.
    pub const UNMOUNTED = 0x20000000;
    /// Some other file/filesystem got mounted over the watched file/directory.
    pub const MOUNTEDOVER = 0x40000000;

    pub fn isException(event: u32) bool {
        return event & (UNMOUNTED | DELETE | RENAME_TO | RENAME_FROM | MOUNTEDOVER) > 0;
    }
};

pub const port_notify = extern struct {
    /// Bind request(s) to port.
    port: u32,
    /// User defined variable.
    user: ?*void,
};

pub const file_obj = extern struct {
    /// Access time.
    atim: timespec,
    /// Modification time
    mtim: timespec,
    /// Change time
    ctim: timespec,
    __pad: [3]usize,
    name: [*:0]u8,
};

// struct ifreq is marked obsolete, with struct lifreq preferred for interface requests.
// Here we alias lifreq to ifreq to avoid chainging existing code in os and x.os.IPv6.
pub const SIOCGLIFINDEX = IOWR('i', 133, lifreq);

pub const lif_nd_req = extern struct {
    addr: sockaddr.storage,
    state_create: u8,
    state_same_lla: u8,
    state_diff_lla: u8,
    hdw_len: i32,
    flags: i32,
    __pad: i32,
    hdw_addr: [64]u8,
};

pub const lif_ifinfo_req = extern struct {
    maxhops: u8,
    reachtime: u32,
    reachretrans: u32,
    maxmtu: u32,
};

/// IP interface request. See if_tcp(7p) for more info.
pub const lifreq = extern struct {
    // Not actually in a union, but the stdlib expects one for ifreq
    ifrn: extern union {
        /// Interface name, e.g. "lo0", "en0".
        name: [IFNAMESIZE]u8,
    },
    ru1: extern union {
        /// For subnet/token etc.
        addrlen: i32,
        /// Driver's PPA (physical point of attachment).
        ppa: u32,
    },
    /// One of the IFT types, e.g. IFT_ETHER.
    type: u32,
    ifru: extern union {
        /// Address.
        addr: sockaddr.storage,
        /// Other end of a peer-to-peer link.
        dstaddr: sockaddr.storage,
        /// Broadcast address.
        broadaddr: sockaddr.storage,
        /// Address token.
        token: sockaddr.storage,
        /// Subnet prefix.
        subnet: sockaddr.storage,
        /// Interface index.
        ivalue: i32,
        /// Flags for SIOC?LIFFLAGS.
        flags: u64,
        /// Hop count metric
        metric: i32,
        /// Maximum transmission unit
        mtu: u32,
        // Technically [2]i32
        muxid: packed struct { ip: i32, arp: i32 },
        /// Neighbor reachability determination entries
        nd_req: lif_nd_req,
        /// Link info
        ifinfo_req: lif_ifinfo_req,
        /// Name of the multipath interface group
        groupname: [IFNAMESIZE]u8,
        binding: [IFNAMESIZE]u8,
        /// Zone id associated with this interface.
        zoneid: zoneid_t,
        /// Duplicate address detection state. Either in progress or completed.
        dadstate: u32,
    },
};

const IoCtlCommand = enum(u32) {
    none = 0x20000000, // no parameters
    write = 0x40000000, // copy out parameters
    read = 0x80000000, // copy in parameters
    read_write = 0xc0000000,
};

fn ioImpl(cmd: IoCtlCommand, io_type: u8, nr: u8, comptime IOT: type) i32 {
    const size = @as(u32, @intCast(@as(u8, @truncate(@sizeOf(IOT))))) << 16;
    const t = @as(u32, @intCast(io_type)) << 8;
    return @as(i32, @bitCast(@intFromEnum(cmd) | size | t | nr));
}

pub fn IO(io_type: u8, nr: u8) i32 {
    return ioImpl(.none, io_type, nr, void);
}

pub fn IOR(io_type: u8, nr: u8, comptime IOT: type) i32 {
    return ioImpl(.write, io_type, nr, IOT);
}

pub fn IOW(io_type: u8, nr: u8, comptime IOT: type) i32 {
    return ioImpl(.read, io_type, nr, IOT);
}

pub fn IOWR(io_type: u8, nr: u8, comptime IOT: type) i32 {
    return ioImpl(.read_write, io_type, nr, IOT);
}
