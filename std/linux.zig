const arch = switch (@compile_var("arch")) {
    x86_64 => @import("linux_x86_64.zig"),
    i386 => @import("linux_i386.zig"),
    else => unreachable{},
};
const errno = @import("errno.zig");

pub const MMAP_PROT_NONE =  0;
pub const MMAP_PROT_READ =  1;
pub const MMAP_PROT_WRITE = 2;
pub const MMAP_PROT_EXEC =  4;

pub const MMAP_MAP_FILE =    0;
pub const MMAP_MAP_SHARED =  1;
pub const MMAP_MAP_PRIVATE = 2;
pub const MMAP_MAP_FIXED =   16;
pub const MMAP_MAP_ANON =    32;

pub const SIGHUP    = 1;
pub const SIGINT    = 2;
pub const SIGQUIT   = 3;
pub const SIGILL    = 4;
pub const SIGTRAP   = 5;
pub const SIGABRT   = 6;
pub const SIGIOT    = SIGABRT;
pub const SIGBUS    = 7;
pub const SIGFPE    = 8;
pub const SIGKILL   = 9;
pub const SIGUSR1   = 10;
pub const SIGSEGV   = 11;
pub const SIGUSR2   = 12;
pub const SIGPIPE   = 13;
pub const SIGALRM   = 14;
pub const SIGTERM   = 15;
pub const SIGSTKFLT = 16;
pub const SIGCHLD   = 17;
pub const SIGCONT   = 18;
pub const SIGSTOP   = 19;
pub const SIGTSTP   = 20;
pub const SIGTTIN   = 21;
pub const SIGTTOU   = 22;
pub const SIGURG    = 23;
pub const SIGXCPU   = 24;
pub const SIGXFSZ   = 25;
pub const SIGVTALRM = 26;
pub const SIGPROF   = 27;
pub const SIGWINCH  = 28;
pub const SIGIO     = 29;
pub const SIGPOLL   = 29;
pub const SIGPWR    = 30;
pub const SIGSYS    = 31;
pub const SIGUNUSED = SIGSYS;

pub const O_RDONLY = 0o0;
pub const O_WRONLY = 0o1;
pub const O_RDWR   = 0o2;

pub const O_CREAT = arch.O_CREAT;
pub const O_EXCL = arch.O_EXCL;
pub const O_NOCTTY = arch.O_NOCTTY;
pub const O_TRUNC = arch.O_TRUNC;
pub const O_APPEND = arch.O_APPEND;
pub const O_NONBLOCK = arch.O_NONBLOCK;
pub const O_DSYNC = arch.O_DSYNC;
pub const O_SYNC = arch.O_SYNC;
pub const O_RSYNC = arch.O_RSYNC;
pub const O_DIRECTORY = arch.O_DIRECTORY;
pub const O_NOFOLLOW = arch.O_NOFOLLOW;
pub const O_CLOEXEC = arch.O_CLOEXEC;

pub const O_ASYNC = arch.O_ASYNC;
pub const O_DIRECT = arch.O_DIRECT;
pub const O_LARGEFILE = arch.O_LARGEFILE;
pub const O_NOATIME = arch.O_NOATIME;
pub const O_PATH = arch.O_PATH;
pub const O_TMPFILE = arch.O_TMPFILE;
pub const O_NDELAY = arch.O_NDELAY;

const SIG_BLOCK   = 0;
const SIG_UNBLOCK = 1;
const SIG_SETMASK = 2;

pub const SOCK_STREAM = 1;
pub const SOCK_DGRAM = 2;
pub const SOCK_RAW = 3;
pub const SOCK_RDM = 4;
pub const SOCK_SEQPACKET = 5;
pub const SOCK_DCCP = 6;
pub const SOCK_PACKET = 10;
pub const SOCK_CLOEXEC = 0o2000000;
pub const SOCK_NONBLOCK = 0o4000;


pub const PROTO_ip = 0o000;
pub const PROTO_icmp = 0o001;
pub const PROTO_igmp = 0o002;
pub const PROTO_ggp = 0o003;
pub const PROTO_ipencap = 0o004;
pub const PROTO_st = 0o005;
pub const PROTO_tcp = 0o006;
pub const PROTO_egp = 0o010;
pub const PROTO_pup = 0o014;
pub const PROTO_udp = 0o021;
pub const PROTO_hmp = 0o024;
pub const PROTO_xns_idp = 0o026;
pub const PROTO_rdp = 0o033;
pub const PROTO_iso_tp4 = 0o035;
pub const PROTO_xtp = 0o044;
pub const PROTO_ddp = 0o045;
pub const PROTO_idpr_cmtp = 0o046;
pub const PROTO_ipv6 = 0o051;
pub const PROTO_ipv6_route = 0o053;
pub const PROTO_ipv6_frag = 0o054;
pub const PROTO_idrp = 0o055;
pub const PROTO_rsvp = 0o056;
pub const PROTO_gre = 0o057;
pub const PROTO_esp = 0o062;
pub const PROTO_ah = 0o063;
pub const PROTO_skip = 0o071;
pub const PROTO_ipv6_icmp = 0o072;
pub const PROTO_ipv6_nonxt = 0o073;
pub const PROTO_ipv6_opts = 0o074;
pub const PROTO_rspf = 0o111;
pub const PROTO_vmtp = 0o121;
pub const PROTO_ospf = 0o131;
pub const PROTO_ipip = 0o136;
pub const PROTO_encap = 0o142;
pub const PROTO_pim = 0o147;
pub const PROTO_raw = 0o377;

