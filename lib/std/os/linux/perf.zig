const std = @import("std");
usingnamespace std.os.linux;

pub const COUNT_SW_BPF_OUTPUT = 10;
pub const TYPE_SOFTWARE = 1;
pub const SAMPLE_RAW = 1 << 10;
pub const FLAG_FD_CLOEXEC = 1 << 3;

pub const RECORD_LOST = 2;
pub const RECORD_SAMPLE = 9;

pub const EVENT_IOC_ENABLE = @bitCast(u32, IO('$', 0));
pub const EVENT_IOC_DISABLE = @bitCast(u32, IO('$', 1));
pub const set_bpf = @bitCast(u32, IOW('$', 8, fd_t));

pub const EventHeader = extern struct {
    type: u32,
    misc: u16,
    size: u16,
};

pub const SampleRaw = extern struct {
    header: EventHeader,
    size: u32,
    // data afterwards
};

pub const SampleLost = extern struct {
    header: EventHeader,
    id: u64,
    lost: u64,
    sample_id: u64,
};

pub const MmapPage = extern struct {
    version: u32,
    compat_version: u32,
    lock: u32,
    index: u32,
    offset: i64,
    time_enabled: u64,
    time_running: u64,
    capabilities: u64, // TODO: expand
    pmc_width: u16,
    time_shift: u16,
    time_mult: u32,
    time_offset: u64,
    time_zero: u64,
    size: u32,
    __reserved: [118 * 8 * 4]u8,
    data_head: u64,
    data_tail: u64,
    data_offset: u64,
    data_size: u64,
    aux_head: u64,
    aux_tail: u64,
    aux_offset: u64,
    aux_size: u64,
};

pub const EventAttr = extern struct {
    type: u32,
    size: u32,
    config: u64,
    sample: extern union {
        period: u64,
        freq: u64,
    },
    sample_type: u64,
    read_format: u64,
    flags: u64, // TODO: expand
    wakeup: extern union {
        events: u32,
        watermark: u32,
    },
    bp_type: u32,
    unnamed_1: extern union {
        bp_addr: u64,
        kprobe_func: u64,
        uprobe_func: u64,
        config1: u64,
    },
    unnamed_2: extern union {
        bp_len: u64,
        kprobe_addr: u64,
        probe_offset: u64,
        config2: u64,
    },
    branch_sample_type: u64,
    sample_regs_user: u64,
    sample_stack_user: u32,
    clockid: i32,
    sample_regs_intr: u64,
    aux_watermark: u32,
    sample_max_stack: u16,
    __reserved_2: u16,
    aux_sample_size: u32,
    __reserved_3: u32,
};
