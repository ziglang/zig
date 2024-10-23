const std = @import("../std.zig");
const assert = std.debug.assert;
const builtin = @import("builtin");
const maxInt = std.math.maxInt;
const iovec = std.posix.iovec;
const iovec_const = std.posix.iovec_const;
const socklen_t = std.c.socklen_t;
const fd_t = std.c.fd_t;
const PATH_MAX = std.c.PATH_MAX;
const uid_t = std.c.uid_t;
const gid_t = std.c.gid_t;
const dev_t = std.c.dev_t;
const ino_t = std.c.ino_t;

comptime {
    assert(builtin.os.tag == .haiku); // Prevent access of std.c symbols on wrong OS.
}

pub extern "root" fn _errnop() *i32;
pub extern "root" fn find_directory(which: directory_which, volume: i32, createIt: bool, path_ptr: [*]u8, length: i32) u64;
pub extern "root" fn find_thread(thread_name: ?*anyopaque) i32;
pub extern "root" fn get_system_info(system_info: *system_info) usize;
pub extern "root" fn _get_team_info(team: i32, team_info: *team_info, size: usize) i32;
pub extern "root" fn _get_next_area_info(team: i32, cookie: *i64, area_info: *area_info, size: usize) i32;
pub extern "root" fn _get_next_image_info(team: i32, cookie: *i32, image_info: *image_info, size: usize) i32;

pub const area_info = extern struct {
    area: u32,
    name: [32]u8,
    size: usize,
    lock: u32,
    protection: u32,
    team_id: i32,
    ram_size: u32,
    copy_count: u32,
    in_count: u32,
    out_count: u32,
    address: *anyopaque,
};

pub const image_info = extern struct {
    id: u32,
    image_type: u32,
    sequence: i32,
    init_order: i32,
    init_routine: *anyopaque,
    term_routine: *anyopaque,
    device: i32,
    node: i64,
    name: [PATH_MAX]u8,
    text: *anyopaque,
    data: *anyopaque,
    text_size: i32,
    data_size: i32,
    api_version: i32,
    abi: i32,
};

pub const system_info = extern struct {
    boot_time: i64,
    cpu_count: u32,
    max_pages: u64,
    used_pages: u64,
    cached_pages: u64,
    block_cache_pages: u64,
    ignored_pages: u64,
    needed_memory: u64,
    free_memory: u64,
    max_swap_pages: u64,
    free_swap_pages: u64,
    page_faults: u32,
    max_sems: u32,
    used_sems: u32,
    max_ports: u32,
    used_ports: u32,
    max_threads: u32,
    used_threads: u32,
    max_teams: u32,
    used_teams: u32,
    kernel_name: [256]u8,
    kernel_build_date: [32]u8,
    kernel_build_time: [32]u8,
    kernel_version: i64,
    abi: u32,
};

pub const team_info = extern struct {
    team_id: i32,
    thread_count: i32,
    image_count: i32,
    area_count: i32,
    debugger_nub_thread: i32,
    debugger_nub_port: i32,
    argc: i32,
    args: [64]u8,
    uid: uid_t,
    gid: gid_t,
};

pub const directory_which = enum(i32) {
    B_USER_SETTINGS_DIRECTORY = 0xbbe,

    _,
};

pub const area_id = i32;
pub const port_id = i32;
pub const sem_id = i32;
pub const team_id = i32;
pub const thread_id = i32;

