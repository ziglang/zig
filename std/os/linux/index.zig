const std = @import("../../index.zig");
const assert = std.debug.assert;
const builtin = @import("builtin");
const maxInt = std.math.maxInt;
const vdso = @import("vdso.zig");
pub use switch (builtin.arch) {
    builtin.Arch.x86_64 => @import("x86_64.zig"),
    builtin.Arch.i386 => @import("i386.zig"),
    builtin.Arch.aarch64v8 => @import("arm64.zig"),
    else => @compileError("unsupported arch"),
};
pub use @import("errno.zig");

pub const PATH_MAX = 4096;

pub const STDIN_FILENO = 0;
pub const STDOUT_FILENO = 1;
pub const STDERR_FILENO = 2;

pub const FUTEX_WAIT = 0;
pub const FUTEX_WAKE = 1;
pub const FUTEX_FD = 2;
pub const FUTEX_REQUEUE = 3;
pub const FUTEX_CMP_REQUEUE = 4;
pub const FUTEX_WAKE_OP = 5;
pub const FUTEX_LOCK_PI = 6;
pub const FUTEX_UNLOCK_PI = 7;
pub const FUTEX_TRYLOCK_PI = 8;
pub const FUTEX_WAIT_BITSET = 9;

pub const FUTEX_PRIVATE_FLAG = 128;

pub const FUTEX_CLOCK_REALTIME = 256;

pub const PROT_NONE = 0;
pub const PROT_READ = 1;
pub const PROT_WRITE = 2;
pub const PROT_EXEC = 4;
pub const PROT_GROWSDOWN = 0x01000000;
pub const PROT_GROWSUP = 0x02000000;

pub const MAP_FAILED = maxInt(usize);
pub const MAP_SHARED = 0x01;
pub const MAP_PRIVATE = 0x02;
pub const MAP_TYPE = 0x0f;
pub const MAP_FIXED = 0x10;
pub const MAP_ANONYMOUS = 0x20;
pub const MAP_NORESERVE = 0x4000;
pub const MAP_GROWSDOWN = 0x0100;
pub const MAP_DENYWRITE = 0x0800;
pub const MAP_EXECUTABLE = 0x1000;
pub const MAP_LOCKED = 0x2000;
pub const MAP_POPULATE = 0x8000;
pub const MAP_NONBLOCK = 0x10000;
pub const MAP_STACK = 0x20000;
pub const MAP_HUGETLB = 0x40000;
pub const MAP_FILE = 0;

pub const F_OK = 0;
pub const X_OK = 1;
pub const W_OK = 2;
pub const R_OK = 4;

pub const WNOHANG = 1;
pub const WUNTRACED = 2;
pub const WSTOPPED = 2;
pub const WEXITED = 4;
pub const WCONTINUED = 8;
pub const WNOWAIT = 0x1000000;

pub const SA_NOCLDSTOP = 1;
pub const SA_NOCLDWAIT = 2;
pub const SA_SIGINFO = 4;
pub const SA_ONSTACK = 0x08000000;
pub const SA_RESTART = 0x10000000;
pub const SA_NODEFER = 0x40000000;
pub const SA_RESETHAND = 0x80000000;
pub const SA_RESTORER = 0x04000000;

pub const SIGHUP = 1;
pub const SIGINT = 2;
pub const SIGQUIT = 3;
pub const SIGILL = 4;
pub const SIGTRAP = 5;
pub const SIGABRT = 6;
pub const SIGIOT = SIGABRT;
pub const SIGBUS = 7;
pub const SIGFPE = 8;
pub const SIGKILL = 9;
pub const SIGUSR1 = 10;
pub const SIGSEGV = 11;
pub const SIGUSR2 = 12;
pub const SIGPIPE = 13;
pub const SIGALRM = 14;
pub const SIGTERM = 15;
pub const SIGSTKFLT = 16;
pub const SIGCHLD = 17;
pub const SIGCONT = 18;
pub const SIGSTOP = 19;
pub const SIGTSTP = 20;
pub const SIGTTIN = 21;
pub const SIGTTOU = 22;
pub const SIGURG = 23;
pub const SIGXCPU = 24;
pub const SIGXFSZ = 25;
pub const SIGVTALRM = 26;
pub const SIGPROF = 27;
pub const SIGWINCH = 28;
pub const SIGIO = 29;
pub const SIGPOLL = 29;
pub const SIGPWR = 30;
pub const SIGSYS = 31;
pub const SIGUNUSED = SIGSYS;

pub const O_RDONLY = 0o0;
pub const O_WRONLY = 0o1;
pub const O_RDWR = 0o2;

pub const SEEK_SET = 0;
pub const SEEK_CUR = 1;
pub const SEEK_END = 2;

pub const SIG_BLOCK = 0;
pub const SIG_UNBLOCK = 1;
pub const SIG_SETMASK = 2;

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

pub const SHUT_RD = 0;
pub const SHUT_WR = 1;
pub const SHUT_RDWR = 2;

pub const SOCK_STREAM = 1;
pub const SOCK_DGRAM = 2;
pub const SOCK_RAW = 3;
pub const SOCK_RDM = 4;
pub const SOCK_SEQPACKET = 5;
pub const SOCK_DCCP = 6;
pub const SOCK_PACKET = 10;
pub const SOCK_CLOEXEC = 0o2000000;
pub const SOCK_NONBLOCK = 0o4000;

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
pub const PF_KCM = 41;
pub const PF_QIPCRTR = 42;
pub const PF_SMC = 43;
pub const PF_MAX = 44;

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
pub const AF_KCM = PF_KCM;
pub const AF_QIPCRTR = PF_QIPCRTR;
pub const AF_SMC = PF_SMC;
pub const AF_MAX = PF_MAX;

pub const SO_DEBUG = 1;
pub const SO_REUSEADDR = 2;
pub const SO_TYPE = 3;
pub const SO_ERROR = 4;
pub const SO_DONTROUTE = 5;
pub const SO_BROADCAST = 6;
pub const SO_SNDBUF = 7;
pub const SO_RCVBUF = 8;
pub const SO_KEEPALIVE = 9;
pub const SO_OOBINLINE = 10;
pub const SO_NO_CHECK = 11;
pub const SO_PRIORITY = 12;
pub const SO_LINGER = 13;
pub const SO_BSDCOMPAT = 14;
pub const SO_REUSEPORT = 15;
pub const SO_PASSCRED = 16;
pub const SO_PEERCRED = 17;
pub const SO_RCVLOWAT = 18;
pub const SO_SNDLOWAT = 19;
pub const SO_RCVTIMEO = 20;
pub const SO_SNDTIMEO = 21;
pub const SO_ACCEPTCONN = 30;
pub const SO_SNDBUFFORCE = 32;
pub const SO_RCVBUFFORCE = 33;
pub const SO_PROTOCOL = 38;
pub const SO_DOMAIN = 39;

pub const SO_SECURITY_AUTHENTICATION = 22;
pub const SO_SECURITY_ENCRYPTION_TRANSPORT = 23;
pub const SO_SECURITY_ENCRYPTION_NETWORK = 24;

pub const SO_BINDTODEVICE = 25;

pub const SO_ATTACH_FILTER = 26;
pub const SO_DETACH_FILTER = 27;
pub const SO_GET_FILTER = SO_ATTACH_FILTER;

