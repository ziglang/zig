// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
usingnamespace @import("../linux.zig");

pub const XDP_SHARED_UMEM = (1 << 0);
pub const XDP_COPY = (1 << 1);
pub const XDP_ZEROCOPY = (1 << 2);

pub const XDP_UMEM_UNALIGNED_CHUNK_FLAG = (1 << 0);

pub const sockaddr_xdp = extern struct {
    family: u16 = AF_XDP,
    flags: u16,
    ifindex: u32,
    queue_id: u32,
    shared_umem_fd: u32,
};

pub const XDP_USE_NEED_WAKEUP = (1 << 3);

pub const xdp_ring_offset = extern struct {
    producer: u64,
    consumer: u64,
    desc: u64,
    flags: u64,
};

pub const xdp_mmap_offsets = extern struct {
    rx: xdp_ring_offset,
    tx: xdp_ring_offset,
    fr: xdp_ring_offset,
    cr: xdp_ring_offset,
};

pub const XDP_MMAP_OFFSETS = 1;
pub const XDP_RX_RING = 2;
pub const XDP_TX_RING = 3;
pub const XDP_UMEM_REG = 4;
pub const XDP_UMEM_FILL_RING = 5;
pub const XDP_UMEM_COMPLETION_RING = 6;
pub const XDP_STATISTICS = 7;
pub const XDP_OPTIONS = 8;

pub const xdp_umem_reg = extern struct {
    addr: u64,
    len: u64,
    chunk_size: u32,
    headroom: u32,
    flags: u32,
};

pub const xdp_statistics = extern struct {
    rx_dropped: u64,
    rx_invalid_descs: u64,
    tx_invalid_descs: u64,
    rx_ring_full: u64,
    rx_fill_ring_empty_descs: u64,
    tx_ring_empty_descs: u64,
};

pub const xdp_options = extern struct {
    flags: u32,
};

pub const XDP_OPTIONS_ZEROCOPY = (1 << 0);

pub const XDP_PGOFF_RX_RING = 0;
pub const XDP_PGOFF_TX_RING = 0x80000000;
pub const XDP_UMEM_PGOFF_FILL_RING = 0x100000000;
pub const XDP_UMEM_PGOFF_COMPLETION_RING = 0x180000000;

pub const XSK_UNALIGNED_BUF_OFFSET_SHIFT = 48;
pub const XSK_UNALIGNED_BUF_ADDR_MASK = (1 << XSK_UNALIGNED_BUF_OFFSET_SHIFT) - 1;

pub const xdp_desc = extern struct {
    addr: u64,
    len: u32,
    options: u32,
};