pub const E = enum(i32) {
    pub const B_GENERAL_ERROR_BASE: i32 = std.math.minInt(i32);
    pub const B_OS_ERROR_BASE = B_GENERAL_ERROR_BASE + 0x1000;
    pub const B_APP_ERROR_BASE = B_GENERAL_ERROR_BASE + 0x2000;
    pub const B_INTERFACE_ERROR_BASE = B_GENERAL_ERROR_BASE + 0x3000;
    pub const B_MEDIA_ERROR_BASE = B_GENERAL_ERROR_BASE + 0x4000;
    pub const B_TRANSLATION_ERROR_BASE = B_GENERAL_ERROR_BASE + 0x4800;
    pub const B_MIDI_ERROR_BASE = B_GENERAL_ERROR_BASE + 0x5000;
    pub const B_STORAGE_ERROR_BASE = B_GENERAL_ERROR_BASE + 0x6000;
    pub const B_POSIX_ERROR_BASE = B_GENERAL_ERROR_BASE + 0x7000;
    pub const B_MAIL_ERROR_BASE = B_GENERAL_ERROR_BASE + 0x8000;
    pub const B_PRINT_ERROR_BASE = B_GENERAL_ERROR_BASE + 0x9000;
    pub const B_DEVICE_ERROR_BASE = B_GENERAL_ERROR_BASE + 0xa000;

    pub const B_ERRORS_END = B_GENERAL_ERROR_BASE + 0xffff;

    pub const B_NO_MEMORY = B_GENERAL_ERROR_BASE + 0;
    pub const B_IO_ERROR = B_GENERAL_ERROR_BASE + 1;
    pub const B_PERMISSION_DENIED = B_GENERAL_ERROR_BASE + 2;
    pub const B_BAD_INDEX = B_GENERAL_ERROR_BASE + 3;
    pub const B_BAD_TYPE = B_GENERAL_ERROR_BASE + 4;
    pub const B_BAD_VALUE = B_GENERAL_ERROR_BASE + 5;
    pub const B_MISMATCHED_VALUES = B_GENERAL_ERROR_BASE + 6;
    pub const B_NAME_NOT_FOUND = B_GENERAL_ERROR_BASE + 7;
    pub const B_NAME_IN_USE = B_GENERAL_ERROR_BASE + 8;
    pub const B_TIMED_OUT = B_GENERAL_ERROR_BASE + 9;
    pub const B_INTERRUPTED = B_GENERAL_ERROR_BASE + 10;
    pub const B_WOULD_BLOCK = B_GENERAL_ERROR_BASE + 11;
    pub const B_CANCELED = B_GENERAL_ERROR_BASE + 12;
    pub const B_NO_INIT = B_GENERAL_ERROR_BASE + 13;
    pub const B_NOT_INITIALIZED = B_GENERAL_ERROR_BASE + 13;
    pub const B_BUSY = B_GENERAL_ERROR_BASE + 14;
    pub const B_NOT_ALLOWED = B_GENERAL_ERROR_BASE + 15;
    pub const B_BAD_DATA = B_GENERAL_ERROR_BASE + 16;
    pub const B_DONT_DO_THAT = B_GENERAL_ERROR_BASE + 17;

    pub const B_BAD_IMAGE_ID = B_OS_ERROR_BASE + 0x300;
    pub const B_BAD_ADDRESS = B_OS_ERROR_BASE + 0x301;
    pub const B_NOT_AN_EXECUTABLE = B_OS_ERROR_BASE + 0x302;
    pub const B_MISSING_LIBRARY = B_OS_ERROR_BASE + 0x303;
    pub const B_MISSING_SYMBOL = B_OS_ERROR_BASE + 0x304;
    pub const B_UNKNOWN_EXECUTABLE = B_OS_ERROR_BASE + 0x305;
    pub const B_LEGACY_EXECUTABLE = B_OS_ERROR_BASE + 0x306;

    pub const B_FILE_ERROR = B_STORAGE_ERROR_BASE + 0;
    pub const B_FILE_EXISTS = B_STORAGE_ERROR_BASE + 2;
    pub const B_ENTRY_NOT_FOUND = B_STORAGE_ERROR_BASE + 3;
    pub const B_NAME_TOO_LONG = B_STORAGE_ERROR_BASE + 4;
    pub const B_NOT_A_DIRECTORY = B_STORAGE_ERROR_BASE + 5;
    pub const B_DIRECTORY_NOT_EMPTY = B_STORAGE_ERROR_BASE + 6;
    pub const B_DEVICE_FULL = B_STORAGE_ERROR_BASE + 7;
    pub const B_READ_ONLY_DEVICE = B_STORAGE_ERROR_BASE + 8;
    pub const B_IS_A_DIRECTORY = B_STORAGE_ERROR_BASE + 9;
    pub const B_NO_MORE_FDS = B_STORAGE_ERROR_BASE + 10;
    pub const B_CROSS_DEVICE_LINK = B_STORAGE_ERROR_BASE + 11;
    pub const B_LINK_LIMIT = B_STORAGE_ERROR_BASE + 12;
    pub const B_BUSTED_PIPE = B_STORAGE_ERROR_BASE + 13;
    pub const B_UNSUPPORTED = B_STORAGE_ERROR_BASE + 14;
    pub const B_PARTITION_TOO_SMALL = B_STORAGE_ERROR_BASE + 15;
    pub const B_PARTIAL_READ = B_STORAGE_ERROR_BASE + 16;
    pub const B_PARTIAL_WRITE = B_STORAGE_ERROR_BASE + 17;

    SUCCESS = 0,

    @"2BIG" = B_POSIX_ERROR_BASE + 1,
    CHILD = B_POSIX_ERROR_BASE + 2,
    DEADLK = B_POSIX_ERROR_BASE + 3,
    FBIG = B_POSIX_ERROR_BASE + 4,
    MLINK = B_POSIX_ERROR_BASE + 5,
    NFILE = B_POSIX_ERROR_BASE + 6,
    NODEV = B_POSIX_ERROR_BASE + 7,
    NOLCK = B_POSIX_ERROR_BASE + 8,
    NOSYS = B_POSIX_ERROR_BASE + 9,
    NOTTY = B_POSIX_ERROR_BASE + 10,
    NXIO = B_POSIX_ERROR_BASE + 11,
    SPIPE = B_POSIX_ERROR_BASE + 12,
    SRCH = B_POSIX_ERROR_BASE + 13,
    FPOS = B_POSIX_ERROR_BASE + 14,
    SIGPARM = B_POSIX_ERROR_BASE + 15,
    DOM = B_POSIX_ERROR_BASE + 16,
    RANGE = B_POSIX_ERROR_BASE + 17,
    PROTOTYPE = B_POSIX_ERROR_BASE + 18,
    PROTONOSUPPORT = B_POSIX_ERROR_BASE + 19,
    PFNOSUPPORT = B_POSIX_ERROR_BASE + 20,
    AFNOSUPPORT = B_POSIX_ERROR_BASE + 21,
    ADDRINUSE = B_POSIX_ERROR_BASE + 22,
    ADDRNOTAVAIL = B_POSIX_ERROR_BASE + 23,
    NETDOWN = B_POSIX_ERROR_BASE + 24,
    NETUNREACH = B_POSIX_ERROR_BASE + 25,
    NETRESET = B_POSIX_ERROR_BASE + 26,
    CONNABORTED = B_POSIX_ERROR_BASE + 27,
    CONNRESET = B_POSIX_ERROR_BASE + 28,
    ISCONN = B_POSIX_ERROR_BASE + 29,
    NOTCONN = B_POSIX_ERROR_BASE + 30,
    SHUTDOWN = B_POSIX_ERROR_BASE + 31,
    CONNREFUSED = B_POSIX_ERROR_BASE + 32,
    HOSTUNREACH = B_POSIX_ERROR_BASE + 33,
    NOPROTOOPT = B_POSIX_ERROR_BASE + 34,
    NOBUFS = B_POSIX_ERROR_BASE + 35,
    INPROGRESS = B_POSIX_ERROR_BASE + 36,
    ALREADY = B_POSIX_ERROR_BASE + 37,
    ILSEQ = B_POSIX_ERROR_BASE + 38,
    NOMSG = B_POSIX_ERROR_BASE + 39,
    STALE = B_POSIX_ERROR_BASE + 40,
    OVERFLOW = B_POSIX_ERROR_BASE + 41,
    MSGSIZE = B_POSIX_ERROR_BASE + 42,
    OPNOTSUPP = B_POSIX_ERROR_BASE + 43,
    NOTSOCK = B_POSIX_ERROR_BASE + 44,
    HOSTDOWN = B_POSIX_ERROR_BASE + 45,
    BADMSG = B_POSIX_ERROR_BASE + 46,
    CANCELED = B_POSIX_ERROR_BASE + 47,
    DESTADDRREQ = B_POSIX_ERROR_BASE + 48,
    DQUOT = B_POSIX_ERROR_BASE + 49,
    IDRM = B_POSIX_ERROR_BASE + 50,
    MULTIHOP = B_POSIX_ERROR_BASE + 51,
    NODATA = B_POSIX_ERROR_BASE + 52,
    NOLINK = B_POSIX_ERROR_BASE + 53,
    NOSR = B_POSIX_ERROR_BASE + 54,
    NOSTR = B_POSIX_ERROR_BASE + 55,
    NOTSUP = B_POSIX_ERROR_BASE + 56,
    PROTO = B_POSIX_ERROR_BASE + 57,
    TIME = B_POSIX_ERROR_BASE + 58,
    TXTBSY = B_POSIX_ERROR_BASE + 59,
    NOATTR = B_POSIX_ERROR_BASE + 60,
    NOTRECOVERABLE = B_POSIX_ERROR_BASE + 61,
    OWNERDEAD = B_POSIX_ERROR_BASE + 62,

    NOMEM = B_NO_MEMORY,

    ACCES = B_PERMISSION_DENIED,
    INTR = B_INTERRUPTED,
    IO = B_IO_ERROR,
    BUSY = B_BUSY,
    FAULT = B_BAD_ADDRESS,
    TIMEDOUT = B_TIMED_OUT,
    /// Also used for WOULDBLOCK
    AGAIN = B_WOULD_BLOCK,
    BADF = B_FILE_ERROR,
    EXIST = B_FILE_EXISTS,
    INVAL = B_BAD_VALUE,
    NAMETOOLONG = B_NAME_TOO_LONG,
    NOENT = B_ENTRY_NOT_FOUND,
    PERM = B_NOT_ALLOWED,
    NOTDIR = B_NOT_A_DIRECTORY,
    ISDIR = B_IS_A_DIRECTORY,
    NOTEMPTY = B_DIRECTORY_NOT_EMPTY,
    NOSPC = B_DEVICE_FULL,
    ROFS = B_READ_ONLY_DEVICE,
    MFILE = B_NO_MORE_FDS,
    XDEV = B_CROSS_DEVICE_LINK,
    LOOP = B_LINK_LIMIT,
    NOEXEC = B_NOT_AN_EXECUTABLE,
    PIPE = B_BUSTED_PIPE,

    _,
};