pub const SO_PEERNAME = 28;
pub const SO_TIMESTAMP = 29;
pub const SCM_TIMESTAMP = SO_TIMESTAMP;

pub const SO_PEERSEC = 31;
pub const SO_PASSSEC = 34;
pub const SO_TIMESTAMPNS = 35;
pub const SCM_TIMESTAMPNS = SO_TIMESTAMPNS;
pub const SO_MARK = 36;
pub const SO_TIMESTAMPING = 37;
pub const SCM_TIMESTAMPING = SO_TIMESTAMPING;
pub const SO_RXQ_OVFL = 40;
pub const SO_WIFI_STATUS = 41;
pub const SCM_WIFI_STATUS = SO_WIFI_STATUS;
pub const SO_PEEK_OFF = 42;
pub const SO_NOFCS = 43;
pub const SO_LOCK_FILTER = 44;
pub const SO_SELECT_ERR_QUEUE = 45;
pub const SO_BUSY_POLL = 46;
pub const SO_MAX_PACING_RATE = 47;
pub const SO_BPF_EXTENSIONS = 48;
pub const SO_INCOMING_CPU = 49;
pub const SO_ATTACH_BPF = 50;
pub const SO_DETACH_BPF = SO_DETACH_FILTER;
pub const SO_ATTACH_REUSEPORT_CBPF = 51;
pub const SO_ATTACH_REUSEPORT_EBPF = 52;
pub const SO_CNX_ADVICE = 53;
pub const SCM_TIMESTAMPING_OPT_STATS = 54;
pub const SO_MEMINFO = 55;
pub const SO_INCOMING_NAPI_ID = 56;
pub const SO_COOKIE = 57;
pub const SCM_TIMESTAMPING_PKTINFO = 58;
pub const SO_PEERGROUPS = 59;
pub const SO_ZEROCOPY = 60;

pub const SOL_SOCKET = 1;

pub const SOL_IP = 0;
pub const SOL_IPV6 = 41;
pub const SOL_ICMPV6 = 58;

pub const SOL_RAW = 255;
pub const SOL_DECNET = 261;
pub const SOL_X25 = 262;
pub const SOL_PACKET = 263;
pub const SOL_ATM = 264;
pub const SOL_AAL = 265;
pub const SOL_IRDA = 266;
pub const SOL_NETBEUI = 267;
pub const SOL_LLC = 268;
pub const SOL_DCCP = 269;
pub const SOL_NETLINK = 270;
pub const SOL_TIPC = 271;
pub const SOL_RXRPC = 272;
pub const SOL_PPPOL2TP = 273;
pub const SOL_BLUETOOTH = 274;
pub const SOL_PNPIPE = 275;
pub const SOL_RDS = 276;
pub const SOL_IUCV = 277;
pub const SOL_CAIF = 278;
pub const SOL_ALG = 279;
pub const SOL_NFC = 280;
pub const SOL_KCM = 281;
pub const SOL_TLS = 282;

pub const SOMAXCONN = 128;

pub const MSG_OOB = 0x0001;
pub const MSG_PEEK = 0x0002;
pub const MSG_DONTROUTE = 0x0004;
pub const MSG_CTRUNC = 0x0008;
pub const MSG_PROXY = 0x0010;
pub const MSG_TRUNC = 0x0020;
pub const MSG_DONTWAIT = 0x0040;
pub const MSG_EOR = 0x0080;
pub const MSG_WAITALL = 0x0100;
pub const MSG_FIN = 0x0200;
pub const MSG_SYN = 0x0400;
pub const MSG_CONFIRM = 0x0800;
pub const MSG_RST = 0x1000;
pub const MSG_ERRQUEUE = 0x2000;
pub const MSG_NOSIGNAL = 0x4000;
pub const MSG_MORE = 0x8000;
pub const MSG_WAITFORONE = 0x10000;
pub const MSG_BATCH = 0x40000;
pub const MSG_ZEROCOPY = 0x4000000;
pub const MSG_FASTOPEN = 0x20000000;
pub const MSG_CMSG_CLOEXEC = 0x40000000;

pub const DT_UNKNOWN = 0;
pub const DT_FIFO = 1;
pub const DT_CHR = 2;
pub const DT_DIR = 4;
pub const DT_BLK = 6;
pub const DT_REG = 8;
pub const DT_LNK = 10;
pub const DT_SOCK = 12;
pub const DT_WHT = 14;

pub const TCGETS = 0x5401;
pub const TCSETS = 0x5402;
pub const TCSETSW = 0x5403;
pub const TCSETSF = 0x5404;
pub const TCGETA = 0x5405;
pub const TCSETA = 0x5406;
pub const TCSETAW = 0x5407;
pub const TCSETAF = 0x5408;
pub const TCSBRK = 0x5409;
pub const TCXONC = 0x540A;
pub const TCFLSH = 0x540B;
pub const TIOCEXCL = 0x540C;
pub const TIOCNXCL = 0x540D;
pub const TIOCSCTTY = 0x540E;
pub const TIOCGPGRP = 0x540F;
pub const TIOCSPGRP = 0x5410;
pub const TIOCOUTQ = 0x5411;
pub const TIOCSTI = 0x5412;
pub const TIOCGWINSZ = 0x5413;
pub const TIOCSWINSZ = 0x5414;
pub const TIOCMGET = 0x5415;
pub const TIOCMBIS = 0x5416;
pub const TIOCMBIC = 0x5417;
pub const TIOCMSET = 0x5418;
pub const TIOCGSOFTCAR = 0x5419;
pub const TIOCSSOFTCAR = 0x541A;
pub const FIONREAD = 0x541B;
pub const TIOCINQ = FIONREAD;
pub const TIOCLINUX = 0x541C;
pub const TIOCCONS = 0x541D;
pub const TIOCGSERIAL = 0x541E;
pub const TIOCSSERIAL = 0x541F;
pub const TIOCPKT = 0x5420;
pub const FIONBIO = 0x5421;
pub const TIOCNOTTY = 0x5422;
pub const TIOCSETD = 0x5423;
pub const TIOCGETD = 0x5424;
pub const TCSBRKP = 0x5425;
pub const TIOCSBRK = 0x5427;
pub const TIOCCBRK = 0x5428;
pub const TIOCGSID = 0x5429;
pub const TIOCGRS485 = 0x542E;
pub const TIOCSRS485 = 0x542F;
pub const TIOCGPTN = 0x80045430;
pub const TIOCSPTLCK = 0x40045431;
pub const TIOCGDEV = 0x80045432;
pub const TCGETX = 0x5432;
pub const TCSETX = 0x5433;
pub const TCSETXF = 0x5434;
pub const TCSETXW = 0x5435;
pub const TIOCSIG = 0x40045436;
pub const TIOCVHANGUP = 0x5437;
pub const TIOCGPKT = 0x80045438;
pub const TIOCGPTLCK = 0x80045439;
pub const TIOCGEXCL = 0x80045440;

pub const EPOLL_CLOEXEC = O_CLOEXEC;

pub const EPOLL_CTL_ADD = 1;
pub const EPOLL_CTL_DEL = 2;
pub const EPOLL_CTL_MOD = 3;