pub const PF_UNSPEC = 0;
pub const PF_LOCAL = 1;
pub const PF_UNIX = PF_LOCAL;
pub const PF_FILE = PF_LOCAL;
pub const PF_INET = 2;
pub const PF_AX25 = 3;
pub const PF_IPX = 4;
pub const PF_APPLETALK = 5;
pub const PF_NETROM = 6;
pub const PF_BRIDGE = 7;
pub const PF_ATMPVC = 8;
pub const PF_X25 = 9;
pub const PF_INET6 = 10;
pub const PF_ROSE = 11;
pub const PF_DECnet = 12;
pub const PF_NETBEUI = 13;
pub const PF_SECURITY = 14;
pub const PF_KEY = 15;
pub const PF_NETLINK = 16;
pub const PF_ROUTE = PF_NETLINK;
pub const PF_PACKET = 17;
pub const PF_ASH = 18;
pub const PF_ECONET = 19;
pub const PF_ATMSVC = 20;
pub const PF_RDS = 21;
pub const PF_SNA = 22;
pub const PF_IRDA = 23;
pub const PF_PPPOX = 24;
pub const PF_WANPIPE = 25;
pub const PF_LLC = 26;
pub const PF_IB = 27;
pub const PF_MPLS = 28;
pub const PF_CAN = 29;
pub const PF_TIPC = 30;
pub const PF_BLUETOOTH = 31;
pub const PF_IUCV = 32;
pub const PF_RXRPC = 33;
pub const PF_ISDN = 34;
pub const PF_PHONET = 35;
pub const PF_IEEE802154 = 36;
pub const PF_CAIF = 37;
pub const PF_ALG = 38;
pub const PF_NFC = 39;
pub const PF_VSOCK = 40;
pub const PF_MAX = 41;

pub const AF_UNSPEC = PF_UNSPEC;
pub const AF_LOCAL = PF_LOCAL;
pub const AF_UNIX = AF_LOCAL;
pub const AF_FILE = AF_LOCAL;
pub const AF_INET = PF_INET;
pub const AF_AX25 = PF_AX25;
pub const AF_IPX = PF_IPX;
pub const AF_APPLETALK = PF_APPLETALK;
pub const AF_NETROM = PF_NETROM;
pub const AF_BRIDGE = PF_BRIDGE;
pub const AF_ATMPVC = PF_ATMPVC;
pub const AF_X25 = PF_X25;
pub const AF_INET6 = PF_INET6;
pub const AF_ROSE = PF_ROSE;
pub const AF_DECnet = PF_DECnet;
pub const AF_NETBEUI = PF_NETBEUI;
pub const AF_SECURITY = PF_SECURITY;
pub const AF_KEY = PF_KEY;
pub const AF_NETLINK = PF_NETLINK;
pub const AF_ROUTE = PF_ROUTE;
pub const AF_PACKET = PF_PACKET;
pub const AF_ASH = PF_ASH;
pub const AF_ECONET = PF_ECONET;
pub const AF_ATMSVC = PF_ATMSVC;
pub const AF_RDS = PF_RDS;
pub const AF_SNA = PF_SNA;
pub const AF_IRDA = PF_IRDA;
pub const AF_PPPOX = PF_PPPOX;
pub const AF_WANPIPE = PF_WANPIPE;
pub const AF_LLC = PF_LLC;
pub const AF_IB = PF_IB;
pub const AF_MPLS = PF_MPLS;
pub const AF_CAN = PF_CAN;
pub const AF_TIPC = PF_TIPC;
pub const AF_BLUETOOTH = PF_BLUETOOTH;
pub const AF_IUCV = PF_IUCV;
pub const AF_RXRPC = PF_RXRPC;
pub const AF_ISDN = PF_ISDN;
pub const AF_PHONET = PF_PHONET;
pub const AF_IEEE802154 = PF_IEEE802154;
pub const AF_CAIF = PF_CAIF;
pub const AF_ALG = PF_ALG;
pub const AF_NFC = PF_NFC;
pub const AF_VSOCK = PF_VSOCK;
pub const AF_MAX = PF_MAX;

