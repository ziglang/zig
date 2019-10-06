pub const SYS_read = 3;
pub const SYS_write = 4;
pub const SYS_close = 6;
pub const SYS_ioctl = 54;
pub const SYS_mmap = 90;
pub const SYS_munmap = 91;
pub const SYS_fstat = 108;
pub const SYS__llseek = 140;
pub const SYS_arch_prctl = 172;
pub const SYS_rt_sigreturn = 173;
pub const SYS_rt_sigaction = 174;
pub const SYS_rt_sigprocmask = 175;
pub const SYS_mmap2 = 192;
pub const SYS_gettid = 224;
pub const SYS_tkill = 238;
pub const SYS_futex = 240;
pub const SYS_set_thread_area = 243;
pub const SYS_exit_group = 252;
pub const SYS_openat = 295;

pub const MMAP2_UNIT = 4096;

pub const O_LARGEFILE = 0x8000;

pub const UserDesc = struct {
    entry_num: u32,
    base_addr: u32,
    limit: u32,
    seg_32bit: u1,
    contents: u2,
    read_exec_only: u1,
    limit_in_pages: u1,
    seg_not_present: u1,
    useable: u1,
};

pub const timespec = extern struct {
    tv_sec: i32,
    tv_nsec: i32,
};

pub const Stat = extern struct {
    dev: u64,
    _pad0: [4]u8,
    ino: u64,
    mode: u32,
    nlink: u32,
    uid: u32,
    gid: u32,
    rdev: u64,
    _pad1: [4]u8,
    size: i64,
    blksize: u32,
    blocks: u64,
    atim: timespec,
    mtim: timespec,
    ctim: timespec,
    unused: [2]u32,

    pub fn atime(self: Stat) timespec {
        return self.atim;
    }

    pub fn mtime(self: Stat) timespec {
        return self.mtim;
    }

    pub fn ctime(self: Stat) timespec {
        return self.ctim;
    }
};