pub const EPOLLIN = 0x001;
pub const EPOLLPRI = 0x002;
pub const EPOLLOUT = 0x004;
pub const EPOLLRDNORM = 0x040;
pub const EPOLLRDBAND = 0x080;
pub const EPOLLWRNORM = 0x100;
pub const EPOLLWRBAND = 0x200;
pub const EPOLLMSG = 0x400;
pub const EPOLLERR = 0x008;
pub const EPOLLHUP = 0x010;
pub const EPOLLRDHUP = 0x2000;
pub const EPOLLEXCLUSIVE = (u32(1) << 28);
pub const EPOLLWAKEUP = (u32(1) << 29);
pub const EPOLLONESHOT = (u32(1) << 30);
pub const EPOLLET = (u32(1) << 31);

pub const CLOCK_REALTIME = 0;
pub const CLOCK_MONOTONIC = 1;
pub const CLOCK_PROCESS_CPUTIME_ID = 2;
pub const CLOCK_THREAD_CPUTIME_ID = 3;
pub const CLOCK_MONOTONIC_RAW = 4;
pub const CLOCK_REALTIME_COARSE = 5;
pub const CLOCK_MONOTONIC_COARSE = 6;
pub const CLOCK_BOOTTIME = 7;
pub const CLOCK_REALTIME_ALARM = 8;
pub const CLOCK_BOOTTIME_ALARM = 9;
pub const CLOCK_SGI_CYCLE = 10;
pub const CLOCK_TAI = 11;

pub const CSIGNAL = 0x000000ff;
pub const CLONE_VM = 0x00000100;
pub const CLONE_FS = 0x00000200;
pub const CLONE_FILES = 0x00000400;
pub const CLONE_SIGHAND = 0x00000800;
pub const CLONE_PTRACE = 0x00002000;
pub const CLONE_VFORK = 0x00004000;
pub const CLONE_PARENT = 0x00008000;
pub const CLONE_THREAD = 0x00010000;
pub const CLONE_NEWNS = 0x00020000;
pub const CLONE_SYSVSEM = 0x00040000;
pub const CLONE_SETTLS = 0x00080000;
pub const CLONE_PARENT_SETTID = 0x00100000;
pub const CLONE_CHILD_CLEARTID = 0x00200000;
pub const CLONE_DETACHED = 0x00400000;
pub const CLONE_UNTRACED = 0x00800000;
pub const CLONE_CHILD_SETTID = 0x01000000;
pub const CLONE_NEWCGROUP = 0x02000000;
pub const CLONE_NEWUTS = 0x04000000;
pub const CLONE_NEWIPC = 0x08000000;
pub const CLONE_NEWUSER = 0x10000000;
pub const CLONE_NEWPID = 0x20000000;
pub const CLONE_NEWNET = 0x40000000;
pub const CLONE_IO = 0x80000000;

pub const EFD_SEMAPHORE = 1;
pub const EFD_CLOEXEC = O_CLOEXEC;
pub const EFD_NONBLOCK = O_NONBLOCK;

pub const MS_RDONLY = 1;
pub const MS_NOSUID = 2;
pub const MS_NODEV = 4;
pub const MS_NOEXEC = 8;
pub const MS_SYNCHRONOUS = 16;
pub const MS_REMOUNT = 32;
pub const MS_MANDLOCK = 64;
pub const MS_DIRSYNC = 128;
pub const MS_NOATIME = 1024;
pub const MS_NODIRATIME = 2048;
pub const MS_BIND = 4096;
pub const MS_MOVE = 8192;
pub const MS_REC = 16384;
pub const MS_SILENT = 32768;
pub const MS_POSIXACL = (1 << 16);
pub const MS_UNBINDABLE = (1 << 17);
pub const MS_PRIVATE = (1 << 18);
pub const MS_SLAVE = (1 << 19);
pub const MS_SHARED = (1 << 20);
pub const MS_RELATIME = (1 << 21);
pub const MS_KERNMOUNT = (1 << 22);
pub const MS_I_VERSION = (1 << 23);
pub const MS_STRICTATIME = (1 << 24);
pub const MS_LAZYTIME = (1 << 25);
pub const MS_NOREMOTELOCK = (1 << 27);
pub const MS_NOSEC = (1 << 28);
pub const MS_BORN = (1 << 29);
pub const MS_ACTIVE = (1 << 30);
pub const MS_NOUSER = (1 << 31);

pub const MS_RMT_MASK = (MS_RDONLY | MS_SYNCHRONOUS | MS_MANDLOCK | MS_I_VERSION | MS_LAZYTIME);

pub const MS_MGC_VAL = 0xc0ed0000;
pub const MS_MGC_MSK = 0xffff0000;

pub const MNT_FORCE = 1;
pub const MNT_DETACH = 2;
pub const MNT_EXPIRE = 4;
pub const UMOUNT_NOFOLLOW = 8;

pub const IN_CLOEXEC = O_CLOEXEC;
pub const IN_NONBLOCK = O_NONBLOCK;

pub const IN_ACCESS = 0x00000001;
pub const IN_MODIFY = 0x00000002;
pub const IN_ATTRIB = 0x00000004;
pub const IN_CLOSE_WRITE = 0x00000008;
pub const IN_CLOSE_NOWRITE = 0x00000010;
pub const IN_CLOSE = IN_CLOSE_WRITE | IN_CLOSE_NOWRITE;
pub const IN_OPEN = 0x00000020;
pub const IN_MOVED_FROM = 0x00000040;
pub const IN_MOVED_TO = 0x00000080;
pub const IN_MOVE = IN_MOVED_FROM | IN_MOVED_TO;
pub const IN_CREATE = 0x00000100;
pub const IN_DELETE = 0x00000200;
pub const IN_DELETE_SELF = 0x00000400;
pub const IN_MOVE_SELF = 0x00000800;
pub const IN_ALL_EVENTS = 0x00000fff;

pub const IN_UNMOUNT = 0x00002000;
pub const IN_Q_OVERFLOW = 0x00004000;
pub const IN_IGNORED = 0x00008000;

pub const IN_ONLYDIR = 0x01000000;
pub const IN_DONT_FOLLOW = 0x02000000;
pub const IN_EXCL_UNLINK = 0x04000000;
pub const IN_MASK_ADD = 0x20000000;

pub const IN_ISDIR = 0x40000000;
pub const IN_ONESHOT = 0x80000000;

pub const S_IFMT = 0o170000;

pub const S_IFDIR = 0o040000;
pub const S_IFCHR = 0o020000;
pub const S_IFBLK = 0o060000;
pub const S_IFREG = 0o100000;
pub const S_IFIFO = 0o010000;
pub const S_IFLNK = 0o120000;
pub const S_IFSOCK = 0o140000;

pub const S_ISUID = 0o4000;
pub const S_ISGID = 0o2000;
pub const S_ISVTX = 0o1000;
pub const S_IRUSR = 0o400;
pub const S_IWUSR = 0o200;
pub const S_IXUSR = 0o100;
pub const S_IRWXU = 0o700;
pub const S_IRGRP = 0o040;
pub const S_IWGRP = 0o020;
pub const S_IXGRP = 0o010;
pub const S_IRWXG = 0o070;
pub const S_IROTH = 0o004;
pub const S_IWOTH = 0o002;
pub const S_IXOTH = 0o001;
pub const S_IRWXO = 0o007;

pub fn S_ISREG(m: u32) bool {
    return m & S_IFMT == S_IFREG;
}

pub fn S_ISDIR(m: u32) bool {
    return m & S_IFMT == S_IFDIR;
}