/// Get the errno from a syscall return value, or 0 for no error.
pub fn get_errno(r: isize) -> isize {
    if (r > -4096) -r else 0
}

pub fn mmap(address: ?&u8, length: isize, prot: isize, flags: isize, fd: isize, offset: isize) -> isize {
    // TODO ability to cast maybe pointer to isize
    const addr = if (const unwrapped ?= address) isize(unwrapped) else 0;
    arch.syscall6(arch.SYS_mmap, addr, length, prot, flags, fd, offset)
}

pub fn munmap(address: &u8, length: isize) -> isize {
    arch.syscall2(arch.SYS_munmap, isize(address), length)
}

pub fn read(fd: isize, buf: &u8, count: isize) -> isize {
    arch.syscall3(arch.SYS_read, isize(fd), isize(buf), count)
}

pub fn write(fd: isize, buf: &const u8, count: isize) -> isize {
    arch.syscall3(arch.SYS_write, isize(fd), isize(buf), count)
}

pub fn open(path: []u8, flags: isize, perm: isize) -> isize {
    var buf: [path.len + 1]u8 = undefined;
    @memcpy(&buf[0], &path[0], path.len);
    buf[path.len] = 0;
    arch.syscall3(arch.SYS_open, isize(&buf[0]), flags, perm)
}

pub fn create(path: []u8, perm: isize) -> isize {
    var buf: [path.len + 1]u8 = undefined;
    @memcpy(&buf[0], &path[0], path.len);
    buf[path.len] = 0;
    arch.syscall2(arch.SYS_creat, isize(&buf[0]), perm)
}

pub fn openat(dirfd: isize, path: []u8, flags: isize, mode: isize) -> isize {
    var buf: [path.len + 1]u8 = undefined;
    @memcpy(&buf[0], &path[0], path.len);
    buf[path.len] = 0;
    arch.syscall4(arch.SYS_openat, dirfd, isize(&buf[0]), flags, mode)
}

pub fn close(fd: isize) -> isize {
    arch.syscall1(arch.SYS_close, fd)
}

pub fn lseek(fd: isize, offset: isize, ref_pos: isize) -> isize {
    arch.syscall3(arch.SYS_lseek, fd, offset, ref_pos)
}

pub fn exit(status: i32) -> unreachable {
    arch.syscall1(arch.SYS_exit, isize(status));
    unreachable{}
}

pub fn getrandom(buf: &u8, count: isize, flags: u32) -> isize {
    arch.syscall3(arch.SYS_getrandom, isize(buf), count, isize(flags))
}

pub fn kill(pid: i32, sig: i32) -> i32 {
    i32(arch.syscall2(arch.SYS_kill, pid, sig))
}

const NSIG = 65;
const sigset_t = [128]u8;
const all_mask = []u8 { 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, };
const app_mask = []u8 { 0xff, 0xff, 0xff, 0xfc, 0x7f, 0xff, 0xff, 0xff, };

pub fn raise(sig: i32) -> i32 {
    var set: sigset_t = undefined;
    block_app_signals(&set);
    const tid = i32(arch.syscall0(arch.SYS_gettid));
    const ret = i32(arch.syscall2(arch.SYS_tkill, tid, sig));
    restore_signals(&set);
    return ret;
}

fn block_all_signals(set: &sigset_t) {
    arch.syscall4(arch.SYS_rt_sigprocmask, SIG_BLOCK, isize(&all_mask), isize(set), NSIG/8);
}

fn block_app_signals(set: &sigset_t) {
    arch.syscall4(arch.SYS_rt_sigprocmask, SIG_BLOCK, isize(&app_mask), isize(set), NSIG/8);
}

fn restore_signals(set: &sigset_t) {
    arch.syscall4(arch.SYS_rt_sigprocmask, SIG_SETMASK, isize(set), 0, NSIG/8);
}


pub const sa_family_t = u16;
pub const socklen_t = u32;
pub const in_addr = u32;
pub const in6_addr = [16]u8;

export struct sockaddr {
    family: sa_family_t,
    port: u16,
    data: [12]u8,
}

export struct sockaddr_in {
    family: sa_family_t,
    port: u16,
    addr: in_addr,
    zero: [8]u8,
}

export struct sockaddr_in6 {
    family: sa_family_t,
    port: u16,
    flowinfo: u32,
    addr: in6_addr,
    scope_id: u32,
}

export struct iovec {
    iov_base: &u8,
    iov_len: usize,
}

