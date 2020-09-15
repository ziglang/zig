// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../../../std.zig");

const in_bpf_program = switch (std.builtin.arch) {
    .bpfel, .bpfeb => true,
    else => false,
};

pub const helpers = if (in_bpf_program) @import("helpers.zig") else struct {};

pub const BpfSock = @Type(.Opaque);
pub const BpfSockAddr = @Type(.Opaque);
pub const FibLookup = @Type(.Opaque);
pub const MapDef = @Type(.Opaque);
pub const PerfEventData = @Type(.Opaque);
pub const PerfEventValue = @Type(.Opaque);
pub const PidNsInfo = @Type(.Opaque);
pub const SeqFile = @Type(.Opaque);
pub const SkBuff = @Type(.Opaque);
pub const SkMsgMd = @Type(.Opaque);
pub const SkReusePortMd = @Type(.Opaque);
pub const Sock = @Type(.Opaque);
pub const SockAddr = @Type(.Opaque);
pub const SockOps = @Type(.Opaque);
pub const SockTuple = @Type(.Opaque);
pub const SpinLock = @Type(.Opaque);
pub const SysCtl = @Type(.Opaque);
pub const Tcp6Sock = @Type(.Opaque);
pub const TcpRequestSock = @Type(.Opaque);
pub const TcpSock = @Type(.Opaque);
pub const TcpTimewaitSock = @Type(.Opaque);
pub const TunnelKey = @Type(.Opaque);
pub const Udp6Sock = @Type(.Opaque);
pub const XdpMd = @Type(.Opaque);
pub const XfrmState = @Type(.Opaque);