pub fn S_ISCHR(m: u32) bool {
    return m & S_IFMT == S_IFCHR;
}

pub fn S_ISBLK(m: u32) bool {
    return m & S_IFMT == S_IFBLK;
}

pub fn S_ISFIFO(m: u32) bool {
    return m & S_IFMT == S_IFIFO;
}

pub fn S_ISLNK(m: u32) bool {
    return m & S_IFMT == S_IFLNK;
}

pub fn S_ISSOCK(m: u32) bool {
    return m & S_IFMT == S_IFSOCK;
}

pub const TFD_NONBLOCK = O_NONBLOCK;
pub const TFD_CLOEXEC = O_CLOEXEC;

pub const TFD_TIMER_ABSTIME = 1;
pub const TFD_TIMER_CANCEL_ON_SET = (1 << 1);

fn unsigned(s: i32) u32 {
    return @bitCast(u32, s);
}
fn signed(s: u32) i32 {
    return @bitCast(i32, s);
}
pub fn WEXITSTATUS(s: i32) i32 {
    return signed((unsigned(s) & 0xff00) >> 8);
}
pub fn WTERMSIG(s: i32) i32 {
    return signed(unsigned(s) & 0x7f);
}
pub fn WSTOPSIG(s: i32) i32 {
    return WEXITSTATUS(s);
}
pub fn WIFEXITED(s: i32) bool {
    return WTERMSIG(s) == 0;
}
pub fn WIFSTOPPED(s: i32) bool {
    return @intCast(u16, ((unsigned(s) & 0xffff) *% 0x10001) >> 8) > 0x7f00;
}
pub fn WIFSIGNALED(s: i32) bool {
    return (unsigned(s) & 0xffff) -% 1 < 0xff;
}

pub const winsize = extern struct {
    ws_row: u16,
    ws_col: u16,
    ws_xpixel: u16,
    ws_ypixel: u16,
};

/// Get the errno from a syscall return value, or 0 for no error.
pub fn getErrno(r: usize) usize {
    const signed_r = @bitCast(isize, r);
    return if (signed_r > -4096 and signed_r < 0) @intCast(usize, -signed_r) else 0;
}

pub fn dup2(old: i32, new: i32) usize {
    return dup3(old, new, 0);
}