/*
const IF_NAMESIZE = 16;

export struct ifreq {
    ifrn_name: [IF_NAMESIZE]u8,
	union {
        ifru_addr: sockaddr,
        ifru_dstaddr: sockaddr,
        ifru_broadaddr: sockaddr,
        ifru_netmask: sockaddr,
        ifru_hwaddr: sockaddr,
        ifru_flags: i16,
        ifru_ivalue: i32,
        ifru_mtu: i32,
        ifru_map: ifmap,
        ifru_slave: [IF_NAMESIZE]u8,
        ifru_newname: [IF_NAMESIZE]u8,
        ifru_data: &u8,
	} ifr_ifru;
}
*/

pub fn getsockname(fd: i32, noalias addr: &sockaddr, noalias len: &socklen_t) -> isize {
    arch.syscall3(arch.SYS_getsockname, fd, isize(addr), isize(len))
}

pub fn getpeername(fd: i32, noalias addr: &sockaddr, noalias len: &socklen_t) -> isize {
    arch.syscall3(arch.SYS_getpeername, fd, isize(addr), isize(len))
}

pub fn socket(domain: i32, socket_type: i32, protocol: i32) -> isize {
    arch.syscall3(arch.SYS_socket, domain, socket_type, protocol)
}

pub fn setsockopt(fd: i32, level: i32, optname: i32, optval: &const u8, optlen: socklen_t) -> isize {
    arch.syscall5(arch.SYS_setsockopt, fd, level, optname, isize(optval), isize(optlen))
}

pub fn getsockopt(fd: i32, level: i32, optname: i32, noalias optval: &u8, noalias optlen: &socklen_t) -> isize {
    arch.syscall5(arch.SYS_getsockopt, fd, level, optname, isize(optval), isize(optlen))
}

pub fn sendmsg(fd: i32, msg: &const arch.msghdr, flags: i32) -> isize {
    arch.syscall3(arch.SYS_sendmsg, fd, isize(msg), flags)
}

pub fn connect(fd: i32, addr: &const sockaddr, len: socklen_t) -> isize {
    arch.syscall3(arch.SYS_connect, fd, isize(addr), isize(len))
}

pub fn accept(fd: i32, noalias addr: &sockaddr, noalias len: &socklen_t) -> isize {
    arch.syscall3(arch.SYS_accept, fd, isize(addr), isize(len))
}

pub fn recvmsg(fd: i32, msg: &arch.msghdr, flags: i32) -> isize {
    arch.syscall3(arch.SYS_recvmsg, fd, isize(msg), flags)
}

pub fn recvfrom(fd: i32, noalias buf: &u8, len: isize, flags: i32,
    noalias addr: ?&sockaddr, noalias alen: ?&socklen_t) -> isize
{
    arch.syscall6(arch.SYS_recvfrom, fd, isize(buf), len, flags, isize(addr), isize(alen))
}

pub fn shutdown(fd: i32, how: i32) -> isize {
    arch.syscall2(arch.SYS_shutdown, fd, how)
}

pub fn bind(fd: i32, addr: &const sockaddr, len: socklen_t) {
    arch.syscall3(arch.SYS_bind, fd, isize(addr), isize(len));
}

pub fn listen(fd: i32, backlog: i32) -> isize {
    arch.syscall2(arch.SYS_listen, fd, backlog)
}

pub fn sendto(fd: i32, buf: &const u8, len: isize, flags: i32, addr: ?&const sockaddr, alen: socklen_t) -> isize {
    arch.syscall6(arch.SYS_sendto, fd, isize(buf), len, flags, isize(addr), isize(alen))
}

pub fn socketpair(domain: i32, socket_type: i32, protocol: i32, fd: [2]i32) -> isize {
    arch.syscall4(arch.SYS_socketpair, domain, socket_type, protocol, isize(&fd[0]))
}

pub fn accept4(fd: i32, noalias addr: &sockaddr, noalias len: &socklen_t, flags: i32) -> isize {
    arch.syscall4(arch.SYS_accept4, fd, isize(addr), isize(len), flags)
}

/*
pub error NameTooLong;
pub error SystemResources;
pub error Io;

pub fn if_nametoindex(name: []u8) -> %u32 {
    var ifr: ifreq = undefined;

    if (name.len >= ifr.ifr_name.len) {
        return error.NameTooLong;
    }

    const socket_ret = socket(AF_UNIX, SOCK_DGRAM|SOCK_CLOEXEC, 0);
    const socket_err = get_errno(socket_ret);
    if (socket_err > 0) {
        return error.SystemResources;
    }
    const socket_fd = i32(socket_ret);
    @memcpy(&ifr.ifr_name[0], &name[0], name.len);
    ifr.ifr_name[name.len] = 0;
    const ioctl_ret = ioctl(socket_fd, SIOCGIFINDEX, &ifr);
    close(socket_fd);
    const ioctl_err = get_errno(ioctl_ret);
    if (ioctl_err > 0) {
        return error.Io;
    }
    return ifr.ifr_ifindex;
}
*/