pub const status_t = i32;

pub const mcontext_t = switch (builtin.cpu.arch) {
    .arm, .thumb => extern struct {
        r0: u32,
        r1: u32,
        r2: u32,
        r3: u32,
        r4: u32,
        r5: u32,
        r6: u32,
        r7: u32,
        r8: u32,
        r9: u32,
        r10: u32,
        r11: u32,
        r12: u32,
        r13: u32,
        r14: u32,
        r15: u32,
        cpsr: u32,
    },
    .aarch64 => extern struct {
        x: [10]u64,
        lr: u64,
        sp: u64,
        elr: u64,
        spsr: u64,
        fp_q: [32]u128,
        fpsr: u32,
        fpcr: u32,
    },
    .m68k => extern struct {
        pc: u32,
        d0: u32,
        d1: u32,
        d2: u32,
        d3: u32,
        d4: u32,
        d5: u32,
        d6: u32,
        d7: u32,
        a0: u32,
        a1: u32,
        a2: u32,
        a3: u32,
        a4: u32,
        a5: u32,
        a6: u32,
        a7: u32,
        ccr: u8,
        f0: f64,
        f1: f64,
        f2: f64,
        f3: f64,
        f4: f64,
        f5: f64,
        f6: f64,
        f7: f64,
        f8: f64,
        f9: f64,
        f10: f64,
        f11: f64,
        f12: f64,
        f13: f64,
    },
    .mipsel => extern struct {
        r0: u32,
    },
    .powerpc => extern struct {
        pc: u32,
        r0: u32,
        r1: u32,
        r2: u32,
        r3: u32,
        r4: u32,
        r5: u32,
        r6: u32,
        r7: u32,
        r8: u32,
        r9: u32,
        r10: u32,
        r11: u32,
        r12: u32,
        f0: f64,
        f1: f64,
        f2: f64,
        f3: f64,
        f4: f64,
        f5: f64,
        f6: f64,
        f7: f64,
        f8: f64,
        f9: f64,
        f10: f64,
        f11: f64,
        f12: f64,
        f13: f64,
        reserved: u32,
        fpscr: u32,
        ctr: u32,
        xer: u32,
        cr: u32,
        msr: u32,
        lr: u32,
    },
    .riscv64 => extern struct {
        x: [31]u64,
        pc: u64,
        f: [32]f64,
        fcsr: u64,
    },
    .sparc64 => extern struct {
        g1: u64,
        g2: u64,
        g3: u64,
        g4: u64,
        g5: u64,
        g6: u64,
        g7: u64,
        o0: u64,
        o1: u64,
        o2: u64,
        o3: u64,
        o4: u64,
        o5: u64,
        sp: u64,
        o7: u64,
        l0: u64,
        l1: u64,
        l2: u64,
        l3: u64,
        l4: u64,
        l5: u64,
        l6: u64,
        l7: u64,
        i0: u64,
        i1: u64,
        i2: u64,
        i3: u64,
        i4: u64,
        i5: u64,
        fp: u64,
        i7: u64,
    },
    .x86 => extern struct {
        pub const old_extended_regs = extern struct {
            control: u16,
            reserved1: u16,
            status: u16,
            reserved2: u16,
            tag: u16,
            reserved3: u16,
            eip: u32,
            cs: u16,
            opcode: u16,
            datap: u32,
            ds: u16,
            reserved4: u16,
            fp_mmx: [8][10]u8,
        };

        pub const fp_register = extern struct { value: [10]u8, reserved: [6]u8 };

        pub const xmm_register = extern struct { value: [16]u8 };

        pub const new_extended_regs = extern struct {
            control: u16,
            status: u16,
            tag: u16,
            opcode: u16,
            eip: u32,
            cs: u16,
            reserved1: u16,
            datap: u32,
            ds: u16,
            reserved2: u16,
            mxcsr: u32,
            reserved3: u32,
            fp_mmx: [8]fp_register,
            xmmx: [8]xmm_register,
            reserved4: [224]u8,
        };

        pub const extended_regs = extern struct {
            state: extern union {
                old_format: old_extended_regs,
                new_format: new_extended_regs,
            },
            format: u32,
        };

        eip: u32,
        eflags: u32,
        eax: u32,
        ecx: u32,
        edx: u32,
        esp: u32,
        ebp: u32,
        reserved: u32,
        xregs: extended_regs,
        edi: u32,
        esi: u32,
        ebx: u32,
    },
    .x86_64 => extern struct {
        pub const fp_register = extern struct {
            value: [10]u8,
            reserved: [6]u8,
        };

        pub const xmm_register = extern struct {
            value: [16]u8,
        };

        pub const fpu_state = extern struct {
            control: u16,
            status: u16,
            tag: u16,
            opcode: u16,
            rip: u64,
            rdp: u64,
            mxcsr: u32,
            mscsr_mask: u32,

            fp_mmx: [8]fp_register,
            xmm: [16]xmm_register,
            reserved: [96]u8,
        };

        pub const xstate_hdr = extern struct {
            bv: u64,
            xcomp_bv: u64,
            reserved: [48]u8,
        };

        pub const savefpu = extern struct {
            fxsave: fpu_state,
            xstate: xstate_hdr,
            ymm: [16]xmm_register,
        };

        rax: u64,
        rbx: u64,
        rcx: u64,
        rdx: u64,
        rdi: u64,
        rsi: u64,
        rbp: u64,
        r8: u64,
        r9: u64,
        r10: u64,
        r11: u64,
        r12: u64,
        r13: u64,
        r14: u64,
        r15: u64,
        rsp: u64,
        rip: u64,
        rflags: u64,
        fpu: savefpu,
    },
    else => void,
};

pub const DirEnt = extern struct {
    /// device
    dev: dev_t,
    /// parent device (only for queries)
    pdev: dev_t,
    /// inode number
    ino: ino_t,
    /// parent inode (only for queries)
    pino: ino_t,
    /// length of this record, not the name
    reclen: u16,
    /// name of the entry (null byte terminated)
    name: [0]u8,
    pub fn getName(dirent: *const DirEnt) [*:0]const u8 {
        return @ptrCast(&dirent.name);
    }
};