pub fn dup3(old: i32, new: i32, flags: u32) usize {
    return syscall3(SYS_dup3, @bitCast(usize, isize(old)), @bitCast(usize, isize(new)), flags);
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn chdir(path: [*]const u8) usize {
    return syscall1(SYS_chdir, @ptrToInt(path));
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn chroot(path: [*]const u8) usize {
    return syscall1(SYS_chroot, @ptrToInt(path));
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn execve(path: [*]const u8, argv: [*]const ?[*]const u8, envp: [*]const ?[*]const u8) usize {
    return syscall3(SYS_execve, @ptrToInt(path), @ptrToInt(argv), @ptrToInt(envp));
}

pub fn fork() usize {
    return clone2(SIGCHLD, 0);
}

/// This must be inline, and inline call the syscall function, because if the
/// child does a return it will clobber the parent's stack.
/// It is advised to avoid this function and use clone instead, because
/// the compiler is not aware of how vfork affects control flow and you may
/// see different results in optimized builds.
pub inline fn vfork() usize {
    return @inlineCall(syscall0, SYS_vfork);
}

pub fn futex_wait(uaddr: *const i32, futex_op: u32, val: i32, timeout: ?*timespec) usize {
    return syscall4(SYS_futex, @ptrToInt(uaddr), futex_op, @bitCast(u32, val), @ptrToInt(timeout));
}

pub fn futex_wake(uaddr: *const i32, futex_op: u32, val: i32) usize {
    return syscall3(SYS_futex, @ptrToInt(uaddr), futex_op, @bitCast(u32, val));
}

pub fn getcwd(buf: [*]u8, size: usize) usize {
    return syscall2(SYS_getcwd, @ptrToInt(buf), size);
}

pub fn getdents64(fd: i32, dirp: [*]u8, count: usize) usize {
    return syscall3(SYS_getdents64, @bitCast(usize, isize(fd)), @ptrToInt(dirp), count);
}

pub fn inotify_init1(flags: u32) usize {
    return syscall1(SYS_inotify_init1, flags);
}

pub fn inotify_add_watch(fd: i32, pathname: [*]const u8, mask: u32) usize {
    return syscall3(SYS_inotify_add_watch, @bitCast(usize, isize(fd)), @ptrToInt(pathname), mask);
}

pub fn inotify_rm_watch(fd: i32, wd: i32) usize {
    return syscall2(SYS_inotify_rm_watch, @bitCast(usize, isize(fd)), @bitCast(usize, isize(wd)));
}

pub fn isatty(fd: i32) bool {
    var wsz: winsize = undefined;
    return syscall3(SYS_ioctl, @bitCast(usize, isize(fd)), TIOCGWINSZ, @ptrToInt(&wsz)) == 0;
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn readlink(noalias path: [*]const u8, noalias buf_ptr: [*]u8, buf_len: usize) usize {
    return readlinkat(AT_FDCWD, path, buf_ptr, buf_len);
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn readlinkat(dirfd: i32, noalias path: [*]const u8, noalias buf_ptr: [*]u8, buf_len: usize) usize {
    return syscall4(SYS_readlinkat, @bitCast(usize, isize(dirfd)), @ptrToInt(path), @ptrToInt(buf_ptr), buf_len);
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn mkdir(path: [*]const u8, mode: u32) usize {
    return mkdirat(AT_FDCWD, path, mode);
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn mkdirat(dirfd: i32, path: [*]const u8, mode: u32) usize {
    return syscall3(SYS_mkdirat, @bitCast(usize, isize(dirfd)), @ptrToInt(path), mode);
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn mount(special: [*]const u8, dir: [*]const u8, fstype: [*]const u8, flags: u32, data: usize) usize {
    return syscall5(SYS_mount, @ptrToInt(special), @ptrToInt(dir), @ptrToInt(fstype), flags, data);
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn umount(special: [*]const u8) usize {
    return syscall2(SYS_umount2, @ptrToInt(special), 0);
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn umount2(special: [*]const u8, flags: u32) usize {
    return syscall2(SYS_umount2, @ptrToInt(special), flags);
}

pub fn mmap(address: ?[*]u8, length: usize, prot: usize, flags: u32, fd: i32, offset: isize) usize {
    return syscall6(SYS_mmap, @ptrToInt(address), length, prot, flags, @bitCast(usize, isize(fd)), @bitCast(usize, offset));
}

pub fn munmap(address: usize, length: usize) usize {
    return syscall2(SYS_munmap, address, length);
}

pub fn read(fd: i32, buf: [*]u8, count: usize) usize {
    return syscall3(SYS_read, @bitCast(usize, isize(fd)), @ptrToInt(buf), count);
}

pub fn preadv(fd: i32, iov: [*]const iovec, count: usize, offset: u64) usize {
    return syscall4(SYS_preadv, @bitCast(usize, isize(fd)), @ptrToInt(iov), count, offset);
}

pub fn readv(fd: i32, iov: [*]const iovec, count: usize) usize {
    return syscall3(SYS_readv, @bitCast(usize, isize(fd)), @ptrToInt(iov), count);
}

pub fn writev(fd: i32, iov: [*]const iovec_const, count: usize) usize {
    return syscall3(SYS_writev, @bitCast(usize, isize(fd)), @ptrToInt(iov), count);
}

pub fn pwritev(fd: i32, iov: [*]const iovec_const, count: usize, offset: u64) usize {
    return syscall4(SYS_pwritev, @bitCast(usize, isize(fd)), @ptrToInt(iov), count, offset);
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn rmdir(path: [*]const u8) usize {
    return unlinkat(AT_FDCWD, path, AT_REMOVEDIR);
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn symlink(existing: [*]const u8, new: [*]const u8) usize {
    return symlinkat(existing, AT_FDCWD, new);
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn symlinkat(existing: [*]const u8, newfd: i32, newpath: [*]const u8) usize {
    return syscall3(SYS_symlinkat, @ptrToInt(existing), @bitCast(usize, isize(newfd)), @ptrToInt(newpath));
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn pread(fd: i32, buf: [*]u8, count: usize, offset: usize) usize {
    return syscall4(SYS_pread, @bitCast(usize, isize(fd)), @ptrToInt(buf), count, offset);
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn access(path: [*]const u8, mode: u32) usize {
    return faccessat(AT_FDCWD, path, mode);
}

pub fn faccessat(dirfd: i32, path: [*]const u8, mode: u32) usize {
    return syscall3(SYS_faccessat, @bitCast(usize, isize(dirfd)), @ptrToInt(path), mode);
}

pub fn pipe(fd: *[2]i32) usize {
    return pipe2(fd, 0);
}

pub fn pipe2(fd: *[2]i32, flags: u32) usize {
    return syscall2(SYS_pipe2, @ptrToInt(fd), flags);
}

pub fn write(fd: i32, buf: [*]const u8, count: usize) usize {
    return syscall3(SYS_write, @bitCast(usize, isize(fd)), @ptrToInt(buf), count);
}

pub fn pwrite(fd: i32, buf: [*]const u8, count: usize, offset: usize) usize {
    return syscall4(SYS_pwrite, @bitCast(usize, isize(fd)), @ptrToInt(buf), count, offset);
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn rename(old: [*]const u8, new: [*]const u8) usize {
    return renameat2(AT_FDCWD, old, AT_FDCWD, new, 0);
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn renameat2(oldfd: i32, oldpath: [*]const u8, newfd: i32, newpath: [*]const u8, flags: u32) usize {
    return syscall5(SYS_renameat2, @bitCast(usize, isize(oldfd)), @ptrToInt(oldpath), @bitCast(usize, isize(newfd)), @ptrToInt(newpath), flags);
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn open(path: [*]const u8, flags: u32, perm: usize) usize {
    return openat(AT_FDCWD, path, flags, perm);
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn create(path: [*]const u8, perm: usize) usize {
    return syscall2(SYS_creat, @ptrToInt(path), perm);
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn openat(dirfd: i32, path: [*]const u8, flags: u32, mode: usize) usize {
    // dirfd could be negative, for example AT_FDCWD is -100
    return syscall4(SYS_openat, @bitCast(usize, isize(dirfd)), @ptrToInt(path), flags, mode);
}

/// See also `clone` (from the arch-specific include)
pub fn clone5(flags: usize, child_stack_ptr: usize, parent_tid: *i32, child_tid: *i32, newtls: usize) usize {
    return syscall5(SYS_clone, flags, child_stack_ptr, @ptrToInt(parent_tid), @ptrToInt(child_tid), newtls);
}

/// See also `clone` (from the arch-specific include)
pub fn clone2(flags: u32, child_stack_ptr: usize) usize {
    return syscall2(SYS_clone, flags, child_stack_ptr);
}

pub fn close(fd: i32) usize {
    return syscall1(SYS_close, @bitCast(usize, isize(fd)));
}

pub fn lseek(fd: i32, offset: isize, ref_pos: usize) usize {
    return syscall3(SYS_lseek, @bitCast(usize, isize(fd)), @bitCast(usize, offset), ref_pos);
}

pub fn exit(status: i32) noreturn {
    _ = syscall1(SYS_exit, @bitCast(usize, isize(status)));
    unreachable;
}

pub fn exit_group(status: i32) noreturn {
    _ = syscall1(SYS_exit_group, @bitCast(usize, isize(status)));
    unreachable;
}

pub fn getrandom(buf: [*]u8, count: usize, flags: u32) usize {
    return syscall3(SYS_getrandom, @ptrToInt(buf), count, flags);
}

pub fn kill(pid: i32, sig: i32) usize {
    return syscall2(SYS_kill, @bitCast(usize, isize(pid)), @bitCast(usize, isize(sig)));
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn unlink(path: [*]const u8) usize {
    return unlinkat(AT_FDCWD, path, 0);
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn unlinkat(dirfd: i32, path: [*]const u8, flags: u32) usize {
    return syscall3(SYS_unlinkat, @bitCast(usize, isize(dirfd)), @ptrToInt(path), flags);
}

pub fn waitpid(pid: i32, status: *i32, options: i32) usize {
    return syscall4(SYS_wait4, @bitCast(usize, isize(pid)), @ptrToInt(status), @bitCast(usize, isize(options)), 0);
}

pub fn clock_gettime(clk_id: i32, tp: *timespec) usize {
    if (VDSO_CGT_SYM.len != 0) {
        const f = @atomicLoad(@typeOf(init_vdso_clock_gettime), &vdso_clock_gettime, builtin.AtomicOrder.Unordered);
        if (@ptrToInt(f) != 0) {
            const rc = f(clk_id, tp);
            switch (rc) {
                0, @bitCast(usize, isize(-EINVAL)) => return rc,
                else => {},
            }
        }
    }
    return syscall2(SYS_clock_gettime, @bitCast(usize, isize(clk_id)), @ptrToInt(tp));
}
var vdso_clock_gettime = init_vdso_clock_gettime;
extern fn init_vdso_clock_gettime(clk: i32, ts: *timespec) usize {
    const addr = vdso.lookup(VDSO_CGT_VER, VDSO_CGT_SYM);
    var f = @intToPtr(@typeOf(init_vdso_clock_gettime), addr);
    _ = @cmpxchgStrong(@typeOf(init_vdso_clock_gettime), &vdso_clock_gettime, init_vdso_clock_gettime, f, builtin.AtomicOrder.Monotonic, builtin.AtomicOrder.Monotonic);
    if (@ptrToInt(f) == 0) return @bitCast(usize, isize(-ENOSYS));
    return f(clk, ts);
}

pub fn clock_getres(clk_id: i32, tp: *timespec) usize {
    return syscall2(SYS_clock_getres, @bitCast(usize, isize(clk_id)), @ptrToInt(tp));
}

pub fn clock_settime(clk_id: i32, tp: *const timespec) usize {
    return syscall2(SYS_clock_settime, @bitCast(usize, isize(clk_id)), @ptrToInt(tp));
}

pub fn gettimeofday(tv: *timeval, tz: *timezone) usize {
    return syscall2(SYS_gettimeofday, @ptrToInt(tv), @ptrToInt(tz));
}

pub fn settimeofday(tv: *const timeval, tz: *const timezone) usize {
    return syscall2(SYS_settimeofday, @ptrToInt(tv), @ptrToInt(tz));
}

pub fn nanosleep(req: *const timespec, rem: ?*timespec) usize {
    return syscall2(SYS_nanosleep, @ptrToInt(req), @ptrToInt(rem));
}

pub fn setuid(uid: u32) usize {
    return syscall1(SYS_setuid, uid);
}

pub fn setgid(gid: u32) usize {
    return syscall1(SYS_setgid, gid);
}

pub fn setreuid(ruid: u32, euid: u32) usize {
    return syscall2(SYS_setreuid, ruid, euid);
}

pub fn setregid(rgid: u32, egid: u32) usize {
    return syscall2(SYS_setregid, rgid, egid);
}

pub fn getuid() u32 {
    return u32(syscall0(SYS_getuid));
}

pub fn getgid() u32 {
    return u32(syscall0(SYS_getgid));
}

pub fn geteuid() u32 {
    return u32(syscall0(SYS_geteuid));
}

pub fn getegid() u32 {
    return u32(syscall0(SYS_getegid));
}

pub fn seteuid(euid: u32) usize {
    return syscall1(SYS_seteuid, euid);
}

pub fn setegid(egid: u32) usize {
    return syscall1(SYS_setegid, egid);
}

pub fn getresuid(ruid: *u32, euid: *u32, suid: *u32) usize {
    return syscall3(SYS_getresuid, @ptrToInt(ruid), @ptrToInt(euid), @ptrToInt(suid));
}

pub fn getresgid(rgid: *u32, egid: *u32, sgid: *u32) usize {
    return syscall3(SYS_getresgid, @ptrToInt(rgid), @ptrToInt(egid), @ptrToInt(sgid));
}

pub fn setresuid(ruid: u32, euid: u32, suid: u32) usize {
    return syscall3(SYS_setresuid, ruid, euid, suid);
}

pub fn setresgid(rgid: u32, egid: u32, sgid: u32) usize {
    return syscall3(SYS_setresgid, rgid, egid, sgid);
}

pub fn getgroups(size: usize, list: *u32) usize {
    return syscall2(SYS_getgroups, size, @ptrToInt(list));
}

pub fn setgroups(size: usize, list: *const u32) usize {
    return syscall2(SYS_setgroups, size, @ptrToInt(list));
}

pub fn getpid() i32 {
    return @bitCast(i32, @truncate(u32, syscall0(SYS_getpid)));
}

pub fn gettid() i32 {
    return @bitCast(i32, @truncate(u32, syscall0(SYS_gettid)));
}

pub fn sigprocmask(flags: u32, noalias set: *const sigset_t, noalias oldset: ?*sigset_t) usize {
    return syscall4(SYS_rt_sigprocmask, flags, @ptrToInt(set), @ptrToInt(oldset), NSIG / 8);
}

pub fn sigaction(sig: u6, noalias act: *const Sigaction, noalias oact: ?*Sigaction) usize {
    assert(sig >= 1);
    assert(sig != SIGKILL);
    assert(sig != SIGSTOP);
    var ksa = k_sigaction{
        .handler = act.handler,
        .flags = act.flags | SA_RESTORER,
        .mask = undefined,
        .restorer = @ptrCast(extern fn () void, restore_rt),
    };
    var ksa_old: k_sigaction = undefined;
    @memcpy(@ptrCast([*]u8, &ksa.mask), @ptrCast([*]const u8, &act.mask), 8);
    const result = syscall4(SYS_rt_sigaction, sig, @ptrToInt(&ksa), @ptrToInt(&ksa_old), @sizeOf(@typeOf(ksa.mask)));
    const err = getErrno(result);
    if (err != 0) {
        return result;
    }
    if (oact) |old| {
        old.handler = ksa_old.handler;
        old.flags = @truncate(u32, ksa_old.flags);
        @memcpy(@ptrCast([*]u8, &old.mask), @ptrCast([*]const u8, &ksa_old.mask), @sizeOf(@typeOf(ksa_old.mask)));
    }
    return 0;
}

const NSIG = 65;
const sigset_t = [128 / @sizeOf(usize)]usize;
const all_mask = []usize{maxInt(usize)};
const app_mask = []usize{0xfffffffc7fffffff};

const k_sigaction = extern struct {
    handler: extern fn (i32) void,
    flags: usize,
    restorer: extern fn () void,
    mask: [2]u32,
};

/// Renamed from `sigaction` to `Sigaction` to avoid conflict with the syscall.
pub const Sigaction = struct {
    handler: extern fn (i32) void,
    mask: sigset_t,
    flags: u32,
};

pub const SIG_ERR = @intToPtr(extern fn (i32) void, maxInt(usize));
pub const SIG_DFL = @intToPtr(extern fn (i32) void, 0);
pub const SIG_IGN = @intToPtr(extern fn (i32) void, 1);
pub const empty_sigset = []usize{0} ** sigset_t.len;

pub fn raise(sig: i32) usize {
    var set: sigset_t = undefined;
    blockAppSignals(&set);
    const tid = syscall0(SYS_gettid);
    const ret = syscall2(SYS_tkill, tid, @bitCast(usize, isize(sig)));
    restoreSignals(&set);
    return ret;
}

fn blockAllSignals(set: *sigset_t) void {
    _ = syscall4(SYS_rt_sigprocmask, SIG_BLOCK, @ptrToInt(&all_mask), @ptrToInt(set), NSIG / 8);
}

fn blockAppSignals(set: *sigset_t) void {
    _ = syscall4(SYS_rt_sigprocmask, SIG_BLOCK, @ptrToInt(&app_mask), @ptrToInt(set), NSIG / 8);
}

fn restoreSignals(set: *sigset_t) void {
    _ = syscall4(SYS_rt_sigprocmask, SIG_SETMASK, @ptrToInt(set), 0, NSIG / 8);
}

pub fn sigaddset(set: *sigset_t, sig: u6) void {
    const s = sig - 1;
    (set.*)[@intCast(usize, s) / usize.bit_count] |= @intCast(usize, 1) << (s & (usize.bit_count - 1));
}

pub fn sigismember(set: *const sigset_t, sig: u6) bool {
    const s = sig - 1;
    return ((set.*)[@intCast(usize, s) / usize.bit_count] & (@intCast(usize, 1) << (s & (usize.bit_count - 1)))) != 0;
}

pub const in_port_t = u16;
pub const sa_family_t = u16;
pub const socklen_t = u32;

/// This intentionally only has ip4 and ip6
pub const sockaddr = extern union {
    in: sockaddr_in,
    in6: sockaddr_in6,
};

pub const sockaddr_in = extern struct {
    family: sa_family_t,
    port: in_port_t,
    addr: u32,
    zero: [8]u8,
};

pub const sockaddr_in6 = extern struct {
    family: sa_family_t,
    port: in_port_t,
    flowinfo: u32,
    addr: [16]u8,
    scope_id: u32,
};

pub const sockaddr_un = extern struct {
    family: sa_family_t,
    path: [108]u8,
};

pub const iovec = extern struct {
    iov_base: [*]u8,
    iov_len: usize,
};

pub const iovec_const = extern struct {
    iov_base: [*]const u8,
    iov_len: usize,
};

pub fn getsockname(fd: i32, noalias addr: *sockaddr, noalias len: *socklen_t) usize {
    return syscall3(SYS_getsockname, @bitCast(usize, isize(fd)), @ptrToInt(addr), @ptrToInt(len));
}

pub fn getpeername(fd: i32, noalias addr: *sockaddr, noalias len: *socklen_t) usize {
    return syscall3(SYS_getpeername, @bitCast(usize, isize(fd)), @ptrToInt(addr), @ptrToInt(len));
}

pub fn socket(domain: u32, socket_type: u32, protocol: u32) usize {
    return syscall3(SYS_socket, domain, socket_type, protocol);
}

pub fn setsockopt(fd: i32, level: u32, optname: u32, optval: [*]const u8, optlen: socklen_t) usize {
    return syscall5(SYS_setsockopt, @bitCast(usize, isize(fd)), level, optname, @ptrToInt(optval), @intCast(usize, optlen));
}

pub fn getsockopt(fd: i32, level: u32, optname: u32, noalias optval: [*]u8, noalias optlen: *socklen_t) usize {
    return syscall5(SYS_getsockopt, @bitCast(usize, isize(fd)), level, optname, @ptrToInt(optval), @ptrToInt(optlen));
}

pub fn sendmsg(fd: i32, msg: *const msghdr, flags: u32) usize {
    return syscall3(SYS_sendmsg, @bitCast(usize, isize(fd)), @ptrToInt(msg), flags);
}

pub fn connect(fd: i32, addr: *const c_void, len: socklen_t) usize {
    return syscall3(SYS_connect, @bitCast(usize, isize(fd)), @ptrToInt(addr), len);
}

pub fn recvmsg(fd: i32, msg: *msghdr, flags: u32) usize {
    return syscall3(SYS_recvmsg, @bitCast(usize, isize(fd)), @ptrToInt(msg), flags);
}

pub fn recvfrom(fd: i32, noalias buf: [*]u8, len: usize, flags: u32, noalias addr: ?*sockaddr, noalias alen: ?*socklen_t) usize {
    return syscall6(SYS_recvfrom, @bitCast(usize, isize(fd)), @ptrToInt(buf), len, flags, @ptrToInt(addr), @ptrToInt(alen));
}

pub fn shutdown(fd: i32, how: i32) usize {
    return syscall2(SYS_shutdown, @bitCast(usize, isize(fd)), @bitCast(usize, isize(how)));
}

pub fn bind(fd: i32, addr: *const sockaddr, len: socklen_t) usize {
    return syscall3(SYS_bind, @bitCast(usize, isize(fd)), @ptrToInt(addr), @intCast(usize, len));
}

pub fn listen(fd: i32, backlog: u32) usize {
    return syscall2(SYS_listen, @bitCast(usize, isize(fd)), backlog);
}

pub fn sendto(fd: i32, buf: [*]const u8, len: usize, flags: u32, addr: ?*const sockaddr, alen: socklen_t) usize {
    return syscall6(SYS_sendto, @bitCast(usize, isize(fd)), @ptrToInt(buf), len, flags, @ptrToInt(addr), @intCast(usize, alen));
}

pub fn socketpair(domain: i32, socket_type: i32, protocol: i32, fd: [2]i32) usize {
    return syscall4(SYS_socketpair, @intCast(usize, domain), @intCast(usize, socket_type), @intCast(usize, protocol), @ptrToInt(&fd[0]));
}

pub fn accept(fd: i32, noalias addr: *sockaddr, noalias len: *socklen_t) usize {
    return accept4(fd, addr, len, 0);
}

pub fn accept4(fd: i32, noalias addr: *sockaddr, noalias len: *socklen_t, flags: u32) usize {
    return syscall4(SYS_accept4, @bitCast(usize, isize(fd)), @ptrToInt(addr), @ptrToInt(len), flags);
}

pub fn fstat(fd: i32, stat_buf: *Stat) usize {
    return syscall2(SYS_fstat, @bitCast(usize, isize(fd)), @ptrToInt(stat_buf));
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn stat(pathname: [*]const u8, statbuf: *Stat) usize {
    return fstatat(AT_FDCWD, pathname, statbuf, AT_NO_AUTOMOUNT);
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn lstat(pathname: [*]const u8, statbuf: *Stat) usize {
    return fstatat(AF_FDCWD, pathname, statbuf, AT_SYMLINK_NOFOLLOW | AT_NO_AUTOMOUNT);
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn fstatat(dirfd: i32, path: [*]const u8, stat_buf: *Stat, flags: u32) usize {
    return syscall4(SYS_fstatat, @bitCast(usize, isize(dirfd)), @ptrToInt(path), @ptrToInt(stat_buf), flags);
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn listxattr(path: [*]const u8, list: [*]u8, size: usize) usize {
    return syscall3(SYS_listxattr, @ptrToInt(path), @ptrToInt(list), size);
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn llistxattr(path: [*]const u8, list: [*]u8, size: usize) usize {
    return syscall3(SYS_llistxattr, @ptrToInt(path), @ptrToInt(list), size);
}

pub fn flistxattr(fd: usize, list: [*]u8, size: usize) usize {
    return syscall3(SYS_flistxattr, fd, @ptrToInt(list), size);
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn getxattr(path: [*]const u8, name: [*]const u8, value: [*]u8, size: usize) usize {
    return syscall4(SYS_getxattr, @ptrToInt(path), @ptrToInt(name), @ptrToInt(value), size);
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn lgetxattr(path: [*]const u8, name: [*]const u8, value: [*]u8, size: usize) usize {
    return syscall4(SYS_lgetxattr, @ptrToInt(path), @ptrToInt(name), @ptrToInt(value), size);
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn fgetxattr(fd: usize, name: [*]const u8, value: [*]u8, size: usize) usize {
    return syscall4(SYS_lgetxattr, fd, @ptrToInt(name), @ptrToInt(value), size);
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn setxattr(path: [*]const u8, name: [*]const u8, value: *const void, size: usize, flags: usize) usize {
    return syscall5(SYS_setxattr, @ptrToInt(path), @ptrToInt(name), @ptrToInt(value), size, flags);
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn lsetxattr(path: [*]const u8, name: [*]const u8, value: *const void, size: usize, flags: usize) usize {
    return syscall5(SYS_lsetxattr, @ptrToInt(path), @ptrToInt(name), @ptrToInt(value), size, flags);
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn fsetxattr(fd: usize, name: [*]const u8, value: *const void, size: usize, flags: usize) usize {
    return syscall5(SYS_fsetxattr, fd, @ptrToInt(name), @ptrToInt(value), size, flags);
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn removexattr(path: [*]const u8, name: [*]const u8) usize {
    return syscall2(SYS_removexattr, @ptrToInt(path), @ptrToInt(name));
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn lremovexattr(path: [*]const u8, name: [*]const u8) usize {
    return syscall2(SYS_lremovexattr, @ptrToInt(path), @ptrToInt(name));
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn fremovexattr(fd: usize, name: [*]const u8) usize {
    return syscall2(SYS_fremovexattr, fd, @ptrToInt(name));
}

pub fn sched_getaffinity(pid: i32, set: []usize) usize {
    return syscall3(SYS_sched_getaffinity, @bitCast(usize, isize(pid)), set.len * @sizeOf(usize), @ptrToInt(set.ptr));
}

pub const epoll_data = packed union {
    ptr: usize,
    fd: i32,
    @"u32": u32,
    @"u64": u64,
};

pub const epoll_event = packed struct {
    events: u32,
    data: epoll_data,
};

pub fn epoll_create() usize {
    return epoll_create1(0);
}

pub fn epoll_create1(flags: usize) usize {
    return syscall1(SYS_epoll_create1, flags);
}

pub fn epoll_ctl(epoll_fd: i32, op: u32, fd: i32, ev: *epoll_event) usize {
    return syscall4(SYS_epoll_ctl, @bitCast(usize, isize(epoll_fd)), @intCast(usize, op), @bitCast(usize, isize(fd)), @ptrToInt(ev));
}

pub fn epoll_wait(epoll_fd: i32, events: [*]epoll_event, maxevents: u32, timeout: i32) usize {
    return epoll_pwait(epoll_fd, events, maxevents, timeout, null);
}

pub fn epoll_pwait(epoll_fd: i32, events: [*]epoll_event, maxevents: u32, timeout: i32, sigmask: ?*sigset_t) usize {
    return syscall6(
        SYS_epoll_pwait,
        @bitCast(usize, isize(epoll_fd)),
        @ptrToInt(events),
        @intCast(usize, maxevents),
        @bitCast(usize, isize(timeout)),
        @ptrToInt(sigmask),
        @sizeOf(sigset_t),
    );
}

pub fn eventfd(count: u32, flags: u32) usize {
    return syscall2(SYS_eventfd2, count, flags);
}

pub fn timerfd_create(clockid: i32, flags: u32) usize {
    return syscall2(SYS_timerfd_create, @bitCast(usize, isize(clockid)), flags);
}

pub const itimerspec = extern struct {
    it_interval: timespec,
    it_value: timespec,
};

pub fn timerfd_gettime(fd: i32, curr_value: *itimerspec) usize {
    return syscall2(SYS_timerfd_gettime, @bitCast(usize, isize(fd)), @ptrToInt(curr_value));
}

pub fn timerfd_settime(fd: i32, flags: u32, new_value: *const itimerspec, old_value: ?*itimerspec) usize {
    return syscall4(SYS_timerfd_settime, @bitCast(usize, isize(fd)), flags, @ptrToInt(new_value), @ptrToInt(old_value));
}

pub const _LINUX_CAPABILITY_VERSION_1 = 0x19980330;
pub const _LINUX_CAPABILITY_U32S_1 = 1;

pub const _LINUX_CAPABILITY_VERSION_2 = 0x20071026;
pub const _LINUX_CAPABILITY_U32S_2 = 2;

pub const _LINUX_CAPABILITY_VERSION_3 = 0x20080522;
pub const _LINUX_CAPABILITY_U32S_3 = 2;

pub const VFS_CAP_REVISION_MASK = 0xFF000000;
pub const VFS_CAP_REVISION_SHIFT = 24;
pub const VFS_CAP_FLAGS_MASK = ~VFS_CAP_REVISION_MASK;
pub const VFS_CAP_FLAGS_EFFECTIVE = 0x000001;

pub const VFS_CAP_REVISION_1 = 0x01000000;
pub const VFS_CAP_U32_1 = 1;
pub const XATTR_CAPS_SZ_1 = @sizeOf(u32) * (1 + 2 * VFS_CAP_U32_1);

pub const VFS_CAP_REVISION_2 = 0x02000000;
pub const VFS_CAP_U32_2 = 2;
pub const XATTR_CAPS_SZ_2 = @sizeOf(u32) * (1 + 2 * VFS_CAP_U32_2);

pub const XATTR_CAPS_SZ = XATTR_CAPS_SZ_2;
pub const VFS_CAP_U32 = VFS_CAP_U32_2;
pub const VFS_CAP_REVISION = VFS_CAP_REVISION_2;

pub const vfs_cap_data = extern struct {
    //all of these are mandated as little endian
    //when on disk.
    const Data = struct {
        permitted: u32,
        inheritable: u32,
    };

    magic_etc: u32,
    data: [VFS_CAP_U32]Data,
};

pub const CAP_CHOWN = 0;
pub const CAP_DAC_OVERRIDE = 1;
pub const CAP_DAC_READ_SEARCH = 2;
pub const CAP_FOWNER = 3;
pub const CAP_FSETID = 4;
pub const CAP_KILL = 5;
pub const CAP_SETGID = 6;
pub const CAP_SETUID = 7;
pub const CAP_SETPCAP = 8;
pub const CAP_LINUX_IMMUTABLE = 9;
pub const CAP_NET_BIND_SERVICE = 10;
pub const CAP_NET_BROADCAST = 11;
pub const CAP_NET_ADMIN = 12;
pub const CAP_NET_RAW = 13;
pub const CAP_IPC_LOCK = 14;
pub const CAP_IPC_OWNER = 15;
pub const CAP_SYS_MODULE = 16;
pub const CAP_SYS_RAWIO = 17;
pub const CAP_SYS_CHROOT = 18;
pub const CAP_SYS_PTRACE = 19;
pub const CAP_SYS_PACCT = 20;
pub const CAP_SYS_ADMIN = 21;
pub const CAP_SYS_BOOT = 22;
pub const CAP_SYS_NICE = 23;
pub const CAP_SYS_RESOURCE = 24;
pub const CAP_SYS_TIME = 25;
pub const CAP_SYS_TTY_CONFIG = 26;
pub const CAP_MKNOD = 27;
pub const CAP_LEASE = 28;
pub const CAP_AUDIT_WRITE = 29;
pub const CAP_AUDIT_CONTROL = 30;
pub const CAP_SETFCAP = 31;
pub const CAP_MAC_OVERRIDE = 32;
pub const CAP_MAC_ADMIN = 33;
pub const CAP_SYSLOG = 34;
pub const CAP_WAKE_ALARM = 35;
pub const CAP_BLOCK_SUSPEND = 36;
pub const CAP_AUDIT_READ = 37;
pub const CAP_LAST_CAP = CAP_AUDIT_READ;

pub fn cap_valid(u8: x) bool {
    return x >= 0 and x <= CAP_LAST_CAP;
}

pub fn CAP_TO_MASK(cap: u8) u32 {
    return u32(1) << u5(cap & 31);
}

pub fn CAP_TO_INDEX(cap: u8) u8 {
    return cap >> 5;
}

pub const cap_t = extern struct {
    hdrp: *cap_user_header_t,
    datap: *cap_user_data_t,
};

pub const cap_user_header_t = extern struct {
    version: u32,
    pid: usize,
};

pub const cap_user_data_t = extern struct {
    effective: u32,
    permitted: u32,
    inheritable: u32,
};

pub fn unshare(flags: usize) usize {
    return syscall1(SYS_unshare, flags);
}

pub fn capget(hdrp: *cap_user_header_t, datap: *cap_user_data_t) usize {
    return syscall2(SYS_capget, @ptrToInt(hdrp), @ptrToInt(datap));
}

pub fn capset(hdrp: *cap_user_header_t, datap: *const cap_user_data_t) usize {
    return syscall2(SYS_capset, @ptrToInt(hdrp), @ptrToInt(datap));
}

pub const inotify_event = extern struct {
    wd: i32,
    mask: u32,
    cookie: u32,
    len: u32,
    //name: [?]u8,
};

pub const dirent64 = extern struct {
    d_ino: u64,
    d_off: u64,
    d_reclen: u16,
    d_type: u8,
    d_name: u8, // field address is the address of first byte of name https://github.com/ziglang/zig/issues/173
};

test "import" {
    if (builtin.os == builtin.Os.linux) {
        _ = @import("test.zig");
    }
}
